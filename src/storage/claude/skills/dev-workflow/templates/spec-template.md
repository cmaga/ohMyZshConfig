# <SPEC NAME> — spec

<!--
Output format for the ultra tier. The process that fills this in is
common/ultra.md.

Written to the project's drafts directory (`docs/drafts/` unless the project
uses another).

dev-workflow reads this at Step 2: a ticket names its system by S-N id and
that section is the contract for the run. Keep the ids and field names
exactly as written here — they are the lookup.

Delete sections that do not apply. Empty headers are forbidden.
-->

## Context

<!--
Why this spec exists, and why now. If it follows a failure, what the failure
was and what it cost, in the plainest terms available. A reader who has never
seen the system should finish this section knowing what is being built.
-->

## Principles

<!--
The non-negotiables every system answers to. After a failure these are the
lessons it taught; greenfield, the invariants the system must hold.
A system tracing to none of these is either unmotivated or this list is short.
-->

- P-1:
- P-2:

## Systems

<!--
One subsection per system: a cohesive unit of work that deploys on its own and
can be tested end to end. Each becomes one ticket and one dev-workflow run.

Where the boundaries fall is the user's call. A unit that cannot deploy alone
is not a system — merge it into the one it needs.

How many systems there are, their order, and how each Behavior is organized
internally are all open. The ids and field names are not.
-->

### S-1: <name>

- **After**: <S-x | none>
- **Traces to**: <P-x>
- **Behavior**: <what this system does and why, in whatever shape fits it. Never how it is built — a sentence naming a file, class, function, library, or ticket key does not belong in a spec; the run's own plan names those.>
- **Falsifier**: <the observation that would prove the premise wrong. "We sell to casual flow" is a belief; "if our fills at a price lose while the public tape's trades at that price win, the premise is dead" is a spec.>
- **Holds while unshipped**: <what must stay true of this system while the ones after it are not yet deployed. Omit for the last system.>

#### Tests

<!--
How this system is exercised end to end, then one named scenario per edge
case. Surviving findings from the adversarial gate land here.

Last thing in the system's section. It is the longest part by far and reads
as a closing argument, not a bullet.
-->

<!--
Unresolved items sit inline in the system they belong to, labelled:

  **Open question:** undecided, needs the user's call.
  **Awaiting S-x:** cannot be decided until that system ships and produces the
  evidence. Expect the rest of the section to be thin, and say why.

The task tracker is the index — no rollup section here.
-->

## Supporting changes

<!--
Infrastructure the systems require that is not strategy in its own right — no
premise, no falsifier, nothing to be wrong about. It exists because a system
needs it, and it is here so it does not get smuggled into a Behavior field or
lost entirely.

One required by a single system rides that system's ticket. One shared by
several gets its own ticket and becomes an After dependency for each system
that needs it.
-->

### SC-1: <name>

- **Required by**: <S-x, S-y>
- **Provides**: <what it must do, in behavior terms>
- **Ticket**: <own key | rides S-x>
