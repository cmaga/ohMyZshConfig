# Medium Tier Planning

Collaborative planning for features and moderate refactors. You and the user agree on the approach, then you write a detailed plan.

## Critical Rules

- Investigate before discussing. Read files first, talk second.
- The plan must be detailed enough that a Sonnet worker executes without asking questions.
- Examples over descriptions — reference `src/path/to/example.ts`, not "RESTful conventions."

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

**If confidence = 10**: Proceed to writing the plan.

### Step 3: Write Plan

Use the template at [dependencies/templates/plan-medium.md](../dependencies/templates/plan-medium.md).

The plan must include:

- Context: what and why (2-3 sentences)
- Files to touch: exact paths with actions
- Steps: numbered, ordered, each with clear deliverable
- Constraints: files/patterns not to touch, dependencies not to add
- Test expectations: specific test scenarios with expected outcomes
- Done criteria: verifiable conditions

Write to: `./plans/plan-{TICKET}-medium.md`

### Step 4: Hand Off

Tell the user:

```
Plan written to plans/plan-{TICKET}-medium.md
Launch with: ~/.cline/skills/task-planner/scripts/launch.zsh --medium plans/plan-{TICKET}-medium.md
```

User reviews the PR asynchronously when ready. The plan should be good enough that the executor fixes its own bugs — review is for feel, not correctness.
