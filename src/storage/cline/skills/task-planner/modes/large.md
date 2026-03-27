# Large Tier Planning

Deep planning with review gate for architectural changes. The extra review step reduces the "last 10%" of manual fixing after execution.

## Critical Rules

- Investigate thoroughly. Read every file the plan will touch.
- The draft plan goes through review agents before finalization.
- The final plan must include sub-tasks with dependency ordering for parallel execution.

## Process

### Step 1: Deep Investigation

Gather comprehensive context:

- Read ticket description, acceptance criteria, and comments
- Map all affected modules and their dependencies
- Read existing patterns for similar features in the codebase
- Identify test conventions, fixture patterns, mock strategies
- Note architectural boundaries (what must NOT change)

### Step 2: Collaborative Design

Work with the user to reach full understanding:

1. Present affected modules and cross-cutting concerns
2. Propose architecture approach with trade-offs
3. Identify sub-task boundaries and dependency ordering
4. Discuss edge cases and error handling strategy
5. Confidence score (1-10)

**If confidence < 10**: Ask specific questions. Offer your best guess for the user to confirm or correct. Loop until 10/10.

### Step 3: UI Scaffolding (if applicable)

If the ticket involves UI changes (components, styles, layouts, visual elements):

1. **Create worktree early** -- run `create-worktree.zsh` now, before writing the plan.
2. **Scaffold UI components** in the worktree with mock/hardcoded data. Follow existing patterns.
3. **Start the dev server** and present:

```
Worktree: {path}
Dev server: {URL, e.g. http://localhost:3000/path}

Verify:
- {What to visually check 1}
- {What to visually check 2}
```

4. **Iterate** with the user until they approve the UI look and feel.
5. **Commit** the approved UI work to the branch in the worktree.

The plan written in subsequent steps will only cover the remaining deterministic work (wiring real data, API calls, business logic, tests). The UI is already done.

If the ticket has no UI changes, skip this step.

### Step 4: Write Draft Plan

Use the template at [dependencies/templates/plan-large.md](../dependencies/templates/plan-large.md).

Write a complete draft including sub-tasks, dependencies, test matrix, and boundaries.

If Step 3 was done, include a **Pre-existing UI** section listing files already committed in the worktree.

### Step 5: Review Gate

Run review sub-agents against the draft plan:

1. **Security review** -- invoke the `security-reviewer` sub-agent with the draft plan and affected files
2. **Architecture review** -- invoke the `techlead-reviewer` sub-agent with the draft plan and affected files (include edge case analysis in the prompt)

Present each reviewer's findings to the user. The user can accept, adjust, or override each recommendation.

### Step 6: Finalize Plan

Incorporate approved review feedback into the plan. Write the final version to: `./plans/plan-{TICKET}-large.md`

The plan must include:

- Architectural context with file references
- Sub-tasks with files, steps, and verification commands per task
- Dependency ordering (which sub-tasks can run in parallel)
- Edge cases from review (with expected behavior)
- Test matrix mapping scenarios to expected outcomes
- Boundaries: files and modules explicitly off-limits
- Done criteria with verification commands
- **Pre-existing UI section** (if Step 3 was done): list files already committed in the worktree that workers should not recreate

### Step 7: Hand Off

Tell the user:

```
Plan written to plans/plan-{TICKET}-large.md
Launch with: ~/.cline/skills/task-planner/scripts/launch.zsh --large plans/plan-{TICKET}-large.md
```

The Opus orchestrator reads the plan, spawns Sonnet workers per sub-task, manages dependencies, and creates the PR. User reviews when ready.
