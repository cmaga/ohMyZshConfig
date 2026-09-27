# Frontmatter

Every note starts with YAML frontmatter:

```yaml
---
type: decision | constraint | domain | component | customer | plan | research | architecture | policy
status: <see Status below>
created: YYYY-MM-DD
---
```

## Status

`status` records currency, not just existence. A reader keys on it before the body, so it must stay honest. Allowed values:

- `active` — current and load-bearing. The default for a live note.
- `proposed` — drafted, not yet adopted.
- `revisit` — decided, but with an explicit reopen tripwire (e.g. "revisit when cost > $50/mo"). Still in force until the tripwire fires.
- `superseded` — re-decided by a later note. Pair with `superseded_by:` and a `> Status:` banner. (Decisions.)
- `deprecated` — no longer applies and has no replacement (moot). Carry a `> Status:` banner saying why. (Decisions.)
- `amended` — the original Decision was overturned in place by a dated `## Amendment` block. Carry a `> Status:` banner pointing at it. (Decisions; see [`templates/adr.md`](adr.md).)
- `open` | `closed` — lifecycle for research / plan notes.

A decision whose status is `superseded`, `deprecated`, or `amended` MUST carry a `> Status:` currency banner as the first body line (see the ADR template). Currency lives at the top of the note, never only in a footer: an agent reads the title and first lines and stops, so a staleness signal below the fold does not exist for the reader.

## Per-type extras

- **Decision (ADR):** add `superseded_by: "[[ADR-NNN-name]]"` (a clean wikilink, never free text) when superseded. When a later note has weakened a premise but the question has not been re-decided, keep `status: active` and carry a `> Status: ACTIVE, premise weakened by [[ADR-NNN]] ...` banner — do not invent a half-superseded status value.
- **Constraint:** add `severity: blocking | high | medium | low`.
- **Policy:** add `steward:` (the role responsible for the policy — e.g. `founder` for a solo operation, or a named role like `head of engineering` / `CISO` once those exist; never a personal name) and `review_cadence:` (grammar below).
- **Any type:** add `aliases: [other name, other name]` when the subject goes by names its title does not carry.
- **Any type:** `last_verified: YYYY-MM-DD` — the day the note's code claims were last checked; equals `created` at capture and moves only after a full re-verification.
- **Any type:** `basis: user-stated | inferred` — where the non-code claims came from; `inferred` marks a hypothesis.
- **Any type:** `sources: [ticket:EN-123, pr:45, commit:abc1234, doc:docs/x.md]` — resolved refs only; never a vault note.
- **Any type:** `review_cadence: annual | semi-annual | quarterly | monthly | annual-or-on-material-change | <N>d` — overrides the vault default of 180 days (plan 30, research 90 while open).
- **Decision, constraint:** `governs: [server/services/execution/**, cli/publish.py]` — git pathspecs the note constrains; `governs: []` says it constrains no code; a commit under one raises a drift flag.
- **Any type:** `applies_to: [server/src/features/x/]` — directories the rule stub covers when the Reusable surface does not name them.
- **Decision:** `revisit_by: YYYY-MM-DD` and `revisit_when: <one-sentence tripwire>` — either or both; the date shows up as overdue.
- **Decision:** `y_statement: In the context of .., facing .., we decided for .. and neglected .., to achieve .., accepting ..` — one line, written once at capture, under 400 characters; its `_index.md` line repeats it verbatim.
- **Decision:** `approved_by: <handle> YYYY-MM-DD` — only from the user's relayed words; `agent` on an unattended run; otherwise omitted.

A key is added to this file only once a shipped script reads it, or when it changes whether the body is trusted before it is read.
