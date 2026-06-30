---
name: dev-workflow
description: End-to-end implementation workflow. Use when the user says "take <TICKET>" to work on an existing Jira ticket, "new take" to scope and create a ticket before working on it, or "cleanup [TICKET]" to tear down after a PR is merged. Handles small/medium/deep tiers with worker subagents, parent review, PR creation, ticket transition, and worktree cleanup.
---

# Dev Workflow

Single orchestrated flow for ticket-driven and manual implementation work.

**Before Step 1, call `TodoWrite` to create the status list seeded with these exact items, then keep it current** — mark the prior item `completed` and the next `in_progress` as you move through the flow. This list is the user's at-a-glance status surface, not narration; maintain it even when responses are otherwise terse.

1. Understand the problem
2. Verify the problem
3. High-level solution research
4. Implementation routing
5. Workspace setup
6. Implementation
7. Exit

**All numbered steps must be done sequentially in order. Bullets can be done in parallel**

## Step 1: Understanding The Problem

1. If a ticket was provided read it using the jira skill, else use the user provided context to begin to try to understand the problem. (Assign the ticket to me as well if not done so already). If the ticket is blocked or parked. STOP immediately and notfiy the user.
2. Restate intent with zero implementation nouns from the ticket. If the ticket says "add a smoke test," my one-sentence intent must not contain "test," "smoke," or any suite name. Force the mechanism out so it can't sneak in as a requirement. ("Continuously assure the deployed sample-pack endpoint serves a real artifact.") Every implementation noun the ticket carries is a hypothesis that must beaten by online research before it is adopted.
3. Once you understand the problem explain it to the user. There may be some back and fourth discussing for understanding and steering. Do not proceed to the next step until the user says go. This is **crucial** your framing of the intent and problem space must be approved by the user before proceeding.
4. Scrutinize whether you think this ticket is worth doing or not.

## Step 2: Verify the problem

1. **Codebase update** In the main checkout, run `git status --porcelain`. If it prints anything, stop: this is the main-checkout gate (see Critical Rules). When it prints nothing, run `git pull --ff-only`.
2. Use `ultracode` to do the following in parallel:
   - **Verify the problem exists in code** Do your own investigation.
   - **Read relevant documentation** Be careful, documentation could be out of date.
   - **Historical precedence** Are there related issues? Does the commit history help us understand where this bug came from? Is it recurring? Is this problem a symptom of something larger?
   - **Is this needed?** What are the business-level implications? Is there a simpler solution? Is the ticket a symptom of a larger problem? Dive deep. If you have reason to beleive this should not be done, stop here and report back to the user with a simple high level explanation.

## Step 3: High Level Solution Research

The goal at this point is to using our understanding or the problem and the business to come up with the best solution possible. Not a lazy hack. Something flawless. To do this you need to gather multiple solution options and pick one.

1. Ask the user what solution they are leaning towards. Leverage their unique perspective and creativity as an option NOT as something set in stone, yet.
2. Use `ultracode` to do deep online research on industry standards, best practices, and clean solutions to the type of problem.
3. Synthesize - Given all of the context you've gathered converge on a single recommended solution. Make sure to challenge any assumptions you've made exhaustively and then present this solution to the user. Do not proceed to the next step until the user approves the high level approach/solution by saying `go`.

## Step 4: Implementation Routing

Recommend an implemetation tier based on the following

| Tier     | When                                                       |
| -------- | ---------------------------------------------------------- |
| `small`  | Bug fix, config change, typo, isolated single-file change  |
| `medium` | New feature, moderate refactor                             |
| `deep`   | Architectural, multi-system, new design pattern, high risk |

The user should reply with `yes` or the tier they want instead.

## Step 5: Workspace Setup

1. **Create/update the ticket**: If `new take`, create a new ticket. If we chose a solution very different from the original ticket, update the original. Use the `jira` skill.
2. **Transition the ticket** to "In Progress" via the `jira` skill.
3. **Enter the worktree.**
   - Call `EnterWorktree` with name `<TICKET>-<tier>` (e.g., `STAX-123-medium`).
   - Verify with `git rev-parse --show-toplevel` that you're inside the worktree. Then proceed with the tier sequence for the implementation.

## Step 6: Per Tier Implementation

Run the sequence for the confirmed tier. Each step links to its procedure file. Mark the Implementation item `in_progress`; add the tier's steps as sub-items of it.

### Small

The parent implements in one pass. No subagents, no plan file.

1. Implement the change(s) directly in the worktree.
2. Add a unit test if applicable and a test suite is set up.
3. Run lint, type checker, and tests on modified files. Fix issues.
4. [Exit](common/exit.md).

### Medium

Parent plans, `worker-agent` subagents implement, parent reviews. The plan must name every file and every step — workers do not make scoping decisions.

1. [Scope](common/scope.md)
2. [Plan](common/plan.md)
3. [Present plan](common/plan-presentation.md)
4. [Dispatch workers](common/worker-dispatch.md) — parallel when files are disjoint
5. [Parent review](common/parent-review.md)
6. [Exit](common/exit.md)

### Deep

Similar to medium tier but Adds QA planning and an architecture review gate before workers dispatch. `Opus` workers instead of sonnet.

1. [Scope](common/scope.md)
2. [Plan](common/plan.md)
3. **QA planning.** Invoke `qa-planner-agent` with the draft plan and the user-facing surfaces it affects (UI, API, CLI). Append the agent's `## QA Plan` section to the plan verbatim.
4. **Architecture review.** Invoke `plan-review-agent` against the draft plan and affected files. Ask for: architecture fit, missing edge cases, risk concentrations. Fix obvious issues; surface judgment calls as `[NEEDS CLARIFICATION]` in the plan.
5. [Present plan](common/plan-presentation.md)
6. [Dispatch workers](common/worker-dispatch.md) — parallel when files are disjoint
7. [Parent review](common/parent-review.md)
8. [Exit](common/exit.md)

## Critical Rules

- Shared-contract blast radius: a change to something other code calls (endpoint, signature, schema, shared validator) is not done until you have listed every caller and confirmed each one's actual usage survives the new behavior. Derive the contract from all consumers, not the ticket's framing — it usually describes one surface, and a test written from it passes while hiding the break elsewhere.
- Never automatically merge a PR. The user merges or asks you to merge.
- Main-checkout gate: before any pull or write in the main checkout, `git status --porcelain` must print nothing. If it prints anything, stop, show the user the dirty files, and wait for their decision. Never stash, commit, or discard main-checkout changes to unblock yourself; all work happens in worktrees, so a dirty main checkout is an anomaly only the user can triage.
- Keep discussions with the user simple and high level unless they ask for more information. THIS IS **CRUCIAL**! Otherwise you waste time where they keep having to ask you to explain or they just rubber stamp.
