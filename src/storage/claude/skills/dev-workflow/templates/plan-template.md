# <TICKET> — <short title>

<!--
Single source of truth for what to build, why, and how.
The intent header (top half) is the contract with workers.
The mechanics (bottom half) is the parent's execution plan.

Tier guidance:
  - small:  no plan.md. Ticket body is the contract; parent verbalizes intent
            in 1-2 sentences before implementing.
  - medium: full template, target 50-150 lines.
  - deep:   full template, target 100-300 lines. Past 500 means over-specified.

Delete sections that do not apply. Empty headers are forbidden — they teach
workers that fields are noise.

During scoping, mark unresolved ambiguity inline as [NEEDS CLARIFICATION: ...].
Parent greps the plan for it and resolves every hit before dispatching workers.
-->

## Objective

<!-- One sentence. Why this work matters. -->

## Outcomes

<!--
2-4 numbered observable state changes from the stakeholder's perspective.
Each must be verifiable without Claude's self-report.

Forbidden: activities ("Claude implements X").
Required: state changes ("user can do X", "endpoint returns Y").
Workers cite these IDs in their task cards.
-->

- O-1:
- O-2:

## Out of scope

<!--
Explicit non-goals. Highest signal-per-line section in the template — workers
expand scope by helpful inference, and only this reliably stops them.
-->

-

## Autonomy

<!-- medium/deep only. Delete for small. -->

**Workers may decide:**

- Internal naming and module structure within their assigned files
- Test scaffolding shape
- Minor refactors to code they are already touching

**Workers must escalate:**

- New runtime dependency
- Schema or migration change
- Public API contract change
- Touching files outside their task card
- Any outcome that becomes ambiguous on a judgment call

## Stop rules

<!-- Hard triggers that halt the worker and surface to the parent. -->

- 3 failed attempts at the same test → stop, write `BLOCKER.md`
- Diff exceeds files in task card → stop
- Any escalation trigger hit → stop
- <N> tool calls without forward progress → stop

---

## Files

<!-- Exhaustive list of paths the workers will touch. -->

-

## Tasks

<!--
One card per worker. T-N IDs cite outcome IDs.
Cards are extracted and passed inline to workers; workers open this file
only if they hit ambiguity.
-->

### T-1: <scope>

- **Satisfies**: O-?
- **Files**: <list>
- **Steps**: <numbered>
- **Done**: <criterion>

## Tests

<!-- Unit and programmatic tests parent writes inline after workers finish. -->

-
