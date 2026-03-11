# Orchestrate Mode

Orchestrate sub-agents to execute implementation plans using git worktrees.

## Process

### Step 1: Validate Plans

You will be orchestrating between 1 and `$MAX_PARALLEL` plans. If there are more plans/tickets than this limit, stop immediately and explain this limitation to the user.

For each plan file in `$PLAN_DIR`, extract the ticket key and validate the plan exists.

### Step 2: Create Worktrees

For each plan, create a git worktree:

```bash
TICKET_KEY="{extracted from plan filename}"
BRANCH="${BRANCH_PREFIX}${TICKET_KEY}"
WORKTREE_PATH="${WORKTREE_DIR}/${TICKET_KEY}"

# Create worktree from PR target branch
git worktree add "${WORKTREE_PATH}" -b "$BRANCH" "$PR_TARGET"
```

Copy necessary environment files to the worktree:

```bash
[ -f ".envrc" ] && cp ".envrc" "${WORKTREE_PATH}/.envrc"
[ -d ".cline-project" ] && cp -r ".cline-project" "${WORKTREE_PATH}/.cline-project"
```

If you encounter issues with duplicate directory names, stop all work and report the error. It needs manual resolution.

### Step 3: Read Plan Content

For each plan, read the full plan file content:

```bash
PLAN_CONTENT=$(cat "${PLAN_DIR}/${TICKET_KEY}-plan.md")
```

### Step 4: Dispatch Sub-agents

For each worktree, invoke the ticket-executor subagent with the plan content embedded in the prompt. Dispatch up to `$MAX_PARALLEL` subagents concurrently.

```xml
<use_subagent_ticket_executor>
<prompt>
Working directory: ${WORKTREE_PATH}
Ticket: ${TICKET_KEY}
PR Target Branch: ${PR_TARGET}

## Implement and complete the following plan

${PLAN_CONTENT}

---

</prompt>
</use_subagent_ticket_executor>
```

### Step 5: Monitor and Report

Wait for all subagent(s) to complete, then report results to the user including:

- Which tickets succeeded/failed
- PR links for successful implementations
- Any blocking issues encountered
