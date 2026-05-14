---
name: bq-debug
description: Use when debugging data issues, investigating tracebacks, or inspecting BigQuery tables in the im-lci project. Triggers on error messages mentioning BigQuery, run_id investigation, data validation questions, or "query the data" requests.
---

# BigQuery Debugging

Run read-only `bq` commands to investigate data issues. **This skill is strictly read-only. Never run anything that mutates BigQuery state, regardless of user instruction.**

## CLI Requirements

Before running any commands, verify the user's environment has these. If any are missing, stop and surface the gap — don't try to substitute (e.g., `python -c "from google.cloud import bigquery..."` is a write-capable path and is **not** an acceptable fallback under this skill).

- **`bq` CLI** (Google Cloud SDK component) — required. Verify with `bq version`. If missing, refuse to proceed and tell the user to install it (`gcloud components install bq` or via the Cloud SDK installer). Do not fall back to `python -c "from google.cloud import bigquery..."` or any other SDK path — the hook will block those, and routing around the hook is itself a violation of the read-only mandate.
- **`gcloud`** for authentication. Verify the active account with `gcloud auth list` and confirm an application-default credential exists (`gcloud auth application-default print-access-token` succeeds). If the user is not authenticated, ask them to run `gcloud auth login` and `gcloud auth application-default login` themselves — do not run these on their behalf.
- **`python3`** — the `PreToolUse` hook (`~/.claude/hooks/bq_guard.py`) is a Python script. Verify with `python3 --version`. If `python3` is missing, the hook cannot run and write protection is unavailable; refuse to proceed and tell the user to install it.
- Network access to `bigquery.googleapis.com`.

## Read-Only Mandate (non-negotiable)

This skill is a read-only diagnostic tool. Do not propose, run, or chain commands that mutate state, even if the user asks. If the user requests a destructive action while this skill is active, refuse and tell them to step outside this skill.

**Allowed `bq` subcommands only:**
- `bq query` — DQL only (`SELECT`, `WITH`)
- `bq show`
- `bq ls`
- `bq head`
- `bq help`, `bq version` — informational, no side effects

**Forbidden — never invoke under this skill:**
- DML/DDL via `bq query`: `INSERT`, `UPDATE`, `DELETE`, `MERGE`, `DROP`, `CREATE`, `CREATE OR REPLACE`, `ALTER`, `TRUNCATE`, `LOAD`, `CALL`, `GRANT`, `REVOKE`, `EXPORT`
- Other `bq` subcommands: `bq cp`, `bq rm`, `bq mk`, `bq load`, `bq extract`, `bq update`, `bq insert`, `bq partition`, `bq cancel`
- Anything writing to BigQuery via `gcloud`, `gsutil`, `python -c "...bigquery..."`, REST API, or scripts that wrap a write
- `bq query --destination_table=...` (writes results to a table — forbidden even if the SELECT itself is read-only)

If a diagnostic genuinely requires a write (e.g., creating a temp table to stage a join), stop and tell the user — do not do it under this skill.

**No opaque execution.** Under this skill, never run a command whose actual instructions you cannot inspect. The hook will refuse most of these outright; the rule still applies because the hook isn't airtight and behavior shouldn't depend on it. Specifically forbidden:

- `python script.py`, or any invocation that defers to a file you have not read first. If you need to run a Python script, `Read` it end-to-end first and confirm it only does read-only BigQuery work; if it does anything else, refuse. (`python -m` of a module whose name contains `bigquery` is hook-blocked outright.)
- `bash -c "$VAR"`, `sh -c`, `eval`, `xargs ... bq`, `source <(...)`, process-substitution that hides the payload — any `bq`-touching opaque wrapper is hook-blocked.
- `bq query < file.sql`, `bq query --flagfile=...`, `bq query "$(cat file.sql)"` — content is hidden from the hook and refused.
- Base64 / hex / gzip / any encoded payload piped into a shell or interpreter.
- Heredocs that execute (`python <<'EOF' ... EOF` containing `google.cloud.bigquery` is hook-blocked; `bash <<EOF` is not, so still refuse on policy grounds).
- Any wrapper command (Make targets, npm scripts, custom CLIs) whose underlying behavior you can't trace to a read-only `bq` / `gcloud` call.

