---
name: knowledge-vault
description: >
  Interact with the centralized Graphify knowledge vault at ~/vault/.
  Use this skill BEFORE making architectural decisions, modifying core systems,
  proposing design changes, or when encountering unfamiliar modules.
  Also use when debugging cross-cutting concerns, investigating why a past decision
  was made, or when you've made an error and want to check if constraints exist.
  Trigger on: architecture questions, "check the vault", "what does the graph say",
  design decisions, unfamiliar modules, cross-project dependencies, constraint checks,
  or any question about how systems relate to each other.
  Do NOT use for simple file edits, formatting, tests, or when the answer is already
  in your current file context.
---

# Knowledge Vault

A centralized Graphify-powered knowledge graph serving all projects. The vault lives
at `~/vault/` and is maintained separately from any individual codebase.

This skill has two parts:

1. **This file** — when and how to use the vault (read this first, always)
2. **`references/graphify-cli.md`** — full Graphify CLI reference (read when you need command details)

## Vault Structure

```
~/vault/
├── projects/
│   ├── symagedocs/       # SymageDocs project graph (Obsidian notes + graph output)
│   ├── kratos/           # Kratos project graph
│   └── <project>/        # Additional projects follow the same pattern
├── brain/                # Cross-project knowledge (shared patterns, decisions, constraints)
└── graphify-out/         # Global graph output (merged across all projects)
    ├── GRAPH_REPORT.md   # God nodes, communities, surprising connections
    ├── graph.json        # Raw graph data (queryable via CLI)
    └── memory/           # Saved query results (feedback loop)
```

## Project Mapping

| Repo       | Vault Path                   | Source Path      |
| ---------- | ---------------------------- | ---------------- |
| symagedocs | ~/vault/projects/symagedocs/ | ~/dev/symagedocs |
| kratos     | ~/vault/projects/kratos/     | ~/dev/kratos     |

## When to Use This Skill

### ALWAYS query the vault before:

- **Proposing or modifying architecture** — check god nodes and community structure first
- **Changing core modules** (auth, database, API layers, deployment) — check for constraints
- **Making a decision that was already made** — the graph stores rationale nodes explaining WHY past decisions were made; check before re-deciding
- **Cross-project work** — use `brain/` and cross-project edges to understand shared patterns

### Query the vault when:

- **Encountering an unfamiliar module** — `graphify explain` before reading source code
- **Debugging cross-cutting concerns** — `graphify path` to trace relationships between concepts
- **You've made an error** — check if a constraint or rationale exists that you missed
- **You need to understand dependencies** — query to see what depends on what before changing it

### Do NOT use the vault for:

- Simple file edits, formatting, linting, or test fixes
- The answer is already visible in your current file context
- You already queried this session for the same topic
- Pure implementation tasks with no architectural implications

## How to Query

You have access to `graphify` as a CLI tool. Use it directly via bash.

### Primary Query Commands

```bash
# Natural language question — BFS traversal, token-capped
# Use for: broad "what is X connected to?" questions
graphify query "how does authentication work in this project" --budget 1500

# DFS traversal — traces a specific path deeply
# Use for: "how does X reach Y?" or dependency chain questions
graphify query "error handling flow from API to database" --dfs --budget 1500

# Shortest path between two concepts
# Use for: understanding how two specific things relate
graphify path "AuthModule" "DatabaseService"

# Plain-language explanation of a single concept and all its connections
# Use for: quick orientation on an unfamiliar module before reading source
graphify explain "PlaidIntegration"
```

### Choosing the Right Command

| Question Pattern                       | Command              | Why                                             |
| -------------------------------------- | -------------------- | ----------------------------------------------- |
| "What is X connected to?"              | `query` (BFS)        | Broad context, nearest neighbors first          |
| "How does X reach/affect Y?"           | `query --dfs`        | Traces a specific chain deeply                  |
| "How are X and Y related?"             | `path`               | Shortest path with edge types                   |
| "What is X? I haven't seen it before." | `explain`            | All connections + source locations              |
| "What are the most important modules?" | Read GRAPH_REPORT.md | God nodes section lists highest-degree concepts |
| "What's the overall architecture?"     | Read GRAPH_REPORT.md | Communities section shows module clusters       |

### Reading Graph Output

Query results include:

- **Node labels** — human-readable concept names
- **Edge relations** — `calls`, `implements`, `references`, `shares_data_with`, `rationale_for`, `semantically_similar_to`, etc.
- **Confidence tags** — `EXTRACTED` (explicit in source), `INFERRED` (reasonable inference), `AMBIGUOUS` (uncertain)
- **confidence_score** — 0.0–1.0 numeric confidence
- **source_file** and **source_location** — where in the codebase the relationship was found

When citing vault findings in your response, reference the `source_file` and `source_location` so the user can verify.

### Token Budget

Always use `--budget` to cap query output and avoid flooding your context:

- `--budget 1500` — good default for most questions
- `--budget 3000` — use for complex cross-cutting questions
- `--budget 500` — use for quick lookups

## Orientation Workflow

You have NO memory between sessions. At the start of every session where this skill
triggers, orient yourself before doing any work:

1. **Read the report first:**

   ```bash
   cat ~/vault/graphify-out/GRAPH_REPORT.md
   ```

   Focus on: God Nodes (highest-degree concepts), Communities (module clusters), Surprising Connections.

2. **Query specific concepts** as you encounter them during implementation.

## If graphify CLI is unavailable

**HARD STOP.** Do not attempt to work around a missing graphify installation.
Tell the user that graphify is required and the vault cannot be queried without it.
Do not fall back to reading raw files, browsing Obsidian notes, or parsing graph.json manually.
The vault is only useful when queried through graphify — raw file reads lose the graph structure
that makes this valuable.

## Full CLI Reference

For the complete list of all graphify commands (build, update, export, add content, hooks, MCP server, etc.), read:

```
references/graphify-cli.md
```

Read this when you need to:

- Build or rebuild the vault (`graphify <path> --update --obsidian`)
- Add external content (`graphify add <url>`)
- Start an MCP server (`graphify --mcp`)
- Understand any command not covered in the query section above
