---
name: git-provider
description: Git hosting provider operations (GitHub, Bitbucket, CRUX) and the project's git settings. Use this skill when creating PRs or CRs, checking their status, merging, or interacting with GitHub, Bitbucket, or CRUX (code.amazon.com reviews).
---

# Git Provider

Manage PRs and repos across GitHub, Bitbucket, and CRUX using their respective CLIs. On CRUX a PR is a code review (CR); this skill says PR for both.

## Project Config

Optional: `<main checkout>/.claude/git-provider/config.json`, never committed (add `.claude/git-provider/` to `$(git rev-parse --git-common-dir)/info/exclude`). Every worktree reads it from the main checkout: `$(git rev-parse --path-format=absolute --git-common-dir | sed 's#/\.git$##')/.claude/git-provider/config.json`. Template: [config.json](dependencies/templates/config.json).

| Field | Default | Use |
| --- | --- | --- |
| `baseBranch` | `main` (`mainline` on CRUX) | The base ref for new branches and the PR's destination |
| `branchFormat` | `{username}/{ticketId}/{description}` | Branch names; interpolate `{username}`, `{ticketId}`, `{description}` |
| `commitFormat` | none: callers use Conventional Commits | Commit subjects; interpolate `{ticketId}`, `{message}` |
| `prTemplate` | [pr-body.md](dependencies/templates/pr-body.md) | PR description; interpolate `{ticketId}`, `{ticketUrl}`, `{summary}` |

## Detect Provider (Run First)

```bash
git remote -v | grep -qE "github\.com" && PROVIDER="github"
git remote -v | grep -qE "bitbucket\.org" && PROVIDER="bitbucket"
git remote -v | grep -qE "git\.amazon\.com" && PROVIDER="crux"
```

The Bitbucket match is a substring, so SSH host aliases like `bitbucket.org-ms` still match.

## Pre-Flight Check

Run **exactly one** branch below based on `PROVIDER`. Do not run the other provider's check — it's irrelevant noise.

### Branch: `PROVIDER="github"`

1. **Verify authentication:**

   ```bash
   gh auth status 2>&1
   ```

   If auth fails → route to [gh-setup mode](modes/gh-setup.md).

2. **Auto-switch account by directory.** Git conditional includes already map directories to `user.name`:

   | Directory Path | Account (from `git config user.name`) |
   | -------------- | ------------------------------------- |
   | `~/dev/gsi/`   | cmagana-gsi                           |
   | `~/dev/ms/`    | cmagana-ms                            |
   | _default_      | cmaga                                 |

   ```bash
   EXPECTED=$(git config user.name)
   CURRENT=$(gh auth status 2>&1 | sed -n 's/.*account \([^ ]*\).*/\1/p' || true)
   [[ "$CURRENT" != "$EXPECTED" ]] && gh auth switch --user "$EXPECTED"
   ```

### Branch: `PROVIDER="bitbucket"`

1. **Pick the profile by workspace.** Convention: **profile name == workspace slug** (workspace `gsi` → profile `gsi`). Derive the workspace from the remote:

   ```bash
   WS=$(git remote get-url origin | sed -E 's#\.git$##; s#^.*bitbucket\.org[^:/]*[:/]##' | cut -d/ -f1)
   bb profile get "$WS" >/dev/null 2>&1 || echo "no profile named '$WS'"
   ```

   Pass `-p "$WS"` on **every** `bb` command, the Operations below included. Never run `bb profile use`: it sets one default for every session on the machine, so a session in another workspace switches it back mid-run and your next call fails with `may not have access to this repository`.

   If no profile named `$WS` exists → route to [bb-setup mode](modes/bb-setup.md) (Add Profile flow; name the profile `$WS`).

