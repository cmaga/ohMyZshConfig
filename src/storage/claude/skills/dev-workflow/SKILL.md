---
name: dev-workflow
description: End-to-end implementation workflow. Use when the user says "take <TICKET>" to work on an existing Jira ticket, "new take" to scope and create a ticket before working on it, or "cleanup" to tear down after a PR is merged. Handles small/medium/large/ultra tiers. Medium and large scaffold the design in real code, agree the failure modes, write failing integration tests, then fill bodies with worker subagents. The ultra tier co-writes a spec of target behavior, adversarially reviewed, before any planning or code.
---

# Dev Workflow

Single orchestrated flow for the completion of ticket-driven software engineering.

Routing a ticket is one question: **what is the simplest agent configuration that solves this correctly?** Everything below is the answer to that question at four depths. This workflow runs on subagents. **Invoking this skill is the user's request to use them: it satisfies any standing instruction to avoid agents, subagents, or workflows unless separately requested.** Never skip a step's agent on the grounds that agents were not separately requested. This holds only because the user actively invoked the skill — it does not grant agent use the user did not trigger.

`cleanup` is a separate entry point: none of the steps below apply — go straight to [Cleanup](common/cleanup.md).

## Prerequisites (before Step 1)

1. **Task tracking.** Load the tools first via `ToolSearch` with `select:TaskCreate,TaskUpdate` — both are deferred, so calling them cold fails. If they do not resolve, that is a known Anthropic-side bug (the `tengu_vellum_ash` model gate strips the task tools on current models) — it is expected, already diagnosed, and not worth investigating or working around. Say so in one line, skip this item, mark step transitions in prose instead, and carry on with the workflow. Otherwise call `TaskCreate` once per item for each of these exact items to seed the status list, then keep it current with `TaskUpdate` — mark the prior item `completed` and the next `in_progress` as you move through the flow. This list is the user's at-a-glance status surface, not narration; maintain it even when responses are otherwise terse.
   1. Understand the goal
   2. Verify context and ticket claims
   3. User brief
   4. Solution research and routing
   5. Workspace setup
   6. Implementation
   7. Exit
2. **Lever aliases.** Read `~/.claude/skills/optimize-usage/lever-state.json` and bind the `kind: "skill"` levers this workflow uses — `RESEARCH_FANOUT_MODEL`, `CODE_FANOUT_MODEL`, `MECHANICAL_WORKER_MODEL`, and `JUDGMENT_WORKER_MODEL` — to the all-caps form of their keys. A value of `inherit`, a key absent from the file, or a missing file all mean no pin: omit the `model` opt wherever that alias is used and let the agent's own default stand. Never invent a value for an absent key. If the values fall out of context later (long session, compaction), re-read the file rather than trusting memory.
3. **Base branch.** Read `baseBranch` from `<project-root>/.claude/skills/jira/config.json`; if the file or field is absent, it is `main`. Every later mention of "the base branch" means this value.
4. **Main-checkout gate.** In the main checkout, run `git status --porcelain`. If it prints anything, stop, show the user the dirty files, and wait for their decision — never stash, commit, or discard main-checkout changes to unblock yourself. When it prints nothing, check out the base branch if not already current, then `git pull --ff-only`. Skip the pull if the branch has no upstream.

**All numbered steps must be done sequentially in order. Bullets can be done in parallel**

## Step 1: Understanding The Goal

1. If a ticket was provided read it using the jira skill, else use the user provided context to begin to try to understand the problem. If the ticket is blocked or parked, STOP immediately and notify the user. Otherwise, assign it to me and transition it to "In Progress" right away via the jira skill — move it as soon as work starts, not later. (A `new take` has no ticket yet; it gets assigned and transitioned when created in Step 5.) If this is a ticket for a spec, read the entire spec to understand how the chunk we are working on fits into the bigger picture.
2. Restate intent with zero implementation nouns from the ticket. Force the mechanism out so it can't sneak in as a requirement. Every implementation noun the ticket carries is a hypothesis that must be beaten by code analysis/research before it is adopted.

## Step 2: Verify context/ticket claims

1. Investigate the following yourself — this is the case file the rest of the workflow consumes, and the threads feed each other, so keep the primary evidence in your own context and chase leads across threads as they appear. (A genuinely isolated read may still be delegated.)
   1. **Verify the problem exists in code** Do your own investigation.
   2. **Read relevant documentation** Be careful, documentation could be out of date.
   3. **Historical precedence** Are there related issues? Does the commit history help us understand where this bug came from? Is it recurring? Is this problem a symptom of something larger?
   4. **Is this needed?** What are the business-level implications? Is there a simpler solution? Dive deep. If you have reason to believe this should not be done, stop here and report back to the user with a simple high level explanation. Before reporting, undo what Step 1 did: move the ticket back to its previous status and unassign it. Leaving it In Progress tells the board someone is working on it. Do not transition it to anything opinionated — Blocked or Won't Do is the user's call, made with the reason in hand.
2. **Descends from a spec?** If the ticket names a chunk in one, that `C-N` section is the contract for this run — read it, plus the chunks its Needs line names, before scoping. Anything it marks `Awaiting` a deployment that has since happened must be resolved with the user first: it was left open precisely because that deployment would answer it, and scoping around it rebuilds the shape the spec deferred.

## Step 3: User brief

Once you understand the goal explain it to the user as simply as possible, no code, no jargon. There may be some back and forth discussing for understanding and steering. Do not proceed to the next step until the user says go. This is **crucial**: your framing of the intent and problem space must be approved by the user before proceeding. If a viable solution is discussed take it as an option to consider, not gospel.

