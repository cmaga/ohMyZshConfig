# Small Tier Planning

Minimal planning for isolated changes. The ticket description is essentially the plan.

## Critical Rules

- Total interaction should be under 2 minutes
- Do not investigate the codebase beyond confirming the file exists
- Do not discuss approach — confirm and write

## Process

### Step 1: Present Ticket Summary

Show the user:

- Ticket ID and title
- Description (condensed)
- Acceptance criteria

Ask: "This looks like a small ticket. Confirm and I'll write the plan?"

### Step 2: Write Plan

Use the template at [dependencies/templates/plan-small.md](../dependencies/templates/plan-small.md).

Fill in:

- Ticket ID and title from Jira
- Branch name: ticket key (e.g., `STAX-42`)
- What to change: extracted from ticket description
- Done criteria: from acceptance criteria

Write to: `./plans/plan-{TICKET}-small.md`

### Step 3: Hand Off

Tell the user:

```
Plan written to plans/plan-{TICKET}-small.md
Launch with: ~/.cline/skills/task-planner/scripts/launch.zsh --small plans/plan-{TICKET}-small.md
```

Move to the next ticket. No review needed unless CI fails.
