# Small Tier Planning

Minimal planning for isolated changes. The ticket description is essentially the plan.

## Critical Rules

- Total interaction should be under 2 minutes for non-UI tickets
- Do not investigate the codebase beyond confirming the file exists
- Do not discuss approach — confirm and write

## Process

### Step 1: Present Ticket Summary

Show the user:

- Ticket ID and title
- Description (condensed)
- Acceptance criteria

### Step 2: Check for UI Changes

If the ticket involves any UI changes (components, styles, layouts, visual elements):

Ask the user: "This ticket involves UI changes ({list what}). Should these be prototyped as an interactive card?"

- **If yes**: The plan will have 2 cards — an interactive prototype card and a follow-up wiring card (see template)
- **If no**: The plan will have 1 autonomous card with the UI changes described textually

If no UI changes, skip this step.

### Step 3: Write Plan

Use the template at [dependencies/templates/plan-small.md](../dependencies/templates/plan-small.md).

Fill in:

- Ticket ID and title from Jira
- What to change: extracted from ticket description
- Done criteria: from acceptance criteria
- Card strategy: single card (or 2 cards if UI prototyping)

Write to: `./plans/plan-{TICKET}-small.md`

### Step 4: Done

Tell the user:

```
Plan written to plans/plan-{TICKET}-small.md
```

Move to the next ticket.
