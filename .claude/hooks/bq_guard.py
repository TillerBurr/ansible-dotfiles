#!/usr/bin/env python3
"""PreToolUse Bash hook: block writes via `bq` and inline-python BigQuery.

Reads the Claude Code hook JSON envelope on stdin. Prints
{"decision":"block","reason":"..."} to stdout when blocking, or nothing
when allowing. Always exits 0 (the JSON conveys the decision).

Fails closed: parse errors, unbalanced quotes, or unexpected exceptions
all block with a reason.

Policy (see PR discussion):
  * Allowed bq subcommands: query, show, ls, head, help, version.
  * `bq query` blocks write flags and DDL/DML keywords.
  * Opaque wrappers (eval, bash -c, xargs, command substitution, stdin
    redirect, --flagfile) involving `bq` are refused — hook can't see
    through indirection.
  * Inline `python -c` / heredoc python / `python -m` that imports or
    references google.cloud.bigquery is blocked outright (strict mode),
    even for ostensibly read-only ops, because the cost of a false
    negative outweighs the inconvenience.
"""

from __future__ import annotations

import json
import re
import shlex
import sys
from typing import NoReturn

ALLOWED_BQ_SUBCMDS = {"query", "show", "ls", "head", "help", "version"}

# Word-boundaried via explicit non-word lookarounds rather than \b, which
# has inconsistent semantics across regex engines.
DESTRUCTIVE_SQL = re.compile(
    r"(?:^|[^a-z0-9_])"
    r"(?:insert|update|delete|merge|drop|create|alter|truncate|load|call|grant|revoke)"
    r"(?:[^a-z0-9_]|$)"
    r"|(?:^|[^a-z0-9_])export[\s]+data(?:[^a-z0-9_]|$)",
    re.IGNORECASE,
)

WRITE_FLAGS = re.compile(
    r"(?:--destination_table|--append_table|--replace(?:[=\s]|$))",
    re.IGNORECASE,
)

PY_BQ_IMPORT = re.compile(
    r"google\s*\.\s*cloud\s*\.\s*bigquery"
    r"|from\s+google\.cloud\s+import\s+bigquery"
    r"|from\s+google\.cloud\.bigquery",
    re.IGNORECASE,
)

OPAQUE_WRAPPER = re.compile(
    r"\beval\b"
    r"|\b(?:bash|sh|zsh)\s+-[a-z]*c\b"
    r"|\bxargs\b",
    re.IGNORECASE,
)

# Commands whose arguments are human-readable text bodies (commit messages,
# PR descriptions). Their argument strings frequently contain words like "bq"
# or "bash -c" as literal data, which would otherwise trip OPAQUE_WRAPPER and
# the python tripwire. They never invoke bq themselves, so we short-circuit.
# Known loophole: `git commit -m "$(bq cp ...)"` would execute via command
# substitution. Acceptable; defense-in-depth, not the boundary.
TEXT_HEAVY_EXECS = {"git", "gh"}

COMMAND_SUB = re.compile(r"\$\([^)]*\)|`[^`]*`")


def strip_single_quoted(s: str) -> str:
    """Blank out single-quoted regions while preserving offsets.

    Backticks and $(...) inside single quotes are literal in shells (no
    command substitution), so they should not trip the command-substitution
    check. Common case: bq query 'SELECT ... FROM `proj.ds.tbl` ...'
    """
    out: list[str] = []
    i = 0
    n = len(s)
    while i < n:
        c = s[i]
        if c == "'":
            j = s.find("'", i + 1)
            if j == -1:
                out.append(s[i:])
                return "".join(out)
            out.append(" " * (j - i + 1))
            i = j + 1
        else:
            out.append(c)
            i += 1
    return "".join(out)


def leading_exec(cmd: str) -> str:
    """Return the leading executable name from the first non-empty line,
    stripping leading env-var assignments, command/env/exec wrappers, and
    any path prefix. Uses plain whitespace splitting (not shlex) so that
    commands with unbalanced quotes on the first line — e.g. heredoc
    bodies in `git commit -m "$(cat <<EOF` — still resolve their leader."""
    first_line = next((ln for ln in cmd.split("\n") if ln.strip()), "")
    for t in first_line.strip().split():
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", t):
            continue
        if t in ("command", "env", "/usr/bin/env", "exec", "builtin"):
            continue
        return t.rsplit("/", 1)[-1].lower()
    return ""


def block(reason: str) -> NoReturn:
    print(json.dumps({"decision": "block", "reason": reason}))
    sys.exit(0)


def allow() -> NoReturn:
    sys.exit(0)