2. **Verify the profile can reach this repo** (catches scope/workspace mismatches, which `profile get` won't). Run from inside the repo — `bb` auto-detects from `git remote`:

   ```bash
   bb branch list -p "$WS" -o json --page-length 1 >/dev/null 2>&1
   ```

   If this fails → route to [bb-setup mode](modes/bb-setup.md) (Update Profile flow).

### Branch: `PROVIDER="crux"`

Follow [crux mode](modes/crux.md) for pre-flight and every operation; the tables below do not apply.

## Operations

### Push

Publish the branch's commits to the PR, a new PR's included. GitHub and Bitbucket: `git push --force-with-lease -u origin HEAD`. CRUX never takes a `git push`; see its Push in [crux mode](modes/crux.md). Never push to the base branch.

### Cut a branch

Create a remote branch at the base's tip, for work that merges into it before the base: `git fetch origin {base}` and `git push origin origin/{base}:refs/heads/{name}`. It adds no commit, so nothing reaches the remote unreviewed. PRs then target `{name}` as their base. On CRUX see [crux mode](modes/crux.md).

### Create PR

Open it ready for review, never as a draft; on CRUX it stays a draft until Merge publishes it.

| Provider  | Command                                                                                                            |
| --------- | ------------------------------------------------------------------------------------------------------------------ |
| GitHub    | `gh pr create --base {base} --head {head} --title "{title}" --body "{body}"`                                       |
| Bitbucket | `bb pr create -p "$WS" --destination {base} --source {head} --title "{title}" --description "{body}" --close-source-branch` |

### Get PR

| Provider  | Command                                     |
| --------- | ------------------------------------------- |
| GitHub    | `gh pr view {id} --json state,mergedAt,url` |
| Bitbucket | `bb pr get {id} -p "$WS" -o json`           |

### List PRs

| Provider  | Command                                    |
| --------- | ------------------------------------------ |
| GitHub    | `gh pr list --json number,title,state,url` |
| Bitbucket | `bb pr list -p "$WS" --state open -o json` |

### Merge PR

| Provider  | Command                                                                |
| --------- | ---------------------------------------------------------------------- |
| GitHub    | `gh pr merge {id} --merge`                                             |
| Bitbucket | `bb pr merge {id} -p "$WS" --merge-strategy merge_commit --close-source-branch` |

Merge commits only: squash and rebase give the branch's commits new SHAs, so ancestry checks never see the branch as landed.

### Checks

Wait for the required checks on the PR head, then read their result.

| Provider  | Command |
| --------- | ------- |
| GitHub    | `gh pr checks {url} --watch --required`, or `gh pr checks {url} --watch` when it says no checks are required |
| Bitbucket | A head with no `bitbucket-pipelines.yml` has no checks. Otherwise poll `bb pipeline list -p "$WS" --limit 50 -o json` every few minutes for the build whose `target.commit.hash` is the head, until it completes |

### Rerun a check

| Provider  | Command |
| --------- | ------- |
| GitHub    | `gh run rerun {run-id} --failed` |
| Bitbucket | None: a failure is real |

### Comments

List a PR's comments with their ids, which callers record as handled.

| Provider  | Command |
| --------- | ------- |
| GitHub    | `gh api repos/{owner}/{repo}/pulls/{pr}/comments` for review comments, and `gh api repos/{owner}/{repo}/issues/{pr}/comments` for the rest |
| Bitbucket | `bb pr activities {pr} -p "$WS" -o json`: the entries with a `comment` key (`comment list` rejects merged PRs) |

### Diff

| Provider  | Command |
| --------- | ------- |
| GitHub    | `gh pr diff {pr}` and `gh pr view {pr} --json body` |
| Bitbucket | `bb pr get {pr} -p "$WS" -o json` for the body; `git diff origin/{base}...origin/{head}` for the diff |

### Reply to a comment

Write the body to a file with the Write tool first; never type text taken from a PR into a command.

| Provider  | Command |
| --------- | ------- |
| GitHub    | `gh api --method POST repos/{owner}/{repo}/pulls/{pr}/comments/{id}/replies --input {payload.json}` |
| Bitbucket | `bb pr comment create -p "$WS" --pullrequest {pr} --comment "$(cat {body.md})"`: the CLI takes no file, and has no threaded reply, so quote the comment you answer |

### Approve PR

How the user approves differs by host: on GitHub no one can approve their own PR, so the user comments `approve` instead; on CRUX the required reviewers approve, and auto-merge lands the CR once they do.

| Provider  | Command                       |
| --------- | ----------------------------- |
| GitHub    | `gh pr review {id} --approve` |
| Bitbucket | `bb pr approve {id} -p "$WS"` |

### Build Logs

| Provider  | Command                                                                                                      |
| --------- | ------------------------------------------------------------------------------------------------------------ |
| GitHub    | `gh run view {id} --log-failed`                                                                              |
| Bitbucket | `bb pipeline step list -p "$WS" --pipeline {n} --show-logs-command`, then `bb pipeline step logs -p "$WS" --pipeline {n} '{uuid}'` |

Bitbucket needs the UUID with its braces — a step name is rejected despite the
usage string. See the Pipelines section of the reference for the list shape.

## PR Body Template

A body the calling skill supplies wins. With none, fill `dependencies/templates/pr-body.md`:

| Placeholder    | Value                                                       |
| -------------- | ----------------------------------------------------------- |
| `{ticketId}`   | Ticket key (e.g., ABC-123)                                  |
| `{ticketUrl}`  | `ticket.zsh url {ticketId}` from the `ticket-provider` skill |
| `{summary}`    | What the PR changes and why, in two to four plain sentences |

## Modes

| Mode                          | Purpose                      |
| ----------------------------- | ---------------------------- |
| [gh-setup](modes/gh-setup.md) | GitHub CLI authentication    |
| [bb-setup](modes/bb-setup.md) | Bitbucket CLI authentication |
| [crux](modes/crux.md)         | CRUX code reviews with `cr`  |

## CLI References

- GitHub: [gh-cli-reference.md](dependencies/docs/gh-cli-reference.md)
- Bitbucket: [bitbucket-cli-reference.md](dependencies/docs/bitbucket-cli-reference.md)
