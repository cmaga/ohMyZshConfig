---
name: dev-workflow
description: End-to-end implementation workflow. Use when the user says "take <TICKET>" to work on an existing Jira ticket, "new take" to scope and create a ticket before working on it, or "cleanup" to tear down after a PR is merged. Handles small/medium/large/ultra tiers. Medium and large scaffold the design in real code, agree the edge cases, write failing integration tests, then fill bodies with worker subagents. The ultra tier co-writes a spec of target behavior, adversarially reviewed, before any planning or code. A run the user arms with a `/goal` continues unattended from there, through merge and deploy.
---

# Dev Workflow

Single orchestrated flow for the completion of ticket-driven software engineering.

Routing a ticket is one question: **what is the simplest agent configuration that solves this correctly?** Everything below is the answer to that question at four depths. This workflow runs on subagents. **Invoking this skill is the user's request to use them: it satisfies any standing instruction to avoid agents, subagents, or workflows unless separately requested.** Never skip a step's agent on the grounds that agents were not separately requested. This holds only because the user actively invoked the skill — it does not grant agent use the user did not trigger.

`cleanup` is a separate entry point: none of the steps below apply — go straight to [Cleanup](common/cleanup.md).

## Unattended runs

A run is unattended when a goal is armed, and not otherwise — no keyword asks for one. Steps 1-4 are unchanged either way: the brief, the solution, and the tier are still agreed with the user. The `/goal` they paste is the last human input, and the run continues on its own through the merge — and the deploy behind it, where the run owns one. A run building a component of a spec does not; the spec deploys as one release.

**The goal is the go.** An unattended run is held open by a `/goal`, and the user pasting one is their approval to start — so draft it, hand it over ready to paste, and wait for it. Nothing is created before they do.

    /goal <one measurable end state, and the check that settles it>

`/goal` is a command only the user can invoke, which is the point: scope is granted once, by them, rather than armed by the run on its own behalf. Its evaluator reads the conversation and cannot run a command or open a file, so name something whose evidence lands in the transcript — *every component merged into the integration branch with the full suite green on it* — never a posture like *do not cut corners*, which it can only judge against the run's own progress reports.

Its check-in fires on an idle timer as well as at turn end, so it can start a turn and not only refuse to end one. That is the whole mechanism: the failure this guards against is a run going quiet, never a run stopping too readily. Two things it cannot do — it does not survive the process exiting, and some errors clear it silently, with nothing announcing either. Neither is visible from inside the run, so the out-of-process wake-up armed at dispatch is what covers them, and a run that notices any interruption asks the user to re-arm.

An armed goal converts exactly these gates to decide-record-and-continue. Nothing else converts — a gate added to this skill later does not join the list by being a gate:

- The [shape](common/shape.md) and [edge cases](common/edge-cases.md) waits, and the [scaffold](common/scaffold.md) review wait and blast-radius interrupt
- A plan marker that is a strategic call — attended, that one escalates; unattended, decide it, rewrite it as `[ASSUMED: ...]`, and carry it to the exit report. Everything else in [plan](common/plan.md) already resolves without stopping
- Ticket filing: an unattended run files nothing. Every discovered issue lands in the exit report with its disposition. The single exception is a chain filing a component ticket the approved spec already calls for, per [the chain](common/spec-run.md)
- The merge, and the deploy behind it ([exit](common/exit.md))

