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
- Before writing code in a subsystem, read its vault note (component / architecture / domain / constraint) and reach for the symbols in `## Reusable surface` before writing new ones.
- If the note lacks `## Reusable surface`, populate it before continuing. The section is the discovery surface that prevents duplicate implementations.
- If a listed symbol fails to be used as documented (renamed, moved, behaviorally drifted), repair the affected entry.

### Writing/Editing and Initial Setup

- All changes to the knowledge vault **MUST** go through the capture documentation skill.
