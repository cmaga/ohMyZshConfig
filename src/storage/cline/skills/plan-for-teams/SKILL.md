---
name: plan-for-teams
description: Generate structured implementation plans for Claude Code Agent Teams handoff. Use when the user asks to create a team plan.
---

# Plan for Teams — Agent Teams Handoff Skill

You produce structured implementation plans that a Claude Code Agent Teams lead
can execute autonomously. The user has been co-planning with you (Cline) and is
ready to hand off to Claude Code for implementation.

## Your Role

You are a plan writer. You take everything discussed in the current conversation
and distill it into a single markdown file to be pasted directly into Claude Code
as a prompt to kick off an Agent Team. The plan must be **self-contained** — the
Claude Code lead has zero context from this conversation.

## Workflow

Read and follow the full 8-step workflow: [docs/workflow.md](docs/workflow.md)

| Step | Action                                         | Output                      |
| ---- | ---------------------------------------------- | --------------------------- |
| 1    | Extract decisions from conversation            | Decisions list              |
| 2    | Classify size (S/M/L) and confirm with user    | Size + justification        |
| 3    | Select agents from `agents/`                   | Agent roster                |
| 4    | Build dependency graph                         | Wave-based task ordering    |
| 5    | Define contracts between waves                 | Inter-wave handoff specs    |
| 6    | Write validation commands                      | Verification per task       |
| 7    | Generate plan using template from `templates/` | `.claude/plans/<slug>.md`   |
| 8    | Provide handoff instructions                   | User prompt for Claude Code |

## Agents

| Agent               | File                                                           |
| ------------------- | -------------------------------------------------------------- |
| Backend Engineer    | [agents/backend-engineer.md](agents/backend-engineer.md)       |
| Database Engineer   | [agents/database-engineer.md](agents/database-engineer.md)     |
| Frontend Specialist | [agents/frontend-specialist.md](agents/frontend-specialist.md) |
| Implementer         | [agents/implementer.md](agents/implementer.md)                 |
| Reviewer            | [agents/reviewer.md](agents/reviewer.md)                       |
| Test Engineer       | [agents/test-engineer.md](agents/test-engineer.md)             |

## Templates

| Size   | Template                                   |
| ------ | ------------------------------------------ |
| Small  | [templates/small.md](templates/small.md)   |
| Medium | [templates/medium.md](templates/medium.md) |
| Large  | [templates/large.md](templates/large.md)   |

## Critical Rules

See [docs/critical-rules.md](docs/critical-rules.md) before generating any plan.
