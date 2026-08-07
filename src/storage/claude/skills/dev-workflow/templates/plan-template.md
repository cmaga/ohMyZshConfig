# <TICKET> — <short title>

<!--
Dispatch plan used by medium and large tiers. Small tier does not write one.

The design is NOT here — it is the committed scaffold. This file exists to
split scaffolded work across workers and to hold the contract they execute
under. Never restate architecture, module boundaries, or interfaces here.

Length is whatever the workers need — the user does not read this file; they
saw the shape gate. Delete sections that do not apply. Empty headers are
forbidden — they teach workers that fields are noise.

Large tier: qa-planner-agent appends a ## QA Plan section after the parent
finishes drafting. Do not pre-create it.

During planning, mark inline: [NEEDS CLARIFICATION: ...] for unresolved
ambiguity, [DEFERRED: ... → ticket] for a related problem too large to fold
in, [REPORT: ...] for an unrelated one. The parent greps for all three and
resolves every hit with the user before dispatching workers.
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

## Scaffold

<!--
The commit the scaffold landed in, and one line on what it establishes.
Workers read the code, not a description of it.

A ticket that only edits existing bodies behind unchanged signatures has
nothing to scaffold. Write `none — no interface changed` and move on.
-->

- Commit: `<sha>`

## Tests

<!--
Integration tests are already written and committed by tester-agent, and are
red. List their paths so workers know what they are iterating against.
Workers write their own unit tests; those are not listed here.
-->

- `<path>` — covers <integration point>

## Reuse contract

<!--
From the shape gate's reuse lines, plus the `## Reusable surface` entries of
any vault component notes this plan touches. Symbols workers must use instead
of re-implementing, and logic to promote rather than copy. Parent review
rejects diffs that re-implement anything listed.
-->

- Use `<symbol>` (`<file>`) for <purpose>
- Promote `<function>` from `<script>` to `<destination>`; retarget existing callers

## Autonomy

**Workers may decide:**

- Internal implementation inside the bodies they own
- Their own unit tests
- Minor refactors to code they are already touching

**Workers must escalate:**

- Any change to a scaffolded signature, type, or schema
- A tester test they believe is wrong
- New runtime dependency
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

<!-- Exhaustive list of paths the workers will touch, taken from the scaffold. -->

-

## Tasks

<!--
One card per worker. T-N IDs cite outcome IDs.
Cards are extracted and passed inline to workers; workers open this file
only if they hit ambiguity.
Model = chosen by archetype (references/archetypes.md) and passed as the
dispatch model opt.
After = dispatch ordering only: list every card this one must run after
(it consumes that card's output, or shares a file with it). Comma-separate
multiple blockers; none = wave 1.
-->

### T-1: <scope>

- **Satisfies**: O-?
- **Model**: <haiku | sonnet | opus>  (never fable — that is the `advisor` tool)
- **After**: <T-x | T-x, T-y | none>
- **Files**: <list>
- **Steps**: <numbered>
- **Done**: <criterion>
