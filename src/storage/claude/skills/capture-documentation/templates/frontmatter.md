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
- `deprecated` — no longer applies. A decision keeps its body and carries a `> Status:` banner saying why. Any other note becomes a tombstone: `obsoletion_reason: merged | split | removed | wrong`, `retired: YYYY-MM-DD`, exactly one of `replaced_by: "[[note]]"` (merged) or `consider: [[[a]], [[b]]]` (split needs two or more), the banner, and a single `History: git log --follow -- <path>` line in place of the prose. Written by `vault-refactor.sh retire`, never by hand.
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
- **Decision:** `revisit_if: [code:`path` condition, data:<metric condition>, external:<vendor or market fact>, date:YYYY-MM-DD]` or `revisit_if: none - <reason>` — the typed reopen tripwires; a `date:` item shows up as overdue, a `code:` item is checked against the tree by the audit, `data:`/`external:` are listed for a human. Required on `status: revisit`.
- **Any type:** `conflicts_with: ["[[other]]"]` — the live note this one disagrees with on a claim the brief could not settle; written on both notes together with the `> Status: CONTESTED with [[other]] on <axis>` first body line, and removed from both when the owners rule.
- **Decision:** `tracking: <ticket>` and `expires: YYYY-MM-DD` — transitional decisions only; an expired one is flagged.
- **Decision:** `y_statement: In the context of .., facing .., we decided for .. and neglected .., to achieve .., accepting ..` — one line, written once at capture, under 400 characters; its `_index.md` line repeats it verbatim.
- **Decision:** `approved_by: <handle> YYYY-MM-DD` — only from the user's relayed words; `agent` on an unattended run; otherwise omitted.

A key is added to this file only once a shipped script reads it, or when it changes whether the body is trusted before it is read.
