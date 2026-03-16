# Orchestrate Mode

Execute implementation plans using git worktrees and Cline CLI parallel instances.

## Critical Rule

**Do NOT read plan file contents.** Plans are validated during design mode. Reading them wastes tokens. Extract ticket keys from filenames only.

## Process

### Step 1: Create Worktrees

Run [create-worktrees.zsh](../scripts/create-worktrees.zsh) with ticket keys as arguments:

```bash
./src/storage/cline/skills/automater/scripts/create-worktrees.zsh PROJ-123 PROJ-456
```

### Step 2: Dispatch CLI Instances

Run [dispatch-tickets.zsh](../scripts/dispatch-tickets.zsh) with the same ticket keys:

```bash
./src/storage/cline/skills/automater/scripts/dispatch-tickets.zsh PROJ-123 PROJ-456
```

Script enforces: max 3 tickets, worktree existence, plan existence.

### Step 3: Report Results

Summarize dispatch script output:

- Succeeded/failed tickets
- PR links (if available)
- Blocking issues
- Next steps for failures

## Error Reference

| Exit Code | Meaning            |
| --------- | ------------------ |
| 0         | All succeeded      |
| 1         | One or more failed |

| Issue           | Resolution            |
| --------------- | --------------------- |
| Worktree exists | Skipped (resume work) |
| Plan not found  | Run design mode first |
