---
name: jira
description: JIRA ticket management using jira-cli. Use whenever the user wants to interact with jira, create tickets, transition issues, list sprints, or any Jira-related task.
---

# JIRA Integration

Manage JIRA tickets using jira-cli by ankitpokhrel.

## Pre-flight Check

Run this check at the start of **every invocation** to detect setup state and route accordingly.

### Detection

Check these three items in order:

1. **jira-cli installed?** — `command -v jira`
2. **API token available?** — `.envrc` exists with `JIRA_API_TOKEN`
3. **Skill config exists?** — `.claude/skills/jira/config.json`
4. **jira-cli initialized?** — `.claude/skills/jira/.jira-config.yml` exists

### Routing

| State                   | Has jira-cli | Has token | Has config.json | Has .jira-config.yml | Action                 |
| ----------------------- | ------------ | --------- | --------------- | -------------------- | ---------------------- |
| Fresh                   | No           | No        | No              | No                   | Full setup (Steps 1-5) |
| Partial: token only     | Yes          | Yes       | No              | No                   | Steps 3-5              |
| Partial: token + config | Yes          | Yes       | Yes             | No                   | Steps 4-5              |
| Ready                   | Yes          | Yes       | Yes             | Yes                  | Execute commands       |

Skip any step whose artifact already exists. Always end with the verification step.

## Setup Steps

### Step 1: Install jira-cli

```bash
brew install jira-cli
```

Verify: `command -v jira`

### Step 2: Configure API Token

1. Provide this link: https://id.atlassian.com/manage-profile/security/api-tokens
2. Ask the user to create a token and paste it
3. Create `.envrc` in the project root:

```bash
export JIRA_API_TOKEN="<token-from-user>"
export JIRA_CONFIG_FILE=".claude/skills/jira/.jira-config.yml"
```

4. Add `.envrc` to `.gitignore`:

```bash
grep -q '^\\.envrc$' .gitignore || echo '.envrc' >> .gitignore
```

5. Load the environment:

```bash
# If direnv is installed:
direnv allow

# Otherwise:
source .envrc
```

6. Verify both vars are set:

```bash
echo "TOKEN=${JIRA_API_TOKEN:+set}" && echo "CONFIG=${JIRA_CONFIG_FILE:+set}"
```

### Step 3: Create Skill Config

Ask user for:

- **server**: Atlassian URL (e.g., https://company.atlassian.net)
- **email**: Login email
- **installationType**: Usually "cloud"
- **username**: For branch naming (e.g., cmagana)
- **projectKey**: JIRA project key (e.g., STAX)
- **labels**: Default label filters (empty array = show all)
- **transitions**: Status names for their board

Create `.claude/skills/jira/config.json` using template:
[dependencies/templates/jira-config.json](dependencies/templates/jira-config.json)

### Step 4: Initialize jira-cli

Ensure `.envrc` is loaded first (`source .envrc` or `direnv allow`), then:

```bash
jira init
```

`JIRA_CONFIG_FILE` tells jira-cli where to write its config. Verify the file was created:

```bash
test -f ".claude/skills/jira/.jira-config.yml" && echo "OK" || echo "MISSING"
```

During init, select:

- "Cloud" for Atlassian Cloud
- Server URL from config
- Login email from config
- Default project from config

### Step 5: Verify Connection

```bash
jira me
```

## Execute Commands

### Config Reference

Location: `.claude/skills/jira/config.json`

| Field              | Description              |
| ------------------ | ------------------------ |
| `server`           | Atlassian server URL     |
| `email`            | Login email              |
| `installationType` | cloud or server          |
| `username`         | For branch naming        |
| `projectKey`       | JIRA project key         |
| `branchFormat`     | Git branch name template |
| `commitFormat`     | Commit message template  |
| `baseBranch`       | Default base branch      |
| `labels`           | Default label filters    |
| `transitions`      | Board transition names   |
| `prTemplate`       | PR description template  |

### Flag Compatibility

Not all flags work on all commands. Use only the flags valid for each command type:

| Flag           | `issue list` | `issue view` | `issue create` | `issue move` | `issue comment add` |
| -------------- | :----------: | :----------: | :------------: | :----------: | :-----------------: |
| `--plain`      |     Yes      |     Yes      |       No       |      No      |         No          |
| `--no-headers` |     Yes      |      No      |       No       |      No      |         No          |
| `--raw`        |     Yes      |      No      |       No       |      No      |         No          |
| `--no-input`   |      No      |      No      |      Yes       |      No      |         No          |

### Label Usage

Use labels to filter issues when the `labels` array in config has values. Omit label flags when the array is empty.

```bash
# config.labels = ["team-alpha", "sprint-1"]
jira issue list -p {projectKey} -lteam-alpha -lsprint-1 --plain --no-headers

# config.labels = []
jira issue list -p {projectKey} --plain --no-headers
```

### Common Operations

**List issues assigned to me:**

```bash
jira issue list -p {projectKey} -a$(jira me) --plain --no-headers
```

**List issues with labels from config:**

```bash
jira issue list -p {projectKey} -l{label} --plain --no-headers
```

**View issue details:**

```bash
jira issue view {ticketId} --plain
```

**Transition issue:**

```bash
jira issue move {ticketId} "{transitions.inProgress}"
```

**Create issue:**

```bash
jira issue create -p {projectKey} -t Task -s "Summary" -b "Description" --no-input
```

For long descriptions, write content to a temp file first, then pass via stdin:

```bash
cat /tmp/description.txt | jira issue create -p {projectKey} -t Task -s "Summary" --no-input
```

**Add comment:**

```bash
jira issue comment add {ticketId} "Comment text"
```

## Full CLI Reference

For complete command documentation, see:
[dependencies/docs/jira-cli-reference.md](dependencies/docs/jira-cli-reference.md)

## Pre-flight Check (repeat for attention)

Always run the detection check at the top of this file before executing commands. Handle partial setup states — never assume full setup or no setup.
