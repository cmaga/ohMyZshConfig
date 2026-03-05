---
name: automater
description: Parallel worktree orchestration for Jira tickets. Use when asked to implement multiple tickets, sync ticket status, or check automater status.
---

# Automater

Orchestrate Jira ticket lifecycle using git worktrees and Cline CLI sub-agents.

## Step 1: Load configuration

Before routing to a mode, read configuration values from `.cline-project/skills/automater/config.json`. If this file does not exist go directly to step 2. If it does skip to step 3.

```bash
CONFIG_FILE=".cline-project/skills/automater/config.json"
WORKTREE_DIR=$(jq -r '.worktreeDir // "./wt"' "$CONFIG_FILE")
BRANCH_PREFIX=$(jq -r '.branchPrefix // "feature/"' "$CONFIG_FILE")
PR_TARGET=$(jq -r '.prTargetBranch // "develop"' "$CONFIG_FILE")
MAX_PARALLEL=$(jq -r '.maxParallelAgents // 3' "$CONFIG_FILE")
```

Here is a description of the configuration fields for context:

| Field               | Default    | Description               |
| ------------------- | ---------- | ------------------------- |
| `worktreeDir`       | `./wt`     | Directory for worktrees   |
| `prTargetBranch`    | `develop`  | Base branch for PRs       |
| `branchPrefix`      | `feature/` | Branch name prefix        |
| `maxParallelAgents` | 3          | Max concurrent sub-agents |

## Step 2: Setup Configuration

If this file or any fields are missing, ask the user in a conversation way to provide these and once you have the information write the config file. Here is the [default config template](./dependencies/templates/config.json) you can use when writing the file for the first time.

Make sure to also add the worktree path to the project's `.gitignore` if it's not already there:

````bash
echo "${WORKTREE_DIR}/" >> .gitignore

-

## First-Time Setup

Add worktree directory to gitignore:

```bash
echo 'wt/' >> .gitignore
````

## Step 3: Determine Mode

The following modes are available. Parse the user request to determine which mode to execute:

### Modes

| Mode          | Triggers                                      | Action                                       |
| ------------- | --------------------------------------------- | -------------------------------------------- |
| **implement** | "implement PROJ-123", "work on these tickets" | Dispatch sub-agents to implement tickets     |
| **sync**      | "sync", "sweep", "move merged to done"        | Check PR status, transition tickets, cleanup |
| **status**    | "status", "what's in progress"                | Report worktrees, PRs, tickets               |

## Step 4: Execute Mode

Once a mode is determined, follow steps in the corresponding file:

- [implement.md](modes/implement.md)
- [sync.md](modes/sync.md)
- [status.md](modes/status.md)
