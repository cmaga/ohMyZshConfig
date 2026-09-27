# ADR Body Template

ADRs follow MADR conventions. The record is immutable history; its CURRENCY is mutable and lives at the top. Frontmatter carries the one-line summary and, when the user relayed it, the approval:

```
y_statement: In the context of <use case>, facing <concern>, we decided for <option> and neglected <alternatives>, to achieve <quality>, accepting <downside>.
approved_by: <handle> YYYY-MM-DD
```

The `y_statement` is written once at capture and never edited afterwards; every clause traces to the brief or the body, and a clause the brief did not supply reads `[unstated in brief]`. Keep it under 400 characters by summarizing the neglected options. `approved_by` comes only from the user's relayed words (`agent` on an unattended run, which the linter flags); with neither, omit the key. Body, in order:

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

## Considered options
<Chosen option first, marked (chosen), then each rejected option with its one-line reason:
- <option> (chosen) - <why it won>.
- <option> - rejected: <why>.
Optionally a ranked `Drivers:` line first. When only one option existed, write
_Only option: <why>._ ; when the brief named none, write
_No alternatives recorded: brief named none._ and say so in the handoff.>

## Consequences
<Bulleted list. Mix positive, negative, and neutral consequences. Wikilink
the components, constraints, or domain notes that this decision changes.>

## Objections considered
<Optional. One bullet per objection, each ending with its disposition:
- <objection> - accepted as cost (see Consequences).
- <objection> - rejected: <why>.
- <objection> - deferred: revisit if <condition>.  (copy the condition into revisit_if)>
```

An ADR written before this template gets `y_statement` and `## Considered options (recorded YYYY-MM-DD)` only when it is touched for another reason, and only from alternatives its body or the brief evidences; never invent options after the fact.

A current ADR carries NO `> Status:` banner. Absence means "no known supersession," not "audited current" — readers still reconcile against code.

## Amending vs superseding

The fork that keeps the log honest without flip-flop chains:

- **Refine the same decision** (new facts, the call evolves but the question is the same): append a dated `## Amendment (YYYY-MM-DD)` block at the end; leave Context / Decision / Consequences intact above it. If the amendment OVERTURNS the original Decision, set `status: amended` and add the `> Status: AMENDED` banner so a top-down reader cannot miss that the Decision above is stale.
- **Re-decide the question** (a different answer): write a NEW ADR and, in the same change, demote the old one (`status: superseded`, `superseded_by:`, `> Status: SUPERSEDED` banner). Do NOT rewrite the old Decision in place — a stable ADR number must keep meaning one thing across git history, or every `per ADR-NNN` reference in commits, PRs, and tickets silently rots.

Skip the template for non-ADR buckets — they take whatever shape fits the content.
