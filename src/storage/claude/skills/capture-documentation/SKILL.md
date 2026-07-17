---
name: capture-documentation
description: Adds and maintains documentation into the docs/project-knowledge/. Known colloquially as the knowledge vault. All changes to the knowledge vault should pass through this skill.
disable-model-invocation: false
---

# Knowledge Vault

Capture and maintain durable project knowledge under `docs/project-knowledge/`. Every change is verified against code where possible.

This skill normally runs inside the `vault-scribe-agent` subagent: the caller dispatches a content brief and reviews the content summary that comes back. Invoked inline instead, follow it identically — the conversation is your brief.

## Critical Rules

- **Quality over throughput.** A bad note with a good wikilink poisons the graph forever. If the input does not clearly belong in the vault, refuse to capture it.
- **Bidirectional wikilinks.** Every new note links out to >=1 existing note. >=1 existing note links back. Orphans must not be allowed.
- **Conventions are inviolable.** ADR-NNN numbering, prefixed kebab-case filenames, frontmatter present. Refuse to write malformed notes.
- **Currency lives at the top.** A decision's current standing goes in `status` frontmatter and a `> Status:` banner as the first body line — never only in a Links footer. An agent reads the title and first lines and stops; a staleness signal below the fold does not exist for the reader. See [`templates/adr.md`](templates/adr.md).
- **Pick, don't poll.** When two buckets seem to fit, pick the more specific one. Do not stall the caller with a question.

## Buckets and templates

- Bucket table, naming conventions, decision rules (architecture-vs-components, policy-vs-architecture) → [`references/buckets.md`](references/buckets.md)
- Frontmatter (per type) → [`templates/frontmatter.md`](templates/frontmatter.md)
- ADR body skeleton → [`templates/adr.md`](templates/adr.md)

## Workflow

1. **Confirm the right worktree.** Run `ROOT=$(git rev-parse --show-toplevel)` and use `$ROOT/docs/project-knowledge/` as the absolute base for every ls, grep, Read, Edit, Write that follows. Non-skippable — when invoked from inside a worktree (e.g. during `dev-workflow`), bare relative paths silently resolve against the main checkout and edits land in the wrong tree.
2. **Apply the capture bar.** Work from the caller's brief (invoked inline, walk the conversation context instead). For each candidate fact, ask the load-bearing question: **is this non-obvious from the code and worth explicitly documenting?** Reject ephemeral task state, debugging output, anything derivable from `git log` / `git blame`, and anything already in CLAUDE.md. Do not stop to discuss — rejections are named in the handoff. If nothing clears the bar, say so and stop.
3. **Split if needed.** If the surviving content covers multiple unrelated concepts (e.g. a decision _and_ a separate constraint), produce one note per concept and summarize each separately in the handoff.
4. **Classify** each concept into one bucket from [`references/buckets.md`](references/buckets.md), applying the decision rules (architecture-vs-components, policy-vs-architecture).
5. **Name** the note per the bucket's convention.
6. **Find link targets.** Grep `$ROOT/docs/project-knowledge/` for the key terms. Read the top 3-5 candidate notes to confirm relevance — skip matches on common words. Identify outbound targets (new → existing) and inbound targets (existing → new).
7. **Draft the new note** with frontmatter (see [`templates/frontmatter.md`](templates/frontmatter.md)), body, and outbound `[[wikilinks]]` woven into the prose where they belong (not piled in a "Related" footer). For ADRs, follow [`templates/adr.md`](templates/adr.md). Write to `$ROOT/docs/project-knowledge/<bucket>/<filename>.md`.
8. **Capture the reusable surface.** Identify each load-bearing reusable symbol owned by this subsystem and list it under `## Reusable surface` in the new note. Apply the bar, entry format, and absence-case rule in [`references/buckets.md`](references/buckets.md). Verify each entry by grepping the symbol at the named path (`grep -nE '\b<Symbol>\b' $ROOT/<path>`); fix or drop entries that don't resolve.
9. **Verify code claims.** For every function name, file path, command, or behavior the draft asserts, confirm against the current codebase. If the code disagrees with the brief, the code wins — fix the draft and flag the deviation in the handoff.
10. **Edit the notes this one touches.** (a) *Reciprocal links* — add a `[[new-note]]` reference to each inbound target in the section that earned the link. (b) *Demote what you overturn* — if this note re-decides, deprecates, or overturns an existing decision, then in the **same change set** demote that decision: set its `status` (`superseded` / `deprecated` / `amended`), add its `> Status:` banner naming this note, set `superseded_by:` for a supersede, and update its line in `_index.md`. Demoting the old decision is the same reciprocal discipline as linking; a new decision that silently leaves the old one reading as current is the exact failure this prevents.
11. **Update `$ROOT/docs/project-knowledge/_index.md`** if the note is hub-level — a new component, ADR class, or major constraint. One-line entry under the appropriate Knowledge Map section.
12. **Update `$ROOT/docs/project-knowledge/glossary.md`** if the note introduces a project-specific term not yet defined.
13. **Verify.** Run the checks in the Verification section below. Fix any failures before handoff. Substitute the actual filename for `NEW`. **DO NOT SKIP ANY BULLET**
    - `grep -c '\[\[' $ROOT/docs/project-knowledge/<bucket>/NEW.md` returns >= 1 — new note has at least one outbound wikilink.
    - For each inbound edit, `grep -l 'NEW' $ROOT/docs/project-knowledge/<bucket>/<inbound>.md` matches — the reciprocal link landed.
    - `git -C $ROOT status --short docs/project-knowledge/` lists the new file and every reciprocal edit. If it shows nothing, the writes landed in the wrong checkout — go back to step 1.
    - New filename matches the bucket convention (e.g. `architecture-*.md` for architecture, bare kebab-case for components, `ADR-NNN-*.md` for decisions, `policy-*.md` for policies).
    - Frontmatter parses as valid YAML and includes `type`, `status`, `created`. Decisions also include `superseded_by` when applicable; constraints include `severity`; policies include `steward` and `review_cadence`.
    - For ADRs only: body contains `## Context`, `## Decision`, `## Consequences` headings.
    - Currency: every decision with `status` of `superseded`, `deprecated`, or `amended` carries a `> Status:` line as its first body element naming the relevant note(s), and every `superseded_by: [[ADR-X]]` resolves to an existing file.
    - Run the currency lint on the new and edited notes: `bash ~/.claude/skills/capture-documentation/scripts/lint-vault-currency.sh $ROOT/docs/project-knowledge <changed-files>`. Fix every `FAIL` before handoff; `WARN` is advisory.
    - For each in-scope new note (components/, architecture/, domain/, constraint/), `grep -n '^## Reusable surface' $ROOT/docs/project-knowledge/<bucket>/NEW.md` returns a hit, or the section is present with the absence-case stanza and an explicit reason.
    - For each entry under `## Reusable surface`, `grep -nE '\b<Symbol>\b' $ROOT/<path>` returns at least one match.

