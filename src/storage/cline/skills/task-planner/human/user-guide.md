# Task Planner User Guide

Quick reference for using the task-planner skill.

## Prerequisites

- Jira CLI configured (the jira skill handles this)
- Cline Kanban set up for your project
- Git repository with a remote

## How It Works

```
You (in Cline)          Plan file on disk          Cline Kanban
     |                       |                         |
     |--- "plan STAX-42" -->|                         |
     |    writes plan ------>|                         |
     |                       |--- cards created ------>|
     |                       |    worktrees created    |
     |                       |    tasks run parallel   |
     |                       |                   creates PR
```

Cline plans. Kanban executes. The plan file is the only bridge.

## Example: Small Ticket

### Step 1: Trigger the Skill

In Cline, say:

```
plan STAX-42 small
```

Or just say `plan STAX-42` and Cline will ask you to classify the tier.

### Step 2: Cline Fetches and Presents the Ticket

Cline reads the Jira ticket and shows you:

```
STAX-42: Fix typo in login error message

Description: The login page shows "Authenication failed" instead of
"Authentication failed" in src/auth/messages.ts line 14.

Acceptance criteria:
- Typo is fixed
- No other strings are modified

This looks like a small ticket. Confirm and I'll write the plan?
```

### Step 3: Confirm

You say: "yes" (or "looks good", "go", etc.)

### Step 4: Cline Writes the Plan

Cline creates `plans/plan-STAX-42-small.md` in your project root:

```markdown
# STAX-42: Fix typo in login error message

## Size: small

## Context

Fix a typo in the login error message string.

## Card Strategy

### Card 1: Fix login error typo

- **Type**: autonomous
- **Scope**: Correct "Authenication" to "Authentication" in error messages
- **Files**: `src/auth/messages.ts`
- **What to change**: Line 14 — change "Authenication failed" to "Authentication failed"
- **Done when**:
  - The typo is corrected
  - No other strings are modified
  - Existing tests still pass
```

### Step 5: Done

The plan is on disk. Kanban picks it up, creates a card, sets up a worktree, and executes it. You move to the next ticket.

## UI Prototyping

If a ticket involves UI changes, Cline will ask:

```
This ticket involves UI changes (new dashboard page, stats cards).
Should these be prototyped as an interactive card?
```

If you say **yes**, the plan splits into:

- **Card 1 (interactive)**: Scaffold UI with mock data. You review in the dev server and iterate.
- **Card 2 (autonomous)**: Wire real data, add tests. Blocked by Card 1. Reads Card 1's actual output files.

If you say **no**, the UI changes are described textually in a normal autonomous card.

## Tier Reference

| Tier   | Trigger example       | Planning time | What Cline does                 |
| ------ | --------------------- | ------------- | ------------------------------- |
| Small  | `plan STAX-42 small`  | ~2 min        | Confirm and write               |
| Medium | `plan STAX-78 medium` | ~10-15 min    | Investigate, discuss, write     |
| Large  | `plan STAX-112 large` | ~20-30 min    | Deep investigation, review gate |

## File Locations

| What           | Where                                                  |
| -------------- | ------------------------------------------------------ |
| Plans          | `./plans/` in project root (gitignored)                |
| Plan templates | `~/.cline/skills/task-planner/dependencies/templates/` |
| Mode docs      | `~/.cline/skills/task-planner/modes/`                  |

## Card Concepts

### Card Types

- **Autonomous**: runs without human interaction
- **Interactive**: requires human review (typically UI prototyping)

### Dependency Chains

Cards can be linked so one blocks another. The plan specifies this with "Blocked by" fields. Kanban handles the sequencing — when Card 1 completes, Card 2 starts automatically.

### Cross-Ticket Dependencies

If ticket B depends on work from ticket A, the plan notes this. Kanban can link cards across tickets.

## Tips

- Plan multiple tickets in one Cline session. Each plan kicks off independently in Kanban.
- For medium/large tickets, the confidence loop (1-10 score) ensures the plan is solid before writing.
- Large tickets get a review gate — security and architecture subagents vet the plan before finalization.
