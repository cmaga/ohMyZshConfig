# CRUX

Amazon's code review system, for repos whose remote is `git.amazon.com` (Brazil packages). A PR here is a code review (CR) at `https://code.amazon.com/reviews/CR-<n>`. `cr` creates and revises CRs; the builder-mcp `CodeReviewReadActions` and `CodeReviewWriteActions` tools read and comment on them. For anything this page does not cover, use the `crux-code-reviews` skill.

## Critical Rules

- **Never `git push` a commit.** `cr` pushes the review branch itself; a push to the base branch ships the change without review. The one push allowed is Cut a branch, which adds no commit.
- **Merge only through auto-merge, and only when the calling skill says to merge** (for kitchen, once its verdict and `sample` pass). Until then every revision stays a draft; publishing it with `--auto-merge` is the merge, and CRUX lands it when the required reviewers approve and the analyzers pass.

## Pre-flight

1. **In a Brazil workspace:** `brazil workspace show` succeeds from the repo. A worktree must also sit inside the workspace to build; one nested under the package (`.claude/worktrees/<name>`) does.
2. **Authenticated:** an auth or Midway error from `cr` or the MCP tools means the session expired; ask the user to run `mwinit`.
3. **Branch tracks the base:** `git branch --set-upstream-to origin/{baseBranch}`, so CRUX can resolve a merge target. Without it the CR is created unmergeable.

`baseBranch` defaults to `mainline` here.

## Operations

| Operation | How |
| --- | --- |
| Cut a branch | `git fetch origin {base}` and `git push origin origin/{base}:refs/heads/{name}`. Refused for want of permission: create the branch with the first CR into it instead, `--new-destination-branch {base}:{name}` in place of `--destination-branch` |
| Push | Before a CR exists, nothing: Create PR uploads the commit. After, `cr -r {CR-ID} --parent origin/{base} --no-amend --no-open` updates the draft revision in place (a new draft once a revision was published); there is no other way to update a CR |
| Create PR | `cr --parent origin/{base} --destination-branch {base} --summary "{title}" --description {body-file} --issue {ticketId} --no-amend --no-open`; it prints the CR URL and leaves revision 1 a draft |
| List PRs | No script-readable list. Read `https://code.amazon.com/reviews/from-user/{login}` with the builder-mcp `ReadInternalWebsites` tool, or the CRs a ticket links (`ticket.zsh get` shows Taskei's `related_code_reviews`) |
| Diff | `git diff origin/{base}...HEAD` in the worktree; the CR's description through `get-cr-info` |
| Get PR | `CodeReviewReadActions` `get-cr-info`: `merged` is the reliable landed signal, since status is per revision. From a script: `curl -sL --cookie ~/.midway/cookie -H 'Accept: application/json' https://code.amazon.com/reviews/{CR-ID}.json`, whose `.revision.cr_revision` has `status` (`SHIPPED` once merged), `approved_by`, `analyzers`, and `last_updated_at`; it is the CR page's own JSON, not a published API, and fails once the Midway cookie expires |
| Approvals | `get-approval-status`: who has approved and who still must, on the latest revision |
| Comments | `get-cr-comments`, once per revision from `get-revisions-by-review`; reviewer comments often sit on an earlier one |
| Reply | `CodeReviewWriteActions` `reply-to-comment` with the comment's `ref`, then `publish-comments` with the revision it reports |
| Checks | Poll `get-approval-status` every few minutes until no analyzer (dry-run build, coverage, and the package's own) is pending on the latest revision |
| Build Logs | `get-approval-status`, each analyzer's status message and details; the CR page links each analyzer's full run |
| Rerun a check | `CodeReviewWriteActions` `retry-analyzer` with the analyzer's name, once it failed or faulted |
| Merge | `cr -r {CR-ID} --parent origin/{base} --no-amend --publish --auto-merge --no-open` on the draft the gate passed. It queues the merge; the CR has landed only once `status` reads `SHIPPED` |
| Approve | None; an author cannot approve their own CR |

`{CR-ID}` is the `CR-<n>` in the URL Create PR printed (for kitchen, the order's `pr`).

`--no-amend` keeps the commit's SHA: by default `cr` rewrites the commit message to add the CR URL, which changes the SHA and breaks anything recorded against the old one. `--issue` links the ticket in the CR, and a ticket's tracker may comment the CR back onto the ticket.

The package's `.crux_template.md` fills the description when `--description` is absent. When you pass `--description`, write the body under the template's section headings yourself.
