# Task Planner User Guide

Quick reference for using the task-planner skill. This guide walks through a small ticket as an example.

## Prerequisites

- Jira CLI configured (the jira skill handles this)
- Claude Code CLI (`claude`) installed
- Git repository with a remote

## How It Works

```
You (in Cline)          Plan file on disk          Claude Code (in terminal)
     |                       |                            |
     |--- "plan STAX-42" -->|                            |
     |    writes plan ------>|                            |
     |                       |--- launch.zsh reads ------>|
     |                       |    creates worktree        |
     |                       |    executes plan           |
     |                       |                     creates PR
```

Cline plans. Claude Code executes. The plan file is the only bridge.

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

## Branch: STAX-42

## Who You Are

Execute this plan independently without asking questions.
If something is ambiguous, fail loudly with a clear error rather than guessing.

## What to change

- File: `src/auth/messages.ts`
- Line 14: Change "Authenication failed" to "Authentication failed"

## Done when

- The typo is corrected
- No other strings are modified
- Existing tests still pass
```

Cline then tells you the launch command.

### Step 5: Launch Claude Code

In a **separate terminal** (not inside Cline), run:

```bash
~/.cline/skills/task-planner/scripts/launch.zsh --small plans/plan-STAX-42-small.md
```

This does three things:

1. Creates a git worktree at `./wt/STAX-42` on branch `STAX-42`
2. Copies the plan into the worktree
3. Spawns a Claude Code Haiku instance that reads the plan and executes it

### Step 6: Claude Code Executes

The Haiku instance:

1. Reads the plan
2. Makes the change
3. Runs verification (existing tests)
4. Commits with message `fix(auth): correct typo in login error message Refs: STAX-42`
5. Pushes the branch
6. Creates a PR

You get output like:

```
[LAUNCHED] Claude Code running in background (PID: 12345)
Worktree: ./wt/STAX-42
Plan:     ./wt/STAX-42/plans/plan-STAX-42-small.md

Monitor with: ps -p 12345
Kill with:    kill 12345
```

### Step 7: Review the PR

Check the PR on GitHub. If CI passes, merge it.

## Tier Reference

| Tier   | Trigger example       | Planning time | Executor               |
| ------ | --------------------- | ------------- | ---------------------- |
| Small  | `plan STAX-42 small`  | ~2 min        | Single Haiku instance  |
| Medium | `plan STAX-78 medium` | ~10-15 min    | Single Sonnet instance |
| Large  | `plan STAX-112 large` | ~20-30 min    | Opus + Sonnet workers  |

## File Locations

| What            | Where                                                       |
| --------------- | ----------------------------------------------------------- |
| Plans           | `./plans/` in project root (gitignored)                     |
| Worktrees       | `./wt/{TICKET}` in project root (gitignored)                |
| Launcher script | `~/.cline/skills/task-planner/scripts/launch.zsh`           |
| System prompts  | `~/.cline/skills/task-planner/dependencies/system-prompts/` |
| Plan templates  | `~/.cline/skills/task-planner/dependencies/templates/`      |

## Tips

- You can plan multiple tickets in one Cline session, then launch them all in parallel from separate terminals.
- If a Claude Code instance fails, check the worktree for partial work. You can re-run the launcher or fix manually.
- After merging, clean up: `git worktree remove ./wt/STAX-42 && git branch -d STAX-42`
