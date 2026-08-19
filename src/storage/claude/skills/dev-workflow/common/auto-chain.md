# Auto chain

`auto` on a ticket whose spec is already written and approved. Every component the spec carves is built and merged onto one integration branch, in waves, and the user is not consulted again until the chain ends.

This Driver is the whole run. Only Step 1's first item ran before it — the ultra ticket was read, assigned, and moved to In Progress. The rest of SKILL.md's Steps 1-4 do not happen: the spec is the approval artifact and settled the intent, the solution, and the routing when the user approved it.

The chain never merges to the base branch and never deploys. It ends with the whole spec sitting on an integration branch the user can run, test, and merge themselves. That final gate is the point: components were carved to be built independently, not to ship independently.

`<SPEC-TICKET>` below is the ultra ticket the spec was written on; its description carries the spec's path. The spec merged with its own PR, so that path resolves in the main checkout — read it there, before any branch is cut. `<COMPONENT-TICKET>` is one component's own ticket.

Three roles, used throughout: **you are the parent**, one per spec. A **manager** is the agent you dispatch per component — it runs this skill for its own ticket, writing its own scaffold and fanning out a tester, a fleet of **workers** and a reviewer. You address managers; what they spawn is theirs. Inside a manager's own run the other files call it the parent — the same role, one level down.

## Driver

Your session drives and holds almost nothing: the spec path, the wave plan, each component's status and returned report. Keep it that way. Dispatching each component is what keeps your own context from compacting halfway through the spec.

Once step 3 below has the waves, seed the task tracker with one item per wave, plus `Integrate wave N` after each, plus `Hand back` — Prerequisite 1's seven-item list describes a single ticket's run and does not fit a chain.

1. **Arm the guard** for the whole chain — `~/.claude/hooks/auto-run-guard.sh start <SPEC-TICKET>`. Disarming is the last tool call of the chain, before the hand-back report and before any halt. The managers are subagents and are not covered by it; they fire `SubagentStop`, which this run must leave alone, and they are told not to arm one of their own.

2. **Run the main-checkout gate once, here.** It is Prerequisite 4 in [SKILL.md](../SKILL.md), and parallel managers running it concurrently would race on one index.

3. **Derive the waves.** The spec does not group components — read each `<section>`'s `data-needs` and topologically sort them. Wave 1 is every component with no edges; a component joins the first wave by which everything it needs is merged. An edge naming something the spec does not define, or a cycle among the edges, halts the chain here: a cycle has no valid order, so no wave opens at all — not even the components outside it. Both are spec defects, not something to reorder around. Nothing has been created yet: disarm the guard, then say in prose which edge is the defect and stop. There is no component to report on and no wave that started.

   **Cap a wave at three.** Each manager runs a scaffold, a tester, a worker fleet and a reviewer of its own, so a wave is already a fan-out of fan-outs, and every extra manager re-pays the same repo background in full. A wider wave queues rather than parallelizes. Where a wave exceeds the cap, split it and run the halves back to back. Nothing else regroups a wave: whether two components collide in the files is not something a spec can tell you, and serial integration below is what catches it.

4. **Confirm every component has a ticket.** Read the ultra ticket via the `jira` skill and match its linked issues to `C-N` ids; file the missing ones the way [ultra](ultra.md) filed the rest — linked to the ultra ticket, naming the `C-N` section rather than copying it, and searching for an existing ticket first. An **Open question** still sitting in a component's section is a spec defect: by its own definition no amount of code answers it, and the user is not in the room. That component is never dispatched: handing it to a manager only spends a build on a contract nobody settled. Caught here, before its wave opens, the question withholds that whole wave — run the waves before it, then halt by [Halting](#halting) below, with the question in the report. The spec's approval is the go-ahead for these — it is the one place auto files tickets.

5. **Cut the integration branch** and push it, without moving the main checkout off the base branch:

       git branch spec/<SPEC-TICKET> && git push -u origin spec/<SPEC-TICKET>

   Every component in this chain branches from `spec/<SPEC-TICKET>`, PRs into it, and rebases onto it. The project's own base branch is not touched again until the user merges at the end. This comes after the two checks above so that a spec which cannot run leaves nothing behind on the remote.

