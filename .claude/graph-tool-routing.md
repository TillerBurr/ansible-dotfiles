## Graph Tool Routing

When a code-review-graph MCP server is active, use graph tools before Grep/Glob/Read; otherwise fall through to Grep/Read.

1. First call: `get_minimal_context_tool(task=...)` (~100 tokens; returns risk + communities + next_tool_suggestions). Use `detail_level="minimal"` after. Target ≤5 calls, ≤800 tokens.
2. CRG miss (<2 nodes) → Grep/Read.

Always check `next_tool_suggestions`.

Quick ref:
- Where is X defined → `semantic_search_nodes_tool(query=X)`
- Who calls X → `query_graph_tool(pattern=callers_of, target=X)`
- What X imports → `query_graph_tool(pattern=imports_of, target=X)`
- Tests for X → `query_graph_tool(pattern=tests_for, target=X)`
- Blast radius → `get_impact_radius_tool(changed_files=[...])`
- Pre-PR review → `detect_changes_tool` → `get_review_context_tool`
- Communities / architecture → `list_communities_tool` / `get_architecture_overview_tool`

Never via MCP (use CLI): `build_or_update_graph_tool`, `embed_graph_tool`, `visualize_graph_tool`, `generate_wiki_tool`, `get_graph_status_tool`, `list_nodes_tool`, `list_files_tool`, `list_edges_tool`.
