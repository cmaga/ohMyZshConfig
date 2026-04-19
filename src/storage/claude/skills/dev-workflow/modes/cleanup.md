# Cleanup

Post-merge teardown for a completed ticket. Invoked when the user says `cleanup <TICKET>` or `cleanup`.

## Critical Rules

- Never proceed unless `gh pr view` reports `MERGED`. If the PR is any other state, abort with the current state in the message.
- Cleanup is idempotent. If a resource is already gone, continue without error.
- Never `--force` remove a worktree without explicit user confirmation.

## Process

### 1. Load state

- Read `~/.claude/state/dev-workflow/<TICKET>.json`.
- If the file is missing or the user said just `cleanup` with no ID, ask the user for the ticket ID or branch name, then look up or derive the rest.

### 2. Verify merge

Run:

    gh pr view <prNumber> --json state --jq .state

- If output is `MERGED` — proceed to teardown.
- Otherwise — report the current state (`OPEN`, `CLOSED`, etc.) and abort. Do not delete anything.

### 3. Teardown

In order:

1. If currently inside the worktree, call `ExitWorktree`.
2. Remove the worktree: `git worktree remove <path>`. If it fails because of leftover changes, surface the error and ask the user whether to `--force`.
3. Delete the local branch: `git branch -d <branch>`. If the branch is not fully merged locally, report and ask before `-D`.
4. Remove the state file: `~/.claude/state/dev-workflow/<TICKET>.json`.

### 4. Report

One line:

    Cleaned up <TICKET>: worktree removed, branch <name> deleted, state cleared.
