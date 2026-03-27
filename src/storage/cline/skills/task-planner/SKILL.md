---
name: task-planner
description: Generate tiered implementation plans for Jira tickets handed off to Claude Code. Use when the user wants to plan a ticket, classify ticket size (small/medium/large), write a plan file for Claude Code execution, or says things like "plan PROJ-123", "work on PROJ-123", "PROJ-123 small". Even when the user just mentions wanting to plan work or prepare a ticket for implementation.
---

# Task Planner

Generate implementation plans consumed by Cline Kanban. Cline plans, Kanban executes.

## Critical Rules

- **Never switch to act mode for implementation.** Output is always a plan file on disk.
- **Never auto-classify tickets.** The user decides small, medium, or large.
- **Plans are implementation-focused.** No Jira transitions, no devops, no PR creation, no worktree management. Focus on what code changes need to happen and how.
- **Cards are the unit of work.** Every plan describes one or more cards. Each card becomes an isolated task in Kanban with its own worktree. Cards run in parallel unless linked by dependencies.
- **Always ask about UI prototyping.** If the ticket involves any UI changes (components, styles, layouts, visual elements), ask the user if these should be prototyped as an interactive card.

## Setup

```bash
grep -q "^plans/" .gitignore || echo "plans/" >> .gitignore
mkdir -p plans
```

## Step 1: Extract Ticket

Parse the ticket ID from user input (pattern: `[A-Z]+-\d+`). Fetch ticket details using the Jira skill.

If no ticket ID provided, ask for one.

## Step 2: Classify Tier

Ask the user to classify the ticket:

| Tier       | When                                      | Planning depth                   |
| ---------- | ----------------------------------------- | -------------------------------- |
| **Small**  | Bug fix, config, typo, isolated change    | Minimal — ticket is the plan     |
| **Medium** | New feature, moderate refactor, 2-5 files | Steps, files, constraints, tests |
| **Large**  | Architectural, multi-module, 5+ files     | Full plan + review gate          |

If user provides tier in initial message (e.g., "STAX-42 small"), skip this step.

## Step 3: Route to Mode

- Small: read [modes/small.md](modes/small.md)
- Medium: read [modes/medium.md](modes/medium.md)
- Large: read [modes/large.md](modes/large.md)

## Plan Output

Plans are written to `./plans/` in the project root:

```
plans/plan-STAX-42-small.md
plans/plan-STAX-78-medium.md
plans/plan-STAX-112-large.md
```

## Card Strategy Concepts

Plans describe work as **cards** — isolated units of work that Kanban picks up. The downstream card creation system reads natural language, so write cards clearly.

### Card Types

- **Autonomous**: runs without human interaction. The executor reads the card instructions and implements.
- **Interactive (requires human review)**: the executor scaffolds something (usually UI), then waits for user feedback. The user may take over the session to iterate.

### Dependency Chains

Cards can be linked so one blocks another. When Card B depends on Card A's output:

- Card A must complete before Card B starts
- Card B's instructions should reference Card A's actual output (read the files) rather than assuming exact names/structure
- This enables fully autonomous chains where one task's output feeds into the next

### Cross-Ticket Dependencies

If this ticket's work depends on cards from another ticket, note it in the plan. The card creation system can link across tickets.

## Post-Completion

When the task using this skill is complete, ask the user:
"How did that go? Anything that worked well or needs improvement?"

If the user provides feedback, append a `type: feedback` entry to `evals/evals.yaml` in this skill's directory.
