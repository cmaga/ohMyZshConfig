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

Write `.claude-artifacts/dev-workflow/plan.md` inside the worktree. Required sections:

- **Context** — what and why, 2-3 sentences
- **Files** — exhaustive list of paths to modify
- **Tasks** — numbered. Each has: scope, files, steps, constraints, done criteria
- **Tests** — unit and programmatic tests the parent will add inline after workers finish

Present the plan to the user and wait for approval before dispatching.

### 3. Dispatch workers

- One `worker-agent` per task.
- Run workers in parallel when their tasks touch disjoint files.
- Give each worker only its task section from the plan, not the whole plan.

### 4. Parent review and tests

After every worker reports done:

- Read each worker's diff.
- Verify pattern adherence named in the plan.
- Write the unit and programmatic tests from the plan's test section.
- Run the test suite. Fix failures.
- Run the build. Fix failures.

### 5. Route to the shared exit in [../SKILL.md](../SKILL.md).
