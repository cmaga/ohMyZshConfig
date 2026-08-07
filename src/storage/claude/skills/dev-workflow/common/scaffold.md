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

Anything inside a body that is not the throw is a violation. Before presenting, grep the scaffold diff for function bodies and confirm every one is the throw.

The three shapes it drifts into:

- Control flow "to show the intent"
- The happy path only
- Constants with invented values — a value the ticket or spec settled is scaffold; a value you chose is a body

## Done means it runs

The scaffold is not finished until the project compiles and the test suite executes. Tests must be able to load the scaffolded code and go red on the throw — a suite that errors during import or collection is not red, and the tester cannot tell whether what it wrote is valid.

## Blast radius

When the scaffold changes an existing signature, schema, or shared validator, list every caller at `file:line` with a verdict: survives, or breaks.

This is a work artifact, not a review artifact. Each break becomes a tester test and a line on a worker's card. Do not put the list in front of the user.

Interrupt the user only when the list says something about the design: a caller that cannot be fixed inside this plan, or a count so large the boundary is in the wrong place.

## Partition check

The scaffold must allow the work to split into disjoint file sets, one per worker. If it cannot, the module boundaries are wrong — say so now rather than discovering it at merge time.

## Editing existing code

When the change modifies existing code and adds no structure, there is nothing to scaffold. Start from the integration tests instead: add or modify the tests covering the flow being changed, and treat those as the design artifact.

If the project has no integration suite at all, stop. Recommend building one as its own piece of work, or ask the user whether to skip it for this ticket. Do not proceed silently without one.

## Reviewing it (`large`)

Open the worktree in the user's editor first. They are about to read code, not a chat message:

    code "$(git rev-parse --show-toplevel)"

If `code` is not on `PATH`, say so in one line and give the absolute worktree path instead. Never install anything to make this work.

Then list the scaffold files by path and present the four questions the user is answering. Work through their corrections in the code with them:

1. Do these module boundaries match how this will actually change?
2. Where does state live?
3. What do the interfaces promise?
4. What is conspicuously missing?

In `medium`, skip the review — the scaffold still gets written and committed, because it is the contract that keeps worker files disjoint and frozen, and it is what the tests bind to.