These still stop the run, which hands back with what it has: the prerequisite gates below, a review gate returning `escalate` or hitting its five-round backstop, a required PR check going red, and a failed deploy. Inside a chain none of them ends the turn: the component stops, returns, and the parent decides what it costs — another round, a question put to the user, or a halt at the end of that wave. See [the chain](common/spec-run.md#escalation).

**Routing, decided the moment the ticket is read.** Run Prerequisites 2 and 3, then Step 1's first item — read the ticket, assign it, move it to In Progress. Prerequisite 1's status list and Prerequisite 4's gate both wait on this call: a chain tracks waves instead of steps, and runs the gate once in its own Driver. If it turns out to be an ultra ticket whose spec is already written and approved — its own PR merged — that is a chain: skip the rest of Steps 1-4 — the spec settled the intent and the solution when it was approved — and go to [the chain](common/spec-run.md), whose Driver is the whole run. A chain runs the same way whether or not the take said `auto`: the spec is the approval, and the one thing that reaches the user is a question the spec does not answer. You know an ultra ticket by its description naming the spec's path — [ultra](common/ultra.md)'s wrap-up records it there for exactly this. The issue type is not the test and never overrides it: an epic whose description carries that path is the chain's own ticket, not a container to look inside for something workable, and the components hanging off it are the chain's to dispatch. Everything else runs the flow below, a single component's own ticket included — that one on Step 2.2's spec-descended path.

## Prerequisites

Run in the order the routing paragraph above sets: 2 and 3 first, then Step 1's first item, then 1 and 4 — a chain handles both of those in its own Driver instead, per that paragraph.

1. **Task tracking.** Seeded once the routing call above is made. Load the tools first via `ToolSearch` with `select:TaskCreate,TaskUpdate` — both are deferred, so calling them cold fails. If they do not resolve, that is a known Anthropic-side bug (the `tengu_vellum_ash` model gate strips the task tools on current models) — it is expected, already diagnosed, and not worth investigating or working around. Say so in one line, skip this item, mark step transitions in prose instead, and carry on with the workflow. Otherwise call `TaskCreate` once per item for each of these exact items to seed the status list, then keep it current with `TaskUpdate` — mark the prior item `completed` and the next `in_progress` as you move through the flow. This list is the user's at-a-glance status surface, not narration; maintain it even when responses are otherwise terse.
   1. Understand the goal
   2. Verify context and ticket claims
   3. User brief
   4. Solution research and routing
   5. Workspace setup
   6. Implementation
   7. Exit
2. **Lever aliases.** Read `~/.claude/skills/optimize-usage/lever-state.json` and bind the `kind: "skill"` levers this workflow uses — `RESEARCH_FANOUT_MODEL`, `CODE_FANOUT_MODEL`, `MECHANICAL_WORKER_MODEL`, and `JUDGMENT_WORKER_MODEL` — to the all-caps form of their keys. A value of `inherit`, a key absent from the file, or a missing file all mean no pin: omit the `model` opt wherever that alias is used and let the agent's own default stand. Never invent a value for an absent key. If the values fall out of context later (long session, compaction), re-read the file rather than trusting memory.
3. **Base branch.** Read `baseBranch` from `<project-root>/.claude/skills/jira/config.json`; if the file or field is absent, it is `main`. Every later mention of "the base branch" means this value, until Step 5.3 rebinds it for a spec-descended run.
4. **Main-checkout gate.** In the main checkout, run `git status --porcelain`. If it prints anything, stop, show the user the dirty files, and wait for their decision — never stash, commit, or discard main-checkout changes to unblock yourself. When it prints nothing, check out the base branch if not already current, then `git pull --ff-only`. Skip the pull if the branch has no upstream. Leave the main checkout on the base branch — nothing later in the flow moves it, and a session that finds it elsewhere is looking at a bug.
   - A chain cannot run this before Step 1, because reading the ticket is what identifies it as a chain. Its Driver runs the gate once for the whole chain instead, and the managers skip it.

**All numbered steps must be done sequentially in order. Bullets can be done in parallel**

Every step below is labelled **internal** or **user-facing**, and the label is binding. An internal step produces no post and never waits — its output is working context for the steps after it, and pausing there hands back mid-thought on something the user was never asked to answer. Only a user-facing step is entitled to end a turn.

## Step 1: Understanding The Goal — internal

1. If a ticket was provided read it using the jira skill, else use the user provided context to begin to try to understand the problem. If the ticket is blocked or parked, STOP immediately and notify the user. **Run the ticket you were handed.** Where it cannot be run, stop and say why — never substitute a child, a sibling, or anything else that looks more workable, and never start one. Which ticket to work is the user's call and they already made it. Otherwise, assign it to me and transition it to "In Progress" right away via the jira skill — move it as soon as work starts, not later. (A `new take` has no ticket yet; it gets assigned and transitioned when created in Step 5.) If this is a ticket for a spec — its own or one component's — read the entire spec, so the part you hold is read against the whole.
2. Restate intent with zero implementation nouns from the ticket. Force the mechanism out so it can't sneak in as a requirement. Every implementation noun the ticket carries is a hypothesis that must be beaten by code analysis/research before it is adopted.

The restatement is working notes, not a post — Step 3 is the brief, and writing one here means writing it twice, the first time before you have verified anything. One line surfaces from this step: the ticket read, assigned, and moved to In Progress.

## Step 2: Verify context/ticket claims — internal

1. Investigate the following yourself — this is the case file the rest of the workflow consumes, and the threads feed each other, so keep the primary evidence in your own context and chase leads across threads as they appear. (A genuinely isolated read may still be delegated.)
   1. **Verify the problem exists in code** Do your own investigation.
   2. **Read relevant documentation** Be careful, documentation could be out of date.
   3. **Historical precedence** Are there related issues? Does the commit history help us understand where this bug came from? Is it recurring? Is this problem a symptom of something larger?
   4. **Is this needed?** What are the business-level implications? Is there a simpler solution? Dive deep. If you have reason to believe this should not be done, stop here and report back to the user with a simple high level explanation. Before reporting, undo what Step 1 did: move the ticket back to its previous status and unassign it. Leaving it In Progress tells the board someone is working on it. Do not transition it to anything opinionated — Blocked or Won't Do is the user's call, made with the reason in hand.
2. **Descends from a spec?** If the ticket names a component in one, the spec's `<section id="C-N"` — the tag carries more attributes after the id — is the contract for this run — read it, plus the components its Needs line names, before scoping. The spec ticket's key comes from the component ticket's link to it; the spec's path is in that ticket. Note the run as spec-descended and carry that to Step 5, which resolves the branch. Investigate the integration branch rather than the main checkout — earlier components are merged there. It is a **local** branch and is never pushed until the spec is whole, so read it at the local ref and never at `origin/`: `git --no-pager log --stat spec/<SPEC-TICKET>` for what moved, `git --no-pager show spec/<SPEC-TICKET>:<path>` for a file. No worktree of yours exists this early and the main checkout does not move.
   - **Its brief and its solution are already agreed.** The spec is the approval artifact, so Step 2.1's "is this needed" question is settled — its other three investigations still run, since the spec never looked at the code. Step 3 and Step 4's research do not re-open the brief either. The tier is the one thing still open — the spec settled what to build, never how big the run is. Do Step 4.2's codebase-fit pass against `C-N`, pick the tier — never ultra, which exists to agree target behavior this section already settled — and go on to Step 5.
   - **Post-deploy** items were ticketed when the spec was approved. Its key is among the ultra ticket's linked issues — cite it and move on; if the spec left one unfiled, it rides to the exit report as a proposal under the discovered-issue rule below — never file one to clear it.
   - An **Open question** surviving into a component ticket is a spec defect: it was supposed to be closed before the ticket was filed, and by its own definition no amount of code reading answers it. Raise it before Step 4.2. Attended, that is the only thing Step 3 runs for on a component ticket — ask that one question and nothing else, since the brief itself is not up for discussion, and their answer is the go. In a chain the parent screens for these before dispatch, so one that reaches you slipped through: never ask — return it, and the parent halts with the question in its report.

## Step 3: User brief — user-facing

Once you understand the goal explain it to the user as simply as possible, no code, no jargon. There may be some back and forth discussing for understanding and steering. Do not proceed to the next step until the user says go. This is **crucial**: your framing of the intent and problem space must be approved by the user before proceeding. If a viable solution is discussed take it as an option to consider, not gospel.

**One short paragraph, plus the one thing you need them to weigh in on.** That is the whole brief. Everything you learned in Step 2 is what makes the paragraph correct, not what goes in it — depth is on request, and they will ask. A brief long enough to skim is a brief that gets rubber-stamped, which is the one outcome this gate exists to prevent.

## Step 4: High Level Solution Research — internal until Present (item 5)

The goal at this point is to use your understanding of the problem and the business to come up with the best solution possible. Not a lazy hack. Something flawless that you can be proud of. To do this you need to gather multiple solutions and pick one.

Fan out only over sets you enumerate yourself — never per-item over a set a subagent produced. Bound the subagent's output first, then batch what's left.

1. Use `ultracode` (fan-out agents on `RESEARCH_FANOUT_MODEL`) to do deep online research on industry standards, best practices, and clean solutions to the type of problem. Weigh any solution direction the user shared.
2. **Codebase fit** - Not all solutions are a good fit for the codebase. Determine which solution is the best fit for the current codebase or if we need to change the codebase instead, mapping the leading one onto this repo: where each new piece lives, and which existing symbols it reuses rather than re-implements. Fan out on `CODE_FANOUT_MODEL` when that surface is too large for one agent, and verify every placement and reuse claim against real code at `file:line` before trusting it — a wrong reuse claim is the failure this step exists to catch. Never assume existing project conventions are perfect, do not adhere to a bad pattern even if it is project convention.
3. **Synthesize** - Given all of the context you've gathered converge on a single recommended solution. Make sure to challenge any assumptions you've made exhaustively.
   - Unless the research says the target behavior is not settled enough to converge. Then do not pick a solution: recommend `ultra`, present what you found and what is still unknown, and carry the research into the spec. Agreeing a solution now would close the conversation ultra exists to open.
4. **Implementation Routing** Determine a recommended implementation tier
   | Tier | When | Where the user is |
   | -------- | ----------------------------------------------------------------------------------------- | ------------------------ |
   | `small` | The whole change states in a sentence and one worker can do it against an obvious check | Intent only |
   | `medium` | Real implementation work, but no structure the user needs to see before the PR | Intent, approach, the PR |
   | `large` | New structure, or a boundary moves that the user needs to see. Not a size call: a 400-line rewrite behind an unchanged signature is not large; a 40-line new interface two modules consume is | In the scaffold |
   | `ultra` | Target behavior is itself unsettled and must be agreed as a spec before it can be planned | Throughout |
   Unattended, nobody is watching, so read the last column as what a user *would* need to see: `large` is where new structure or a moved boundary appears, whether or not anyone reviews the scaffold.
5. **Present** — user-facing. By this point a lot of time will have passed and the user has been watching agents run, so the first thing they need is their bearings back. Three parts, in this order, and nothing else:
   1. **Where we are.** `Research complete for <the problem, restated in one line>.` They should not have to scroll up to remember what this run is about.
   2. **The approach.** What we are going to do, in plain language. No jargon, no file paths, no symbol names. Short.
   3. **The tier**, with one clause on why.
   4. **The `/goal` line to paste**, where the run is meant to be unattended — see [Unattended runs](#unattended-runs). Pasting it is the go; there is no separate approval, and a user who pastes nothing has answered that they are staying in the loop.

   Then stop and let them react. **Do not walk the solution point by point unless they ask** — a run that opens on "Point 1 of 5" drops them into a conversation they have lost the thread of, and the summary they needed never gets written. Point-by-point is what "more details" buys: only then break the approach into pieces, one per message, advancing on "next", and repeat the one-line problem restatement at the top of each so no piece lands contextless. Consensus reached, the user says "go" and implementation begins.

   **Note** it is crucial that the user fully understand the problem and solution and is not just rubber stamping. Length is not understanding — a wall of text is skimmed, and a skimmed proposal is rubber-stamped. You have access to the following tools to help the user with understanding as well as with your planning.
   - UI artifact prototypes for ambiguous/large UI changes (mocked data)
   - Architectural Artifact visual diff diagrams for complex systems

## Step 5: Workspace Setup — internal

1. **Create/update the ticket**: If `new take`, create a new ticket. If we chose a solution very different from the original ticket, update the original. Use the `jira` skill.
2. **Transition the ticket** to "In Progress" via the `jira` skill (first transition for a `new take`; an existing ticket was already moved in Step 1, so no-op if already there).
3. **Spec-descended runs only — resolve the base branch.** A component of a spec builds against that spec's integration branch, `spec/<SPEC-TICKET>`; cut it from the project base if it does not exist yet. **That branch is local and is not pushed** — it goes up once, as one pull request, when the spec is whole, so a spec of twenty components costs one continuous-integration run rather than twenty. From here on, "the base branch" means that branch for any rebase and for whatever this run merges into. Nothing is fetched: siblings merged into it here, locally, so the local ref is the current one. The main checkout stays on the project base, so Prerequisite 4 is unaffected.
4. **Enter the worktree.**
   - **Ordinary runs:** call `EnterWorktree` with name `<TICKET>-<tier>` (e.g., `STAX-123-medium`).
   - **Spec-descended runs:** `EnterWorktree` has no base-ref parameter — given a `name` it branches from the project's default branch, which is the one branch a component must not build on. Create the worktree yourself and enter it by path instead:

         git worktree add -b <TICKET>-<tier> "$(git rev-parse --show-toplevel)/.claude/worktrees/<TICKET>-<tier>" spec/<SPEC-TICKET>

     then call `EnterWorktree` with that `path`. It must live under `.claude/worktrees/` or the entry is refused. A refusal saying the tool only switches from inside an existing worktree is expected whenever you were dispatched at the repo root, as a chain's manager is: carry on by absolute path and `git -C`, which are available precisely because you never entered. It is not a halt, and it is not friction — this sentence is the skill anticipating it. `ExitWorktree` will not remove a worktree entered this way — only `keep` works, and [cleanup](common/cleanup.md) takes it down with git.
   - Verify with `git rev-parse --show-toplevel` that you're inside the worktree. Then proceed with the tier sequence for the implementation.
   - From here until `ExitWorktree`, the session is pinned to the worktree and git reaches nothing else: `cd` out of it, `git -C`, `--git-dir`, and `GIT_DIR`/`GIT_WORK_TREE` are refused, and so is any Bash command whose shape hides where it lands — `cd` chained with `&&`, command substitution, redirects. When one is refused, write the commands to a script under the scratchpad and run it by absolute path.

## Step 6: Per Tier Implementation — internal except the waits listed below

Run the sequence for the confirmed tier. Each step links to its procedure file. If task tracking is active, mark the Implementation item `in_progress` and add the tier's steps as their own tasks via `TaskCreate` tool.

### What stops, attended

The complete list, closed the same way the unattended one above is. A step not named here does not wait, whatever its procedure file says about posting or presenting — and a step added to this skill later does not join the list by looking like a gate:

- `large` — four waits, all of them before any code is written: [shape](common/shape.md), the [scaffold](common/scaffold.md) review, the [edge case](common/edge-cases.md) component list, then one wait per component.
- `medium` — none.
- `small` — none.

**Once the last component is discussed, the run does not stop again until the PR is out.** Tests, plan, QA, dispatch, review and exit are internal. This is the point of the tier: the user spent their attention on the design, and spending it again on mechanics is what makes them stop reading.

Only escalation breaks that, and escalation means one of three things: the review gate returns `escalate` or hits its five-round backstop, a worker escalation you cannot decide from the code, or a hard blocker. **A question whose answer is in the repo is not an escalation** — the user is needed for strategic and directional calls, not for anything you can check. Read the code and decide it.

### Small

1. Dispatch any number of `worker-agent` with changes to be made to implement your approach. Pick each one's model id with the [archetypes](references/archetypes.md).
2. [Exit](common/exit.md).

### Medium

The full pipeline, unattended. The user approved the approach and sees the PR. The only thing that stops for them is an unresolved marker in the plan ([plan](common/plan.md)).

1. [Scope](common/scope.md)
2. [Shape](common/shape.md) — post it with the next step's first tool call, in one message
3. [Scaffold](common/scaffold.md) — same; commit it as soon as it is written
4. [Edge cases](common/edge-cases.md) — produce the full list and carry it straight into the tester
5. [Tests first](common/tests-first.md)
6. [Plan](common/plan.md) — every task card carries its own model, by [archetype](references/archetypes.md)
7. [Dispatch workers](common/worker-dispatch.md)
8. [Parent review](common/parent-review.md)
9. [Exit](common/exit.md)

### Large

Medium, plus the user in the scaffolding code and two review gates on it.

1. [Scope](common/scope.md)
2. [Shape](common/shape.md) — **wait for the user**
3. [Scaffold](common/scaffold.md) — left uncommitted and **wait for the user**; commit once their corrections are in, then invoke `plan-review-agent` against that commit. Ask for: architecture fit, missing edge cases, risk concentrations. Fix obvious issues; surface judgment calls to the user.
4. [Edge cases](common/edge-cases.md) — **wait** on the component list, then one component at a time, **waiting between each**. The last one is the last wait in the run.
5. [Tests first](common/tests-first.md)
6. [Plan](common/plan.md) — every task card carries its own model, by [archetype](references/archetypes.md)
7. **QA planning.** Invoke `qa-planner-agent` with the draft plan and the user-facing surfaces it affects (UI, API, CLI). Append the agent's `## QA Plan` section to the plan verbatim.
8. [Dispatch workers](common/worker-dispatch.md)
9. [Parent review](common/parent-review.md)
10. [Exit](common/exit.md)

### Ultra

The target behavior is settled as a spec, carved into independently buildable components, before anything is coded. This tier ends in tickets, not a PR of code.

1. [Write the spec](common/ultra.md)
2. Each component's ticket re-enters this workflow at Step 1 at its own tier — its own worktree, merging locally into the spec's integration branch, ending at [Exit](common/exit.md). No component opens a pull request: the branch is local and the whole spec goes up once. Which components build at the same time is derived from their declared edges, not written down — walked by the user or by [the chain](common/spec-run.md). A chain finishes the spec itself ([hand-back](common/spec-run.md#hand-back)). Walked by hand there is no chain to do it, so the run that finishes the spec's last component says so in its exit report — read the ultra ticket's linked component tickets to know that you are it, since nothing else tells you and names what closing the spec takes: pushing the integration branch — nothing has pushed it until now — then a PR from it into the project's own base branch, and a worktree on it to run it from. That PR is the first time continuous integration sees any of the spec. Do both when the user asks — never unasked, since the spec reaching the base branch is their call.

## Critical Rules

- Friction with **this skill** is recorded when it happens, never at the end. Two triggers: the user correcting how the run works rather than what it builds, or text that underdetermined something you then had to decide. Read [friction](common/friction.md) and write the entry the moment either fires — mid-run, never reported, discussed, or waited on.
  - **Every process correction the user makes is one, including where the lapse was yours.** A rule this skill states and you did not apply at the moment it mattered is a placement defect until a reader holding every other entry says otherwise. Writing it off as your own slip is how the defect survives. Fault is never yours to rule on here; the entry is.
  - A slip you caught yourself, with nobody correcting you, is **not** an entry. Their correction is the event: without one there is nothing separating text that failed from a run that stumbled, and a run logging its every stumble fills the pile with what no reader can act on.
  - The test is mechanical: **if your next tool call exists because the user just told you to make it, and what they told you is about how the run works rather than what it builds, the entry goes in that same message.** A correction you can obey in one command is still a correction — quick ones read as instructions to carry out and are the entries that never get written, which is exactly why those defects never get fixed.
  - A correction about the code, and an outcome the text told you to expect, are both not entries — the first is the discovered-issue rule above, the second is the skill working.
- A message with no tool call in it ends the turn and hands back to the user. Every step that says post, report, or present means: ship that prose in the same message as the next step's first tool call. Prose on its own is a hand-back whatever it says, and only a gate that waits for the user is entitled to one.
- Shared-contract blast radius: a change to something other code calls (endpoint, signature, schema, shared validator) is not done until you have listed every caller and confirmed each one's actual usage survives the new behavior. Derive the contract from all consumers, not the ticket's framing — it usually describes one surface, and a test written from it passes while hiding the break elsewhere.
- **Commit in coherent pieces throughout, not only at the scaffold.** Sessions die and uncommitted work does not survive one — a run doing a large relocation can otherwise go an entire session with nothing committed. For a relocation the natural unit is one commit per move, which also makes a bisect land on a single move and a rebase conflict name one thing.
- **Before adding a validator that refuses a configuration, grep the tests for the field it would refuse.** A defect-guard test is the cheapest possible source of *we tried that*: it names the failure mode in its own docstring and it outlives every argument about it. One refusal was drafted, briefed to the user as a decision, approved, and then reverted, because a test five hundred lines away already recorded that refusing that band of values *is* the defect — which spent the user's attention on a question the code had already settled.
- Discovered-issue routing: a problem found mid-flow (scope, scaffold, planning, implementation, or review) is routed when found, never parked as prose.
  - Related and smaller than the task at hand → fold into this ticket. The default — the context is already loaded, so spending it now is cheaper than reacquiring it later.
  - Anything else → search first, then propose it to the user with your recommendation. They decide whether it earns a ticket.
  - **Search before proposing.** `jira issue list -p {projectKey} -q "status != Done AND status != Closed" --plain --no-headers --columns key,status,summary`, then read every candidate that looks close. Search the component and file names too — the same defect gets described three different ways. An existing ticket ends the matter: cite its key, say it is already covered, propose nothing.
  - **File only after the user says to.** Never file to close out a review finding, to clear your own list, or because a subagent recommended it. An unfiled item lives in the exit report until they answer, which is a disposition.
  - Invariant: anything not folded in leaves as a ticket key or a line in the exit report the user reads. A paragraph in a plan or PR description is not an owner.
- Never automatically merge a PR into the base branch. The user merges or asks you to merge; an armed goal is that ask. Merging a component into a spec's integration branch is the one exception, and only ever for whoever owns the component's ticket: a chain merges its components, a lone unattended run on a component ticket merges its own, and a component dispatched inside a chain merges nothing — its parent does. That merge is local and opens no pull request. The user's merge is the single one at the end that takes the whole spec to the base branch.
- A refused tool call is not a blocker until you have tried the other way. A denial is about one command's shape, never about the question you were answering — where a second route to the same information exists, take it and carry on. Naming an alternative and then stopping to ask whether to use it is the exact failure this rule exists to prevent: a read-only fact is the same fact however you obtain it. Escalate only once every route you can name is refused, and say which ones you tried.
- Nothing dispatched ever parks waiting for an answer. A subagent cannot message whatever spawned it — the reply path does not resolve — so an agent that stops mid-task to wait has stranded itself and everything above it. When you need a decision you cannot make, **end your turn and return the question as your report**; that is the one channel that works. Return what you did, what you need decided, and what a replacement would need, so the work survives whether you are resumed or replaced.
- **Three levels, and the worker level is the floor.** A session dispatches managers, a manager dispatches workers, and a worker dispatches nothing. A completion reaches its spawner one level down and no further: deeper than that it surfaces to the main session, so the agent that asked never receives it and waits forever on a result already delivered to somebody else. Say it in every dispatch prompt, in the second person — *anything you spawn reports to me, not to you; do the work yourself* — and make each level say it to the one below. Where a job is genuinely too large for one agent, the level that can hold the results splits it and dispatches the pieces itself.
  - This binds the reviewer too. A review gate that fans out to per-dimension reviewers loses every one of their findings and returns a verdict over the ground it happened to cover itself, which reads as a pass over the whole diff. If a review needs more than one agent, whoever spawned the reviewer runs them.
  - **When an agent goes quiet, mis-addressed is likelier than deep.** A stalled agent is indistinguishable from a thinking one — there is no error and no crash, only silence — so before crediting it with depth, check whether one of its children's results landed in your queue. Relay it in full if it did, and say why it is arriving from you so it stops waiting.
- Browser tool split: the Playwright MCP browser is only for verifying the change under test (the Exit verify step). Use Claude's built-in Chrome for every other browsing task across the flow — reading the ticket, research, docs, dashboards.
- Fan-out sizing: fan out only when one agent cannot hold the work. Estimate what a single agent would have to read — if it fits comfortably in context (~200k), run one agent. Every extra agent re-pays the shared background in full, and parallelism only buys wall-clock.
  - When it genuinely does not fit, split along what the agents do *not* share: the cheapest split duplicates the least reading, not the one with the most agents.
  - Never shorten the item list to cut the agent count. Give each agent more items instead.
