# Merge

Land a PR once a verdict from a session that did not write it covers the change, and its checks pass on the base it lands on. Green is not safe: green CI and an approving bot review are not verdicts, because neither runs the change as a user would.

**You own what lands.**

1. **Ask what the PR needs**: `kitchen.zsh sample <KEY>` from the order's worktree, again before every merge. It prints one word:
   - `rebase`: the base moved under a file this branch changes, or under its checks. Repeat [open a PR](open-a-pr.md) step 4, then ask again.
   - `regate`: the change differs from what the quality gate passed. Run the [bug review](../../taste/taste.md#bug-review) on `git range-diff <gated_base>..<gated_head> origin/<base>..HEAD`, with `gated_base` and `gated_head` from the order; fold its fixes and push per open a PR step 4; run `kitchen.zsh order gated <KEY>`; ask again.
   - `fix`: the verdict on this change is `FAIL`. Fix each finding in the order's `verdict_notes` per [follow a PR](follow-a-pr.md) step 6, then ask again. A third `FAIL` (the order's `verify_fails`) parks the order: comment the findings on the PR, run `kitchen.zsh order set <KEY> status=86 "reason=parked: three FAIL verdicts"`, and end.
   - `verify`: no verdict covers this change. A verdict covers a patch, not its commits, so a rebase that changes no line keeps it. Headless, run `kitchen.zsh order verify <KEY>` and end: the scheduler starts a session that did not write the change, and wakes one here once the verdict lands. With the user here, dispatch a fresh agent on the verify role with `isolation: "worktree"`, told to follow [verify](../../taste/verify.md) for this order, then ask again.
   - `review`: the PR waits for the user, and the order's `review_why` says why. Wait on the checks and fix red per step 2 without merging. Then `kitchen.zsh order pr <KEY> <url>` hands the PR to the scheduler, which wakes a session when the user acts. A comment can land while you hand it over, so list the PR's comments once more: any whose id is not in the order's `handled` means `kitchen.zsh order set <KEY> pr_seen=` and [follow a PR](follow-a-pr.md). Otherwise, with the user here, give them the PR link and the reason it waits; then stop.
   - `no`: go on.
2. **Wait on the required checks**: `gh pr checks <url> --watch --required` on GitHub, or `gh pr checks <url> --watch` when it says no checks are required. On Bitbucket, a PR head with no `bitbucket-pipelines.yml` has no checks: go on. Otherwise poll `bb pipeline list -o json` every few minutes for the build whose `target.commit.hash` is the PR head (the git-provider Bitbucket reference, under Pipelines) until it completes; there is no rerun there, so any failure is real.
   - **Red**: classify it per [follow a PR](follow-a-pr.md) step 7 before fixing, then ask again per step 1. After three real red rounds, park the order: comment what failed on the PR, run `kitchen.zsh order set <KEY> status=86 "reason=parked: three red check rounds"`, and end.
   - **Green**: list the PR's comments; any whose id is not in `handled` takes you to [follow a PR](follow-a-pr.md).
3. **Merge** through the `git-provider` skill, after one more `sample` that prints `no`. Read the PR back for the result: a merge queue that only queued it, or a requested auto-merge, is not a merge. A landed PR reads merged, with the base as its target.
4. **Close the order**: `kitchen.zsh order close <KEY>`. With the user here, end with an [exit report](../templates/exit-report.md).

A PR stacked on another merges only after its parent merged and it was moved onto the base and pushed with `--force-with-lease`; its verdict stands when `sample` says so. Leave every other branch alone while a PR lands. If a merge stalls, find out why before you change anything.

**Reply:** what landed, the verdict that covered it and who gave it, how you confirmed the merge, and anything left for the user.
