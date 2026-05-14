#!/usr/bin/env python3
"""Test harness for bq_guard.py.

Run: python3 .claude/hooks/test_bq_guard.py
Exits non-zero if any case fails.
"""

from __future__ import annotations

import json
import pathlib
import subprocess
import sys

HOOK = pathlib.Path(__file__).with_name("bq_guard.py")


def run(cmd: str) -> tuple[bool, str]:
    p = subprocess.run(
        ["python3", str(HOOK)],
        input=json.dumps({"tool_input": {"command": cmd}}),
        capture_output=True,
        text=True,
        timeout=10,
    )
    if p.returncode != 0:
        raise SystemExit(f"hook crashed (rc={p.returncode}): {p.stderr}")
    out = p.stdout.strip()
    if not out:
        return False, ""
    obj = json.loads(out)
    return obj.get("decision") == "block", obj.get("reason", "")


CASES: list[tuple[bool, str]] = [
    # --- baseline allow ---
    (False, 'bq query "SELECT 1"'),
    (False, "bq show proj:ds.tbl"),
    (False, "bq ls proj:ds"),
    (False, "bq head -n 5 proj:ds.tbl"),
    (False, "bq help"),
    (False, "bq version"),
    (False, "bq --format=json show proj:ds.tbl"),
    (False, "echo hi"),
    (False, "ls -la"),
    # --- baseline block (subcommand) ---
    (True, "bq cp src dst"),
    (True, "bq rm -t -f proj:ds.t"),
    (True, "bq mk --table proj:ds.t schema.json"),
    (True, "bq update proj:ds.t"),
    (True, "bq load proj:ds.t data.csv"),
    (True, "bq extract proj:ds.t gs://b/o"),
    (True, "bq insert proj:ds.t data.json"),
    # --- bq query write paths ---
    (True, 'bq query "DROP TABLE proj.ds.t"'),
    (True, 'bq query "INSERT INTO proj.ds.t VALUES (1)"'),
    (True, 'bq query "DELETE FROM proj.ds.t WHERE 1=1"'),
    (True, 'bq query "TRUNCATE TABLE proj.ds.t"'),
    (True, 'bq query "MERGE INTO proj.ds.t USING ..."'),
    (True, 'bq query --destination_table=proj:ds.t "SELECT 1"'),
    (True, 'bq query --replace=true --destination_table=x "SELECT 1"'),
    (True, 'bq query --append_table "SELECT 1"'),
    # --- gaps the inline-bash hook missed ---
    (True, "echo ok\nbq cp src dst"),
    (True, 'bq query "SELECT 1"; bq cp src dst'),
    (True, 'bq query "SELECT 1" && bq rm -f proj:ds.t'),
    (True, 'BQ query "DROP TABLE x"'),
    (True, " bq cp src dst"),
    (True, "/usr/local/bin/bq rm -f proj:ds.t"),
    (True, "env FOO=1 bq cp src dst"),
    (True, "command bq cp src dst"),
    (True, 'eval "bq cp src dst"'),
    (True, 'bash -c "bq cp src dst"'),
    (True, 'sh -c "bq cp src dst"'),
    (True, "echo proj:ds.t | xargs bq rm -f"),
    (True, "bq query < drop.sql"),
    (True, "bq query --flagfile=foo.txt"),
    (True, 'bq query "$(cat drop.sql)"'),
    (True, 'bq query "`cat drop.sql`"'),
    # --- python tripwire (strict) ---
    (True, "python3 -c \"from google.cloud import bigquery; bigquery.Client().delete_table('x')\""),
    (True, "python3 -c \"from google.cloud import bigquery; print(bigquery.Client().query('SELECT 1').result())\""),
    (True, 'python -c "import google.cloud.bigquery as bq"'),
    (True, "python <<EOF\nfrom google.cloud import bigquery\nbigquery.Client().create_table(t)\nEOF"),
    (True, "python -m google.cloud.bigquery.something"),
    (True, "python -m my_pkg.bigquery_tools"),
    # --- python that does NOT touch bigquery should pass ---
    (False, 'python3 -c "print(1+1)"'),
    (False, "python script.py"),
    (False, "python -m pytest"),
    # --- false-positive guards (must NOT block) ---
    (False, 'bq query "SELECT created_at FROM proj.ds.t"'),
    (False, 'bq query "SELECT update_time FROM proj.ds.t"'),
    (False, "bq show proj:ds.created_table"),
    # --- text-heavy execs (git, gh) must short-circuit ---
    # Commit message body contains words that would otherwise trip the hook.
    (False, 'git commit -m "fix: handle bq query write paths via bash -c wrapper"'),
    (False, "git commit -m \"$(cat <<'EOF'\nrefuses bq invoked through eval / bash -c\nEOF\n)\""),
    (False, "git commit -F /tmp/msg.txt"),
    (False, 'git tag -m "release notes mention bq cp" v1.0'),
    (False, 'gh pr create --body "describes bash -c and bq behavior"'),
    (False, "gh pr edit 123 --body-file /tmp/body.md"),
    # Explicit documentation of the known loophole — see TEXT_HEAVY_EXECS comment.
    # `git commit -m "$(bq cp src dst)"` executes bq cp via command substitution,
    # but is intentionally NOT blocked. This test pins that behavior.
    (False, 'git commit -m "$(bq cp src dst)"'),
]


def main() -> int:
    fails = 0
    for expect_block, cmd in CASES:
        got_block, reason = run(cmd)
        ok = got_block == expect_block
        if not ok:
            fails += 1
        flag = "OK  " if ok else "FAIL"
        snippet = cmd.replace("\n", "\\n")[:90]
        tail = f"  -> {reason}" if got_block else ""
        print(f"{flag}  expect={expect_block!s:<5} got={got_block!s:<5} :: {snippet}{tail}")
    print()
    print("PASS" if fails == 0 else f"{fails} FAILURES")
    return 0 if fails == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