6. **Run each wave**: dispatch its components in parallel, wait for all of them, integrate them one at a time, then open the next wave. Dispatch is what must wait for the previous wave — managers create their own worktrees, and a wave dispatched early would branch from an integration branch missing the work it needs.

## Dispatching a wave

Spawn one `general-purpose` agent per component, all in one message so they run concurrently. Omit the `model` opt — no lever alias covers an agent that runs this entire skill, so let its default stand. Each agent gets:

> Run the `dev-workflow` skill for `<COMPONENT-TICKET>` in auto mode. You are the **manager** for component `C-N` of the approved spec at `<absolute path>`; that section is your contract.
>
> - **Your base branch is `spec/<SPEC-TICKET>`.** Follow Step 5's spec-descended path: create your worktree from that branch with `git worktree add` and enter it by path. Target your PR at it, and never touch the project's own base branch. Investigate it too — earlier components are merged there and are not in the main checkout.
> - **Skip** Prerequisite 4, the main-checkout gate — it has already run. Skip Step 5.3, arming a guard — the chain owns it. Skip Step 3, and all of Step 4 except 4.2 and the tier pick in 4.4; the spec settled the brief, the solution, and the Present, so there is nothing to post and nothing to wait for.
> - **Everything not named above runs as normal**, Steps 1 and 2 included — your ticket still gets read, assigned, and moved to In Progress.
> - **Do** Step 4.2's codebase-fit pass against `C-N`, pick the tier, then run from Step 5 to a PR whose review gate has passed and whose required checks are green.
> - **Stop there.** No Landing, no merge, no deploy, no cleanup, no guard disarm, and do not call `ExitWorktree`. The chain parent lands your component and will send you back into your worktree to rebase it.
> - **Return your exit report**, including how to exercise your component by hand.

A component that comes back with neither a green PR nor a blocker it names ended its turn early — send it back in with `SendMessage` naming what is missing, and never read a partial return as a finished component. One that returns a blocker it cannot pass has finished its turn correctly; price it below.

A manager that cannot load this skill or enter a worktree halts the chain — say so plainly. There is no fallback where you build the component yourself; that is the context the dispatch exists to avoid spending.

## Integrating a wave

Components build in parallel; they integrate one at a time. `Needs` says which component's *behavior* another depends on — it cannot say which files they collide in, because a spec never names files. Serial integration is what catches that: a textual collision surfaces as a rebase conflict and a semantic one as a red suite, both while the manager that wrote the code is still alive and still holding its worktree.

**You never touch a working tree.** Each component's branch is checked out in that component's worktree, so you could not rebase it even if you wanted to, and you have no worktree of your own. Everything below is done by resuming its manager with `SendMessage`; what you do yourself is read — a PR's checks, a committed file at the remote ref — then merge and move the ticket.

Once every component in the wave has returned, take them one at a time in wave order:

1. **Resume its manager** and tell it to fetch, rebase onto `origin/spec/<SPEC-TICKET>`, run the full suite, and push. You merge through the provider's API, so the branch only moves on the remote — a rebase onto a local ref replays onto a branch missing every sibling already merged. It still holds every file it read and every decision it made.
2. **Green** — wait for the PR's required checks, then merge it via the `git-provider` skill and transition the ticket to done via the `jira` skill. Red checks, or checks that never go green, are a failure to finish.
3. **Conflict or red** — send back what failed and resume again. **Three returns that are not green**, counting step 1's rebase as the first. Every return that is not green spends one, whatever it carries — a conflict, a red suite, a question you can answer, or all three. One exception, and it wins over everything else the return carries: a question only the user can answer halts the chain rather than spending a round, per [escalation](#escalation). A red suite alongside it is moot — the chain is stopping either way. A component that is not green after the third has not finished, and the chain halts on it; more rounds past that are rounds spent on a design problem, not a code problem.

Leave every component's worktree and branch standing until [hand-back](#hand-back). A later wave's rebase can expose a defect in an already-merged component, and the resume path only works while that component's worktree still exists — cleaning up at merge would destroy exactly the property this section is built on.

