# Sync Mode

Synchronize ticket status with PR status. Check merged PRs, transition Jira tickets, cleanup worktrees.

## Steps

### 1. Discover Active Work

Find all automater-managed branches and worktrees:

```bash
# List worktrees
git worktree list --porcelain | grep "worktree ./wt/"

# List feature branches matching pattern
git --no-pager branch -l '{branchPrefix}*' --format='%(refname:short)'
```

Extract ticket keys from branch names (e.g., `feature/PROJ-123-summary` → `PROJ-123`).

### 2. Check PR Status

For each discovered ticket/branch, query PR status using **git-provider skill**:

**GitHub:**

```bash
gh pr list --head {branch} --json number,state,url
```

**Bitbucket:**

```bash
bb pr list --query "source.branch.name=\"{branch}\"" -o json
```

### 3. Process Results

| PR State | Worktree Exists | Action                                                     |
| -------- | --------------- | ---------------------------------------------------------- |
| MERGED   | Yes             | Transition Jira to "Done", remove worktree, report success |
| MERGED   | No              | Transition Jira to "Done", report success                  |
| CLOSED   | Yes             | Flag for review, remove worktree                           |
| CLOSED   | No              | Flag for review                                            |
| OPEN     | Yes             | Leave alone, report as in-progress                         |
| OPEN     | No              | Leave alone (branch pushed, worktree cleaned)              |
| NO PR    | Yes             | Stale worktree - offer to cleanup or resume                |
| NO PR    | No              | Orphan branch - offer to cleanup                           |

### 4. Transition Jira Tickets

For merged PRs, use **jira skill** to transition:

```bash
jira issue move {TICKET-KEY} "Done"
jira issue comment add {TICKET-KEY} -b "PR merged. Ticket completed by automater."
```

### 5. Cleanup Worktrees

Remove worktrees for merged/closed PRs:

```bash
git worktree remove ./wt/{TICKET-KEY}
```

For stale worktrees (no PR), ask user:

- Resume work?
- Delete worktree and branch?
- Leave for manual review?

### 6. Report Summary

```
## Sync Results

### Completed (Merged → Done)
- PROJ-123: PR #42 merged, transitioned to Done
- PROJ-125: PR #43 merged, transitioned to Done

### Closed (Manual Review Needed)
- PROJ-127: PR #45 was closed without merge

### In Progress
- PROJ-124: PR #44 still open

### Stale (No PR Found)
- PROJ-128: Worktree exists but no PR
  Action needed: resume or cleanup

### Orphan Branches
- feature/PROJ-129-old: Branch exists, no worktree, no PR
  Consider: git branch -D feature/PROJ-129-old
```
