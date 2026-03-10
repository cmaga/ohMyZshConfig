# Cleanup Mode

Clean up worktrees for merged PRs and synchronize Jira ticket status.

## Process

### Step 1: Discover Active Worktrees

List all automater-managed worktrees:

```bash
git worktree list --porcelain | grep "worktree ${WORKTREE_DIR}/"
```

Extract ticket keys from worktree paths (e.g., `./wt/PROJ-123` → `PROJ-123`).

### Step 2: Check PR Status

For each discovered ticket, query PR status using the git-provider skill.

### Step 3: Process Results

| PR State      | Worktree Exists | Action                                     |
| ------------- | --------------- | ------------------------------------------ |
| MERGED/CLOSED | Yes             | Transition Jira to "Done", remove worktree |
| OPEN          | Yes             | Ensure ticket is "In Review"               |
| NO PR         | Yes             | Stale - ask user to resume or cleanup      |

Determine actions based on the PR state above. Then proceed to use the jira skill for ticket actions and remove worktrees if needed.

### Step 4: Report Summary

Create a summary once clean up is complete. Below is an example:

```markdown
## Cleanup Results

### Completed/Closed

- PROJ-123: PR #42 merged, transitioned to Done, worktree removed
- PROJ-125: PR #43 merged, transitioned to Done, worktree removed

### Still In Review

- PROJ-124: PR #44 still open, worktree preserved

### Stale (No PR)

- PROJ-128: Worktree exists but no PR found user stated (WIP/STALE), work tree (PRESERVED/REMOVED)
```
