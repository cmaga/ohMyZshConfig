---
name: automater
description: Parallel worktree orchestration for Jira tickets. Use when asked to implement multiple tickets, sync ticket status, or check automater status.
---

# Automater

Orchestrate Jira ticket implementation using git worktrees and Cline CLI parallel instances.

## Step 1: Ensure Setup

Ensure the worktree directory is in `.gitignore`:

```bash
grep -q "^./wt/" .gitignore || echo "./wt/" >> .gitignore
```

Create the plans directory if it doesn't exist:

```bash
mkdir -p ".cline-project/skills/automater/plans"
```

## Step 2: Determine Mode

Parse the user's request to determine which mode to execute:

| Mode            | Triggers                                                        | Action                                       |
| --------------- | --------------------------------------------------------------- | -------------------------------------------- |
| **design**      | "design PROJ-123", "create plan for...", "plan implementation"  | Create an implementation plan for a ticket   |
| **orchestrate** | "implement PROJ-123", "execute plan", "run plan", "orchestrate" | Orchestrate CLI instances to implement plans |
| **cleanup**     | "cleanup", "sweep", "remove merged worktrees"                   | Clean up worktrees for merged PRs            |

## Step 3: Execute Mode

Follow the instructions in the corresponding mode file:

- [design.md](modes/design.md) - Create implementation plans
- [orchestrate.md](modes/orchestrate.md) - Orchestrate CLI instances to implement plans
- [cleanup.md](modes/cleanup.md) - Clean up merged worktrees

## Configuration

All values are hardcoded for simplicity:

| Setting            | Value                                   |
| ------------------ | --------------------------------------- |
| Worktree directory | `./wt`                                  |
| Plan directory     | `.cline-project/skills/automater/plans` |
| PR target branch   | `develop`                               |
| Branch naming      | Ticket key only (e.g., `STAX-444`)      |
| Max parallel       | 3                                       |
