---
name: dev-workflow
description: End-to-end implementation workflow. Use when the user says "take <TICKET>" to work on an existing Jira ticket, "new take" to scope and create a ticket before working on it, or "cleanup" to tear down after a PR is merged. Handles small/medium/large/ultra tiers. Medium and large scaffold the design in real code, list the edge cases, write failing integration tests, then fill bodies with worker subagents. The ultra tier co-writes a spec of target behavior, adversarially reviewed, before any planning or code. A run the user arms with a `/goal` continues unattended from there to a complete, reviewed PR.
---

# Dev Workflow

Single orchestrated flow for ticket-driven software engineering, at four depths: **what is the simplest agent configuration that solves this correctly?** This workflow runs on subagents. **Invoking it is the user's request to use them** — it satisfies any standing instruction to avoid agents unless separately requested. Never skip a step's agent on those grounds.

`cleanup` is a separate entry point: none of the steps below apply — go straight to [Cleanup](common/cleanup.md).

## Unattended runs

A run is unattended when the user pastes a `/goal`; `manual` in the take keeps it attended. Steps 1-4 run the same either way. The goal is the go: draft it, hand it over, create nothing until they paste it.

    /goal <one measurable end state, and the check that settles it>

Name something whose evidence lands in the transcript — *every component merged with the suite green* — never a posture. Schedule nothing alongside it; only [the chain](common/spec-run.md) arms a wake-up. A run that notices any interruption asks the user to re-arm.

An armed goal converts these gates, and only these, to decide-record-and-continue:

