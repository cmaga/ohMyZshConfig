---
name: capture
description: Add durable knowledge (architectural decisions, non-obvious constraints, cross-project patterns) to the Graphify vault at ~/vault/. Triggers on explicit requests ("capture this", "add to vault", "save this") or when the current session produced knowledge worth preserving that is not already in code or git. Queries the vault for placement, writes an Obsidian-style note to the right location (project or brain), and runs a graphify incremental update. Do NOT use for orientation reads — the knowledge-vault rule handles those via GRAPH_REPORT.md / wiki/.
---

# Capture

Write new, durable knowledge into the centralized Graphify vault at `~/vault/`. Only knowledge that is non-obvious and won't rot in a commit message — not task narratives, status updates, or things the code already expresses.

CLI syntax lives in [`references/graphify-cli.md`](references/graphify-cli.md). Use this file for the workflow; jump to the reference when you need command details.

## Vault layout

```
~/vault/
├── projects/<repo>/     # Obsidian notes + graphify-out/ for one repo
├── brain/               # Cross-project knowledge
├── graphify-out/        # Global merged graph
└── .declined-projects   # Repos the user opted out of (per-machine, gitignored)
```

Project mapping is identity: `~/dev/<repo>` → `~/vault/projects/<repo>/`.

## When to trigger

Capture when:

- User says "capture this", "add to vault", "save this", "graphify this"
- The session produced a decision plus its rationale ("we chose X over Y because Z")
- A non-obvious constraint, invariant, or gotcha surfaced
- A cross-module or cross-project relationship came up that is invisible from imports alone

Do NOT capture:

- Implementation details already visible in the code
- Task state, status updates, "what I just did" — git log and PRs hold those
- Content already in the vault (step 2 checks)

## Preflight

1. `command -v graphify` → if missing, **HARD STOP** (see Edge cases).
2. `~/vault/` exists → if missing, **HARD STOP**.
3. `~/vault/projects/<repo>/` exists for the current project → if missing, see Edge cases before proceeding.

## Workflow

### 1. Extract candidate knowledge

Pull only the durable pieces from the current context:

- Decision + rationale
- Hidden constraint or invariant
- Non-obvious relationship between concepts

If nothing fits, stop. Do not invent knowledge to capture.

### 2. Query the vault for placement

Before writing, query the graph to avoid duplicates and find wikilink targets. See [`references/graphify-cli.md`](references/graphify-cli.md#query--traversal) for flags and budgets.

- `graphify explain "<concept>"` — does a node already exist?
- `graphify query "<nearby topic>" --budget 500` — what community does this sit in?
- `graphify path "<A>" "<B>"` — is there already a relationship between candidates?

Decide based on results:

| Result                            | Action                                          |
| --------------------------------- | ----------------------------------------------- |
| Node exists, same meaning         | Update the existing Obsidian note               |
| Node exists, related but distinct | New note, wikilink to the existing node         |
| No match, project-specific        | New note under `~/vault/projects/<repo>/`       |
| No match, pattern spans projects  | New note under `~/vault/brain/`                 |
| Already captured verbatim         | Stop                                            |

### 3. Write the note

Obsidian-compatible markdown, one concept per file:

- Title = the concept name (becomes the graph node label)
- 2–4 sentences stating the knowledge
- `[[wikilinks]]` to neighbors identified in step 2
- If it's a decision: capture date (today) and a one-line rationale

Keep it compact. Multiple concepts → multiple files.

### 4. Re-index the graph

Incremental update so the new note merges into `graph.json` and `GRAPH_REPORT.md`. See [`references/graphify-cli.md`](references/graphify-cli.md#incremental-update).

- Project-level: `graphify ~/dev/<repo> --update --obsidian --obsidian-dir ~/vault/projects/<repo>/`
- Brain-level: `graphify ~/vault/brain --update`

## Edge cases

### Project has no vault yet

1. Check `~/vault/.declined-projects`. If the repo name is listed, silently skip — do not prompt.
2. Otherwise ask once: "Build a Graphify vault for `<repo>`? (yes / no / not now)"
3. **yes** → full build, then resume at step 2 of the main workflow:
   ```bash
   graphify ~/dev/<repo> --mode deep --obsidian --obsidian-dir ~/vault/projects/<repo>/
   ```
4. **no** → append `<repo>` to `~/vault/.declined-projects` (create the file if missing). Also ensure `.declined-projects` is listed in `~/vault/.gitignore` (create the gitignore if missing) — the registry is per-machine and must never be committed. Capture aborts.
5. **not now** → capture aborts without writing to the registry. The question recurs on next trigger.

### `graphify` CLI unavailable

**HARD STOP.** Tell the user graphify is required and capture cannot proceed. Do not write notes that won't be indexed — orphan notes rot.

### `~/vault/` root missing

**HARD STOP.** The vault is managed separately from any repo. Tell the user.

## Full CLI reference

Command syntax, flags, output formats, MCP server: [`references/graphify-cli.md`](references/graphify-cli.md).
