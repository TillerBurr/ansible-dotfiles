#!/bin/sh
# PostToolUse hook (Edit|Write|Bash) — fires an async incremental code-review-graph
# update after each edit, unless a prior update for this project is still running.
# POSIX sh compatible. External deps: code-review-graph (CLI).

PIDFILE="/tmp/crg-$(echo "$PWD" | tr '/' '-').pid"

if command -v code-review-graph >/dev/null 2>&1 && [ -d .code-review-graph ]; then
  # Skip if a previous update for this project is still alive.
  if [ -f "$PIDFILE" ]; then
    OLDPID=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$OLDPID" ] && kill -0 "$OLDPID" 2>/dev/null; then
      exit 0
    fi
  fi
  # Fire-and-forget; record the PID so the next turn can check liveness.
  code-review-graph update --skip-flows >/dev/null 2>&1 &
  echo $! > "$PIDFILE"
fi

exit 0
