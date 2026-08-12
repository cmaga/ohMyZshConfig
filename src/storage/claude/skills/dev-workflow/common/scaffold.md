# Scaffold

The design, in a form the user can hold: real code, all structure, no behavior. This replaces the plan document as the design artifact — the plan was consumed only by workers and never read.

Written by the parent, not a subagent. The parent already read the system during scoping, and that context does not survive a handoff.

Commit it before dispatching anyone. It survives into the PR.

## What to write

- Type, interface, and schema definitions — complete and real
- Function and method signatures — complete and real
- Module placement: real files, real directories, real imports
- Migration DDL, including the constraints and indexes that enforce something
- Doc comments on the contracts. Everything true about an interface gets documented here, so no worker has to infer it later.

A worker still comments what it discovers inside a body — a coupling nobody predicted, why an edge case is handled the way it is. Those are the comments only someone in the weeds can write. What the scaffold prevents is workers re-documenting the interface from below, where it drifts.

Every function body is exactly the unimplemented throw, in the language's idiom (`throw new Error("unimplemented")`, `raise NotImplementedError`).

## The drift line

**A body is a violation when it contains behavior the tests will check.** Declarations, schema, and wiring are structure even when they live inside a function — migration DDL and the composition root (what gets constructed with what, what order middleware sits in) are scaffold, and leaving them out pushes real design decisions into bodies you will not read.

Everything else is the throw. Before presenting, grep the scaffold diff for function bodies and confirm each one either is the throw or is structure by the line above.

The four shapes it drifts into:

- Control flow "to show the intent"
- The happy path only
- Constants with invented values — a value the ticket or spec settled is scaffold; a value you chose is a body
- A body that returns a closure containing the throw. The outer body is not a throw, and it reads as compliant at a glance

## Done means it runs

The scaffold is not finished until the project compiles and the test suite executes. Tests must be able to load the scaffolded code and go red on the throw — a suite that errors during import or collection is not red, and the tester cannot tell whether what it wrote is valid.

## Blast radius

When the scaffold changes an existing signature, schema, or shared validator, list every caller at `file:line` with a verdict: survives, or breaks.

This is a work artifact, not a review artifact. Each break becomes a tester test and a line on a worker's card. Do not put the list in front of the user.

Interrupt the user only when the list says something about the design: a caller that cannot be fixed inside this plan, or a count so large the boundary is in the wrong place.

## Partition check

The scaffold must allow the work to split into disjoint file sets, one per worker. If it cannot, the module boundaries are wrong — say so now rather than discovering it at merge time.

## Editing existing code

Most tickets change existing code rather than adding modules. Scaffold whatever the change adds or moves at the interface level, however small — a new helper's signature, a changed signature, a widened type. That set is usually a handful of lines.

Sometimes it is empty: a pure body rewrite behind an unchanged signature has no structure to draw. That is a normal outcome, not a separate path. Record `## Scaffold: none — no interface changed` in the plan and carry on; the tests still come before the code, they just bind to a surface that already existed.

If the project has no integration suite at all, stop. Recommend building one as its own piece of work, or ask the user whether to skip it for this ticket. Do not proceed silently without one.

Under auto there is nobody to ask, and nobody reading the PR either: stand up a minimal harness covering this ticket's integration points and continue. The red test is what makes a cheap worker safe, and auto has nothing else in that role.

## Reviewing it (`large`)

Under auto, nobody is opening an editor: call `advisor`, act on what it says, and continue. Only the user's read is converted — the `plan-review-agent` pass in the large sequence still runs. The rest of this section is the attended run.

Open the worktree in the user's editor first. They are about to read code, not a chat message:

    code "$(git rev-parse --show-toplevel)"

If `code` is not on `PATH`, say so in one line and give the absolute worktree path instead. Never install anything to make this work.

Call `advisor` on the scaffold before showing it. This is the cheapest artifact in the run and everything downstream inherits it, so it is the one place a stronger read pays for itself ([archetypes](../references/archetypes.md)).

Then say in two lines what the change is and what the scaffold covers, name the files in the order they should be read, and present the four questions the user is answering. Reading order matters more than completeness — a bare list of paths makes the user pick an entry point into code they have not seen. Work through their corrections in the code with them:

1. Do these module boundaries match how this will actually change?
2. Where does state live?
3. What do the interfaces promise?
4. What is conspicuously missing?

In `medium`, skip the review — the scaffold still gets written and committed, because it is the contract that keeps worker files disjoint and frozen, and it is what the tests bind to.
