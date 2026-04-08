# Medium Tier Planning

Collaborative planning for features and moderate refactors. You and the user agree on the approach, then you write a detailed plan.

## Critical Rules

- Investigate before discussing. Read files first, talk second.
- The plan must be detailed enough that an executor implements without asking questions.
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

**If confidence = 10**: Proceed to the next step.

### Step 3: Check for UI Changes

If the ticket involves any UI changes (components, styles, layouts, visual elements):

Ask the user: "This ticket involves UI changes ({list what}). Should these be prototyped as an interactive card?"

- **If yes**: The plan will split into an interactive prototype card (Card 1) and follow-up cards for wiring/backend/tests. Card 2+ are blocked by Card 1 and must read Card 1's actual output files rather than assuming component structure.
- **If no**: UI changes are described textually in a normal autonomous card.

If no UI changes, skip this step.

### Step 4: Write Plan

Use the template at [dependencies/templates/plan-medium.md](../dependencies/templates/plan-medium.md).

The plan must include:

- Context: what and why (2-3 sentences)
- Card strategy: how to split into cards with dependency links
- Per card: files to touch, implementation steps, constraints, test expectations
- Done criteria: verifiable conditions

Write to: `.claude/skills/task-planner/plans/plan-{TICKET}-medium.md`

### Step 5: Done

Tell the user:

```
Plan written to .claude/skills/task-planner/plans/plan-{TICKET}-medium.md
```
