# Medium Tier Planning

Collaborative planning for features and moderate refactors. You and the user agree on the approach, then you write a detailed plan.

## Critical Rules

- Investigate before discussing. Read files first, talk second.
- The plan must be detailed enough that a Sonnet worker executes without asking questions.
- Examples over descriptions -- reference `src/path/to/example.ts`, not "RESTful conventions."

## Process

### Step 1: Investigate

Gather context silently using terminal commands and `read_file`:

- Read the ticket description and acceptance criteria
- Identify affected files by scanning the codebase (grep, list_files)
- Read those files to understand current patterns
- Note existing test patterns and conventions

### Step 2: Discuss Approach

Present your understanding to the user:

1. Affected files and modules
2. Proposed approach (high-level)
3. Key decisions or trade-offs
4. Confidence score (1-10)

**If confidence < 10**: Ask targeted questions about what's unclear. Bundle questions. Loop until 10/10.

**If confidence = 10**: Proceed to the next step.

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

The plan written in the next step will only cover the remaining deterministic work (wiring real data, API calls, business logic, tests). The UI is already done.

If the ticket has no UI changes, skip this step.

### Step 4: Write Plan

Use the template at [dependencies/templates/plan-medium.md](../dependencies/templates/plan-medium.md).

The plan must include:

- Context: what and why (2-3 sentences)
- Files to touch: exact paths with actions
- Steps: numbered, ordered, each with clear deliverable
- Constraints: files/patterns not to touch, dependencies not to add
- Test expectations: specific test scenarios with expected outcomes
- Done criteria: verifiable conditions
- **Pre-existing UI section** (if Step 3 was done): list files already committed in the worktree that the implementer should not recreate

Write to: `./plans/plan-{TICKET}-medium.md`

### Step 5: Hand Off

Tell the user:

```
Plan written to plans/plan-{TICKET}-medium.md
Launch with: ~/.cline/skills/task-planner/scripts/launch.zsh --medium plans/plan-{TICKET}-medium.md
```

User reviews the PR asynchronously when ready. The plan should be good enough that the executor fixes its own bugs -- review is for feel, not correctness.