def split_segments(cmd: str) -> list[str]:
    """Split on shell separators that start a fresh command word, while
    respecting quotes (so `;` inside "..." doesn't split).

    Each newline-delimited line is parsed by shlex independently so that
    bare newlines act as command separators (POSIX behavior). When a line
    contains an unterminated quoted string (e.g. a heredoc opener like
    `git commit -m "$(cat <<'EOF'`), we accumulate subsequent lines until
    shlex can parse the chunk — this preserves multi-line quoted strings
    without false-flagging them as unbalanced."""
    out: list[str] = []
    lines = cmd.split("\n")
    i = 0
    while i < len(lines):
        if not lines[i].strip():
            i += 1
            continue
        chunk = lines[i]
        i += 1
        toks: list[str] | None = None
        last_err: ValueError | None = None
        while toks is None:
            try:
                lex = shlex.shlex(chunk, posix=True, punctuation_chars=True)
                lex.whitespace_split = False
                lex.commenters = ""
                toks = list(lex)
            except ValueError as e:
                last_err = e
                if i >= len(lines):
                    block(f"Hook could not parse command (unbalanced quotes: {last_err}); blocking")
                chunk = chunk + "\n" + lines[i]
                i += 1

        buf: list[str] = []
        for t in toks:
            if t in (";", "&&", "||", "|", "&"):
                if buf:
                    out.append(" ".join(buf))
                    buf = []
            else:
                buf.append(t)
        if buf:
            out.append(" ".join(buf))
    return out


def is_bq_invocation(tokens: list[str]) -> tuple[bool, str | None]:
    """Identify a `bq` invocation regardless of leading env-var assignments,
    `command`/`env`/`exec` wrappers, or absolute paths."""
    i = 0
    while i < len(tokens):
        t = tokens[i]
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", t):
            i += 1
            continue
        if t in ("command", "env", "/usr/bin/env", "exec", "builtin"):
            i += 1
            continue
        base = t.rsplit("/", 1)[-1]
        if base.lower() == "bq":
            j = i + 1
            while j < len(tokens) and tokens[j].startswith("-"):
                j += 1
            sub = tokens[j].lower() if j < len(tokens) else ""
            return True, sub
        return False, None
    return False, None


def scan_segment(seg: str) -> None:
    try:
        tokens = shlex.split(seg, posix=True)
    except ValueError as e:
        block(f"Hook could not parse segment (unbalanced quotes: {e}); blocking")
    if not tokens:
        return
    is_bq, sub = is_bq_invocation(tokens)
    if not is_bq:
        return
    if sub not in ALLOWED_BQ_SUBCMDS:
        block(f"Blocked: only bq {sorted(ALLOWED_BQ_SUBCMDS)} are allowed (got: bq {sub or '<none>'})")
    if sub in ("help", "version"):
        return
    if sub == "query":
        if WRITE_FLAGS.search(seg):
            block("Blocked: bq query write flags not allowed (--destination_table / --append_table / --replace)")
        if DESTRUCTIVE_SQL.search(seg):
            block("Blocked: bq query contains write/DDL keyword")
        if re.search(r"<\s*\S+\.(sql|txt)\b", seg) or "--flagfile" in seg:
            block("Blocked: bq query reading SQL from file/stdin — hook cannot inspect content")


def scan_python(cmd: str) -> None:
    """Strict mode: any inline python that touches google.cloud.bigquery
    is blocked, regardless of whether the visible op looks read-only."""
    # python -c "..."
    for m in re.finditer(r"\bpython3?\b\s+(?:-\w*\s+)*-c\s+(['\"])(.*?)\1", cmd, re.DOTALL):
        if PY_BQ_IMPORT.search(m.group(2)):
            block("Blocked: inline python -c imports google.cloud.bigquery (strict mode — use the bq CLI instead)")
    # python <<EOF ... EOF (and <<-EOF, <<'EOF')
    for m in re.finditer(
        r"\bpython3?\b[^\n]*<<-?\s*['\"]?(\w+)['\"]?\s*\n(.*?)\n\1",
        cmd,
        re.DOTALL,
    ):
        if PY_BQ_IMPORT.search(m.group(2)):
            block("Blocked: heredoc python imports google.cloud.bigquery (strict mode — use the bq CLI instead)")
    # python -m some.module.with.bigquery.in.it
    for m in re.finditer(r"\bpython3?\b\s+(?:-\w*\s+)*-m\s+(\S+)", cmd):
        if "bigquery" in m.group(1).lower():
            block(f"Blocked: python -m {m.group(1)} (strict mode — any bigquery-named module is refused)")


def main() -> None:
    try:
        envelope = json.load(sys.stdin)
    except Exception as e:
        block(f"Hook could not parse stdin JSON: {e}")

    cmd = (envelope.get("tool_input") or {}).get("command", "")
    if not isinstance(cmd, str) or not cmd.strip():
        allow()

    if leading_exec(cmd) in TEXT_HEAVY_EXECS:
        allow()

    if OPAQUE_WRAPPER.search(cmd) and re.search(r"\bbq\b", cmd, re.IGNORECASE):
        block("Blocked: bq invoked through eval/bash -c/xargs — hook cannot inspect")

    for seg in split_segments(cmd):
        scan_segment(seg)

    # Command-substitution check for bq query: run on raw cmd with single-
    # quoted regions blanked out, so backticks inside single-quoted SQL
    # identifiers (literal in shells) do not false-positive while real
    # $(...) or unquoted/double-quoted backticks still block.
    if re.search(r"\bbq\b[^\n;|&]*\bquery\b", cmd, re.IGNORECASE):
        if COMMAND_SUB.search(strip_single_quoted(cmd)):
            block("Blocked: bq query uses command substitution — hook cannot inspect content")

    scan_python(cmd)
    allow()


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception as e:
        block(f"Hook internal error (failing closed): {e!r}")
