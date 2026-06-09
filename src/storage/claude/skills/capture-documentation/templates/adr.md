# ADR Body Template

ADRs follow MADR conventions. The record is immutable history; its CURRENCY is mutable and lives at the top. Body, in order:

```
# ADR-NNN: <decision title>

> Status: <PRESENT ONLY WHEN NOT CURRENT — the first thing under the title, one line.
>   SUPERSEDED by [[ADR-NNN-name]] — read that instead.
>   DEPRECATED — <why it is moot>; no replacement.
>   AMENDED <YYYY-MM-DD> — the Decision below was overturned in place by the Amendment dated <date>; read it first.
>   ACTIVE, premise weakened by [[ADR-NNN]] — re-validate before quoting the Decision.>

## Context
<1-3 paragraphs: the situation that forced the decision, the constraints,
and what was already true. Wikilink prior ADRs and constraints that bound this one.>

## Decision
<1-2 paragraphs: what we chose, stated in the present tense as written AT DECISION TIME.
Whether that choice is still load-bearing TODAY is governed by the `> Status:` banner above,
not by hedging this prose. The banner is the single hedge site — never water down the title
or this section to signal staleness.>

## Consequences
<Bulleted list. Mix positive, negative, and neutral consequences. Wikilink
the components, constraints, or domain notes that this decision changes.>
```

A current ADR carries NO `> Status:` banner. Absence means "no known supersession," not "audited current" — readers still reconcile against code.

## Amending vs superseding

The fork that keeps the log honest without flip-flop chains:

- **Refine the same decision** (new facts, the call evolves but the question is the same): append a dated `## Amendment (YYYY-MM-DD)` block at the end; leave Context / Decision / Consequences intact above it. If the amendment OVERTURNS the original Decision, set `status: amended` and add the `> Status: AMENDED` banner so a top-down reader cannot miss that the Decision above is stale.
- **Re-decide the question** (a different answer): write a NEW ADR and, in the same change, demote the old one (`status: superseded`, `superseded_by:`, `> Status: SUPERSEDED` banner). Do NOT rewrite the old Decision in place — a stable ADR number must keep meaning one thing across git history, or every `per ADR-NNN` reference in commits, PRs, and tickets silently rots.

Skip the template for non-ADR buckets — they take whatever shape fits the content.
