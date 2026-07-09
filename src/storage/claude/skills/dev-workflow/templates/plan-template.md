# <TICKET> — <short title>

<!--
Plan file used by medium and deep tiers. Small tier does not write a plan.

The intent header (Objective, Outcomes, Out of scope, Autonomy, Stop rules)
is the contract with workers. The mechanics (Files, Tasks, Tests) are the
parent's execution plan.

Length is whatever the workers need — the user reads the plan-presentation
summary, not the file. Delete sections that do not apply. Empty headers are
forbidden — they teach workers that fields are noise.

Deep tier: qa-planner-agent appends a ## QA Plan section after the parent
finishes drafting. Do not pre-create it.

During planning, mark unresolved ambiguity inline as [NEEDS CLARIFICATION: ...].
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

## Reuse contract

<!--
From the Step-3 codebase-fit pass, plus the `## Reusable surface` entries of
any vault component notes this plan touches. Symbols workers must use instead
of re-implementing, and logic to promote rather than copy. Parent review
rejects diffs that re-implement anything listed. Delete only when the change
adds no new components.
-->

- Use `<symbol>` (`<file>`) for <purpose>
- Promote `<function>` from `<script>` to `<destination>`; retarget existing callers

## Autonomy

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
After = dispatch ordering only: list any card this one must run after
(it consumes that card's output, or shares a file with it). none = wave 1.
-->

### T-1: <scope>

- **Satisfies**: O-?
- **After**: <T-x | none>
- **Files**: <list>
- **Steps**: <numbered>
- **Done**: <criterion>

## Tests

<!-- Unit and programmatic tests parent writes inline after workers finish. -->

-
