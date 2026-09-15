# Cleanup

Post-merge teardown for a completed ticket. Invoked when the user says `cleanup <TICKET>` or `cleanup`.

## Critical Rules

- Never proceed unless `gh pr view` reports `MERGED`. If the PR is any other state, abort with the current state in the message.
- Cleanup is idempotent. If a resource is already gone, continue without error.
- `--force` removal of a worktree is allowed only after step 2 confirms `MERGED`. Never `--force` on an unmerged worktree.
- Never run `git worktree remove` on the worktree the session is currently inside. The session is pinned to it: `cd` out, `git -C`, `--git-dir`, and `GIT_DIR`/`GIT_WORK_TREE` are all refused, so once the directory is gone the pin resolves to nothing and every later git command fails. `ExitWorktree` is the only exit. If that has already happened, `ExitWorktree` with `action: "remove"` still clears the pin and restores the session — it does not need the directory to exist.
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

**Then check what this ticket was blocking.** Closing a blocker is the moment its dependents become actionable, and it is the only moment anything in this workflow is looking at them — otherwise a dependent keeps its old status until somebody happens to open it. Measured once on a real board: ten open tickets had every recorded blocker already Done, the oldest for sixty days.

`jira-cli` has no command for this, so it goes to the REST API directly — the same exception the `jira` skill makes for attachments, and not a config problem to be fixed back to the CLI. `$host` is that skill's `config.json` `server` with the scheme stripped; `-n` reads the same `~/.netrc` token.

```bash
for d in $(curl -s -n "https://$host/rest/api/3/issue/<TICKET>?fields=issuelinks" \
      | jq -r '.fields.issuelinks[] | select(.type.outward=="blocks" and .outwardIssue) | .outwardIssue.key'); do
  curl -s -n "https://$host/rest/api/3/issue/$d?fields=summary,status,issuelinks" | jq -r '
    select(.fields.status.statusCategory.key != "done")
    | [.fields.issuelinks[] | select(.type.inward=="is blocked by" and .inwardIssue)] as $b
    | [$b[] | select(.inwardIssue.fields.status.statusCategory.key != "done")] as $open
    | if ($open|length)==0
      then "CLEAR    \(.key) [\(.fields.status.name)] \(.fields.summary)"
      else "WAITING  \(.key) still blocked by \([$open[].inwardIssue.key]|join(", "))" end'
done
```

- **Report it, never transition it.** A cleared link says nothing recorded is blocking that ticket any more — not that it is ready. A dependent can still be waiting on something nobody wrote down as a link, so which ones actually move is the user's call.
- **Link direction is the silent failure.** `blocks` is the outward spelling, `is blocked by` the inward one; swapping them returns nothing and reads exactly like a clean pass.
- Empty output means nothing this ticket blocked is still open. Say that in the report rather than omitting the line — a check that reports only on hits is indistinguishable from one that never ran.

### 4. Teardown

In order:

1. Release anything the worktree left running. If `<path>/.claude-artifacts/teardown.sh` exists, run it:

       bash <path>/.claude-artifacts/teardown.sh

   Projects that provision per-worktree resources — containers, background servers, tunnels — record their own undo commands there as they start them. Run it first; the next step deletes the file along with the rest of `<worktree>/.claude-artifacts/`.

   If the file does not exist, skip without comment. Most projects provision nothing.

   Report failures but do not stop on them: a resource that is already gone is the expected case, not an error. Never substitute your own cleanup commands for the file's contents, and never widen the scope — no `docker system prune`, no `docker volume prune`, nothing that could reach another worktree or another project. Concurrent worktrees are running their own resources.
2. Call `ExitWorktree` with `action: "remove"` and `discard_changes: true`. One move: it deletes the worktree and its branch and returns the session to the main checkout, so the pin never outlives the directory. `action` is required — a call without it is invalid. `discard_changes` is required because squash and rebase merges (GitHub's defaults) leave a branch "unmerged" by git's local heuristic; section 2 (Verify merge) confirmed `MERGED` via `gh`, which is the source of truth.
3. Fall back to git — `git worktree remove --force <path>`, then `git branch -D <branch>`, using `-D` for the reason in step 2 — in either case where step 2 could not do the job:
   - No worktree session was active, so `ExitWorktree` was a no-op. This is a `cleanup <TICKET>` run in a session that never entered the worktree.
   - The worktree was entered by `path` rather than created by `name`, which is how every spec-descended run enters one. `ExitWorktree` refuses to remove those; call it with `action: "keep"` to unpin the session, then remove them here.
4. Update the local base branch: in the main checkout, run `git status --porcelain`. If it prints anything, stop (main-checkout gate in Critical Rules). When it prints nothing, check out the base branch and run `git pull --ff-only`; skip the pull if the branch has no upstream. A spec-descended ticket's base branch is the spec's integration branch, which is local and has no upstream to pull from — leave it exactly as it is, and leave the main checkout on the project base.
5. Kill any shells still running

### 5. Report

One line, plus step 3's finding:

    Cleaned up <TICKET>: ticket done, worktree removed, branch <name> deleted.
    Unblocked by this: <keys, or "nothing — it blocked no open ticket">.
