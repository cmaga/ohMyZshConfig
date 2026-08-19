# Auto chain

`auto` on a ticket whose spec is already written and approved. Every chunk the spec carves is built and merged onto one integration branch, in waves, and the user is not consulted again until the chain ends.

This Driver is the whole run. Only Step 1's first item ran before it — the ultra ticket was read, assigned, and moved to In Progress. The rest of SKILL.md's Steps 1-4 do not happen: the spec is the approval artifact and settled the intent, the solution, and the routing when the user approved it.

The chain never merges to the base branch and never deploys. It ends with the whole spec sitting on an integration branch the user can run, test, and merge themselves. That final gate is the point: chunks were carved to be built independently, not to ship independently.

`<SPEC-TICKET>` below is the ultra ticket the spec was written on; its description carries the spec's path. The spec merged with its own PR, so that path resolves in the main checkout — read it there, before any branch is cut. `<CHUNK-TICKET>` is one chunk's own ticket.

## Driver

Your session drives and holds almost nothing: the spec path, the wave plan, each chunk's status and returned report. Keep it that way. Dispatching each chunk is what keeps your own context from compacting halfway through the spec.

Seed the task tracker with one item per wave, plus `Integrate wave N` after each, plus `Hand back` — Prerequisite 1's seven-item list describes a single ticket's run and does not fit a chain.

1. **Arm the guard** for the whole chain — `~/.claude/hooks/auto-run-guard.sh start <SPEC-TICKET>`. Disarming is the last tool call of the chain, before the hand-back report and before any halt. The chunk agents are subagents and are not covered by it; they fire `SubagentStop`, which this run must leave alone, and they are told not to arm one of their own.

2. **Run the main-checkout gate once, here.** It is Prerequisite 4 in [SKILL.md](../SKILL.md), and parallel chunk agents running it concurrently would race on one index. Then cut the integration branch and push it without moving the main checkout off the base branch:

       git branch spec/<SPEC-TICKET> && git push -u origin spec/<SPEC-TICKET>

   Every chunk in this chain branches from `spec/<SPEC-TICKET>`, PRs into it, and rebases onto it. The project's own base branch is not touched again until the user merges at the end.

3. **Read the waves off the spec.** Its `## Wave N` headings are the plan — do not recompute one from the `Needs` lines. Check them instead: a `Needs` naming a chunk in the same wave or a later one, or naming something the spec does not define, halts before anything is built. Siblings cannot see each other's work, so that is a spec defect, not something to reorder around.

   **Cap a wave at three chunks.** Each chunk agent runs a scaffold, a tester, a worker fleet and a reviewer of its own, so a wave is already a fan-out of fan-outs, and every extra chunk agent re-pays the same repo background in full. A wider wave queues rather than parallelizes. Where a wave exceeds the cap, split it and run the halves back to back.

4. **Confirm every chunk has a ticket.** Read the ultra ticket via the `jira` skill and match its linked issues to `C-N` ids; file the missing ones the way [ultra](ultra.md) filed the rest — linked to the ultra ticket, naming the `C-N` section rather than copying it, and searching for an existing ticket first. An **Open question** still sitting in a chunk's section is a spec defect: by its own definition no amount of code answers it, and the user is not in the room. That chunk is never dispatched: handing it to an agent only spends a build on a contract nobody settled. Caught here, before its wave opens, the question withholds that whole wave — run the waves before it, then halt by [Halting](#halting) below, with the question in the report. The spec's approval is the go-ahead for these — it is the one place auto files tickets.

5. **Run each wave**: dispatch its chunks in parallel, wait for all of them, integrate them one at a time, then open the next wave. Dispatch is what must wait for the previous wave — chunk agents create their own worktrees, and a wave dispatched early would branch from an integration branch missing the work it needs.

## Dispatching a wave

Spawn one `general-purpose` agent per chunk, all in one message so they run concurrently. Omit the `model` opt — no lever alias covers an agent that runs this entire skill, so let its default stand. Each agent gets:

> Run the `dev-workflow` skill for `<CHUNK-TICKET>` in auto mode. It is chunk `C-N` of the approved spec at `<absolute path>`; that section is your contract.
>
> - **Your base branch is `spec/<SPEC-TICKET>`.** Follow Step 5's spec-descended path: create your worktree from that branch with `git worktree add` and enter it by path. Target your PR at it, and never touch the project's own base branch. Investigate it too — earlier chunks are merged there and are not in the main checkout.
> - **Skip** Prerequisite 4, the main-checkout gate — it has already run. Skip Step 5.3, arming a guard — the chain owns it. Skip Step 3, and all of Step 4 except 4.2 and the tier pick in 4.4; the spec settled the brief, the solution, and the Present, so there is nothing to post and nothing to wait for.
> - **Everything not named above runs as normal**, Steps 1 and 2 included — your ticket still gets read, assigned, and moved to In Progress.
> - **Do** Step 4.2's codebase-fit pass against `C-N`, pick the tier, then run from Step 5 to a PR whose review gate has passed and whose required checks are green.
> - **Stop there.** No Landing, no merge, no deploy, no cleanup, no guard disarm, and do not call `ExitWorktree`. The chain parent lands your chunk and will send you back into your worktree to rebase it.
> - **Return your exit report**, including how to exercise your chunk by hand.

A chunk that comes back with neither a green PR nor a blocker it names ended its turn early — send it back in with `SendMessage` naming what is missing, and never read a partial return as a finished chunk. One that returns a blocker it cannot pass has finished its turn correctly; price it below.

An agent that cannot load this skill or enter a worktree halts the chain — say so plainly. There is no fallback where you build the chunk yourself; that is the context the dispatch exists to avoid spending.

