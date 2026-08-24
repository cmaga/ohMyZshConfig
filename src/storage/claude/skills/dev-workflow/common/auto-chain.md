# The chain

A ticket whose spec is already written and approved. Every component the spec carves is built and merged onto one integration branch, in waves. There is no attended variant and `auto` changes nothing here — the spec is the approval, and the only thing that reaches the user is a question the spec does not answer.

This Driver is the whole run. Only Step 1's first item ran before it — the ultra ticket was read, assigned, and moved to In Progress. The rest of SKILL.md's Steps 1-4 do not happen: the spec is the approval artifact and settled the intent, the solution, and the routing when the user approved it.

The chain never merges to the base branch and never deploys. It ends with the whole spec sitting on an integration branch the user can run, test, and merge themselves. That final gate is the point: components were carved to be built independently, not to ship independently.

`<SPEC-TICKET>` below is the ultra ticket the spec was written on; its description carries the spec's path. The spec merged with its own PR, so that path resolves in the main checkout — read it there, before any branch is cut. `<COMPONENT-TICKET>` is one component's own ticket.

Three roles, used throughout: **you are the parent**, one per spec. A **manager** is the agent you dispatch per component — it runs this skill for its own ticket, writing its own scaffold and fanning out a tester, a fleet of **workers** and a reviewer. You address managers; what they spawn is theirs. Inside a manager's own run the other files call it the parent — the same role, one level down.

## Driver

Your session drives and holds almost nothing: the spec path, the wave plan, each component's status and returned report. Keep it that way. Dispatching each component is what keeps your own context from compacting halfway through the spec.

**The integration branch and the tracker are the record; your context is a cache.** Every one of those things is derivable from the repo and the tickets, and the chain re-derives them at step 3 rather than trusting what it remembers. That is what makes this Driver re-enterable: a chain that lost its session — a usage limit, a compaction, a closed terminal — is resumed by running it again on the same ticket, not restarted.

Once step 3 below has the waves, seed the task tracker with one item per wave, plus `Integrate wave N` after each, plus `Hand back` — Prerequisite 1's seven-item list describes a single ticket's run and does not fit a chain.

1. **Arm the guard** for the whole chain — `~/.claude/hooks/auto-run-guard.sh start <SPEC-TICKET>`. Disarming is the last tool call of the chain, before the hand-back report and before any halt. The managers are subagents and are not covered by it; they fire `SubagentStop`, which this run must leave alone, and they are told not to arm one of their own.

2. **Run the main-checkout gate once, here.** It is Prerequisite 4 in [SKILL.md](../SKILL.md), and parallel managers running it concurrently would race on one index.

3. **Derive the waves.** The spec does not group components into waves — read each `class="component"` section's `data-needs` and topologically sort them. Nothing without that class is a node: the context, the map, and any grouping heading are prose the sort does not see. Wave 1 is every component with no edges; a component joins the first wave by which everything it needs is merged. An edge naming something the spec does not define, or a cycle among the edges, halts the chain here: a cycle has no valid order, so no wave opens at all — not even the components outside it. Both are spec defects, not something to reorder around. Nothing has been created yet: disarm the guard, then say in prose which edge is the defect and stop. There is no component to report on and no wave that started.

   **A wave is as wide as the sort makes it.** Nothing narrows it in advance. Each manager runs a scaffold, a tester, a worker fleet and a reviewer of its own, so a wave is a fan-out of fan-outs and a wide one may reach the harness's concurrency ceiling — but the symptom of that is agents queuing, which is slower and not wrong, and splitting a wave before you have seen it costs the same wall-clock with certainty. If managers visibly queue rather than run, split that wave and run the halves back to back; that is an observation, not a plan.

   **A component marked `data-exclusive="true"` is a wave of one.** Pull it out of whatever wave the sort put it in and run it alone, first, in that wave's place; its siblings follow in the wave after. First rather than last because this marks work that lands underneath everything — siblings that build after it build against the shape it left, where siblings that build before it would each have to rebase across the whole of it. Two of them in one derived wave become two waves, in spec order. This is the spec author saying what the edges cannot: not that the component consumes anything, but that nothing can be under construction while it lands.

   Nothing else regroups a wave. Whether two components collide in the files is not something a spec can tell you in general, and serial integration below is what catches the rest.

   **Then read each component's status off the repo, never off memory.** A `spec/<SPEC-TICKET>` branch that already exists means this chain ran before and is being resumed; step 5 will not cut a new one. For each component: its work is **merged** if its branch is an ancestor of `spec/<SPEC-TICKET>` (`git merge-base --is-ancestor`), **in flight** if it has a branch or a worktree that is not, and **unstarted** if it has neither. Where the branch and the ticket disagree — a ticket still In Progress whose work is merged — the branch wins and you move the ticket to match. A ticket is a label somebody moved; the branch is the fact, and a chain that trusted the label would rebuild a component that has already landed.
