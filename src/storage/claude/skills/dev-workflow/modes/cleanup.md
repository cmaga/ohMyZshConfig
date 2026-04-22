# Cleanup

Post-merge teardown for a completed ticket. Invoked when the user says `cleanup <TICKET>` or `cleanup`.

## Critical Rules

- Never proceed unless `gh pr view` reports `MERGED`. If the PR is any other state, abort with the current state in the message.
- Cleanup is idempotent. If a resource is already gone, continue without error.
- Never `--force` remove a worktree without explicit user confirmation.

## Process

### 1. Identify the ticket's artifacts

Prefer the current session context (worktree path, branch, PR number from the `take` flow you just ran). Fall back to derivation only when missing:

- Worktree + branch: `git worktree list --porcelain | grep -B2 <TICKET>`
- PR number: `gh pr list --search "<TICKET>" --state all --json number,state,headRefName`

If the user said `cleanup` with no ticket ID and session context is empty, ask for the ticket ID.

### 2. Verify merge

Run:

    gh pr view <prNumber> --json state --jq .state

- If output is `MERGED` — proceed.
- Otherwise — report the current state (`OPEN`, `CLOSED`, etc.) and abort. Do not delete anything.

### 3. Transition ticket to done

Invoke the `jira` skill to transition the ticket to `transitions.done`. Trust the result — `jira-cli` surfaces errors on non-zero exit.

### 4. Teardown

In order:

1. If currently inside the worktree, call `ExitWorktree`.
2. Remove the worktree: `git worktree remove <path>`. If it fails because of leftover changes, surface the error and ask the user whether to `--force`. Artifacts under `<worktree>/.claude-artifacts/` are removed with the worktree.
3. Delete the local branch: `git branch -d <branch>`. If the branch is not fully merged locally, report and ask before `-D`.

### 5. Report

One line:

    Cleaned up <TICKET>: ticket done, worktree removed, branch <name> deleted.
