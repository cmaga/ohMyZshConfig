---
name: plan-for-teams
description: Generate structured implementation plans for Claude Code Agent Teams handoff. Use when the user asks to create a team plan, hand off to Claude Code, set up an agent team, create a plan for parallel implementation, or delegate implementation to Claude Code Agent Teams. Even when the user just says "let's hand this off", "create a team for this", "write a plan for this", or "set up agents to build this", this skill applies.
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

This skill uses two categories of agents at different stages:

### Cline Subagents (used during plan creation)

These are Cline Agent Configs (`~/Documents/Cline/Agents/*.yaml`) invoked as
`use_subagent_*` tools during Step 3 of the workflow. They review the draft
plan before it is finalized and handed off.

| Agent              | Tool                             | Purpose                                              |
| ------------------ | -------------------------------- | ---------------------------------------------------- |
| Security Reviewer  | `use_subagent_security-reviewer` | Identifies auth gaps, injection risks, data exposure |
| Tech Lead Reviewer | `use_subagent_techlead-reviewer` | Validates patterns, architecture, tech debt risks    |

### Claude Code Team Agents (embedded in the output plan)

These agent personas are written into the generated plan file. Claude Code's
lead agent uses them as spawn prompts for its team members.

| Agent       | File                                           | Purpose                           |
| ----------- | ---------------------------------------------- | --------------------------------- |
| Implementer | [agents/implementer.md](agents/implementer.md) | TDD-first implementation of tasks |
| Reviewer    | [agents/reviewer.md](agents/reviewer.md)       | Final review and validation       |

## Templates

| Size   | Template                                   |
| ------ | ------------------------------------------ |
| Small  | [templates/small.md](templates/small.md)   |
| Medium | [templates/medium.md](templates/medium.md) |
| Large  | [templates/large.md](templates/large.md)   |

## Custom Agents

For projects with specialized domains (CLI tools, infrastructure, data pipelines,
ML), construct a custom implementer persona using `agents/implementer.md` as the
base template. Add domain-specific conventions and verification commands. The key
structure to preserve: role, TDD execution order, file ownership, contracts,
verification, self-sufficiency rules, and completion message format.

To add new Cline review subagents, create Agent Config YAML files in
`~/Documents/Cline/Agents/` following the pattern in the existing
`security-reviewer.yaml` and `techlead-reviewer.yaml`.

## Critical Rules

See [docs/critical-rules.md](docs/critical-rules.md) before generating any plan.

## Post-Completion

When the plan has been generated and handed off, ask the user:
"How did that go? After Claude Code finishes executing the plan, let me know
what worked well or needs improvement."

If the user provides feedback, append a feedback entry to `evals/evals.yaml`:

```yaml
- type: feedback
  id: [next sequential integer]
  date: [YYYY-MM-DD]
  task: [brief description of the plan that was generated]
  worked:
    - [what went well]
  issues:
    - [what went wrong or could be better]
  severity: low|medium|high
```
