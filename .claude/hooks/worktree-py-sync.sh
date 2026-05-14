#!/usr/bin/env bash
# SessionStart hook: auto-sync Python env in worktrees.
# Detects uv (uv.lock) or poetry (poetry.lock) and runs appropriate sync.
# Only runs when .venv is missing, so no-op in warm worktrees.

set -u

sync_dir() {
  local dir=$1
  [ -f "$dir/pyproject.toml" ] || return 0
  [ -e "$dir/.venv" ] && return 0

  if [ -f "$dir/uv.lock" ]; then
    echo "[worktree-sync] uv sync in $dir" >&2
    (cd "$dir" && uv sync --quiet 2>&1 | tail -5 >&2)
  elif [ -f "$dir/poetry.lock" ]; then
    echo "[worktree-sync] poetry install in $dir" >&2
    (cd "$dir" && poetry install --quiet 2>&1 | tail -5 >&2)
  fi
}

# Root
sync_dir "$PWD"

# Known nested Python projects (extend as needed)
for sub in measurement_airflow; do
  [ -d "$PWD/$sub" ] && sync_dir "$PWD/$sub"
done

exit 0
