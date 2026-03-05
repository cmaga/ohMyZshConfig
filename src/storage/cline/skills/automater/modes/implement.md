# Implement Mode

Dispatch sub-agents to implement Jira tickets in parallel using git worktrees.

## Steps

### 1. Parse Input

Accept ticket keys in any format:

| Format        | Example                               |
| ------------- | ------------------------------------- |
| Explicit list | `PROJ-123, PROJ-124, PROJ-125`        |
| Sprint query  | `current sprint`                      |
| JQL           | `project = PROJ AND status = "To Do"` |

Use **git provider skill** to fetch ticket details (summary, description, links).

### 2. Analyze Dependencies

The main goal here is to check if there are any other tickets that are linked to the tickets we are trying to complete do they have any dub-dependencies or linked tickets. Should we just work on the entire epic the ticket is tied to?

**Check for conflicts:**

1. Jira links (blocks/is-blocked-by)
2. Subtask relationships
3. Shared modules/files

Report ticket analysis to the user so they can make the final decision on what ticket(s) will be implemented.

### 3. Task Delegation Planning

This is the most important part of the process. You will be delegating task to sub-agents that will have only the context that you give them about the ticket. Therefore you must give as much context as possible in the description for what must be changed and why WITHOUT specifying implementation details. Map out a description for each ticket.

### 4. Dispatch Sub-agents

Run tickets in parallel (up to `$MAX_PARALLEL`).

**For each ticket:**

```bash
# Create branch name
BRANCH="${BRANCH_PREFIX}{TICKET-KEY}-{sanitized-summary}"

# Create worktree
git worktree add "${WORKTREE_DIR}/{TICKET-KEY}" -b "$BRANCH" "$PR_TARGET"

# Copy sub-agent rules to worktree
SKILL_DIR="$(dirname "$(realpath "$0")")/.."
cp -r "$SKILL_DIR/sub-agent-rules/.clinerules" "${WORKTREE_DIR}/{TICKET-KEY}/.clinerules"

# Copy project configs to worktree (environment vars, cline settings)
[ -f ".envrc" ] && cp ".envrc" "${WORKTREE_DIR}/{TICKET-KEY}/.envrc"
[ -d ".cline-project" ] && cp -r ".cline-project" "${WORKTREE_DIR}/{TICKET-KEY}/.cline-project"

# Spawn sub-agent (yolo mode)
# IMPORTANT: CLI arguments must be single-line to avoid terminal parsing issues
# See .clinerules/01-learnings.md for details
cline -y -c "${WORKTREE_DIR}/{TICKET-KEY}" "Implement {TICKET-KEY}: {summary}. Description: {description}. Instructions: 1) Implement the changes, 2) Commit when done (pre-commit hooks validate), 3) Push branch to remote, 4) Create PR targeting $PR_TARGET branch, 5) Comment on Jira ticket with PR link. Context: Ticket={TICKET-KEY}, Branch=$BRANCH, Target=$PR_TARGET, Worktree=${WORKTREE_DIR}/{TICKET-KEY}"
```

Then wait for sub-agents to complete.

### 5. Handle Results

**For each completed ticket:**

| Result                  | Actions                                         |
| ----------------------- | ----------------------------------------------- |
| **Success** (PR exists) | Transition Jira to "In Review", remove worktree |
| **Failure** (no PR)     | Log error, keep worktree for debug              |

### 5. Report Summary

```md
## Results

### PRs Created

- PROJ-123: PR #42 - https://...
- PROJ-125: PR #43 - https://...

### Failed (Manual Review)

- PROJ-124: Pre-commit failed (lint errors)
  Worktree: ${WORKTREE_DIR}/PROJ-124

### Skipped (Dependency Failed)

- PROJ-126: Depends on PROJ-124

### Next Steps

1. Fix: cd ${WORKTREE_DIR}/PROJ-124 && npm run lint
2. Re-run automater for failed tickets
```
