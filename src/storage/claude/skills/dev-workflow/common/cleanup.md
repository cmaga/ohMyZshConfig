# Cleanup

Post-merge teardown for a completed ticket. Invoked when the user says `cleanup <TICKET>` or `cleanup`.

## Critical Rules

- Never proceed unless `gh pr view` reports `MERGED`. If the PR is any other state, abort with the current state in the message.
- Cleanup is idempotent. If a resource is already gone, continue without error.
- `--force` removal of a worktree is allowed only after step 2 confirms `MERGED`. Never `--force` on an unmerged worktree.
- Main-checkout gate: before the step 4 pull or any other write in the main checkout, `git status --porcelain` must print nothing. If it prints anything, stop, show the user the dirty files, and wait for their decision. Never stash, commit, or discard main-checkout changes to unblock the cleanup.

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

1. If currently inside the worktree, call `ExitWorktree` with `discard_changes: true`. Section 2 (Verify merge) confirmed `MERGED` via `gh` — local git treats squash/rebase-merged branches as dirty even though the work is in main.
2. Release anything the worktree left running. If `<path>/.claude-artifacts/teardown.sh` exists, run it:

       bash <path>/.claude-artifacts/teardown.sh

   Projects that provision per-worktree resources — containers, background servers, tunnels — record their own undo commands there as they start them. Run it before step 3; removing the worktree deletes the file.

   If the file does not exist, skip without comment. Most projects provision nothing.

   Report failures but do not stop on them: a resource that is already gone is the expected case, not an error. Never substitute your own cleanup commands for the file's contents, and never widen the scope — no `docker system prune`, no `docker volume prune`, nothing that could reach another worktree or another project. Concurrent worktrees are running their own resources.
3. Remove the worktree: `git worktree remove --force <path>`. Same reasoning as step 1. Artifacts under `<worktree>/.claude-artifacts/` are removed with the worktree.
4. Delete the local branch: `git branch -D <branch>`. Use `-D`, not `-d` — squash and rebase merges (GitHub's defaults) leave a branch "unmerged" by git's local heuristic even though the work is in main. Section 2 (Verify merge) already confirmed `MERGED` via `gh`, which is the source of truth.
5. Update the local base branch: in the main checkout, run `git status --porcelain`. If it prints anything, stop (main-checkout gate in Critical Rules). When it prints nothing, check out the base branch and run `git pull --ff-only`; skip the pull if the branch has no upstream.
6. Kill any shells still running

### 5. Report

One line:

    Cleaned up <TICKET>: ticket done, worktree removed, branch <name> deleted.
