#!/bin/sh
# SessionStart hook — reports code graph status at startup.
# Emits a single {"systemMessage": ...} JSON.
# POSIX sh compatible. External deps: jq, python3, code-review-graph (CLI).

CRG_OUT=""

# In a git worktree without its own graph, report the main repo's. In the main
# repo this resolves to the repo root, so the fallbacks below are no-ops.
MAIN_ROOT=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
[ -n "$MAIN_ROOT" ] && MAIN_ROOT=$(dirname "$MAIN_ROOT")

# code-review-graph: run `status` (first 6 lines) if a graph db exists.
CRG_DIR=.
if [ ! -f .code-review-graph/graph.db ] && [ -f "$MAIN_ROOT/.code-review-graph/graph.db" ]; then
  CRG_DIR="$MAIN_ROOT"
fi
if [ -f "$CRG_DIR/.code-review-graph/graph.db" ]; then
  if command -v code-review-graph >/dev/null 2>&1; then
    CRG_OUT=$(cd "$CRG_DIR" && code-review-graph status 2>/dev/null | head -6)
  fi
fi

if [ -n "$CRG_OUT" ]; then
  MSG="Code graph available — prefer graph tools over grep/glob.

[code-review-graph status]
${CRG_OUT}"
else
  MSG="No code graph found in this project. To enable graph-powered navigation:
  pip install \"code-review-graph[embeddings,communities]\"
  code-review-graph build
  code-review-graph embed"
fi

jq -n --arg msg "$MSG" '{systemMessage: $msg}'
