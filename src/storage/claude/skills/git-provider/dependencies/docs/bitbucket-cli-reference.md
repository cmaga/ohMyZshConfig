# Bitbucket CLI Reference

Complete reference for the `bb` CLI (gildas/bitbucket-cli) used by the git-provider skill.

## Installation

```bash
brew install gildas/tap/bitbucket-cli
```

## Authentication

The `bb` CLI uses profiles to manage authentication. Credentials are stored securely in the system keychain.

### Create a Profile

First, create an App Password at: https://bitbucket.org/account/settings/app-passwords/

Required permissions:

- Repositories: Read, Write
- Pull requests: Read, Write

```bash
bb profile create \
  --name "default" \
  --user "your-username" \
  --password "your-app-password" \
  --default-workspace "your-workspace" \
  --default
```

### Profile Management

```bash
# List all profiles
bb profile list

# Show current profile
bb profile which

# Switch default profile
bb profile use {profile-name}

# Get profile details
bb profile get {profile-name}

# Delete a profile
bb profile delete {profile-name}
```

## Global Flags

These flags work with all commands:

| Flag            | Description                              |
| --------------- | ---------------------------------------- |
| `-o, --output`  | Output format: `json`, `yaml`, `table`   |
| `-p, --profile` | Profile to use (overrides default)       |
| `--dry-run`     | Show what would happen without executing |
| `--debug`       | Enable debug logging                     |
| `-v, --verbose` | Verbose output                           |
| `--repository`  | Specify repository (defaults to current) |

## Pull Requests

### Create Pull Request

```bash
bb pr create \
  --source "feature/TICKET-123-summary" \
  --destination "develop" \
  --title "[TICKET-123] Feature description" \
  --description "PR description here" \
  --close-source-branch \
  --reviewer default \
  -o json
```

**Flags:**

| Flag                    | Description                                     |
| ----------------------- | ----------------------------------------------- |
| `--source`              | Source branch                                   |
| `--destination`         | Target branch                                   |
| `--title`               | PR title                                        |
| `--description`         | PR description/body                             |
| `--close-source-branch` | Delete source branch after merge                |
| `--draft`               | Create as draft PR                              |
| `--reviewer`            | Add reviewers (use `default` for repo defaults) |
| `--repository`          | Repository (defaults to current)                |

**Example with JSON output:**

```bash
PR_JSON=$(bb pr create \
  --source "feature/STAX-123-login" \
  --destination "develop" \
  --title "[STAX-123] Add login functionality" \
  --description "Implements user login" \
  --close-source-branch \
  -o json)

PR_ID=$(echo "$PR_JSON" | jq -r '.id')
echo "Created PR #$PR_ID"
```

### Get Pull Request

```bash
# Get PR details
bb pr get {pr-id} -o json

# With specific columns
bb pr get {pr-id} --columns id,title,state,author
```

**PR States:**

- `OPEN` - PR is open
- `MERGED` - PR was merged
- `DECLINED` - PR was declined/closed
- `SUPERSEDED` - PR was superseded

### List Pull Requests

```bash
# List open PRs (default)
bb pr list -o json

# List by state
bb pr list --state open
bb pr list --state merged
bb pr list --state declined

# Filter with query
bb pr list --query "author.username = \"myuser\""

# Custom columns
bb pr list --columns id,title,state,author

# Pagination
bb pr list --page-length 25

# Sort by column
bb pr list --sort id
```

### Merge Pull Request

```bash
# Default merge (merge commit)
bb pr merge {pr-id}

# Squash merge
bb pr merge {pr-id} --merge-strategy squash

# Fast-forward merge
bb pr merge {pr-id} --merge-strategy fast_forward

# With custom message and close source branch
bb pr merge {pr-id} \
  --merge-strategy squash \
  --message "Merged PR #{pr-id}: Feature description" \
  --close-source-branch
```

**Merge Strategies:**

| Strategy       | Description                     |
| -------------- | ------------------------------- |
| `merge_commit` | Create a merge commit (default) |
| `squash`       | Squash all commits into one     |
| `fast_forward` | Fast-forward if possible        |

### Approve/Unapprove Pull Request

```bash
# Approve
bb pr approve {pr-id}

# Unapprove
bb pr unapprove {pr-id}
```

### Decline (Close) Pull Request

```bash
bb pr decline {pr-id}
```

### Update Pull Request

```bash
bb pr update {pr-id} \
  --title "Updated title" \
  --description "Updated description"
```

### PR Comments

```bash
# List comments
bb pr comment list {pr-id}

# Add comment
bb pr comment create {pr-id} --content "This is a comment"
```

### PR Activity

```bash
# View PR activity/history
bb pr activity list {pr-id}
```

