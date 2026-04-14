# Graphify CLI Reference

Complete reference for all `graphify` commands. This file is a reference — read it
when you need specific command details, not on every vault query.

## Table of Contents

- [Graphify CLI Reference](#graphify-cli-reference)
  - [Table of Contents](#table-of-contents)
  - [Build \& Extract](#build--extract)
    - [Full pipeline](#full-pipeline)
    - [What the pipeline does (in order)](#what-the-pipeline-does-in-order)
    - [Build outputs](#build-outputs)
  - [Incremental Update](#incremental-update)
  - [Query \& Traversal](#query--traversal)
    - [Natural language query](#natural-language-query)
    - [Shortest path](#shortest-path)
    - [Explain a concept](#explain-a-concept)
  - [Add Content](#add-content)
  - [Export \& Output Formats](#export--output-formats)
    - [Visualization](#visualization)
    - [Graph interchange formats](#graph-interchange-formats)
    - [Agent-friendly formats](#agent-friendly-formats)
  - [MCP Server](#mcp-server)
    - [Claude Code MCP configuration](#claude-code-mcp-configuration)
  - [Watch Mode](#watch-mode)
  - [Community Clustering](#community-clustering)
  - [Graph Report](#graph-report)
  - [Git Hooks (NOT used in our vault — documented for reference)](#git-hooks-not-used-in-our-vault--documented-for-reference)
  - [Claude Integration (NOT used in our vault — documented for reference)](#claude-integration-not-used-in-our-vault--documented-for-reference)

---

## Build & Extract

### Full pipeline

```bash
graphify <path>                                # Full pipeline → graph.json + GRAPH_REPORT.md + graph.html
graphify <path> --mode deep                    # Thorough extraction, richer INFERRED edges (more LLM cost)
graphify <path> --obsidian                     # Also generate Obsidian vault (one note per node)
graphify <path> --obsidian --obsidian-dir DIR  # Write Obsidian vault to custom path
graphify <path> --directed                     # Build directed graph (preserves edge direction: source→target)
graphify <path> --whisper-model medium         # Use a larger Whisper model for video/audio transcription
```

**For our centralized vault**, the standard build command is:

```bash
graphify ~/dev/<project> --mode deep --obsidian --obsidian-dir ~/vault/projects/<project>/
```

### What the pipeline does (in order)

1. **Detect** — scans the path for supported files (code, docs, papers, images, video)
2. **AST extraction** — tree-sitter parses code files locally (no LLM, deterministic)
3. **Semantic extraction** — LLM extracts concepts/relationships from docs, papers, images
4. **Merge** — combines AST + semantic into unified graph
5. **Cluster** — Leiden community detection on the graph topology
6. **Analyze** — identifies god nodes, surprising connections, suggests questions
7. **Report** — generates GRAPH_REPORT.md
8. **Export** — writes graph.json, graph.html, and optionally Obsidian vault / other formats

### Build outputs

All outputs go to `<path>/graphify-out/` by default:

| File                    | Description                                              |
| ----------------------- | -------------------------------------------------------- |
| `graph.json`            | Raw graph data (nodes, edges, communities)               |
| `graph.html`            | Interactive visualization (open in browser, no server)   |
| `GRAPH_REPORT.md`       | One-page audit: god nodes, communities, surprises, costs |
| `obsidian/`             | Obsidian vault (if `--obsidian`): one note per concept   |
| `obsidian/graph.canvas` | Obsidian canvas with community layout                    |
| `cost.json`             | Cumulative token usage tracker across runs               |
| `memory/`               | Saved query results (feedback loop for future updates)   |

---

## Incremental Update

Only re-extracts new or changed files since the last run. Significantly cheaper than full rebuild.

```bash
graphify <path> --update
graphify <path> --update --obsidian --obsidian-dir DIR
```

**For our centralized vault:**

```bash
graphify ~/dev/<project> --update --obsidian --obsidian-dir ~/vault/projects/<project>/
```

Behavior:

- Compares file hashes against a saved manifest from the last run
- Code-only changes: re-runs AST extraction only (no LLM cost)
- Doc/paper/image changes: runs full semantic extraction on changed files only
- Merges new extraction into existing graph, re-clusters, regenerates report

---

## Query & Traversal

All query commands operate on the graph at `graphify-out/graph.json` in the current directory.
For our vault, run from `~/vault/` or specify the graph path.

### Natural language query

```bash
graphify query "<question>"                    # BFS traversal — broad context
graphify query "<question>" --dfs              # DFS traversal — trace a specific path
graphify query "<question>" --budget 1500      # Cap answer at N tokens (default: 2000)
```

**BFS** (default): explores all neighbors layer by layer, depth 3. Best for "what is X connected to?"
**DFS**: follows one path as deep as possible (depth 6) before backtracking. Best for "how does X reach Y?"

The query:

1. Finds 1-3 nodes whose labels best match the question terms
2. Traverses from those nodes using BFS or DFS
3. Returns the subgraph: node labels, edge relations, confidence tags, source locations
4. Truncates output at the token budget

Query results are saved to `graphify-out/memory/` and become nodes in the graph on next `--update`.

### Shortest path

```bash
graphify path "ConceptA" "ConceptB"
```

Finds the shortest path between two named concepts. Returns each hop with edge relation and confidence.
Uses fuzzy node matching — partial names work.

### Explain a concept

```bash
graphify explain "SomeNode"
```

Returns all connections to/from a single node: label, source file, degree, and every neighbor with
edge relation and confidence. Use before reading source code for unfamiliar modules.

---

## Add Content

Fetch a URL and add it to the corpus.

```bash
graphify add <url>                             # Fetch URL, save to ./raw, update graph
graphify add <url> --author "Name"             # Tag who wrote it
graphify add <url> --contributor "Name"         # Tag who added it to the corpus
```

Supported URL types (auto-detected):

- **Twitter/X** → fetched via oEmbed, saved as `.md` with tweet text and author
- **arXiv** → abstract + metadata saved as `.md`
- **PDF** → downloaded as `.pdf`
- **Images** (.png/.jpg/.webp) → downloaded, Claude vision extracts on next run
- **Any webpage** → converted to markdown via html2text

After saving, automatically triggers an incremental update to merge into the graph.

---

## Export & Output Formats

### Visualization

```bash
graphify <path> --html                         # HTML is default — this is a no-op
graphify <path> --no-viz                       # Skip visualization, just report + JSON
graphify <path> --svg                          # Export graph.svg (embeds in Notion, GitHub)
```

### Graph interchange formats

```bash
graphify <path> --graphml                      # Export graph.graphml (Gephi, yEd)
graphify <path> --neo4j                        # Generate graphify-out/cypher.txt for Neo4j import
graphify <path> --neo4j-push bolt://host:7687  # Push directly to a running Neo4j instance
```

### Agent-friendly formats

```bash
graphify <path> --wiki                         # Build wiki: index.md + one article per community
graphify <path> --obsidian                     # Generate Obsidian vault (one note per node + canvas)
graphify <path> --obsidian --obsidian-dir DIR  # Obsidian vault at custom path
```

**Wiki** (`--wiki`): generates `graphify-out/wiki/index.md` as an entry point with links to
per-community articles. Agents can navigate by reading files — no graph parsing needed.

**Obsidian** (`--obsidian`): generates one markdown note per concept node with backlinks.
Opening as an Obsidian vault gives you graph view with community coloring.

---

## MCP Server

Start a stdio MCP server for live agent access to the graph.

```bash
graphify <path> --mcp
# or
python3 -m graphify.serve graphify-out/graph.json
```

Exposes tools: `query_graph`, `get_node`, `get_neighbors`, `get_community`, `god_nodes`,
`graph_stats`, `shortest_path`.

### Claude Code MCP configuration

Add to your Claude Code MCP settings (e.g., `claude_desktop_config.json` or project `.mcp.json`):

```json
{
  "mcpServers": {
    "graphify": {
      "command": "python3",
      "args": [
        "-m",
        "graphify.serve",
        "/absolute/path/to/graphify-out/graph.json"
      ]
    }
  }
}
```

This gives agents native tool access to the graph — they can query without shelling out.

---

## Watch Mode

File watcher that auto-rebuilds on changes. Runs in the background.

```bash
graphify <path> --watch                        # Default 3s debounce
python3 -m graphify.watch <path> --debounce 3  # Explicit debounce control
```

Behavior:

- **Code file changes** → re-runs AST + rebuild + cluster immediately (no LLM)
- **Doc/paper/image changes** → writes a flag and prints notification to run `--update` (LLM needed)
- **Debounce** waits until file activity stops, so parallel agent writes don't trigger per-file rebuilds

---

## Community Clustering

Re-run clustering on an existing graph without re-extracting.

```bash
graphify <path> --cluster-only
```

Loads `graphify-out/graph.json`, runs Leiden community detection, regenerates communities and
GRAPH_REPORT.md. Useful after manually editing graph.json or tweaking clustering parameters.

---

## Graph Report

The `GRAPH_REPORT.md` is the most important orientation artifact. Key sections:

- **God Nodes** — highest-degree concepts that everything routes through. These are the critical
  modules — changing them has the widest blast radius.
- **Communities** — clusters of related concepts. Each community is labeled with a 2-5 word name.
  Cohesion scores indicate how tightly connected each cluster is.
- **Surprising Connections** — cross-community edges ranked by unexpectedness. These are the
  relationships you wouldn't find by grepping.
- **Suggested Questions** — questions the graph can answer that cross community boundaries.
- **Token Cost** — input/output tokens used for this run and cumulative across all runs.

When orienting on a codebase, read God Nodes and Communities first. They give you the structural
map that makes individual file reads meaningful.

---

## Git Hooks (NOT used in our vault — documented for reference)

Graphify can install a post-commit hook that auto-rebuilds the graph after every commit.
We do NOT use this — our centralized vault is rebuilt via Makefile, not per-repo hooks.

```bash
graphify hook install    # Install post-commit AST rebuild hook
graphify hook uninstall  # Remove the hook
graphify hook status     # Check whether the hook is installed
```

Behavior: after every `git commit`, detects changed code files via `git diff HEAD~1`,
re-runs AST extraction on those files, rebuilds graph.json and GRAPH_REPORT.md.
Doc/image changes are ignored — requires manual `--update`.

---

## Claude Integration (NOT used in our vault — documented for reference)

Graphify can auto-configure Claude Code with a CLAUDE.md section and a PreToolUse hook.
We do NOT use this — our skill replaces both the CLAUDE.md section and the hook.

```bash
graphify claude install    # Write ## graphify section into project's CLAUDE.md + install PreToolUse hook
graphify claude uninstall  # Remove the graphify section from CLAUDE.md
```

The PreToolUse hook fires before every Glob and Grep call, injecting a reminder to
consult GRAPH_REPORT.md first. This is designed for colocated graphs (`./graphify-out/`),
not centralized vaults.