4. **Confirm every component has a ticket.** Read the ultra ticket via the `jira` skill and match its linked issues to `C-N` ids; file the missing ones the way [ultra](ultra.md) filed the rest — linked to the ultra ticket, naming the `C-N` section rather than copying it, and searching for an existing ticket first. An **Open question** still sitting in a component's section is a spec defect: by its own definition no amount of code answers it, and the user is not in the room. That component is never dispatched: handing it to a manager only spends a build on a contract nobody settled. Caught here, before its wave opens, the question withholds that whole wave — run the waves before it, then ask it the way [escalation](#escalation) says and open that wave once it is answered. The spec's approval is the go-ahead for these — it is the one place a chain files tickets.

5. **Take the integration branch and a worktree on it.** The branch is local and stays local — `spec/<SPEC-TICKET>` is never pushed until [hand-back](#hand-back), so a spec of twenty components costs one push, one pull request and one continuous-integration run rather than twenty of each. Cut it only if step 3 found none:

       git branch spec/<SPEC-TICKET>            # only when it does not already exist
       git worktree add <path> spec/<SPEC-TICKET>

   The main checkout does not move. This worktree is yours and is the one working tree you own — the assembled spec, standing from here to hand-back, which is also what the user tests at the end rather than something conjured for them then. Every component branches from `spec/<SPEC-TICKET>`, merges into it here, and rebases onto it. The project's own base branch is untouched until the user merges.

   **Do not enter it — drive it by path and `git -C`.** Entering pins the session to one tree, and this Driver needs reach across the whole repository: step 3 reads every component's branch, and hand-back takes down worktrees that are not this one.

   Cutting comes after the two checks above so that a spec which cannot run leaves nothing behind.

6. **Run each wave**: dispatch its components in parallel, wait for all of them, integrate them one at a time, then open the next wave. Skip a component step 3 found already merged — its work is in the branch and re-running it would rebuild what is already there. Dispatch is what must wait for the previous wave — managers create their own worktrees, and a wave dispatched early would branch from an integration branch missing the work it needs.

## Dispatching a wave

Spawn one `general-purpose` agent per component, all in one message so they run concurrently. Omit the `model` opt — no lever alias covers an agent that runs this entire skill, so let its default stand. Each agent gets:

> Run the `dev-workflow` skill for `<COMPONENT-TICKET>` in auto mode. You are the **manager** for component `C-N` of the approved spec at `<absolute path>`; that section is your contract.
>
> - **Your base branch is the local `spec/<SPEC-TICKET>`.** Follow Step 5's spec-descended path: create your worktree from that branch with `git worktree add` and work it by path. It is a local branch and there is nothing to fetch — earlier components are merged into it here, not on a remote, so read it locally and never at `origin/`. Never touch the project's own base branch.
> - **If a worktree for your ticket already exists, enter it by path and carry on from what is in it** rather than creating one. You are resuming work a previous run left standing, and its commits are yours to build on.
> - **You open no pull request and push nothing.** The whole spec goes up once, at the end, as one pull request the chain parent opens.
> - **If `EnterWorktree` refuses you, that is expected — carry on by path.** It only switches from inside an existing worktree, and you start at the repo root. Work through absolute paths and `git -C <worktree>`; both are available to you precisely because you never entered. Do not halt over it and do not retry it.
> - **Explore with Read/Grep/Glob at absolute paths inside your worktree**, not through a code-index tool. An index is built against the main checkout, and your branch diverges from it by design.
> - **Skip** Prerequisite 4, the main-checkout gate — it has already run. Skip Step 5.3, arming a guard — the chain owns it. Skip Step 3, and all of Step 4 except 4.2 and the tier pick in 4.4; the spec settled the brief, the solution, and the Present, so there is nothing to post and nothing to wait for.
> - **Everything not named above runs as normal**, Steps 1 and 2 included — your ticket still gets read, assigned, and moved to In Progress.
> - **Do** Step 4.2's codebase-fit pass against `C-N`, pick the tier, then run from Step 5 until your work is committed on your own branch, the review gate has passed, and the full suite is green in your worktree. That is a finished component here; there is no pull request and no continuous-integration run to wait on, so the suite is the whole bar.
> - **Stop there.** No Landing, no merge, no deploy, no cleanup, no guard disarm, and do not call `ExitWorktree`. The chain parent merges your component and will send you back into your worktree to rebase it.
> - **Never park waiting for an answer.** You cannot message me — a subagent has no address for its parent, so a question you stop on is a question nobody receives. If you need a decision you cannot make, or every route past a refused call is exhausted, end your turn and return the question as your report: what you did, what needs deciding, and what a replacement would need to carry on. A refused tool call is not that moment — try the other route first.
> - **The agents you dispatch must not dispatch further.** A result reaches its spawner one level down and no further; deeper than that it surfaces to the main session and the agent that asked never sees it. Your testers, workers and reviewer are your level — tell each of them to gather its own evidence and spawn nothing. That includes the review gate: if a review needs several perspectives, run those agents yourself so you hold their findings.
> - **Return your exit report**, naming the branch you committed on and how to exercise your component by hand.

A component that comes back with neither a green suite on a committed branch nor a blocker it names ended its turn early — send it back in with `SendMessage` naming what is missing, and never read a partial return as a finished component. If that send fails, replace it per [escalation](#escalation) rather than halting. One that returns a blocker it cannot pass has finished its turn correctly; price it below.

**A manager reports by returning, never by messaging you.** A subagent cannot address its parent — the reply path does not resolve — so a manager that stops mid-task to wait is stranded, and a question it cannot deliver is a question nobody will answer. Every dispatch prompt must say: end the turn and return the question as your report; never park waiting for an answer.

**`EnterWorktree` refusing a manager is normal and is not a halt.** The tool only switches from inside an existing worktree, so a manager dispatched at the repo root cannot call it. That costs nothing: `git worktree add` still creates the worktree, and the manager works it through absolute paths and `git -C`. Those are refused only for a session that *did* enter one, which this manager did not — so the fallback is fully available. Say in the report that the worktree was driven by path rather than entered.

A manager that cannot load this skill, or cannot create its worktree at all, halts the chain — say so plainly. There is no fallback where you build the component yourself; that is the context the dispatch exists to avoid spending.

## Integrating a wave

Components build in parallel; they integrate one at a time. `Needs` says which component's *behavior* another depends on — it cannot say which files they collide in, because a spec never names files. Serial integration is what catches that: a textual collision surfaces as a rebase conflict and a semantic one as a red suite, both while the manager that wrote the code is still alive and still holding its worktree.

**You touch one working tree and only one — your own, on `spec/<SPEC-TICKET>`.** Never a component's: each is checked out in that component's worktree, held by the manager that wrote it, and a rebase belongs to whoever owns the tree. Conflicts are resolved by resuming that manager with `SendMessage`; what you do in your own worktree is fast-forward and run the suite.

Once every component in the wave has returned, take them one at a time in wave order:

1. **Resume its manager** and tell it to rebase onto `spec/<SPEC-TICKET>` and run the full suite. The branch is local and shared between your worktree and theirs, so there is nothing to fetch and nothing to push — the ref they rebase onto already carries every sibling merged before them. The manager still holds every file it read and every decision it made.
2. **Green** — merge it in your own worktree, which after that rebase is a fast-forward, then run the full suite there yourself before opening the next component. Then transition the ticket to done via the `jira` skill. The manager's green suite says the component works; yours says the branch does, and they are not the same claim once a third component is in it.
3. **Conflict or red** — send back what failed and resume again. **Three returns that are not green**, counting step 1's rebase as the first. Every return that is not green spends one, whatever it carries — a conflict, a red suite, a question you can answer, or all three. One exception, and it wins over everything else the return carries: a question only the user can answer costs no round and pauses the chain instead, per [escalation](#escalation). A red suite alongside it waits with it — the answer is what decides whether that suite was even failing the right thing. A component that is not green after the third has not finished, and the chain halts on it; more rounds past that are rounds spent on a design problem, not a code problem.

Leave every component's worktree and branch standing until [hand-back](#hand-back). A later wave's rebase can expose a defect in an already-merged component, and the resume path only works while that component's worktree still exists — cleaning up at merge would destroy exactly the property this section is built on.

**A failure in an already-merged sibling's committed tests is a contract disagreement, not a bug to patch.** The rebasing component must not edit a test it did not write. Have it report which assumption of the sibling's it breaks and what it believes the correct behavior is — then read the test yourself before ruling — it is in your own worktree — since that report comes from the one party that wants it changed. Decide it the way [escalation](#escalation) says: from the spec where the spec answers it. Where it does not, resume the sibling's manager for its side before taking it to the user — it wrote the assertion and may hold a reason the spec implies without stating.

Whichever way it goes, **the manager that owns a test is the one that edits it.** If the ruling goes against the sibling's assertion, resume that manager to change it on its own branch, integrate that as its own step, and only then send the rebasing component back to rebase onto it. Two components whose testers independently created the same integration test path is the version of this you will actually hit.

The review gate ran on each component before its rebase, so no reviewer sees cross-component interaction. A green suite after rebase is the bar — the tests are the contract in this workflow, and the user's own pass on the integration branch is what backs it.

**Nothing here has been through continuous integration.** Buying one run instead of one per component means the first is on the whole spec, at hand-back, and anything the local suite cannot reproduce — a service it does not stand up, an environment it does not have — surfaces there rather than against the component that caused it. Running the suite in your own worktree after every merge is what narrows that: a failure that appears the moment a component lands names it, while the same failure found at the end names nothing.

## Escalation

The chain parent answers what the spec answers. A manager only ever held its own `C-N` section; you hold the whole document and every sibling's report, so most of what a manager escalates is decidable one level up. Read the relevant section and resume that manager with `SendMessage` in preference to replacing it. Answering costs a round like anything else: a manager that spends all three asking is one whose section did not say enough.

**If the resume itself fails, replace the manager — that is not a halt.** A `SendMessage` that is refused, errors, or reports the agent unreachable is a broken channel, and a broken channel says nothing about whether the component can be built. Dispatch a fresh manager for the same ticket with the original dispatch prompt, your answer, and the returned report of the one it replaces; its worktree and commits are still standing, so the replacement inherits the work, not just the question. Two failed resumes is the cap — replace on the third rather than spending the wave on the channel. Note the restart in the chain report. Halt only when the component itself cannot finish.

The test is whether you are applying a sentence the spec already contains or writing one it does not. Anything that would **change** the spec goes to the user, whatever the round count — the spec is what they approved, and amending it silently amends their approval. A review gate returning `escalate` is usually this: the reviewer has concluded the design is wrong, not the code.

**Asking pauses the chain; it does not end it.** Let the wave's siblings finish and integrate — they are already building and their work is good whatever the answer — then disarm the guard, ask, and stop the turn. Ask only what the spec failed to answer: the question, the section that did not settle it, and what it blocks. Never a scaffold to review or a progress report; a wave in which nothing was underspecified reaches the user not at all.

When they answer, re-arm the guard and carry on from where the wave stopped. This is the same session, so the wave plan, every returned report and every manager still holding its worktree are all still here — which is the whole reason to pause rather than halt. A manager whose question was answered is resumed with `SendMessage` like any other resume, and the next wave opens behind it.

Halting is what happens when there is nothing to carry on to — [Halting](#halting) below.

## Halting

Halting is for a component that cannot finish, never for a question — a question [pauses](#escalation) and the chain carries on once it is answered.

A component that fails after it was dispatched stops the chain at the end of its wave. Its siblings are already building in their own worktrees, so let them finish and integrate; the next wave does not open. A component withheld before its wave ever opened is the other case — step 4 above — and there nothing in that wave is built at all, defect or not.

The rule is wave-level even when a later component does not name the failed one in its `Needs`. The spec's tests are written per component and the user's final pass is over the whole branch, so a spec that is missing a piece is worth less than a stopped chain — and deciding which later work is still safe on a branch with a hole in it is exactly the judgment a chain should not make unattended.

A halt hands control back, but it is not the [hand-back](#hand-back) below: no PR into the base branch, since the spec is incomplete. Leave whatever the stopped component has — a PR and worktree if it was dispatched, nothing at all if it never was — and leave every other component's standing too, disarm the guard, and report in prose — which component stopped or was withheld, what it stopped on, which waves never started, and what is left standing. Not the [exit report](../templates/exit-report.md): that template is for a run that finished, and this one did not. Nothing is deployed and nothing reached the base branch, so what the user picks up is your own worktree on the integration branch, carrying whatever completed — give them its absolute path.

## Hand-back

The chain does not merge and does not deploy. When the last wave integrates:

1. **Push the branch and open the one PR** — `git push -u origin spec/<SPEC-TICKET>`, then the PR into the base branch via the `git-provider` skill. This is the chain's only push and the first time continuous integration sees any of it. Red checks here are the chain's to report, not to fix: say which are red in the report and leave the branch standing.
2. Run [cleanup](cleanup.md) for every merged component, taking down the worktrees and branches held open for the resume path. A spec-descended worktree was entered by path, so `ExitWorktree` will not remove it — cleanup's git fallback does. Your own integration worktree is not one of them — it stays, and it is what the user runs.
3. **Hand over your worktree.** It has been the assembled spec since step 5 and needs nothing done to it; stop working in it and give the user its absolute path and the command that starts the app.
4. Disarm the guard.
5. **Report.** One report for the chain, not one per component. Each component's exit report was written for a reader who was not there — collapse them into a single [exit report](../templates/exit-report.md) for the whole spec: what the user can now do, what to test on the integration branch, which component stopped and why, which never started, every check that came back red on that first continuous-integration run, and every assumption, deferral, and unfixed finding the components accumulated along the way.
