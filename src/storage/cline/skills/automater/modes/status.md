# Status Mode

Report current state of automater-managed work: worktrees, branches, PRs, and Jira tickets.

## Steps

### 1. Gather Information

**Worktrees:**

```bash
git worktree list --porcelain | grep "worktree ./wt/"
```

**Feature branches:**

```bash
git --no-pager branch -l '{branchPrefix}*' --format='%(refname:short)'
```

**Extract ticket keys** from branch names (e.g., `feature/PROJ-123-summary` → `PROJ-123`).

### 2. Query PR Status

For each discovered branch, check PR status using **git-provider skill**.

### 3. Query Jira Status

For each ticket key, fetch current status using **jira skill**:

```bash
jira issue view {TICKET-KEY} --plain
```

### 4. Build Status Report

Categorize by state:

| Category      | Criteria                            |
| ------------- | ----------------------------------- |
| **Active**    | Worktree exists, work in progress   |
| **In Review** | PR open, waiting for review         |
| **Merged**    | PR merged, Jira may need sync       |
| **Blocked**   | Has unresolved dependencies         |
| **Stale**     | No recent activity, needs attention |

### 5. Report

```
## Automater Status

### Active Worktrees
| Ticket | Branch | Last Commit | Has PR |
|--------|--------|-------------|--------|
| PROJ-123 | feature/PROJ-123-login | 2h ago | No |
| PROJ-124 | feature/PROJ-124-api | 1d ago | Yes (#42) |

### Open PRs
| Ticket | PR | Status | Reviews |
|--------|-----|--------|---------|
| PROJ-124 | #42 | Open | 1/2 approved |
| PROJ-125 | #43 | Changes requested | 0/2 |

### Pending Sync (Merged but Jira not Done)
- PROJ-126: PR #40 merged, Jira status: "In Review"
  → Run sync to transition to Done

### Summary
- 2 active worktrees
- 2 open PRs
- 1 pending Jira sync
- 0 blocked tickets
```
