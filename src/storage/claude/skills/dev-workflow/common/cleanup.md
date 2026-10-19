# Cleanup

Post-merge teardown for a completed ticket. Invoked when the user says `cleanup <TICKET>` or `cleanup`.

## Critical Rules

- Never proceed unless `gh pr view` reports `MERGED`. Any other state: abort with the state in the message.
- Idempotent. A resource already gone is not an error.
- `--force` removal of a worktree only after step 2 confirms `MERGED`.
- Never `git worktree remove` the worktree the session is inside — the pin then resolves to nothing. `ExitWorktree` with `action: "keep"` is the only exit. Its `remove` reports removals it never did; git does the removing.
- Work silently. Speak only when something unexpected happens — a command fails, or a resource survives its removal — and then say what and why. The step 5 report is the only other output.
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
2. Update the local base branch: main-checkout gate, then check out the base branch and `git pull --ff-only`; skip the pull with no upstream.
3. Land the vault, if `~/.claude/skills/capture-documentation/scripts/vault-git.sh` exists: `bash <that script> sync <main checkout>`. It merges the worktree's vault branch into the vault's main now that the code is on the base, and prints nothing for a project without a local vault. Run it while the code branch still exists — once it is deleted, the vault branch can no longer tell that it landed. Relay any `vault:` line it prints.
4. Confirm the branch landed: `git merge-base --is-ancestor <branch> <base>`. Non-zero means the base lacks some of the branch's commits — a squash or rebase merge, or local commits the PR never had. Stop, show `git --no-pager log --oneline <base>..<branch>`, and delete nothing until the user answers.
5. `ExitWorktree` with `action: "keep"` to unpin the session. Skip it when no worktree session is active.
6. Remove with git, worktree first — `git branch -D` refuses a branch a worktree still claims:

       git worktree remove --force <path>
       git branch -D <branch>
       git ls-remote --heads origin <branch>   # prints anything → git push origin --delete <branch>
       git for-each-ref --format='delete %(refname)' 'refs/tags/<TICKET>-M-*-proven' | git update-ref --stdin   # an epic's milestone proof tags

   `-D`, not `-d`: step 4 already proved the branch is in the base, and `-d` checks the branch's own upstream instead. Done when `git worktree list` no longer shows `<path>`.
7. Kill any shells still running.

### 5. Report

    Cleaned up <TICKET>: ticket done, worktree removed, branch <name> deleted.
    Unblocked by this: <keys, or "nothing — it blocked no open ticket">.
