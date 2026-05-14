#!/usr/bin/env bash
# PreToolUse hook for Bash: remove stale .git/index.lock before git commands.
# Safe-guard: skip removal if any `git` process is currently running.
# Exits 0 always — never blocks the tool call.

set -u

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
cwd=$(printf '%s' "$input" | jq -r '.cwd // ""')

# Only act on git commands
case "$cmd" in
  git|git\ *|*/git|*/git\ *) ;;
  *) exit 0 ;;
esac

[ -n "$cwd" ] || cwd="$PWD"
[ -d "$cwd" ] || exit 0

# Walk up to find .git directory
root="$cwd"
while [ "$root" != "/" ] && [ ! -e "$root/.git" ]; do
  root=$(dirname "$root")
done

lock="$root/.git/index.lock"
[ -f "$lock" ] || exit 0

# Bail if any git process is running (could legitimately hold the lock)
if pgrep -x git >/dev/null 2>&1; then
  exit 0
fi

rm -f "$lock" 2>/dev/null
echo "{\"systemMessage\":\"Removed stale git lock: $lock\"}"
exit 0