## Repositories

### Get Repository Info

```bash
bb repo get -o json
bb repo get --repository workspace/repo-slug -o json
```

## Branches

### List Branches

```bash
bb branch list -o json
```

### Get Branch

```bash
bb branch get {branch-name} -o json
```

## Commits

### List Commits

```bash
bb commit list -o json

# For specific branch
bb commit list --branch {branch-name}
```

## Users

### Get Current User

```bash
bb user get -o json
```

## Workspaces

### List Workspaces

```bash
bb workspace list -o json
```

## Helper Scripts

### Check if PR is Merged

```bash
check_pr_merged() {
  local PR_ID=$1

  STATE=$(bb pr get "$PR_ID" -o json | jq -r '.state')

  if [ "$STATE" = "MERGED" ]; then
    echo "true"
  else
    echo "false"
  fi
}

# Usage
if [ "$(check_pr_merged 123)" = "true" ]; then
  echo "PR is merged"
fi
```

### Create PR and Get ID

```bash
create_pr() {
  local SOURCE_BRANCH=$1
  local DEST_BRANCH=$2
  local TITLE=$3
  local DESCRIPTION=$4

  PR_ID=$(bb pr create \
    --source "$SOURCE_BRANCH" \
    --destination "$DEST_BRANCH" \
    --title "$TITLE" \
    --description "$DESCRIPTION" \
    --close-source-branch \
    -o json | jq -r '.id')

  echo "$PR_ID"
}

# Usage
PR_ID=$(create_pr "feature/STAX-123" "develop" "Title" "Description")
echo "Created PR #$PR_ID"
```

### Full PR Creation with Jira Link

```bash
TICKET_KEY="STAX-123"
JIRA_URL="https://company.atlassian.net/browse/STAX-123"
SOURCE_BRANCH="feature/STAX-123-login"
DEST_BRANCH="develop"
TITLE="[$TICKET_KEY] Add login functionality"
DESCRIPTION="## Jira Ticket
[$TICKET_KEY]($JIRA_URL)

## Description
Implements user login."

PR_JSON=$(bb pr create \
  --source "$SOURCE_BRANCH" \
  --destination "$DEST_BRANCH" \
  --title "$TITLE" \
  --description "$DESCRIPTION" \
  --close-source-branch \
  --reviewer default \
  -o json)

PR_ID=$(echo "$PR_JSON" | jq -r '.id')
echo "Created PR #$PR_ID"
```

### Check PR Status and Merge if Ready

```bash
PR_ID="123"

# Get PR state
STATE=$(bb pr get "$PR_ID" -o json | jq -r '.state')

if [ "$STATE" = "OPEN" ]; then
  bb pr merge "$PR_ID" --merge-strategy squash --close-source-branch
  echo "PR merged"
elif [ "$STATE" = "MERGED" ]; then
  echo "PR already merged"
else
  echo "PR state: $STATE"
fi
```

## Error Handling

The CLI returns non-zero exit codes on failure. Check exit status:

```bash
if bb pr get 123 -o json > /dev/null 2>&1; then
  echo "PR exists"
else
  echo "PR not found or error occurred"
fi
```

## JSON Output Examples

### PR Create Response

```json
{
  "id": 123,
  "title": "[STAX-123] Feature description",
  "state": "OPEN",
  "source": {
    "branch": {
      "name": "feature/STAX-123-summary"
    }
  },
  "destination": {
    "branch": {
      "name": "develop"
    }
  },
  "author": {
    "display_name": "John Doe",
    "uuid": "{user-uuid}"
  },
  "links": {
    "html": {
      "href": "https://bitbucket.org/workspace/repo/pull-requests/123"
    }
  }
}
```

### PR Get Response

```json
{
  "id": 123,
  "title": "[STAX-123] Feature description",
  "state": "MERGED",
  "merge_commit": {
    "hash": "abc123def456"
  },
  "closed_by": {
    "display_name": "John Doe"
  }
}
```

## Comparison with REST API

The `bb` CLI wraps the Bitbucket REST API with a simpler interface:

| Operation | bb CLI               | REST API                          |
| --------- | -------------------- | --------------------------------- |
| Create PR | `bb pr create`       | `POST /pullrequests`              |
| Get PR    | `bb pr get {id}`     | `GET /pullrequests/{id}`          |
| List PRs  | `bb pr list`         | `GET /pullrequests`               |
| Merge PR  | `bb pr merge {id}`   | `POST /pullrequests/{id}/merge`   |
| Approve   | `bb pr approve {id}` | `POST /pullrequests/{id}/approve` |

The CLI automatically handles:

- Authentication from profiles
- Repository detection from git remote
- Workspace/repo slug parsing
- Pagination
- Error handling
