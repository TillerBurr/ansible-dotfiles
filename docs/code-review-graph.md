# code-review-graph: global MCP server, per-project graphs

A knowledge-graph tool that makes Claude Code search structurally instead of
grepping. The MCP server is registered **once globally** and auto-detects the
repo from the cwd; each repo holds its own graph database.

## Mental model

```
        ┌─────────────────── GLOBAL (every project) ───────────────────┐
        │  ~/.claude.json   → mcpServers."code-review-graph" (stdio)    │
        │  ~/.claude/settings.json hooks                                │
        │    PostToolUse(Edit|Write|Bash) → crg-update.sh (async CRG  │
        │       refresh after each edit)                               │
        │  ~/.claude/graph-tool-routing.md → routing decision tree      │
        │  uv tool: code-review-graph (CLI + MCP server)                │
        └───────────────────────────┬──────────────────────────────────┘
                                     │ server auto-detects repo from cwd
        ┌────────────────────────────▼─────────────────── PER PROJECT ──┐
        │  .code-review-graph/graph.db   (tree-sitter structural graph) │
        │  .code-review-graphignore      (optional skip list)           │
        └────────────────────────────────────────────────────────────────┘
```

- **code-review-graph (CRG)** — fast, deterministic, tree-sitter AST graph.
  Callers, callees, imports, tests, impact radius, communities. Auto-refreshes
  after each edit via the PostToolUse hook.
- One global MCP server entry serves every repo: `serve` resolves the graph from
  the cwd's `.code-review-graph/graph.db`. No per-project `.mcp.json` needed.
- graphify is no longer part of this setup. Routing is CRG → Grep/Read.

---

## Prerequisites

- `uv` (tool install)

```sh
uv tool install code-review-graph
code-review-graph --version          # 3.x
```

---

## 1. Global install (once per machine)

### 1a. CLI as a uv tool

```sh
uv tool install code-review-graph
```

### 1b. Global MCP server (`~/.claude.json` → `mcpServers`)

```jsonc
"code-review-graph": {
  "type": "stdio",
  "command": "code-review-graph",
  "args": [
    "serve", "--tools",
    "get_minimal_context_tool,semantic_search_nodes_tool,query_graph_tool,get_impact_radius_tool,detect_changes_tool,get_review_context_tool,get_affected_flows_tool,list_communities_tool,get_architecture_overview_tool,suggest_refactoring_tool,detect_dead_code_tool"
  ],
  "env": {}
}
```

- `serve` auto-detects the repo root from the cwd Claude Code launches it in, so
  one entry covers every project. `--tools` is an allowlist — trim as desired.
- After editing, reconnect with `/mcp` (or restart the session).

### 1c. Global hooks (`~/.claude/settings.json`)

Only the PostToolUse hook remains — it keeps each project's graph fresh after
any edit (the script is gated on `.code-review-graph` + PID-locked, so it's a
no-op in non-CRG repos and never overlaps):

```jsonc
"hooks": {
  "PostToolUse": [
    { "matcher": "Edit|Write|Bash", "hooks": [{
        "type": "command",
        "command": "$HOME/.claude/hooks/crg-update.sh",
        "timeout": 5,
        "async": true
    }] }
  ]
}
```

Permissions to allow the CLI without prompts:

```jsonc
"permissions": { "allow": ["Bash(code-review-graph *)", "Bash(~/.claude/hooks/*.sh)"] }
```

### 1d. Global routing rules (`~/.claude/graph-tool-routing.md`)

Tells Claude which graph tool to reach for. Current routing:

```markdown
1. First call: get_minimal_context_tool(task="<description>")  (~100 tokens)
2. CRG miss (<2 nodes) → Grep/Read

Quick reference:
  Where is X defined           → semantic_search_nodes_tool(query=X)
  Who calls X                  → query_graph_tool(pattern=callers_of, target=X)
  What does X import           → query_graph_tool(pattern=imports_of, target=X)
  What tests cover X           → query_graph_tool(pattern=tests_for, target=X)
  Blast radius before refactor → get_impact_radius_tool(changed_files=[...])
  Architecture question        → get_architecture_overview_tool
  Semantic / concept search    → semantic_search_nodes_tool
```

