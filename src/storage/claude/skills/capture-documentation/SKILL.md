---
name: capture-documentation
description: Adds and maintains documentation into the docs/project-knowledge/. Known colloquially as the knowledge vault. All changes to the knowledge vault should pass through this skill.
disable-model-invocation: false
---

# Knowledge Vault

Capture and maintain durable project knowledge under `docs/project-knowledge/`. Every change is verified against code where possible.

## Critical Rules

- **Quality over throughput.** A bad note with a good wikilink poisons the graph forever. If the input does not clearly belong in the vault, refuse to capture it.
- **Bidirectional wikilinks.** Every new note links out to >=1 existing note. >=1 existing note links back. Orphans must not be allowed.
- **Conventions are inviolable.** ADR-NNN numbering, prefixed kebab-case filenames, frontmatter present. Refuse to write malformed notes.
- **Pick, don't poll.** When two buckets seem to fit, pick the more specific one and explain the choice in the handoff. Do not stall the user with a question.

## Buckets and templates

- Bucket table, naming conventions, decision rules (architecture-vs-components, policy-vs-architecture) → [`references/buckets.md`](references/buckets.md)
- Frontmatter (per type) → [`templates/frontmatter.md`](templates/frontmatter.md)
- ADR body skeleton → [`templates/adr.md`](templates/adr.md)

## Workflow

1. **Confirm the right worktree.** Run `ROOT=$(git rev-parse --show-toplevel)` and use `$ROOT/docs/project-knowledge/` as the absolute base for every ls, grep, Read, Edit, Write that follows. Non-skippable — when invoked from inside a worktree (e.g. during `dev-workflow`), bare relative paths silently resolve against the main checkout and edits land in the wrong tree.
2. **Decide what (if anything) is worth capturing.** Walk the conversation context. For each candidate fact, ask the load-bearing question: **is this non-obvious from the code and worth explicitly documenting?** Reject ephemeral task state, debugging output, anything derivable from `git log` / `git blame`, and anything already in CLAUDE.md. Discuss your reasoning with the user before drafting anything — name what you're including, what you're rejecting, and why. If nothing clears the bar, say so and stop.
3. **Split if needed.** If the surviving content covers multiple unrelated concepts (e.g. a decision _and_ a separate constraint), produce one draft per concept and present them as separate diffs.
4. **Classify** each concept into one bucket from [`references/buckets.md`](references/buckets.md), applying the decision rules (architecture-vs-components, policy-vs-architecture).
5. **Name** the note per the bucket's convention.
6. **Find link targets.** Grep `$ROOT/docs/project-knowledge/` for the key terms. Read the top 3-5 candidate notes to confirm relevance — skip matches on common words. Identify outbound targets (new → existing) and inbound targets (existing → new).
7. **Draft the new note** with frontmatter (see [`templates/frontmatter.md`](templates/frontmatter.md)), body, and outbound `[[wikilinks]]` woven into the prose where they belong (not piled in a "Related" footer). For ADRs, follow [`templates/adr.md`](templates/adr.md). Write to `$ROOT/docs/project-knowledge/<bucket>/<filename>.md`.
8. **Capture the reusable surface.** Identify each load-bearing reusable symbol owned by this subsystem and list it under `## Reusable surface` in the new note. Apply the bar, entry format, and absence-case rule in [`references/buckets.md`](references/buckets.md). Verify each entry by grepping the symbol at the named path (`grep -nE '\b<Symbol>\b' $ROOT/<path>`); fix or drop entries that don't resolve.
9. **Verify code claims.** For every function name, file path, command, or behavior the draft asserts, confirm against the current codebase. If the code has drifted from the claim, fix the draft or surface the discrepancy to the user before continuing.
10. **Edit each inbound target** to add a reciprocal `[[new-note]]` reference in the section that earned the link.
11. **Update `$ROOT/docs/project-knowledge/_index.md`** if the note is hub-level — a new component, ADR class, or major constraint. One-line entry under the appropriate Knowledge Map section.
12. **Update `$ROOT/docs/project-knowledge/glossary.md`** if the note introduces a project-specific term not yet defined.
13. **Verify.** Run the checks in the Verification section below. Fix any failures before handoff. Substitute the actual filename for `NEW`. **DO NOT SKIP ANY BULLET**
    - `grep -c '\[\[' $ROOT/docs/project-knowledge/<bucket>/NEW.md` returns >= 1 — new note has at least one outbound wikilink.
    - For each inbound edit, `grep -l 'NEW' $ROOT/docs/project-knowledge/<bucket>/<inbound>.md` matches — the reciprocal link landed.
    - `git -C $ROOT status --short docs/project-knowledge/` lists the new file and every reciprocal edit. If it shows nothing, the writes landed in the wrong checkout — go back to step 1.
    - New filename matches the bucket convention (e.g. `architecture-*.md` for architecture, bare kebab-case for components, `ADR-NNN-*.md` for decisions, `policy-*.md` for policies).
    - Frontmatter parses as valid YAML and includes `type`, `status`, `created`. Decisions also include `superseded_by` when applicable; constraints include `severity`; policies include `steward` and `review_cadence`.
    - For ADRs only: body contains `## Context`, `## Decision`, `## Consequences` headings.
    - For each in-scope new note (components/, architecture/, domain/, constraint/), `grep -n '^## Reusable surface' $ROOT/docs/project-knowledge/<bucket>/NEW.md` returns a hit, or the section is present with the absence-case stanza and an explicit reason.
    - For each entry under `## Reusable surface`, `grep -nE '\b<Symbol>\b' $ROOT/<path>` returns at least one match.

14. **Hand off with clickable absolute paths.** The user reviews in a VS Code terminal where absolute paths are command-clickable. Open with — verbatim: "All edits are queued for your review. Read each diff carefully before accepting — vault quality is load-bearing for agent retrieval, and slop here is hard to clean up later." Then list every affected file as an **absolute path on its own line**, grouped under `Created:` and `Edited:` headers, with a one-line trailing reason. Use the full `$ROOT/docs/project-knowledge/...` path:

    ```
    **Created**:
      $ROOT/docs/project-knowledge/<bucket>/<file>.md — <bucket>; <why this bucket>

    **Edited**:
      $ROOT/docs/project-knowledge/<bucket>/<file>.md — <what changed and why>
    ```

## Anti-Patterns

- Writing a new note without first finding link targets. Every note belongs in a neighborhood.
- Wikilink dumps in a "Related" footer instead of woven into the prose.
- Updating `_index.md` for every note. Only hub-level additions warrant index entries.
- Glossary entries for generic technical terms. The glossary is for project-specific ubiquitous language only.
- Asking the user to disambiguate two buckets. Pick the more specific one and explain in the handoff.
- Deleting or rewriting existing notes wholesale. If a decision is superseded, mark with `superseded_by:` in frontmatter and add the new ADR; do not delete.
- Forcing a fit. If the input is ephemeral or doesn't match a bucket, refuse with a one-line reason.

## Verification
