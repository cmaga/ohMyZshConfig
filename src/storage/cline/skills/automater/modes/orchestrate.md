# Orchestrate Mode

Orchestrate Cline CLI parallel instances to execute implementation plans using git worktrees.

## Important: Token Efficiency

**Do NOT read plan file contents.** Plans are already in the correct format (validated during design mode). Reading plans wastes tokens and time since CLI instances will read them directly. Only extract ticket keys from filenames.

## Process

### Step 1: Validate Plan Count

You were given ticket names that should have corresponding implementation plans.

Check the following:

- For each ticket you were given there is a corresponding plan in `.cline-project/skills/automater/plans/`
- The number of ticket names you were given is 3 or fewer

These are hard requirements. If these conditions are not met you need to resolve this conversationally with the user.

### Step 2: Create Worktrees

Run the worktree creation [script](../scripts/create-worktrees.zsh). Pass each ticket name as an argument.

### Step 3: Dispatch CLI Instances

Run the [dispatch script](../scripts/dispatch-tickets.zsh) which will handle plan execution hand off and reporting. Pass each ticket name as args.

### Step 4: Report Results

The dispatch script outputs results to the console. Summarize for the user:

- Which tickets succeeded/failed
- PR links for successful implementations (if available)
- Any blocking issues encountered
- Next steps for failed tickets

## Error Handling

The scripts provide detailed error messages and exit codes:

| Exit Code | Meaning                       |
| --------- | ----------------------------- |
| 0         | All operations succeeded      |
| 1         | One or more operations failed |

Common issues and resolutions:

- **Branch conflict**: A branch like `TICKET-123/subtask` exists, preventing creation of `TICKET-123`. Delete the conflicting branch.
- **Worktree exists**: The worktree directory already exists. This is skipped (not an error).
- **Plan not found**: The plan file doesn't exist in the worktree. Ensure design mode completed successfully.
