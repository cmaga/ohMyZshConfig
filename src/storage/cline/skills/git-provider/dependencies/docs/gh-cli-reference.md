# GitHub CLI (gh) Reference

Complete reference for the GitHub CLI (`gh`) used by the git-provider skill.

## Installation

```bash
# macOS
brew install gh

# Windows
winget install --id GitHub.cli

# Linux (Debian/Ubuntu)
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update && sudo apt install gh
```

## Authentication

```bash
# Interactive login
gh auth login

# Check auth status
gh auth status

# Login with token
gh auth login --with-token < token.txt

# Login with specific options (non-interactive)
gh auth login --hostname github.com --git-protocol ssh --web

# Skip SSH key generation
gh auth login --git-protocol https --skip-ssh-key --web
```

## Multi-Account Management

```bash
# List all authenticated accounts
gh auth status

# Switch active account (interactive)
gh auth switch

# Switch to specific account
gh auth switch --user username

# Switch account on enterprise host
gh auth switch --hostname enterprise.internal --user monalisa

# Add another account to same host
gh auth login --hostname github.com
# (CLI detects existing account and adds new one alongside)

# Logout specific account
gh auth logout --user username

# Logout from specific host
gh auth logout --hostname enterprise.internal
```

## Pull Requests

### Create PR

```bash
# Basic PR creation
gh pr create --title "PR Title" --body "Description"

# With base and head branches
gh pr create --base main --head feature-branch --title "Title" --body "Body"

# Interactive mode
gh pr create

# Create draft PR
gh pr create --draft --title "WIP: Feature" --body "Work in progress"

# Assign reviewers
gh pr create --reviewer user1,user2 --title "Title" --body "Body"

# Add labels
gh pr create --label bug,urgent --title "Fix bug" --body "Description"

# From specific remote
gh pr create --repo owner/repo --title "Title" --body "Body"
```

### View PR

```bash
# View PR in terminal
gh pr view 123

# View current branch's PR
gh pr view

# JSON output (for parsing)
gh pr view 123 --json state,title,body,url,mergedAt,author

# Specific fields
gh pr view 123 --json state --jq '.state'

# Open in browser
gh pr view 123 --web
```

### List PRs

```bash
# List all open PRs
gh pr list

# List my PRs
gh pr list --author @me

# List with specific state
gh pr list --state open
gh pr list --state closed
gh pr list --state merged
gh pr list --state all

# JSON output
gh pr list --json number,title,state,url

# Filter by label
gh pr list --label bug

# Filter by base branch
gh pr list --base main

# Limit results
gh pr list --limit 10
```

### Check/Merge PR

```bash
# Check PR status (CI checks)
gh pr checks 123

# Wait for checks to pass
gh pr checks 123 --watch

# Merge PR (default merge commit)
gh pr merge 123

# Squash merge
gh pr merge 123 --squash

# Rebase merge
gh pr merge 123 --rebase

# Auto-merge when checks pass
gh pr merge 123 --auto --squash

# Delete branch after merge
gh pr merge 123 --squash --delete-branch
```

### Close/Reopen PR

```bash
# Close PR
gh pr close 123

# Close with comment
gh pr close 123 --comment "Closing because..."

# Delete branch when closing
gh pr close 123 --delete-branch

# Reopen PR
gh pr reopen 123
```

### PR Comments

```bash
# Add comment
gh pr comment 123 --body "Comment text"

# Add comment from file
gh pr comment 123 --body-file comment.md

# Edit PR body
gh pr edit 123 --body "New description"

# Add reviewers
gh pr edit 123 --add-reviewer user1,user2

# Add labels
gh pr edit 123 --add-label bug,priority
```

### PR Diff

```bash
# View diff
gh pr diff 123

# View diff with specific format
gh pr diff 123 --color always
```

## Issues

### Create Issue

```bash
# Basic issue
gh issue create --title "Bug report" --body "Description"

# With labels and assignees
gh issue create --title "Bug" --body "Desc" --label bug --assignee @me

# Interactive mode
gh issue create
```

### View/List Issues

```bash
# View issue
gh issue view 123

# List issues
gh issue list

# List my issues
gh issue list --assignee @me

# JSON output
gh issue list --json number,title,state,url
```

### Close/Reopen Issue

```bash
# Close issue
gh issue close 123

# Close with comment
gh issue close 123 --comment "Fixed in PR #456"

# Reopen issue
gh issue reopen 123
```

## Repository

### Clone/Fork

```bash
# Clone repo
gh repo clone owner/repo

# Fork repo
gh repo fork owner/repo

# Fork and clone
gh repo fork owner/repo --clone
```

### View Repo

```bash
# View repo info
gh repo view

# View specific repo
gh repo view owner/repo

# JSON output
gh repo view --json name,description,url,defaultBranchRef
```

## Releases

```bash
# List releases
gh release list

# View release
gh release view v1.0.0

# Create release
gh release create v1.0.0 --title "Release 1.0.0" --notes "Release notes"

# Create release with assets
gh release create v1.0.0 ./dist/*.zip --title "Release 1.0.0"
```

## Workflows (GitHub Actions)

```bash
# List workflows
gh workflow list

# View workflow runs
gh run list

# View specific run
gh run view 123456

# Download artifacts
gh run download 123456
```

## Key Flags

| Flag     | Purpose                           |
| -------- | --------------------------------- |
| `--json` | Output in JSON format             |
| `--jq`   | Filter JSON output with jq syntax |
| `--web`  | Open in browser                   |
| `--repo` | Specify repository (owner/repo)   |

## JSON Output Fields

Common fields available with `--json`:

**Pull Requests:**

- `number`, `title`, `body`, `state`, `url`
- `author`, `assignees`, `reviewers`
- `headRefName`, `baseRefName`
- `createdAt`, `updatedAt`, `mergedAt`, `closedAt`
- `mergeable`, `isDraft`
- `labels`, `milestone`

**Issues:**

- `number`, `title`, `body`, `state`, `url`
- `author`, `assignees`
- `createdAt`, `updatedAt`, `closedAt`
- `labels`, `milestone`

## Examples

### Create PR with full options

```bash
gh pr create \
  --base develop \
  --head feature/STAX-123-login \
  --title "[STAX-123] Add login functionality" \
  --body "## Jira Ticket
[STAX-123](https://company.atlassian.net/browse/STAX-123)

## Description
Implements user login with JWT authentication.

## Changes
- Added login endpoint
- Added JWT token generation
- Added auth middleware" \
  --reviewer teammate1,teammate2 \
  --label feature,auth
```

### Check if PR is merged

```bash
STATE=$(gh pr view 123 --json state --jq '.state')
if [ "$STATE" = "MERGED" ]; then
  echo "PR is merged"
fi
```

### Get PR number from branch

```bash
PR_NUMBER=$(gh pr view feature-branch --json number --jq '.number')
echo "PR number: $PR_NUMBER"
```

### List all my open PRs across repos

```bash
gh pr list --author @me --state open --json number,title,url,repository
```