14. **Hand off the meat — nothing else.** Your closing message is the caller's review surface: content bullets stating what the vault now records, phrased as the facts themselves in plain language. The caller checks one thing — is this what I intended to be written? — so vault mechanics (buckets, wikilinks, banners, index lines, reciprocal edits, file paths) stay out of the handoff; they are yours, and paths are supplied only on request. Flag content-level deviations inline: anything refused (`Not captured: <fact> — <reason>`) and anywhere code contradicted the brief. Canonical phrasing:

    ```
    - Operator authorized arming (cmagana, 2026-07-16): parlay-responder pilot goes live with real money at micro-size, on the pilot host only.
    - Soak dropped for live guardrails: the multi-day latency soak is replaced by the always-on confirm-latency breaker + bankroll/fill-rate guard, both deployed. A slow confirm fails closed (no fill), so latency degrades to no-trade, never a bad trade.
    - Funding: starts at $1,000, not $2,500 (transfer limits), topped up during the ramp. Bankroll is throughput headroom, not money-at-risk — the $85/fill cap and $1,000 loss backstop are unchanged.
    ```

    Each bullet is the fact as recorded — never an edit description ("added a deviation note", "updated the banner") and never ADR bookkeeping ("this amends ADR-002", "marked superseded"). State a decision's standing as what holds and what no longer holds: "nightly batch retires at migration cutover", not "ADR-002 is now superseded". The caller may reply with tweaks: apply them through this same workflow, re-run step 13, and re-emit the full handoff.

## Anti-Patterns

- Writing a new note without first finding link targets. Every note belongs in a neighborhood.
- Wikilink dumps in a "Related" footer instead of woven into the prose.
- Updating `_index.md` for every note. Only hub-level additions warrant index entries.
- Glossary entries for generic technical terms. The glossary is for project-specific ubiquitous language only.
- Asking the caller to disambiguate two buckets. Pick the more specific one.
- Deleting or rewriting existing notes wholesale. A decision's record is immutable history. To change a decision, either supersede it (new ADR + demote the old one per step 10) or, for same-question refinement, append a dated `## Amendment` block. Never rewrite a Decision's verdict under its old number — that makes one ADR mean different things across git history and rots every `per ADR-NNN` reference.
- Shipping a note that overturns or erodes an existing decision while leaving that decision reading as current (`status: active`, no `> Status:` banner). Demote it in the same change (step 10b).
- Re-stating another note's decision as standalone present-tense fact. Link and attribute (`per [[ADR-NNN]], ...`) instead of re-arguing the verdict; the rationale has one home, the note that owns it.
- Forcing a fit. If the input is ephemeral or doesn't match a bucket, refuse with a one-line reason.

## Verification