- The [scaffold](common/scaffold.md) review wait and blast-radius interrupt
- A strategic plan marker — decide it, rewrite as `[ASSUMED: ...]`, carry it to the [loose-end tracker](common/exit.md#the-loose-end-tracker)
- Ticket filing — file nothing; every discovered issue becomes a tracker task. Exception: a chain filing a component ticket the spec calls for
- A spec component's local merge into its integration branch

Still stops the run: the prerequisite gates, a review gate at its five-round backstop or an `escalate` the [escalation agent](#what-stops-attended) cannot decide, a red required PR check. Inside a chain the component returns instead and the parent decides. The run ends on the tracker's first item — that is the hand-back.

## Routing

Read the ticket first (Step 1.1), then run Prerequisites 1-4. A **chain** skips Steps 1-4 and runs [the chain](common/spec-run.md) instead; its Driver seeds tracking and runs the main-checkout gate itself.

A chain is an ultra ticket — its description names a spec path — whose spec is approved: the path resolves in the main checkout on the base branch. If it does not resolve, the ticket's status says why. **In review**: say so and stop; the user merging it starts the run. **Done**: the chain already ran; say so and stop. Issue type never overrides this — an epic carrying the path is the chain's ticket, not a container to look inside. `manual` does not apply to a chain.

Everything else, a component ticket included, runs the steps below.

## Prerequisites

1. **Task tracking.** `ToolSearch` with `select:TaskCreate,TaskUpdate` — both are deferred. If they do not resolve, mark step transitions in prose and carry on. Otherwise seed one task per item below and keep it current — prior `completed`, next `in_progress`. This list is the status surface; maintain it even when responses are terse.
   1. Understand the goal
   2. Verify context and ticket claims
   3. User brief
   4. Solution research and routing
   5. Workspace setup
   6. Implementation
   7. Exit
2. **Lever aliases.** Read `~/.claude/skills/optimize-usage/lever-state.json` and bind its `kind: "skill"` levers to the all-caps form of their keys: `RESEARCH_FANOUT_MODEL`, `CODE_FANOUT_MODEL`, `MECHANICAL_WORKER_MODEL`, `JUDGMENT_WORKER_MODEL`, `ESCALATION_MODEL`, and `PARENT_FANOUT_MODEL` (every dispatch no other alias covers). `inherit`, an absent key, or a missing file means omit the `model` opt. Re-read the file after compaction. Prefix every dispatched agent's `description` with its alias and value — `code-fanout(opus): seam check on the intake path` — since the model is recorded nowhere else.
3. **Base branch.** Read `baseBranch` from `<project-root>/.claude/skills/jira/config.json`; if the file or field is absent, it is `main`. Every later mention of "the base branch" means this value, until Step 5.3 rebinds it for a spec-descended run.
4. **Main-checkout gate.** In the main checkout, run `git status --porcelain`. If it prints anything, stop, show the user the dirty files, and wait for their decision — never stash, commit, or discard main-checkout changes to unblock yourself. When it prints nothing, check out the base branch if not already current, then `git pull --ff-only`. Skip the pull if the branch has no upstream. Leave the main checkout on the base branch — nothing later in the flow moves it, and a session that finds it elsewhere is looking at a bug.

**All numbered steps must be done sequentially in order. Bullets can be done in parallel**

Every step below is labelled **internal** or **user-facing**. An internal step prints nothing between its tool calls and never ends a turn — the task list is the status surface. Every message that waits on the user is at most four sentences of plain words, plus anything it has to show (a file list, a `/goal` line), then each thing that needs their answer, numbered. Detail is what they ask for next.

## Step 1: Understanding The Goal — internal

1. Read the ticket via the jira skill (a `new take` has none; use the user's context). Blocked or parked: stop and tell the user. **Run the ticket you were handed** — never substitute a child or sibling; if it cannot be run, stop and say why. Otherwise assign it to me and transition it to "In Progress" now. If it is a spec's ticket — its own or one component's — read the entire spec. A ticket for one component of an approved spec is spec-descended — the spec's own epic is a chain, routed above, never here — and its `## C-N:` section is what to build. Note it for Step 5.
2. Restate intent with zero implementation nouns from the ticket. Every implementation noun it carries is a hypothesis to be beaten by code analysis before it is adopted. Working notes, not a post.

One line surfaces from this step: the ticket read, assigned, and moved to In Progress.

## Step 2: Verify context/ticket claims — internal

1. Dispatch `scoping-agent` with the ticket and Step 1's restatement; spec-descended, add the spec path and component id. Read the case file; do not repeat its reading.
   - Not needed → stop, report to the user in plain words, and undo Step 1: previous status, unassigned. Blocked or Won't Do is their call.
   - Spec-descended: the spec settled the brief and the solution, so Steps 3 and 4 do not re-open them; pick the tier only, never ultra. A surviving Open question is a spec defect: attended, ask that one at Step 3 and nothing else; in a chain, return it to the parent per [escalation](common/spec-run.md#escalation).

## Step 3: User brief — user-facing

Explain the goal to the user as simply as possible — no code, no jargon. **Four sentences at most, plus the one thing you need them to weigh in on.** Depth is on request. Do not proceed until the user says go: your framing of the problem must be approved. A solution they suggest is an option to consider, not gospel.

## Step 4: High Level Solution Research — internal until Present (item 5)

Gather multiple solutions and pick the best one. Fan out only over sets you enumerate yourself — never per-item over a set a subagent produced.

1. Use `ultracode` (fan-out agents on `RESEARCH_FANOUT_MODEL`) for deep online research on industry standards and clean solutions to this type of problem. Weigh any direction the user shared.
2. **Codebase fit** — map the leading solution onto this repo: where each new piece lives, which existing symbols it reuses. Fan out on `CODE_FANOUT_MODEL` when the surface is too large for one agent. Verify every placement and reuse claim at `file:line` before trusting it. A bad pattern is not to be followed because it is convention.
3. **Synthesize** — converge on one recommended solution, challenging every assumption. If the target behavior is not settled enough to converge, recommend `ultra` instead and carry the research into the spec.
4. **Implementation Routing** Determine a recommended implementation tier
   | Tier | When | Where the user is |
   | -------- | ----------------------------------------------------------------------------------------- | ------------------------ |
   | `small` | The whole change states in a sentence and one worker can do it against an obvious check | Intent only |
   | `medium` | Real implementation work, but no structure the user needs to see before the PR | Intent, approach, the PR |
   | `large` | New structure, or a boundary moves that the user needs to see. Not a size call: a 400-line rewrite behind an unchanged signature is not large; a 40-line new interface two modules consume is | In the scaffold |
   | `ultra` | Target behavior is itself unsettled and must be agreed as a spec before it can be planned | Throughout |
   Unattended, nobody is watching, so read the last column as what a user *would* need to see: `large` is where new structure or a moved boundary appears, whether or not anyone reviews the scaffold.
5. **Present** — user-facing. Four parts, in this order, nothing else:
   1. **Where we are.** `Research complete for <the problem, restated in one line>.`
   2. **The approach.** Plain language. No jargon, file paths, or symbol names. Short.
   3. **The tier**, with one clause on why.
   4. **The `/goal` line to paste**, unless the take said `manual` — see [Unattended runs](#unattended-runs). Pasting it is the go; pasting nothing means they stay in the loop.

   Then stop. Walk the solution point by point only if they ask — one piece per message, advancing on "next", the one-line problem restatement at the top of each. The user says "go" and implementation begins. For understanding: UI artifact prototypes (mocked data) for ambiguous UI changes; architectural diagrams for complex systems.

## Step 5: Workspace Setup — internal

1. **Create/update the ticket**: If `new take`, create a new ticket. If we chose a solution very different from the original ticket, update the original. Use the `jira` skill.
2. **Transition the ticket** to "In Progress" via the `jira` skill (first transition for a `new take`; an existing ticket was already moved in Step 1, so no-op if already there).
3. **Spec-descended runs only — resolve the base branch.** A component builds against the spec's integration branch, `spec/<SPEC-TICKET>`; cut it from the project base if it does not exist. **It is local and never pushed** — the whole spec goes up as one PR. From here on, "the base branch" means that branch. The main checkout stays on the project base.
4. **Enter the worktree.**
   - **Ordinary runs:** `EnterWorktree` with name `<TICKET>-<tier>` (e.g., `STAX-123-medium`).
   - **Spec-descended runs:** `EnterWorktree` by name branches from the default branch, which a component must not build on. Create it yourself, then `EnterWorktree` with that `path`:

         git worktree add -b <TICKET>-<tier> "$(git rev-parse --show-toplevel)/.claude/worktrees/<TICKET>-<tier>" spec/<SPEC-TICKET>

     A refusal saying the tool only switches from inside a worktree is expected when dispatched at the repo root, as a chain's manager is: carry on by absolute path and `git -C`. `ExitWorktree` only `keep`s a worktree entered this way; [cleanup](common/cleanup.md) removes it with git.
   - Verify with `git rev-parse --show-toplevel`.
   - Until `ExitWorktree`, git reaches nothing outside the worktree: `cd` out, `git -C`, `--git-dir`, `GIT_DIR`, and any Bash whose shape hides where it lands are refused. When one is, write the commands to a scratchpad script and run it by absolute path.

## Step 6: Per Tier Implementation — internal except the waits listed below

Run the sequence for the confirmed tier. Each step links to its procedure file. If task tracking is active, mark the Implementation item `in_progress` and add the tier's steps as their own tasks via `TaskCreate` tool.

### What stops, attended

The complete list; a step not named here does not wait, whatever its procedure file says:

- `large` — one wait, before any code is written: the [scaffold](common/scaffold.md) review.
- `medium` — none.
- `small` — none.

After that the run does not stop until the PR is out. Only escalation breaks it: the review gate returns `escalate` or hits its five-round backstop, a worker escalation you cannot decide from the code, or a hard blocker. **A question whose answer is in the repo is not an escalation** — read the code and decide it.

**Before an escalation reaches the user, give it to the escalation agent** — a `general-purpose` agent on `ESCALATION_MODEL` — with the question and the evidence, told to decide it and spawn nothing. Act on its decision without reporting it; only what it cannot decide reaches the user.

### Small

1. Dispatch any number of `worker-agent` with changes to be made to implement your approach. Pick each one's model id with the [archetypes](references/archetypes.md).
2. [Exit](common/exit.md).

### Medium

The full pipeline, no waits.

1. [Scope](common/scope.md)
2. [Scaffold](common/scaffold.md) — commit it as soon as it is written
3. [Edge cases](common/edge-cases.md) — produce the full list and carry it straight into the tester
4. [Tests first](common/tests-first.md)
5. [Plan](common/plan.md) — every task card carries its own model, by [archetype](references/archetypes.md)
6. [Dispatch workers](common/worker-dispatch.md)
7. [Parent review](common/parent-review.md)
8. [Exit](common/exit.md)

### Large

Medium, plus the user in the scaffolding code and two review gates on it.

1. [Scope](common/scope.md)
2. [Scaffold](common/scaffold.md) — left uncommitted and **wait for the user**; commit once their corrections are in, then invoke `plan-review-agent` against that commit. Ask for: architecture fit, missing edge cases, risk concentrations. Fix obvious issues; surface judgment calls to the user.
3. [Edge cases](common/edge-cases.md) — produce the full list and carry it straight into the tester
4. [Tests first](common/tests-first.md)
5. [Plan](common/plan.md) — every task card carries its own model, by [archetype](references/archetypes.md)
6. **QA planning.** Invoke `qa-planner-agent` with the draft plan and the user-facing surfaces it affects (UI, API, CLI). Append the agent's `## QA Plan` section to the plan verbatim.
7. [Dispatch workers](common/worker-dispatch.md)
8. [Parent review](common/parent-review.md)
9. [Exit](common/exit.md)

### Ultra

The target behavior is settled as a spec, carved into independently buildable components, before anything is coded. This tier ends in tickets, not a PR of code.

1. [Write the spec](common/ultra.md)
2. Each component's ticket re-enters this workflow at Step 1 at its own tier, merging locally into the spec's integration branch. No component opens a PR — the whole spec goes up once, by [the chain](common/spec-run.md) or, walked by hand, by the run that finishes the last component: check the spec against the branch as [hand-back](common/spec-run.md#hand-back) step 1 does, then, when the user asks, push the branch and open the PR.

## Critical Rules

- A user correction about how the run works — not what it builds — is a skill lesson. File it in auto memory per [lesson format](../memory-review/lesson-format.md) in the same message as the tool call that obeys it, never at the end. A slip you caught yourself is not one.
- A message with no tool call ends the turn. Every step that says post, report, or present means: ship that prose in the same message as the next step's first tool call. Only a gate that waits for the user ends a turn.
- Shared-contract blast radius: a change to something other code calls (endpoint, signature, schema, shared validator) is not done until every caller is listed and confirmed to survive. Derive the contract from all consumers, not the ticket's framing.
- **Commit in coherent pieces throughout.** Sessions die and uncommitted work does not survive one. For a relocation, one commit per move.
- **Before adding a validator that refuses a configuration, grep the tests for the field it would refuse.** A defect-guard test is the record of *we tried that*.
- Discovered-issue routing: a problem found mid-flow is routed when found, never parked as prose.
  - **Fix it.** The one question is whether the fix can ride this branch — not whether it is in scope. This is the cheapest moment the fix will ever have.
  - Leave it only when it genuinely cannot ride — a different subsystem, a design decision the user owns, a scope that would double the diff. Then propose it with your recommendation and why it could not ride. A third proposal on the tracker means re-ask whether any could have been fixed.
  - **Search before proposing.** `jira issue list -p {projectKey} -q "status != Done AND status != Closed" --plain --no-headers --columns key,status,summary`, then read every close candidate; search component and file names too. An existing ticket ends the matter: cite its key.
  - **File only after the user says to.** An unfiled item is an open task on the [loose-end tracker](common/exit.md#the-loose-end-tracker) until they answer. Prose in a plan, PR description, vault note, or exit report is not an owner.
- Never merge a PR into the base branch; an armed goal is not that ask. The one exception is a component's local merge into its spec's integration branch, by whoever owns the component's ticket — a chain merges its components; a component dispatched inside a chain merges nothing.
- A refused tool call is not a blocker until every route to the same information is refused. Take the other route and carry on; never stop to ask whether to use it.
- Nothing dispatched parks waiting for an answer. A decision you cannot make goes back as your report — **end your turn and return the question** — with what you did and what a replacement would need. `SendMessage` to `main` carries nothing of the work; it is for a [skill lesson](../memory-review/lesson-format.md) only.
- **Three levels, and the worker level is the floor.** A session dispatches managers, a manager dispatches workers, a worker dispatches nothing — a deeper completion surfaces to the main session and its asker waits forever. Say it in every dispatch prompt: *anything you spawn reports to me, not to you; do the work yourself.* Too large for one agent → the level that can hold the results splits it. This binds the reviewer: if a review needs more than one agent, whoever spawned the reviewer runs them.
  - **When an agent goes quiet, read its status with `ListAgents` before believing anything.** A finished agent whose result never reached its waiter was mis-addressed — check your queue and relay it. Replace only an agent that is no longer running and delivered nothing.
- **Cap every return.** Put this in every dispatch prompt: *return only what I act on — files and commits touched, the answer with `file:line`, what needs deciding. Keep the reasoning; I can ask.* An uncapped report lands whole in the parent's context.
- Browser tool split: Playwright MCP only for verifying the change under test (Exit). Built-in Chrome for everything else.
- Fan-out sizing: fan out only when one agent cannot hold the work (~200k). Split along what the agents do *not* share. Never shorten the item list to cut the agent count.
