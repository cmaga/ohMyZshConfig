---
name: dev-workflow
description: End-to-end implementation workflow. Use when the user says "take <TICKET>" to work on an existing Jira ticket, "new take" to scope and create a ticket before working on it, or "cleanup [TICKET]" to tear down after a PR is merged. Handles small/medium/deep tiers with worker subagents, parent review, PR creation, ticket transition, and worktree cleanup.
---

# Dev Workflow

Single orchestrated flow for ticket-driven and manual implementation work. The parent session is opus; implementation workers are sonnet.

## Critical Rules

- Never automatically merge a PR. The user merges or asks you to merge.
- All tiers run in an isolated worktree. Create it before any file modification.
- Classification is Claude-proposed, user-confirmed. Never proceed without confirmation.
- Treat tickets as hypotheses/recommended work. The prescribed fix is a guess until verified.

## Trigger routing

Parse the user's message on invocation.

| Input              | Route to                                                                                       |
| ------------------ | ---------------------------------------------------------------------------------------------- |
| `take <TICKET>`    | Scoping → tier sequence                                                                        |
| `new take`         | Scoping → ticket creation → tier sequence                                                      |
| `cleanup [TICKET]` | [common/cleanup.md](common/cleanup.md) (infer ticket if missing, ask if it cannot be inferred) |

## Scoping

Whether or not there's a ticket, investigate first and fully understand the problem. Even when the ticket prescribes a fix, treat that as a hypothesis.

### Tier definitions

| Tier     | When                                                      |
| -------- | --------------------------------------------------------- |
| `small`  | Bug fix, config change, typo, isolated single-file change |
| `medium` | New feature, moderate refactor, 2-5 files                 |
| `deep`   | Architectural, multi-system, new design pattern, 5+ files |

### Process

0. **pull** Always pull the latest version of main first to make sure we're up to date on the latest changes.
1. **Understand the ask.** If a ticket was provided, read it and its information via the `jira` skill. Otherwise use the user-provided context.
2. **Verify load-bearing premises.** Treat the framing as a hypothesis — even the proposed task itself.
   - Do we even need this?
   - Name the assumptions it depends on (third-party API behavior, schema state, existing-code mitigations) and verify the ones that cross a system boundary.
   - Check project documentation.
   - Collect information from the codebase.
   - Ask the user relevant business or product questions.
3. **Re-state the problem.** Re-state in simple terms based on what you've learned. Confirm with the user to refine.
4. **Pick a solution.** Every problem can be solved multiple ways; the goal is the best one.
   1. Investigate multiple options. Prefer solutions that prevent future mistakes, are self-documenting, and adhere to project architecture and convention — but challenge suboptimal designs and tech debt.
   2. Do online research for best practices and read docs on the relevant tech.
   3. Once you have a recommended solution, ask: "Is this the cleanest fix I can think of? Is this beautiful code I'd be proud of writing?" Iterate.
   4. Verify your recommendation. Your recommendation carries real weight. If a solution feels clean, that's interesting, not authoritative — clean solutions are sometimes right and sometimes training-data echoes (a Stripe-style event ID for a Plaid webhook, a TanStack Query pattern in a `useState` codebase). The verification tells you which. Name the assumption you'd most want a confident answer to, go answer it, and bring back what you found and what you think it means.
   5. Use the [solution template](templates/solution-template.md) to present the recommendation and any considered alternatives.
5. **Propose a tier** per the table above with one-sentence rationale. The user responds with `go` or names the tier they want.
6. **Create the ticket** *(`new take` only — skip if a ticket was provided)*. Use the `jira` skill to capture the scoped problem.
7. **Transition the ticket** to "In Progress" via the `jira` skill.
8. **Enter the worktree.**
   - Call `EnterWorktree` with name `<TICKET>-<tier>` (e.g., `STAX-123-medium`).
   - Verify with `git rev-parse --show-toplevel` that you're inside the worktree.

## Tier sequences

Run the sequence for the confirmed tier. Each step links to its procedure file.

### Small

The parent implements in one pass. No subagents, no plan file.

1. Implement the change(s) directly in the worktree.
2. Add a unit test if applicable and a test suite is set up.
3. Run lint, type checker, and tests on modified files. Fix issues.
4. [Exit](common/exit.md).

### Medium

Parent plans, `worker-agent` subagents implement, parent reviews. The plan must name every file and every step — workers do not make scoping decisions.

1. [Investigate](common/investigate.md)
2. [Plan](common/plan.md)
3. [Present plan](common/plan-presentation.md)
4. [Dispatch workers](common/worker-dispatch.md) — parallel when files are disjoint
5. [Parent review](common/parent-review.md)
6. [Exit](common/exit.md)

### Deep

Architectural or cross-module change. Adds QA planning and an architecture review gate before workers dispatch.

1. [Investigate](common/investigate.md)
2. [Plan](common/plan.md)
3. **QA planning.** Invoke `qa-planner-agent` with the draft plan and the user-facing surfaces it affects (UI, API, CLI). Append the agent's `## QA Plan` section to the plan verbatim.
4. **Architecture review.** Invoke `plan-review-agent` against the draft plan and affected files. Ask for: architecture fit, missing edge cases, risk concentrations. Fix obvious issues; surface judgment calls as `[NEEDS CLARIFICATION]` in the plan.
5. [Present plan](common/plan-presentation.md)
6. [Dispatch workers](common/worker-dispatch.md) — parallel when files are disjoint
7. [Parent review](common/parent-review.md)
8. [Exit](common/exit.md)