**A failure in an already-merged sibling's committed tests is a contract disagreement, not a bug to patch.** The rebasing component must not edit a test it did not write. Have it report which assumption of the sibling's it breaks and what it believes the correct behavior is — then read the test yourself before ruling, `git --no-pager show origin/spec/<SPEC-TICKET>:<path>`, since that report comes from the one party that wants it changed. Decide it the way [escalation](#escalation) says: from the spec where the spec answers it. Where it does not, resume the sibling's manager for its side before taking it to the user — it wrote the assertion and may hold a reason the spec implies without stating.

Whichever way it goes, **the manager that owns a test is the one that edits it.** If the ruling goes against the sibling's assertion, resume that manager to change it on its own branch, integrate that as its own step, and only then send the rebasing component back to rebase onto it. Two components whose testers independently created the same integration test path is the version of this you will actually hit.

The review gate ran on each component before its rebase, so no reviewer sees cross-component interaction. A green suite after rebase is the bar — the tests are the contract in this workflow, and the user's own pass on the integration branch is what backs it.

## Escalation

The chain parent answers what the spec answers. A manager only ever held its own `C-N` section; you hold the whole document and every sibling's report, so most of what a manager escalates is decidable one level up. Read the relevant section and resume that manager with `SendMessage` — never replace it. Answering costs a round like anything else: a manager that spends all three asking is one whose section did not say enough.

The test is whether you are applying a sentence the spec already contains or writing one it does not. Anything that would **change** the spec goes to the user, and the chain halts on it whatever the round count — never waiting on an answer. It halts the way [Halting](#halting) says, at the end of that wave: the question is the user's, but the siblings still finish. The spec is what they approved, and amending it silently amends their approval. A review gate returning `escalate` is usually this: the reviewer has concluded the design is wrong, not the code.

## Halting

A component that fails after it was dispatched stops the chain at the end of its wave. Its siblings are already building in their own worktrees, so let them finish and integrate; the next wave does not open. A component withheld before its wave ever opened is the other case — step 4 above — and there nothing in that wave is built at all, defect or not.

The rule is wave-level even when a later component does not name the failed one in its `Needs`. The spec's tests are written per component and the user's final pass is over the whole branch, so a spec that is missing a piece is worth less than a stopped chain — and deciding which later work is still safe on a branch with a hole in it is exactly the judgment a chain should not make unattended.

A halt hands control back, but it is not the [hand-back](#hand-back) below: no PR into the base branch, since the spec is incomplete. Leave whatever the stopped component has — a PR and worktree if it was dispatched, nothing at all if it never was — and leave every other component's standing too, disarm the guard, and report in prose — which component stopped or was withheld, what it stopped on, which waves never started, and what is left standing. Not the [exit report](../templates/exit-report.md): that template is for a run that finished, and this one did not. Nothing is deployed and nothing reached the base branch, so what the user picks up is an integration branch carrying whatever completed.

## Hand-back

The chain does not merge and does not deploy. When the last wave integrates:

1. Open the PR from `spec/<SPEC-TICKET>` into the base branch via the `git-provider` skill.
2. Run [cleanup](cleanup.md) for every merged component, taking down the worktrees and branches held open for the resume path. A spec-descended worktree was entered by path, so `ExitWorktree` will not remove it — cleanup's git fallback does.
3. Create a worktree on `spec/<SPEC-TICKET>` so the user can run the whole spec. Your local ref is behind — every component merged on the remote — so catch it up first, then check the branch out rather than cutting a new one:

       git fetch origin
       git branch -f spec/<SPEC-TICKET> origin/spec/<SPEC-TICKET>
       git worktree add <path> spec/<SPEC-TICKET>

   The worktree is theirs, not yours: do not enter it. Give them its absolute path and the command that starts the app.
4. Disarm the guard.
5. **Report.** One report for the chain, not one per component. Each component's exit report was written for a reader who was not there — collapse them into a single [exit report](../templates/exit-report.md) for the whole spec: what the user can now do, what to test on the integration branch, which component stopped and why, which never started, and every assumption, deferral, and unfixed finding the components accumulated along the way.
