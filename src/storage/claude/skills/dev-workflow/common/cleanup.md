# Cleanup

Post-merge teardown for a completed ticket. Invoked when the user says `cleanup <TICKET>` or `cleanup`.

## Critical Rules

- Never proceed unless `gh pr view` reports `MERGED`. Any other state: abort with the state in the message.
- Idempotent. A resource already gone is not an error.
- `--force` removal of a worktree only after step 2 confirms `MERGED`.
- Never `git worktree remove` the worktree the session is inside — the pin then resolves to nothing. `ExitWorktree` is the only exit; if it already happened, `ExitWorktree` with `action: "remove"` still clears the pin.
- Main-checkout gate: before any write in the main checkout, `git status --porcelain` must print nothing. If it prints anything, stop and show the user. Never stash, commit, or discard main-checkout changes.

## Process

### 1. Identify the ticket's artifacts

Prefer the current session context. Fall back to derivation only when missing:

- Worktree + branch: `git worktree list --porcelain | grep -B2 <TICKET>`
- PR number: `gh pr list --search "<TICKET>" --state all --json number,state,headRefName`

If the user said `cleanup` with no ticket and session context is empty, ask for the ticket ID.

### 2. Verify merge

    gh pr view <prNumber> --json state --jq .state

`MERGED` — proceed. Otherwise report the state and abort.

### 3. Transition ticket to done

Invoke the `jira` skill to transition the ticket to `transitions.done`.

**Then check what this ticket was blocking.** `jira-cli` has no command for this; use the REST API. `$host` is the `jira` skill's `config.json` `server` with the scheme stripped; `-n` reads `~/.netrc`.

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

- **Report it, never transition it** — which dependents actually move is the user's call.
- `blocks` is the outward spelling, `is blocked by` the inward one; swapping them returns nothing and reads like a clean pass.
- Empty output means nothing this ticket blocked is still open. Say so in the report.

### 4. Teardown

In order:

1. If `<path>/.claude-artifacts/teardown.sh` exists, run it: `bash <path>/.claude-artifacts/teardown.sh`. Projects that provision per-worktree resources record their undo commands there. Report failures but do not stop. Never substitute your own cleanup commands or widen the scope — no `docker system prune`, nothing that could reach another worktree.
2. `ExitWorktree` with `action: "remove"` and `discard_changes: true` — squash and rebase merges leave a branch "unmerged" by git's heuristic; step 2 confirmed `MERGED` via `gh`.
3. Fall back to git — `git worktree remove --force <path>`, then `git branch -D <branch>` — when step 2 could not do the job: no worktree session was active, or the worktree was entered by `path` (every spec-descended run). For the latter, `ExitWorktree` with `action: "keep"` first to unpin.
4. Update the local base branch: main-checkout gate, then check out the base branch and `git pull --ff-only`; skip the pull with no upstream. A spec-descended ticket's base branch is the local integration branch — leave it as it is.
5. Kill any shells still running.

### 5. Report

    Cleaned up <TICKET>: ticket done, worktree removed, branch <name> deleted.
    Unblocked by this: <keys, or "nothing — it blocked no open ticket">.
