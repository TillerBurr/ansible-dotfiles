# Bash hook — `bq` allowlist + Python BigQuery tripwire

A single `PreToolUse` Bash hook in `~/.claude/settings.json` defends the read-only mandate. The actual logic lives in `~/.claude/hooks/bq_guard.py`.

```json
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "command": "python3 /Users/tbaur/.claude/hooks/bq_guard.py"
    }
  ]
}
```

The hook reads the Bash tool envelope on stdin, prints a `{"decision":"block","reason":"..."}` JSON object when blocking, or nothing when allowing. It always exits 0 — the JSON conveys the decision.

Auto-approval for read-only `bq` calls is handled separately by `~/.dippy/config`; the hook is the enforcement layer that runs regardless.

## What it allows

- `bq query ...` — DQL only.
- `bq show ...`, `bq ls ...`, `bq head ...`
- `bq help`, `bq version` — informational.
- Anything that isn't a `bq` invocation and doesn't reference `google.cloud.bigquery` from inline Python.

## What it blocks

### `bq` subcommand allowlist
Every `bq` subcommand other than `query/show/ls/head/help/version` is refused — `bq cp`, `bq rm`, `bq mk`, `bq load`, `bq extract`, `bq update`, `bq insert`, `bq partition`, etc.

The hook recognises a `bq` invocation regardless of:
- absolute path (`/usr/local/bin/bq`)
- leading wrappers (`command bq`, `env bq`, `/usr/bin/env bq`, `exec bq`)
- leading env-var assignments (`FOO=1 bq …`)
- leading whitespace, mixed case (`BQ Query`)
- chaining (`bq query "SELECT 1"; bq cp src dst` — second segment is scanned independently)
- multi-line commands (newline-separated statements are each scanned)

### `bq query` write paths
- Write flags: `--destination_table`, `--append_table`, `--replace`/`--replace=...`.
- DDL/DML keywords in the SQL text (case-insensitive, non-word-boundary): `insert`, `update`, `delete`, `merge`, `drop`, `create`, `alter`, `truncate`, `load`, `call`, `grant`, `revoke`, `export data`.

### Hidden-content refusals
Refused outright because the hook can't see the SQL text:
- `bq query < file.sql`
- `bq query --flagfile=...`
- `bq query "$(cat file.sql)"` / `bq query "\`cat file.sql\`"`

### Opaque wrappers around `bq`
Refused outright when combined with `bq` anywhere in the command:
- `eval "..."`
- `bash -c "..."`, `sh -c "..."`, `zsh -c "..."`
- `xargs ... bq ...`

### Python tripwire (strict mode)
Inline Python that imports or names `google.cloud.bigquery` is refused regardless of whether the visible op looks read-only. Three forms covered:
- `python -c "...google.cloud.bigquery..."`
- `python <<EOF ... google.cloud.bigquery ... EOF` (heredoc)
- `python -m <module>` where the module name contains `bigquery`

## Known gaps (this is defense-in-depth, not airtight)

Out of reach for any textual filter:
- `python script.py` — the hook only sees the command string, not file contents. Mitigation: skill rule says `Read` the file end-to-end first.
- Other SDKs: `pandas-gbq`, `google-cloud-bigquery-storage`, raw REST via `requests`, `bigquery-magics`, `sqlalchemy-bigquery`. The `google.cloud.bigquery` regex doesn't see them.
- Other languages: Node `@google-cloud/bigquery`, Go, Java.
- Tools other than `Bash`. The hook's matcher is `Bash`; future MCP BigQuery tools would not be gated.
- The fundamental textual-filter problem. The real boundary should be IAM (a read-only service account); this hook is a fast-fail UX layer.

## Requirements

- `python3` on `PATH`. If missing, the hook can't run and write protection is unavailable. Verify with `python3 --version`.

## Tests

`~/.claude/hooks/test_bq_guard.py` covers ~50 allow/block cases including every bypass listed above. Run with `python3 ~/.claude/hooks/test_bq_guard.py`. Add a case before changing policy.