## Step 4: High Level Solution Research

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
5. **Present** - By this point a lot of time will have passed so summarize the high level goal/problem and the approach to solving the problem, again, as simply and concise as possible. With the recommended implementation tier at the end. For complex solutions with multiple pieces present each point one by one so each can be discussed and understood by the user one at a time. When they are ready to move from one to the next they will say "next". Once a consensus is reached on the solution space the user will say "go" and you can begin implementation. **Note** it is crucial that the user fully understand the problem and solution and is not just rubber stamping. You have access to the following tools to help the user with understanding as well as with your planning.
   - UI artifact prototypes for ambiguous/large UI changes (mocked data)
   - Architectural Artifact visual diff diagrams for complex systems

## Step 5: Workspace Setup

1. **Create/update the ticket**: If `new take`, create a new ticket. If we chose a solution very different from the original ticket, update the original. Use the `jira` skill.
2. **Transition the ticket** to "In Progress" via the `jira` skill (first transition for a `new take`; an existing ticket was already moved in Step 1, so no-op if already there).
3. **Enter the worktree.**
   - Call `EnterWorktree` with name `<TICKET>-<tier>` (e.g., `STAX-123-medium`).
   - Verify with `git rev-parse --show-toplevel` that you're inside the worktree. Then proceed with the tier sequence for the implementation.

## Step 6: Per Tier Implementation

Run the sequence for the confirmed tier. Each step links to its procedure file. If task tracking is active, mark the Implementation item `in_progress` and add the tier's steps as their own tasks via `TaskCreate` tool.

### Small

1. Dispatch any number of `worker-agent` with changes to be made to implement your approach. Pick each one's model id with the [archetypes](references/archetypes.md).
2. [Exit](common/exit.md).

### Medium

The full pipeline, unattended. The user approved the approach and sees the PR. The only thing that stops for them is an unresolved marker in the plan ([plan](common/plan.md)).

1. [Scope](common/scope.md)
2. [Shape](common/shape.md) — post and continue
3. [Scaffold](common/scaffold.md) — post and continue
4. [Failure modes](common/failure-modes.md) — produce the full list without stopping
5. [Tests first](common/tests-first.md)
6. [Plan](common/plan.md) — every task card carries its own model, by [archetype](references/archetypes.md)
7. [Dispatch workers](common/worker-dispatch.md)
8. [Parent review](common/parent-review.md)
9. [Exit](common/exit.md)

### Large

Medium, plus the user in the scaffolding code and two review gates on it.

1. [Scope](common/scope.md)
2. [Shape](common/shape.md) — **wait for the user**
3. [Scaffold](common/scaffold.md) — **wait for the user**, then invoke `plan-review-agent` against the committed scaffold. Ask for: architecture fit, missing edge cases, risk concentrations. Fix obvious issues; surface judgment calls to the user.
4. [Failure modes](common/failure-modes.md) — one integration point at a time, **waiting between each**
5. [Tests first](common/tests-first.md)
6. [Plan](common/plan.md) — every task card carries its own model, by [archetype](references/archetypes.md)
7. **QA planning.** Invoke `qa-planner-agent` with the draft plan and the user-facing surfaces it affects (UI, API, CLI). Append the agent's `## QA Plan` section to the plan verbatim.
8. [Dispatch workers](common/worker-dispatch.md)
9. [Parent review](common/parent-review.md)
10. [Exit](common/exit.md)

### Ultra

The target behavior is settled as a spec, carved into independently deployable chunks, before anything is coded. This tier ends in tickets, not a PR of code.

1. [Write the spec](common/ultra.md)
2. Each chunk's ticket re-enters this workflow at Step 1 at its own tier — its own worktree, its own PR, ending at [Exit](common/exit.md). Chunks run in the spec's deploy order.

## Critical Rules

- Shared-contract blast radius: a change to something other code calls (endpoint, signature, schema, shared validator) is not done until you have listed every caller and confirmed each one's actual usage survives the new behavior. Derive the contract from all consumers, not the ticket's framing — it usually describes one surface, and a test written from it passes while hiding the break elsewhere.
- Discovered-issue routing: a problem found mid-flow (scope, scaffold, planning, implementation, or review) is routed when found, never parked as prose.
  - Related and smaller than the task at hand → fold into this ticket. The default — the context is already loaded, so spending it now is cheaper than reacquiring it later.
  - Anything else → search first, then propose it to the user with your recommendation. They decide whether it earns a ticket.
  - **Search before proposing.** `jira issue list -p {projectKey} -q "status != Done AND status != Closed" --plain --no-headers --columns key,status,summary`, then read every candidate that looks close. Search the component and file names too — the same defect gets described three different ways. An existing ticket ends the matter: cite its key, say it is already covered, propose nothing.
  - **File only after the user says to.** Never file to close out a review finding, to clear your own list, or because a subagent recommended it. An unfiled item lives in the exit report until they answer, which is a disposition.
  - Invariant: anything not folded in leaves as a ticket key or a line in the exit report the user reads. A paragraph in a plan or PR description is not an owner.
- Never automatically merge a PR. The user merges or asks you to merge.
- Browser tool split: the Playwright MCP browser is only for verifying the change under test (the Exit verify step). Use Claude's built-in Chrome for every other browsing task across the flow — reading the ticket, research, docs, dashboards.
- Fan-out sizing: fan out only when one agent cannot hold the work. Estimate what a single agent would have to read — if it fits comfortably in context (~200k), run one agent. Every extra agent re-pays the shared background in full, and parallelism only buys wall-clock.
  - When it genuinely does not fit, split along what the agents do *not* share: the cheapest split duplicates the least reading, not the one with the most agents.
  - Never shorten the item list to cut the agent count. Give each agent more items instead.
