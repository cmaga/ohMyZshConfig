# Project Knowledge Vault

`docs/project-knowledge/` is the definitive source for project documentation: decisions, constraints, domain rules, architecture, and components. The vault is self-contained.

## Pre-req

Not every project has a knowledge vault. The following rules are for projects that do.

## Rules

### Reading

Start at [`docs/project-knowledge/_index.md`](docs/project-knowledge/_index.md) for orientation. Vocabulary lives in [`glossary.md`](docs/project-knowledge/glossary.md).

- When gathering context, **always investigate the codebase first**, then the vault. Code is truth.
- If the vault has drifted from the code, surface it to the user immediately. Don't reconcile silently.
- Follow `[[wikilinks]]`. They are load-bearing context, not decoration.
- A decision note carrying a `> Status:` banner (or a `status` of `superseded` / `deprecated` / `amended`) is **not** current truth on its own. Read the notes it names before reporting what it decided; treat the banner as a hard stop, like a failing test. Absence of a banner means "no known supersession," not "audited current" — reconcile against code regardless.
- Before writing code in a subsystem, read its vault note (component / architecture / domain / constraint) and reach for the symbols in `## Reusable surface` before writing new ones.
- If the note lacks `## Reusable surface`, populate it before continuing. The section is the discovery surface that prevents duplicate implementations.
- If a listed symbol fails to be used as documented (renamed, moved, behaviorally drifted), repair the affected entry.

### Writing/Editing and Initial Setup

- All changes to the knowledge vault **MUST** go through the `vault-scribe-agent` subagent. Dispatch it with a content brief — the facts, numbers, and why — then review the content summary it returns and approve or reply with tweaks. The agent owns all vault mechanics.
- For a quick manual capture, invoking the capture-documentation skill inline is acceptable — same rules, same handoff.
