---
name: task-planner
description: Generate tiered implementation plans for Jira tickets handed off to Claude Code. Use when the user wants to plan a ticket, classify ticket size (small/medium/large), write a plan file for Claude Code execution, or says things like "plan PROJ-123", "work on PROJ-123", "PROJ-123 small". Even when the user just mentions wanting to plan work or prepare a ticket for implementation.
---

# Task Planner

Generate implementation plans consumed by Claude Code instances. Cline plans, Claude Code executes.

## Critical Rules

- **Never switch to act mode for implementation.** Output is always a plan file on disk.
- **Never auto-classify tickets.** The user decides small, medium, or large.
- The plan file is the only bridge between Cline and Claude Code. It must be self-contained.

## Setup

```bash
grep -q "^plans/" .gitignore || echo "plans/" >> .gitignore
grep -q "^./wt/" .gitignore || echo "./wt/" >> .gitignore
mkdir -p plans
```

## Step 1: Extract Ticket

Parse the ticket ID from user input (pattern: `[A-Z]+-\d+`). Fetch ticket details using the Jira skill.

If no ticket ID provided, ask for one.

## Step 2: Classify Tier

Ask the user to classify the ticket:

| Tier       | When                                      | Planning depth                   | Executor                           |
| ---------- | ----------------------------------------- | -------------------------------- | ---------------------------------- |
| **Small**  | Bug fix, config, typo, isolated change    | Minimal — ticket is the plan     | Single Haiku instance              |
| **Medium** | New feature, moderate refactor, 2-5 files | Steps, files, constraints, tests | Single Sonnet instance             |
| **Large**  | Architectural, multi-module, 5+ files     | Full plan + review gate          | Opus orchestrator + Sonnet workers |

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

## Launching Execution

After writing the plan, tell the user to run the launcher in a separate terminal:

```bash
# From project root:
./path/to/launch.zsh --small plans/plan-STAX-42-small.md
./path/to/launch.zsh --medium plans/plan-STAX-78-medium.md
./path/to/launch.zsh --large plans/plan-STAX-112-large.md
```

The global script location: `~/.cline/skills/task-planner/scripts/launch.zsh`

## Post-Completion

When the task using this skill is complete, ask the user:
"How did that go? Anything that worked well or needs improvement?"

If the user provides feedback, append a `type: feedback` entry to `evals/evals.yaml` in this skill's directory.
