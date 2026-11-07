# Open a PR

The end of every recipe that ships a change: hold the quality gate, fold the branch into one commit, and open a PR a reviewer can read in a minute.

Contents: Steps, Commits, Titles, The PR body, Size and stacks.

## Steps

1. **Hold the quality gate**: follow the [taste](../../taste/taste.md) command on this branch with the order's key and done-when. Nothing goes out until it clears.
2. **Triage what is left** per the [left for you](../stations/left-for-you.md) station.
3. **Record the gate.** When a vault rule under `.claude/rules/vault/` loaded for a file you changed, first dispatch `vault-scribe-agent` with what changed and why; nothing else writes vault notes. Then `kitchen.zsh order gated <KEY>` records the change the gate passed, so a later change to it is caught.
4. **Fold the branch into one commit, then run the full suite once.**
   1. With a clean tree, run `bash ~/.claude/skills/kitchen/dependencies/scripts/contract-check.sh origin/<base>`; it must not report the contract broken. After the fold every test edit sits in one commit, and the check can no longer tell who made it. It names the latest contract commit.
   2. Note `git rev-parse HEAD^{tree}`, `git fetch origin <base>`, then `git reset --soft $(git merge-base HEAD origin/<base>)` and commit per [Commits](#commits). `git rev-parse HEAD^{tree}` must print what you noted.
   3. `git rebase origin/<base>`, resolving any conflict so both sides' intent survives.
   4. Run the `Gate` command from the project rules (`.claude/kitchen/house.md`). Red: fix, `git commit --amend --no-edit`, re-run only the failures each fix could change, then every failure once, then the full suite; a test that fails twice at the same step after a fix is a finding to trace, not one to rerun. Green: `git push --force-with-lease -u origin HEAD`.
5. **Open the PR.** First settle the review flag: when step 2 left any item and the order is not already flagged, run `kitchen.zsh order set <KEY> review=true "review_why=left for you: <n> items"`. Then open the PR through the `git-provider` skill, ready and never as a draft, targeting `<base>`, with a title and body per the sections below written through the [technical writing](../stations/technical-writing.md) and [unslop](../stations/unslop.md) stations. Record it with `kitchen.zsh order set <KEY> pr=<url>` and move the ticket with `transitions.review`.
6. Run the [merge](merge.md) recipe. A PR flagged for the user's review still gets its verdict first: `sample` prints `verify` before `review`, and the PR goes to the user only when `sample` prints `review`.

Opening a PR does not start a [follow a PR](follow-a-pr.md) pass. The scheduler wakes a session when the PR changes.

## Commits

Commit liberally while working; those commits save work and never reach the base. Step 4 folds them into the PR's one commit, so reverting the PR's merge removes the change whole:

- Subject: the PR's title in the project's commit format; with none, Conventional Commits.
- Body: a few lines on what the change does, not how it got there.
- Trailers: when the branch has a contract commit, end with that latest contract commit's trailers (`git log -1 --format='%(trailers)' <sha>`), which restate the whole contract.

A change that needs two commits to read is two PRs, per [Size and stacks](#size-and-stacks). A move whose files also change goes in its own PR first, so git still follows the rename.

## Titles

`type(scope): subject`, no trailing period, unless the project's format says otherwise. Type such as `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, or `perf`; scope is the area; the subject is short, imperative, and names a real symbol when one carries the change. Start it with the ticket key when the project's titles do.

## The PR body

Fill the project's `.claude/kitchen/pr-body.md` when it exists, else the [default template](../templates/pr-body.md). Everyone who can see the PR reads it, so nothing in it addresses the user: their questions go to the order's `left` per [left for you](../stations/left-for-you.md), and the calls made without them are already in `decisions`. They read both when they review the order in its own session ([the user's review](merge.md#the-users-review)). Write the body to a file and check it against the template's length limit with `wc -c` before opening the PR; cut it until it fits.

## Size and stacks

Prefer several narrow PRs to one large one; an order whose change splits cleanly says so in **Left for you** or, at intake, becomes a [multi-phase plan](multi-phase-plan.md). A stack is a chain of base branches: the root PR targets the base, and each child branch rebases onto its parent's exact tip and targets the parent's branch (`gh pr create --base <parent-branch>`). Branch from the base only for independent work.

**Reply:** the PR link as a full URL, what it changes for whom, and anything waiting on the user.
