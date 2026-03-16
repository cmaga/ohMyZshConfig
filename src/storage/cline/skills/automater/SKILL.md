---
name: automater
description: Parallel worktree orchestration for Jira tickets. Use when asked to implement multiple tickets, sync ticket status, or check automater status.
---

# Automater

Orchestrate Jira ticket implementation using git worktrees and Cline CLI.

## Setup

```bash
grep -q "^./wt/" .gitignore || echo "./wt/" >> .gitignore
mkdir -p ".cline-project/skills/automater/plans"
```

## Mode Selection

| Mode            | Triggers                                    | Output                                       |
| --------------- | ------------------------------------------- | -------------------------------------------- |
| **design**      | "design PROJ-123", "plan implementation"    | `.cline-project/skills/automater/plans/*.md` |
| **orchestrate** | "implement PROJ-123", "execute plan", "run" | `./wt/<TICKET>` worktrees + CLI instances    |
| **cleanup**     | "cleanup", "sweep", "remove merged"         | Removes merged worktrees, syncs Jira         |

## Mode Instructions

- [design.md](modes/design.md) — Create implementation plans
- [orchestrate.md](modes/orchestrate.md) — Execute plans via CLI
- [cleanup.md](modes/cleanup.md) — Clean up merged worktrees

## Configuration

| Setting      | Value                                   |
| ------------ | --------------------------------------- |
| Worktrees    | `./wt/<TICKET-KEY>`                     |
| Plans        | `.cline-project/skills/automater/plans` |
| PR target    | `main`                                  |
| Max parallel | 3                                       |