---

## 2. Per-project setup

Run from the repo root.

```sh
code-review-graph build           # parses all files → .code-review-graph/graph.db
code-review-graph embed           # optional: vector embeddings for semantic_search
code-review-graph status          # node/edge counts
```

CRG writes a `.code-review-graph/.gitignore` containing `*` — never commit the db
(absolute paths + code metadata). Add to the repo `.gitignore`:

```
.code-review-graph/
```

Optionally tell CRG what to skip with `.code-review-graphignore`:

```
.claude/
node_modules/
dist/
build/
coverage/
*.min.js
*.lock
```

---

## 3. How it works (request flow)

The MCP graph tools query `.code-review-graph/graph.db` directly — no LLM. Claude
calls `get_minimal_context_tool` first, then the targeted tools per the routing
table; it falls through to Grep/Read only when the graph misses.

After each edit the **PostToolUse** hook (`crg-update.sh`, matching `Edit|Write|Bash`)
fires `code-review-graph update --skip-flows` async (guarded by a per-project pidfile so
updates don't stack), keeping the graph fresh as files change.

---

## 3a. Worktrees

A fresh worktree starts with no graph (`.code-review-graph/` is gitignored). The
global MCP server still launches there; its tools just return empty until a graph
exists. Options:

- Let `crg-update.sh` build incrementally — but `update` needs an existing db, so
  run `code-review-graph build` once in the worktree first.
- Or rely on the main worktree's graph for navigation and only build per-worktree
  when you need branch-accurate `detect_changes` / `get_impact_radius`.

The `wt` slash command runs `code-review-graph build` in new worktrees so
change-aware tools are accurate to the branch.

---

## 4. Hook script (`~/.claude/hooks/crg-update.sh`)

```sh
#!/bin/sh
# PostToolUse hook — async incremental CRG update after each edit, guarded by a pidfile
# so updates for the same project don't stack. POSIX sh. Deps: code-review-graph.

PIDFILE="/tmp/crg-$(echo "$PWD" | tr '/' '-').pid"

if command -v code-review-graph >/dev/null 2>&1 && [ -d .code-review-graph ]; then
  if [ -f "$PIDFILE" ]; then
    OLDPID=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$OLDPID" ] && kill -0 "$OLDPID" 2>/dev/null; then exit 0; fi
  fi
  code-review-graph update --skip-flows >/dev/null 2>&1 &
  echo $! > "$PIDFILE"
fi
exit 0
```

Make it executable: `chmod +x ~/.claude/hooks/crg-update.sh`

---

## 5. Gotchas

- **No graph in a repo → tools return empty.** Run `code-review-graph build` once.
- **`build` vs `update`.** `build` re-parses everything (slow, run once); `update`
  is incremental (what the PostToolUse hook runs). `detect-changes` is read-only and does
  *not* re-parse.
- **Local proxy disables defaults.** Running CC behind `ANTHROPIC_BASE_URL` turns
  off first-party defaults like Tool Search; set `ENABLE_TOOL_SEARCH=true` in `env`.

---

## 6. Updating graphs

```sh
code-review-graph update            # incremental (also automatic via PostToolUse hook)
code-review-graph build             # full rebuild after large refactors
```

---

## Reproducing this in ansible-dotfiles

This doc is descriptive of the live machine. To make `roles/claude` reproduce it:

1. Add `hooks/crg-update.sh` (section 4) to `.claude/hooks/`.
2. Add the `PostToolUse` hook + permissions (section 1c) to `.claude/settings.json`.
3. Register the global MCP server (section 1b) — note `~/.claude.json` is the live
   runtime file, not symlinked from this repo, so a provisioning task must merge
   the `mcpServers` entry rather than overwrite the file.
4. The uv-tool CLI is installed by `uv tool install`, not symlinked — add it to a
   provisioning task if you want it in the playbook.

Per-project files (`.code-review-graph/`, `.code-review-graphignore`) live in each
project repo, not here.
