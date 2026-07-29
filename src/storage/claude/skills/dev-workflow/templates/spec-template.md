# <SPEC NAME> — spec

<!--
Output format for the ultra tier. The process that fills this in is
common/ultra.md.

Written to the project's drafts directory (`docs/drafts/` unless the project
uses another).

The body is free-form: write the document the content wants, as prose that
reads the way the system works end to end. The template demands exactly one
structural thing — the work is carved into chunks.

A chunk is a named unit of work one ticket delivers. It deploys on its own,
in the spec's declared order, and its section must let a reader answer three
things: what it does when it is live, what it needs deployed before it, and
how it is proven. A chunk does not have to be a user-facing capability:
shared infrastructure other chunks ride on is a chunk in its own right — the
means of a strategy, not a strategy.

dev-workflow reads this at Step 2: a ticket names its chunk by C-N id and
that section is the contract for the run. The C-N ids, each chunk's Needs
line, and its closing Tests heading are the lookup surface — keep those
exactly as written here. Everything else, including how many chunks there
are and what order the document presents them in, is open.

Number a chunk's subsections by its id — C-1's sections are 1.1, 1.2, …;
C-2's are 2.x — so a prose ref like "section 1.9" names its chunk by
itself.
-->

## Context

<!--
Why this spec exists, and why now. If it follows a failure, what the failure
was and what it cost, in the plainest terms available — lessons learned
belong here as prose, not as a numbered rule list. A reader who has never
seen the system should finish this section knowing what is being built.
-->

## C-1: <name>

Needs: <C-x | none>

<!--
Free-form body, end to end: a reader should be able to follow the chunk the
way the live system executes it. Where the chunk bets on a premise about the
world, state in prose the observation that would prove the premise wrong.
Never how it is built — a sentence naming a file, class, function, library,
or ticket key does not belong in a spec; the run's own plan names those.

Unresolved items sit inline where they belong, labelled:

  **Open question:** undecided, needs the user's call.
  **Awaiting C-x:** cannot be decided until that chunk ships and produces
  the evidence.

The task tracker is the index — no rollup section here.
-->

### Tests

<!--
Last thing in every chunk: how it is exercised end to end, then one named
scenario per edge case. Surviving findings from the adversarial gate land
here. It is the longest part by far and reads as a closing argument, not a
bullet.
-->
