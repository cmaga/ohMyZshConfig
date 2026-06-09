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

- **Decision (ADR):** add `superseded_by: [[ADR-NNN-name]]` (a clean wikilink, never free text) when superseded. When a later note has weakened a premise but the question has not been re-decided, keep `status: active` and carry a `> Status: ACTIVE, premise weakened by [[ADR-NNN]] ...` banner — do not invent a half-superseded status value.
- **Constraint:** add `severity: blocking | high | medium | low`.
- **Policy:** add `steward:` (the role responsible for the policy — e.g. `founder` for a solo operation, or a named role like `head of engineering` / `CISO` once those exist; never a personal name) and `review_cadence:` (e.g. `annual`, `semi-annual`, `annual-or-on-material-change`).
