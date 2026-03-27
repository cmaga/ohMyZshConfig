# Small Tier Planning

Minimal planning for isolated changes. The ticket description is essentially the plan.

## Critical Rules

- Total interaction should be under 2 minutes for non-UI tickets
- Do not investigate the codebase beyond confirming the file exists
- Do not discuss approach -- confirm and write

## Process

### Step 1: Present Ticket Summary

Show the user:

- Ticket ID and title
- Description (condensed)
- Acceptance criteria

Determine: does this ticket involve UI changes (components, styles, layouts, visual elements)?

---

### Path A: UI Changes (any ticket with visual elements)

If the ticket involves UI changes, implement it directly -- no plan file, no handoff.

#### A1: Create Worktree

Run `create-worktree.zsh` to set up the branch and worktree. Work inside the worktree for all changes.

#### A2: Implement Everything

Make all changes -- UI and logic -- directly in the worktree. Use existing patterns from the codebase.

#### A3: Show the User

Start the dev server and present:

```
Worktree: {path}
Dev server: {URL, e.g. http://localhost:3000/path}

Verify:
- {What to visually check 1}
- {What to visually check 2}
```

Wait for user feedback. Iterate until approved.

#### A4: Finalize

- Commit all changes with a conventional commit referencing the ticket ID
- Push the branch
- Create a PR targeting main

Done. No plan file needed.

---

### Path B: No UI Changes

#### B1: Write Plan

Use the template at [dependencies/templates/plan-small.md](../dependencies/templates/plan-small.md).

Fill in:

- Ticket ID and title from Jira
- Branch name: ticket key (e.g., `STAX-42`)
- What to change: extracted from ticket description
- Done criteria: from acceptance criteria

Write to: `./plans/plan-{TICKET}-small.md`

#### B2: Hand Off

Tell the user:

```
Plan written to plans/plan-{TICKET}-small.md
Launch with: ~/.cline/skills/task-planner/scripts/launch.zsh --small plans/plan-{TICKET}-small.md
```

Move to the next ticket. No review needed unless CI fails.
