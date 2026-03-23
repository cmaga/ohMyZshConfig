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

## Pre-Flight Check (GitHub Only)

Only run this section if `PROVIDER="github"`.

### 1. Verify Authentication

```bash
gh auth status 2>&1
```

**If auth fails:** Route to [gh-setup mode](modes/gh-setup.md) for interactive authentication.

### 2. Auto-Switch Account by Directory

Git conditional includes already map directories to user.name. Use that directly:

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

## Operations

### Create PR

| Provider  | Command                                                                                                            |
| --------- | ------------------------------------------------------------------------------------------------------------------ |
| GitHub    | `gh pr create --base {base} --head {head} --title "{title}" --body "{body}"`                                       |
| Bitbucket | `bb pr create --destination {base} --source {head} --title "{title}" --description "{body}" --close-source-branch` |

### Get PR

| Provider  | Command                                     |
| --------- | ------------------------------------------- |
| GitHub    | `gh pr view {id} --json state,mergedAt,url` |
| Bitbucket | `bb pr get {id} -o json`                    |

### List PRs

| Provider  | Command                                    |
| --------- | ------------------------------------------ |
| GitHub    | `gh pr list --json number,title,state,url` |
| Bitbucket | `bb pr list --state open -o json`          |

### Merge PR

| Provider  | Command                                                          |
| --------- | ---------------------------------------------------------------- |
| GitHub    | `gh pr merge {id} --squash`                                      |
| Bitbucket | `bb pr merge {id} --merge-strategy squash --close-source-branch` |

### Approve PR

| Provider  | Command                       |
| --------- | ----------------------------- |
| GitHub    | `gh pr review {id} --approve` |
| Bitbucket | `bb pr approve {id}`          |

## PR Body Template

Use `dependencies/templates/pr-body.md` with placeholders:

| Placeholder            | Value                    |
| ---------------------- | ------------------------ |
| `{TICKET_KEY}`         | Jira key (e.g., ABC-123) |
| `{JIRA_URL}`           | Full Jira ticket URL     |
| `{TICKET_DESCRIPTION}` | Ticket description       |
| `{COMMIT_LOG}`         | Git commit log           |

## Modes

| Mode                          | Purpose                   |
| ----------------------------- | ------------------------- |
| [gh-setup](modes/gh-setup.md) | GitHub CLI authentication |

## CLI References

- GitHub: [gh-cli-reference.md](dependencies/docs/gh-cli-reference.md)
- Bitbucket: [bitbucket-cli-reference.md](dependencies/docs/bitbucket-cli-reference.md)
