# <SPEC NAME> — spec

<!--
Output format for the ultra tier. The process that fills this in is
common/ultra.md.

Written to the project's drafts directory (`docs/drafts/` unless the project
uses another).

The body is free-form: write the document the content wants, as prose that
reads the way the system works end to end. The template demands two
structural things — the work is carved into chunks, and the chunks are
grouped into waves.

A chunk is a named unit of work one ticket delivers. It is built and merged
on its own, and its section must let a reader answer three things: what it
does when it is live, which chunks must be merged before it can be built,
and how it is proven. A chunk does not have to be a user-facing capability:
shared infrastructure other chunks ride on is a chunk in its own right — the
means of a strategy, not a strategy.

A wave is every chunk that can be built at the same time. One wave's chunks
are built in parallel by separate agents that cannot see each other's work,
so nothing in a wave may depend on anything else in it. The whole spec
deploys as one release, so waves are the only thing sequencing the build:
push a chunk into a later wave only where the design truly forces it, since
every chunk moved back is throughput given away.

Number chunks C-1, C-2, … straight through the document, ignoring wave
boundaries. An id is permanent once assigned: a chunk added later takes the
next free number wherever it sits, and nothing already written is renumbered
around it — a ticket names its chunk by id, and renumbering would silently
repoint it. dev-workflow reads this at Step 2: a ticket names its chunk by
C-N id and that section is the contract for the run. The C-N ids, the wave
headings, each chunk's Needs line, and its closing Tests heading are the
lookup surface — keep that markup exactly as written here. The words inside
a wave heading are yours: when a fold-in makes one untrue, fix it in the same
edit, and let the cohesion pass catch what slipped. Everything else is open.

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

## Wave 1 — <what becomes true once this wave lands>

<!--
The heading carries one behavioral line: what the integration branch can do
after this wave that it could not before. Read top to bottom, the wave
headings alone are the build narrative, and they are what the user walks
when they test the branch before merging.

Chunks in one wave often unlock different things, and the line does not have
to force them into one capability — say both, in the branch's terms. Write
what becomes possible, never a list of what the chunks are.

Wave 1 is everything that needs nothing. Any wave holding a single chunk is
worth a second look, since a sequential carve is usually habit rather than
necessity — but a foundation everything else reads from really is alone, and
so is a capability that cannot start until several earlier chunks are all
merged. Once you have checked, leave it there.
-->

### C-1: <name>

Needs: <C-x, C-y | none>

<!--
Needs names the chunks this one consumes, and the why — what it cannot do
until they are merged — is said either in the body or in the wave's opening
lines, where one sentence often covers every chunk in it. The wave already
said when; this says why.
Everything named here must sit in an earlier wave — a Needs pointing inside
its own wave is the one error that breaks the build, since siblings cannot
see each other.

Free-form body, end to end: a reader should be able to follow the chunk the
way the live system executes it. Where the chunk bets on a premise about the
world, state in prose the observation that would prove the premise wrong.
Never how it is built. Naming a file, class, function, library, or ticket key
is the obvious version, but the line is wider than code nouns: a storage
shape, a data structure, an ordering, a concurrency model usually smuggle it
in too. None of those words is banned on sight — the test is the rule, and the
list is only where it most often trips: could two competent teams build your
sentence differently and both be right? If it rules one of them out without a
behavioral reason, it belongs in the run's plan, not here.

One exception: a named established mechanism the spec deliberately adopts —
the named equivalent that ultra's precedent research hunts down — is a decision, not an
implementation detail. Name it and say what it buys; inheriting its
literature is the whole point of naming it.

Unresolved items sit inline where they belong, flush left, labelled:

**Open question:** undecided, needs the user's call.

**Post-deploy:** cannot be decided until the spec is live and real traffic
answers it. Ships as a follow-up ticket, never as a blocker.

The task tracker is the index — no rollup section here.
-->

#### Tests

<!--
Last thing in every chunk: how it is exercised end to end, then one named
scenario per edge case. The body's rule holds here too — a scenario says what
is observed, never how the code makes it so. Surviving findings from the adversarial gate land
here. It is the longest part by far, and every scenario carries its
reasoning — a named bullet with a sentence behind it, never a bare list of
labels.
-->

## Wave 2 — <what becomes true once this wave lands>

<!--
Same shape, repeated for as many waves as the design forces. A wave exists
because its chunks could not be built until the previous wave was merged —
if you cannot say which earlier chunk each one is waiting on, it belongs in
the earlier wave.
-->
