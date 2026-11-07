---
name: git-provider
description: Git hosting provider operations (GitHub, Bitbucket). Use this skill when creating PRs, checking PR status, or interacting with GitHub/Bitbucket.
---

# Git Provider

Manage PRs and repos across GitHub and Bitbucket using their respective CLIs.

## Detect Provider (Run First)

```bash
git remote -v | grep -qE "github\.com" && PROVIDER="github"
git remote -v | grep -qE "bitbucket\.org" && PROVIDER="bitbucket"
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

## Operations

### Create PR

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

### Approve PR

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
| `{TICKET_KEY}` | Jira key (e.g., ABC-123)                                    |
| `{JIRA_URL}`   | Full Jira ticket URL                                        |
| `{SUMMARY}`    | What the PR changes and why, in two to four plain sentences |

## Modes

| Mode                          | Purpose                      |
| ----------------------------- | ---------------------------- |
| [gh-setup](modes/gh-setup.md) | GitHub CLI authentication    |
| [bb-setup](modes/bb-setup.md) | Bitbucket CLI authentication |

## CLI References

- GitHub: [gh-cli-reference.md](dependencies/docs/gh-cli-reference.md)
- Bitbucket: [bitbucket-cli-reference.md](dependencies/docs/bitbucket-cli-reference.md)
