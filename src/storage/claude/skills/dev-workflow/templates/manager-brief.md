# Manager brief

The dispatch prompt for one component's manager. Fill every section or write `none` in it — the form exists because a blank that is visibly empty is the only thing that catches an omission. Every coordination failure worth naming in this workflow was an omission, not a wrong instruction: a clause written into whichever brief was drafted second, a sibling nobody was told about, a number nobody was told to check.

Send it verbatim. What is in angle brackets is yours to fill.

---

Run the `dev-workflow` skill for `<COMPONENT-TICKET>` in auto mode. You are the **manager** for component `<C-N>` of the approved spec at `<absolute path>`; that section is your contract.

## Branch and worktree

- **Your base branch is the local `spec/<SPEC-TICKET>`.** Follow Step 5's spec-descended path: create your worktree from that branch with `git worktree add` and work it by path. It is a local branch and there is nothing to fetch — earlier components are merged into it here, not on a remote, so read it locally and never at `origin/`. Never touch the project's own base branch.
- **If a worktree for your ticket already exists, enter it by path and carry on from what is in it** rather than creating one. You are resuming work a previous run left standing, and its commits are yours to build on.
- **You open no pull request and push nothing.** The whole spec goes up once, at the end, as one pull request the chain parent opens.
- **If `EnterWorktree` refuses you, that is expected — carry on by path.** It only switches from inside an existing worktree, and you start at the repo root. Work through absolute paths and `git -C <worktree>`; both are available to you precisely because you never entered. Do not halt over it and do not retry it, and say in your report that the worktree was driven by path rather than entered.
- **Explore with Read/Grep/Glob at absolute paths inside your worktree**, not through a code-index tool. An index is built against the main checkout, and your branch diverges from it by design.

## What runs and what is skipped

- **Skip** Prerequisite 4, the main-checkout gate — it has already run. Skip Step 3, and all of Step 4 except 4.2 and the tier pick in 4.4; the spec settled the brief, the solution, and the Present, so there is nothing to post and nothing to wait for.
- **Everything not named above runs as normal**, Steps 1 and 2 included — your ticket still gets read, assigned, and moved to In Progress.
- **Do** Step 4.2's codebase-fit pass against `<C-N>`, pick the tier, then run from Step 5 until your work is committed on your own branch, the review gate has passed, and the full suite is green in your worktree. That is a finished component here; there is no pull request and no continuous-integration run to wait on, so the suite is the whole bar.
- **Stop there.** No Landing, no merge, no deploy, no cleanup, and do not call `ExitWorktree`. The chain parent merges your component and will send you back into your worktree to rebase it.

## Concurrent siblings

`<Every manager live in this wave, by component id and ticket, and what each one is doing — or "none: you are alone in this wave.">`

Fill this for every manager in the wave, not for whichever brief raises the question. A manager that does not know a sibling exists will happily rewrite the files that sibling was told to relocate.

## Your lease

`<The source directories you hold this wave, whether each lease is deep or shallow, and the computed do-not-touch set.>`

Ownership of a source directory is a lease held for this wave, not a property of your system. A **deep** lease restructures the directory. A **shallow** lease only follows moves through it — symmetric import rewrites, a few lines a file. Two deep leases on one directory collide; a shallow and a deep lease do not, and where they meet the shallow holder merges first and you rebase onto it.

Do not touch a path on the do-not-touch set. If your contract appears to require one, say so and return rather than taking it — the set is computed from the live branches and is more current than either of our readings of the spec.

## Verify anything I tell you

Everything in this brief is a claim to check, not a fact to act on. Where I give a number, check the number. Where I describe the state of a file, open the file.

This is not caution. Briefs on this workflow have been wrong in two distinct ways, and both were caught only by managers told to verify: stale facts that were true once, and — worse — facts that were never true at all, because a summary preserves the *shape* of a finding while the numbers inside it decay, and the shape reads as authoritative precisely because it is specific. If a claim here is load-bearing for what you build, re-derive it and tell me it was wrong.

## Outcomes, not steps

What follows names what must be true when you are done, not how to get there. Where I have prescribed a step anyway, treat it as a claim to check like any other — prescribed steps in this workflow have repeatedly turned out to be already built, sending the manager to re-derive what exists. Report anything you find already done.

`<The outcomes. For each, what must be true, and the command or file that would show it.>`

## A blocker is not a plan

**A thing that must happen first is a plan. A thing that cannot happen at all is a blocker.** A sequencing constraint is the most convincing form of deferral because it is usually true, and it is one short step from a correct order of operations to stopping.

If you run out of room, say so in those words. `Unstarted, not blocked` is a better report than a blocked one, it costs nothing to read, and the brief that replaces you writes itself from it.

## Deferral

The bar for leaving something out of your component is proof it cannot be done, naming the blocker — never that it is a natural seam, a good follow-up candidate, or a tidy ticket of its own. A rule about what order things happen in inside your system is not permission to omit one of them.

A routing label that hands work to your **own** section is a deferral, not delegation. It reads as diligence and costs one token to write.

## Commit as you go

Commit in coherent pieces throughout, not only at the scaffold. Sessions die, and only committed work survives one — a manager on a large relocation can otherwise go an entire session with nothing committed and be one crash from losing all of it. For a relocation the natural unit is one commit per move, which also makes a bisect land on a single move and a rebase conflict name one thing.

## One writer per worktree

If you fan out, **one worker writes at a time — per tree, not per file.** A working tree is a single mutable object: `git reset`, `checkout --`, `stash`, `clean` and `restore` act on all of it regardless of who was assigned what. Two workers with no file overlap whatsoever have lost a verified session's edits to one `reset`.

Fan out freely for reading — classification, measurement, review, verification. Keep every write in one worker or in your own hands, tell your workers they may not run those commands, and name the siblings in each worker's card so a worker that finds edits it did not make can tell a sibling from an intruder.

## Reporting

- **Never park waiting for an answer.** You cannot message me — a subagent has no address for its parent, so a question you stop on is a question nobody receives. If you need a decision you cannot make, or every route past a refused call is exhausted, end your turn and return the question as your report: what you did, what needs deciding, and what a replacement would need to carry on. A refused tool call is not that moment — try the other route first.
- **Your workers are the last level. They spawn nothing.** Tell every one of them so, in these words: *anything you spawn reports to the chain parent, not to you — do the work yourself.* A result reaches its spawner one level down and no further, so a worker's helper reports past you to a session that never asked for it, and you wait forever on an answer already delivered elsewhere. That binds your reviewer too: if a review needs several perspectives, run those agents yourself so you hold their findings. Where a job is too large for one worker, split it and dispatch the pieces yourself.
- **Record friction with the skill as it happens** — per [friction](../common/friction.md), any place its text underdetermined what you did and you had to decide. Nobody can reconstruct that from your report, and you are the only one who was there. Write the entry and carry on; never return it to me or wait on it.
- **Return your exit report**, naming the branch you committed on and how to exercise your component by hand. Where your component is partial, enumerate what is **not** built, specifically. A label for partial delivery means whatever the last component meant by it, which is how "pass 1 of two" once carried a deferred database move in one report and an entirely unbuilt system in the next.
