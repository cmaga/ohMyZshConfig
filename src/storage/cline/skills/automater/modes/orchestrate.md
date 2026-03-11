# Orchestrate Mode

Orchestrate Cline CLI parallel instances to execute implementation plans using git worktrees.

## Important: Token Efficiency

**Do NOT read plan file contents.** Plans are already in the correct format (validated during design mode). Reading plans wastes tokens and time since CLI instances will read them directly. Only extract ticket keys from filenames.

## Process

### Step 1: Validate Plan Count

You were given ticket names that should have corresponding implementation plans.

Check the following:

- For each ticket you were given there is a corresponding plan. Plan files are located in `$PLAN_DIR`.
- The number of ticket names you were given is less than or equal to `$MAX_PARALLEL`.

These are hard requirements. If these conditions are not met you need to resolve this conversationally with the user.

### Step 2: Create Worktrees

For each plan, create a git worktree:

```bash
TICKET_KEY="{extracted from plan filename}"
BRANCH="${BRANCH_PREFIX}${TICKET_KEY}"
WORKTREE_PATH="${WORKTREE_DIR}/${TICKET_KEY}"

# Create worktree from PR target branch
git worktree add "${WORKTREE_PATH}" -b "$BRANCH" "$PR_TARGET"

# Copy environment and Cline configuration
[ -f ".envrc" ] && cp ".envrc" "${WORKTREE_PATH}/.envrc"
[ -d ".cline-project" ] && cp -r ".cline-project" "${WORKTREE_PATH}/.cline-project"
[ -d ".clinerules" ] && cp -r ".clinerules" "${WORKTREE_PATH}/.clinerules"

# Enable direnv for the worktree
[ -f "${WORKTREE_PATH}/.envrc" ] && (cd "${WORKTREE_PATH}" && direnv allow)
```

### Step 3: Build Prompt

For each ticket, construct the prompt with automation preamble and plan path reference:

```bash
PLAN_PATH=".cline-project/skills/automater/plans/${TICKET_KEY}-plan.md"

PROMPT="You are a self sufficient and talented software engineer. You receive detailed implementation plans and execute them independently without asking questions. Your job is to transform a plan into working, tested, linted, and reviewed code, then deliver it via pull request and keep jira tickets up to date.

## Effiency Rules

- **Always provide completion summary** - Use attempt_completion with a final summary including even if there is a failure:
   - PR link
   - Brief description of changes
   - Any related issues discovered (but not fixed)
   - Any major assumptions made

- **Stay in scope** - Only modify files directly required for the assigned ticket. Note related issues in your completion summary but do not fix them.

- **Prefer existing patterns** - Use patterns already established in the codebase rather than introducing new ones. Read before guessing.

## Execution Workflow

1. Read and understand the implementation plan at: ${PLAN_PATH}
2. Implement all tasks following the plan exactly
3. Final review - ensure code is clean, tests pass, changes follow architecture
4. Push the branch to remote
5. Create PR using git-provider skill targeting ${PR_TARGET}
6. Update Corresponding jira tickets using the jira skill - add PR link comment, move to In Review
7. Complete with attempt_completion summary"
```

### Step 4: Dispatch CLI Instances

For each prompt, invoke the Cline CLI in yolo mode and dispatch the prompts created in the previous step:

```bash
cline -y --cwd "${WORKTREE_PATH}" "${PROMPT}" &
PIDS+=($!)
```

### Step 5: Wait and Synchronize

Wait for all background CLI instances to complete:

```bash
for pid in "${PIDS[@]}"; do
    wait $pid
done
```

### Step 6: Report Results

After all instances complete, report results to the user including:

- Which tickets succeeded/failed
- PR links for successful implementations
- Any blocking issues encountered
