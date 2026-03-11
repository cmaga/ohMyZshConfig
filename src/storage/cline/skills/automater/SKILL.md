---
name: automater
description: Parallel worktree orchestration for Jira tickets. Use when asked to implement multiple tickets, sync ticket status, or check automater status.
---

# Automater

Orchestrate Jira ticket implementation using git worktrees and Cline CLI parallel instances.

## Step 1: Load Configuration

Read configuration from `.cline-project/skills/automater/config.json`. If this file does not exist, proceed to Step 2. Otherwise, skip to Step 3.

```bash
CONFIG_FILE=".cline-project/skills/automater/config.json"
WORKTREE_DIR=$(jq -r '.worktreeDir // "./wt"' "$CONFIG_FILE")
PLAN_DIR=$(jq -r '.planDir // ".cline-project/skills/automater/plans"' "$CONFIG_FILE")
BRANCH_PREFIX=$(jq -r '.branchPrefix // "feature/"' "$CONFIG_FILE")
PR_TARGET=$(jq -r '.prTargetBranch // "develop"' "$CONFIG_FILE")
MAX_PARALLEL=$(jq -r '.maxParallelInstances // 3' "$CONFIG_FILE")
```

| Field                  | Default                                 | Description                        |
| ---------------------- | --------------------------------------- | ---------------------------------- |
| `worktreeDir`          | `./wt`                                  | Directory for worktrees            |
| `planDir`              | `.cline-project/skills/automater/plans` | Directory for implementation plans |
| `prTargetBranch`       | `develop`                               | Base branch for PRs                |
| `branchPrefix`         | `feature/`                              | Branch name prefix                 |
| `maxParallelInstances` | 3                                       | Max concurrent CLI instances       |

## Step 2: Setup Configuration

If the config file is missing, ask the user conversationally for these values and write the config file using the [default config template](./dependencies/templates/config.json).

Ensure the worktree directory is in `.gitignore`:

```bash
grep -q "^${WORKTREE_DIR}/" .gitignore || echo "${WORKTREE_DIR}/" >> .gitignore
```

Create the plans directory:

```bash
mkdir -p "${PLAN_DIR}"
```

## Step 3: Determine Mode

Parse the user's request to determine which mode to execute:

| Mode            | Triggers                                                        | Action                                       |
| --------------- | --------------------------------------------------------------- | -------------------------------------------- |
| **design**      | "design PROJ-123", "create plan for...", "plan implementation"  | Create an implementation plan for a ticket   |
| **orchestrate** | "implement PROJ-123", "execute plan", "run plan", "orchestrate" | Orchestrate CLI instances to implement plans |
| **cleanup**     | "cleanup", "sweep", "remove merged worktrees"                   | Clean up worktrees for merged PRs            |

## Step 4: Execute Mode

Follow the instructions in the corresponding mode file:

- [design.md](modes/design.md) - Create implementation plans
- [orchestrate.md](modes/orchestrate.md) - Orchestrate CLI instances to implement plans
- [cleanup.md](modes/cleanup.md) - Clean up merged worktrees