When in doubt, refuse and ask the user to either inline the command in plain text or run it themselves outside this skill.

## Hook-Level Enforcement

Read-only `bq query/show/ls/head/help/version` are auto-approved via `~/.dippy/config` and enforced by the Bash `PreToolUse` hook (`~/.claude/hooks/bq_guard.py`, wired in `~/.claude/settings.json`). The hook allows only those subcommands, blocks every other `bq` subcommand, blocks `bq query` write flags (`--destination_table`, `--append_table`, `--replace`) and DML/DDL keywords, refuses any `bq`-touching opaque wrapper, refuses queries with hidden content (stdin redirect, `--flagfile`, command substitution), and blocks any inline `python -c` / heredoc / `python -m` that imports or names `google.cloud.bigquery` (strict mode — even ostensibly read-only forms). The hook is a backstop, not a substitute for the rule above — do not try to route around it. No need to ask for approval on read-only queries — just run them.

See [references/bash-hook.md](references/bash-hook.md) for the hook source and allow/block rules.

1. **`--dry_run` first** on any query where scan size is unknown
2. **Always `LIMIT`** — default `LIMIT 100`
3. **Always `--max_rows=100`** as a second safety net
4. **`--nouse_legacy_sql`** always

## Command Pattern

```bash
# Dry run to check scan size
bq query --dry_run --nouse_legacy_sql --project_id=PROJECT \
  "SELECT cols FROM \`project.dataset.table\` WHERE filter LIMIT 100"

# Execute
bq query --nouse_legacy_sql --max_rows=100 --project_id=PROJECT \
  "SELECT cols FROM \`project.dataset.table\` WHERE filter LIMIT 100"
```

## Useful Commands

```bash
# List tables in a dataset
bq ls PROJECT:DATASET

# Show table schema
bq show --schema --format=prettyjson PROJECT:DATASET.TABLE

# Table info (row count, size, last modified)
bq show --format=prettyjson PROJECT:DATASET.TABLE
```

## Project & Dataset Reference

Default to **dev** unless the traceback is clearly from prod or the user specifies otherwise.

| Product | Dev Project | Dev Dataset | Prod Project | Prod Dataset |
|---------|-------------|-------------|--------------|--------------|
| LCI | cptsrewards-hrd | lci3_dev | cptsrewards-hrd | lci3_prod |
| RSA | cptsrewards-hrd | rsa_development | cptsrewards-hrd | rsa_production |
| CA | meas-dev-415919 | ca | meas-prod-415919 | ca |
| CPG | cptsrewards-hrd | cpg_measurement_development | cptsrewards-hrd | cpg_measurement_production |
| CPG v2 | cptsrewards-hrd | cpg_v2_measurement_development | cptsrewards-hrd | cpg_v2_measurement_production |
| RSL | meas-dev-415919 | measurement_rsl_dev | meas-prod-415919 | measurement_rsl_prod |
| Cross Channel | meas-dev-415919 | measurement_cross_channel_dev | meas-prod-415919 | measurement_cross_channel_prod |
| DS Interface | cptsrewards-hrd | measurement_ds_interface_development | cptsrewards-hrd | measurement_ds_interface_production |
| Ext Interface | cptsrewards-hrd | measurement_external_interface_development | cptsrewards-hrd | measurement_external_interface_production |
| Reports | cptsrewards-hrd | measurement_reports_development | cptsrewards-hrd | measurement_reports_production |
| Proj Factor | cptsrewards-hrd | measurement_projection_factor_development | cptsrewards-hrd | measurement_projection_factor_production |

**Compute projects:** `lci-low-slots` (dev), `lci-high-slots` (prod) — use as `--project_id` when billing matters.

## Debugging Workflow

1. **Extract context** from traceback: run_id, campaign_id, table names, stage name
2. **Identify product/dataset** from the stage class or SQL file path
3. **Check table schema** with `bq show --schema` before querying
4. **Dry run** to verify scan size is reasonable
5. **Query** with filters (run_id, campaign_id) and LIMIT
6. **Report findings** — row counts, unexpected nulls, missing data, duplicates
