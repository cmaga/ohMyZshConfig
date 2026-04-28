# Medium Tier

Features and moderate refactors. Parent plans, `worker-agent` subagents implement, parent reviews.

## Critical Rules

- Investigate before planning. Read affected files, not just the ticket.
- The plan must name every file and every step. Workers do not make scoping decisions.
- Workers run in parallel when their tasks do not share files.
- Test-planning is inline by the parent. No QA planner in this tier.

## Process

### 1. Investigate

- Read the ticket and acceptance criteria.
- Identify affected files — search symbols, read neighbors.
- Read similar existing implementations for pattern reference.

### 2. Write the plan

Write `.claude-artifacts/dev-workflow/plan.md` inside the worktree using [../templates/plan-template.md](../templates/plan-template.md) as the structure. Target 50-150 lines.

The intent header (Objective, Outcomes, Out of scope, Autonomy, Stop rules) is the contract with workers. The mechanics (Files, Tasks, Tests) are the execution plan.

- Number outcomes (`O-1`, `O-2`, …). Each task card cites the outcome IDs it satisfies.
- Mark unresolved ambiguity inline as `[NEEDS CLARIFICATION: ...]`. Grep the plan for it and resolve every hit with the user before dispatching.

Present the plan to the user and wait for approval before dispatching.

### 3. Dispatch workers

- One `worker-agent` per task.
- Run workers in parallel when their tasks touch disjoint files.
- Pass each worker its task card inline (the T-N block from the plan), not the whole plan. The worker can read `plan.md` if it needs to disambiguate.

### 4. Parent review and tests

After every worker reports done:

- Read each worker's diff.
- Verify pattern adherence named in the plan.
- Write the unit and programmatic tests from the plan's test section.
- Run the test suite. Fix failures.
- Run the build. Fix failures.

### 5. Route to the shared exit in [../SKILL.md](../SKILL.md).
