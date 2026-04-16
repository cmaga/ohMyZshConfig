# Knowledge Vault

A centralized Graphify vault lives at `~/vault/`:

- `~/vault/projects/<repo>/` — per-project graph + Obsidian notes
- `~/vault/brain/` — cross-project knowledge
- `~/vault/graphify-out/` — global merged graph

Vault directory names match repo names (`~/dev/<repo>` → `~/vault/projects/<repo>/`).

## Usage

- Before architectural work, read `~/vault/projects/<repo>/graphify-out/GRAPH_REPORT.md`. If `~/vault/projects/<repo>/graphify-out/wiki/index.md` exists, navigate it instead of raw files.
- For cross-project questions, read `~/vault/graphify-out/GRAPH_REPORT.md`.
- To add new knowledge to a vault, invoke the `capture` skill.
- If the current project has no vault yet, `capture` will offer to build one on first trigger.