## Integrating a wave

Chunks build in parallel; they integrate one at a time. `Needs` says which chunk's *behavior* a chunk depends on — it cannot say which files they collide in, because a spec never names files. Serial integration is what catches that: a textual collision surfaces as a rebase conflict and a semantic one as a red suite, both while the agent that wrote the code is still alive and still holding its worktree.

**You never touch a working tree.** Each chunk's branch is checked out in that chunk's worktree, so you could not rebase it even if you wanted to, and you have no worktree of your own. Everything below is done by resuming the chunk's own agent with `SendMessage`; the only things you do yourself here are read a PR's checks, merge it, and move its ticket.

Once every chunk in the wave has returned, take them one at a time in wave order:

1. **Resume its agent** and tell it to fetch, rebase onto `origin/spec/<SPEC-TICKET>`, run the full suite, and push. You merge through the provider's API, so the branch only moves on the remote — a rebase onto a local ref replays onto a branch missing every sibling already merged. It still holds every file it read and every decision it made.
2. **Green** — wait for the PR's required checks, then merge it via the `git-provider` skill and transition the ticket to done via the `jira` skill. Red checks, or checks that never go green, are a failure to finish.
3. **Conflict or red** — send back what failed and resume again. **Three returns that are not green**, counting step 1's rebase as the first. Every return that is not green spends one, whatever it carries — a conflict, a red suite, a question you can answer, or all three. One exception, and it wins over everything else the return carries: a question only the user can answer halts the chain rather than spending a round, per [escalation](#escalation). A red suite alongside it is moot — the chain is stopping either way. A chunk that is not green after the third has not finished, and the chain halts on it; more rounds past that are rounds spent on a design problem, not a code problem.

Leave every chunk's worktree and branch standing until [hand-back](#hand-back). A later wave's rebase can expose a defect in an already-merged chunk, and the resume path only works while that chunk's worktree still exists — cleaning up at merge would destroy exactly the property this section is built on.

**A failure in an already-merged sibling's committed tests is a contract disagreement, not a bug to patch.** The rebasing chunk must not edit a test it did not write. Have it report which assumption of the sibling's it breaks and what it believes the correct behavior is, then decide it the way [escalation](#escalation) says: from the spec if the spec answers it, from the user if it does not. Two chunks whose testers independently created the same integration test path is the version of this you will actually hit.

The review gate ran on each chunk before its rebase, so no reviewer sees cross-chunk interaction. A green suite after rebase is the bar — the tests are the contract in this workflow, and the user's own pass on the integration branch is what backs it.

## Escalation

The chain parent answers what the spec answers. A chunk agent only ever held its own `C-N` section; you hold the whole document and every sibling's report, so most of what a chunk escalates is decidable one level up. Read the relevant section and resume that agent with `SendMessage` — never replace it. Answering costs a round like anything else: a chunk that spends all three asking is a chunk whose section did not say enough.

The test is whether you are applying a sentence the spec already contains or writing one it does not. Anything that would **change** the spec goes to the user, and the chain halts on it whatever the round count — never waiting on an answer. It halts the way [Halting](#halting) says, at the end of that wave: the question is the user's, but the siblings still finish. The spec is what they approved, and amending it silently amends their approval. A review gate returning `escalate` is usually this: the reviewer has concluded the design is wrong, not the code.

## Halting

A chunk that does not finish stops the chain at the end of its wave. Its siblings are isolated in their own worktrees, so let them finish and integrate; the next wave does not open.

The rule is wave-level even when a later chunk does not name the failed one in its `Needs`. The spec's tests are written per chunk and the user's final pass is over the whole branch, so a spec that is missing a piece is worth less than a stopped chain — and deciding which later work is still safe on a branch with a hole in it is exactly the judgment a chain should not make unattended.

A halt hands control back, but it is not the [hand-back](#hand-back) below: no PR into the base branch, since the spec is incomplete. Leave whatever the stopped chunk has — a PR and worktree if it was dispatched, nothing at all if it never was — and leave every other chunk's standing too, disarm the guard, and report in prose — which chunk stopped, what it stopped on, which waves never started, and what is left standing. Not the [exit report](../templates/exit-report.md): that template is for a run that finished, and this one did not. Nothing is deployed and nothing reached the base branch, so what the user picks up is an integration branch carrying whatever completed.

## Hand-back

The chain does not merge and does not deploy. When the last wave integrates:

1. Open the PR from `spec/<SPEC-TICKET>` into the base branch via the `git-provider` skill.
2. Run [cleanup](cleanup.md) for every merged chunk, taking down the worktrees and branches held open for the resume path. A spec-descended worktree was entered by path, so `ExitWorktree` will not remove it — cleanup's git fallback does.
3. Create a worktree on `spec/<SPEC-TICKET>` so the user can run the whole spec. Your local ref is behind — every chunk merged on the remote — so catch it up first, then check the branch out rather than cutting a new one:

       git fetch origin
       git branch -f spec/<SPEC-TICKET> origin/spec/<SPEC-TICKET>
       git worktree add <path> spec/<SPEC-TICKET>

   The worktree is theirs, not yours: do not enter it. Give them its absolute path and the command that starts the app.
4. Disarm the guard.
5. **Report.** One report for the chain, not one per chunk. Each chunk's exit report was written for a reader who was not there — collapse them into a single [exit report](../templates/exit-report.md) for the whole spec: what the user can now do, what to test on the integration branch, which chunk stopped and why, which never started, and every assumption, deferral, and unfixed finding the chunks accumulated along the way.
