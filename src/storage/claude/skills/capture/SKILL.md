---
name: capture
description: Add durable knowledge (architectural decisions, non-obvious constraints, cross-project patterns) to the knowledge vault at ~/dev/vault/. Triggers on explicit requests ("capture this", "add to vault", "save this") or when the current session produced knowledge worth preserving that is not already in code or git. Writes an Obsidian-style note to the correct vault path and commits to the vault repo. Do NOT use for orientation reads — those are handled by the knowledge-vault rule and the SessionStart hook.
---

# Capture

Write new durable knowledge into `~/dev/vault/`. Only content that is
non-obvious and won't rot in a commit message — not task narratives, status
updates, or facts the code itself expresses.

The vault has its own git-backed rebuild automation: committing to the vault
triggers a background graph rebuild via `post-commit` hook. This skill's job
is **write the note and commit**. It does not invoke graphify.

## When to trigger

Capture when:

- User says "capture this", "add to vault", "save this", "graphify this"
- The session produced a decision plus its rationale ("we chose X over Y because Z")
- A non-obvious constraint, invariant, or gotcha surfaced
- A cross-module or cross-project relationship came up that is invisible from imports alone

Do NOT capture:

- Implementation details already visible in the code
- Task state, status updates, "what I just did" — git log and PRs hold those
- Content already in the vault (grep first; see step 2)

## Preflight

1. `~/dev/vault/` exists → if missing, **HARD STOP**. Tell the user the vault is managed separately.
2. `~/dev/vault/projects.json` exists → if missing, **HARD STOP**. It maps repo basenames to vault paths.

## Workflow

### 1. Extract candidate knowledge

Pull only durable pieces from the current context:

- Decision + rationale
- Hidden constraint or invariant
- Non-obvious relationship between concepts

If nothing fits, stop. Do not invent content.

### 2. Check for duplicates

Grep the vault for the concept name and adjacent terms:

```bash
grep -r -l -i "<concept>" ~/dev/vault/ --include='*.md'
```

Decide:

| Result                          | Action                                   |
| ------------------------------- | ---------------------------------------- |
| Exact concept already captured  | Stop                                     |
| Related note exists             | New note, add `[[wikilink]]` to it       |
| No match, project-specific      | New note under the project's vault path  |
| No match, spans projects        | New note under `~/dev/vault/brain/`      |

### 3. Resolve placement

For project-specific knowledge, resolve the current repo to its vault path:

```bash
repo=$(basename "$(git rev-parse --show-toplevel)")
rel=$(jq -r --arg k "$repo" '.[$k] // empty' ~/dev/vault/projects.json)
```

Behavior by `rel` result:

- Non-empty → target is `~/dev/vault/<rel>/<category>/`
- Empty and knowledge is cross-project → target is `~/dev/vault/brain/<category>/`
- Empty and knowledge is project-specific → see "Project not yet indexed" edge case

Categories:

- Per-project: `architecture/`, `constraints/`, `decisions/`, `customers/`, `domain/`, `plan/`, `research/`
- Brain: `patterns/`, `principles/`, `tools/`

Create the subdirectory if it doesn't exist.

### 4. Write the note

Obsidian-compatible markdown, one concept per file:

- Filename: kebab-case concept name (e.g., `decision-fast-bulk-queue-split.md`)
- Title heading = the concept name (becomes the graph node label)
- 2–4 sentences stating the knowledge
- `[[wikilinks]]` to related notes identified in step 2
- For a decision: add a `> **Why:**` block with one-line rationale and today's date

Keep it compact. Multiple concepts → multiple files.

### 5. Commit to the vault

```bash
git -C ~/dev/vault add <new-file-paths>
git -C ~/dev/vault commit -m "capture: <concept>"
```

The vault's `post-commit` hook triggers a background graph rebuild. Do not wait for it.

## Edge cases

### Note already exists with same meaning

Update the existing note in place. Commit with `capture: update <concept>`.

### Project not yet indexed

If the current repo isn't in `projects.json` but the knowledge is clearly
project-specific, ask the user once:

> Add `personal/<repo>/` to the vault? (yes / no / not now)

- **yes** → create `~/dev/vault/personal/<repo>/_index.md` with a minimal stub (title, one-line purpose, empty Knowledge Map), add `"<repo>": "personal/<repo>"` to `projects.json`, then proceed with step 3.
- **no** → capture aborts. Do not write anywhere.
- **not now** → capture aborts. Question recurs on next trigger.

### Vault or `projects.json` missing

HARD STOP. Tell the user — do not try to create either from this skill.
