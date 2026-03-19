---
name: jira
description: JIRA ticket management using jira-cli. Use whenver the user wants to interact with jira.
---

# JIRA Integration

Manage JIRA tickets using jira-cli by ankitpokhrel.

## Steps

### Step 1: Check Configuration

Check if `.cline-project/skills/jira/config.json` exists in the project.

- **If config exists**: Proceed to Step 3 (Execute Commands)
- **If config missing**: Proceed to Step 2 (Setup)

### Step 2: Setup (First Time)

Guide the user through setup conversationally:

#### 2.1 Install jira-cli

```bash
brew install jira-cli
```

#### 2.2 Configure API Token

1. Provide the user this link: https://id.atlassian.com/manage-profile/security/api-tokens
2. Ask the user to create a token and paste it in the conversation
3. Once received, create `.envrc` in the project root:

```bash
export JIRA_API_TOKEN="<token-from-user>"
export JIRA_CONFIG_FILE=".cline-project/skills/jira/.jira-config.yml"
```

4. Ensure `.envrc` is in `.gitignore`:

```bash
grep -q '^\\.envrc$' .gitignore || echo '.envrc' >> .gitignore
```

5. If user has direnv installed, run `direnv allow` to load the token and config path.

#### 2.3 Create Config File

Ask user for:

- **server**: Atlassian server URL (e.g., https://company.atlassian.net)
- **email**: Login email for JIRA
- **installationType**: Usually "cloud" for Atlassian Cloud
- **username**: For branch naming (e.g., cmagana)
- **projectKey**: JIRA project key (e.g., STAX)
- **labels**: Default labels to filter by (optional - leave empty array to show all)
- **transitions**: Status names for their board

Create `.cline-project/skills/jira/config.json` using template:
[dependencies/templates/jira-config.json](dependencies/templates/jira-config.json)

#### 2.4 Create jira-cli Config File

Create a project-specific jira-cli config file at `.cline-project/skills/jira/.jira-config.yml`.

Use the template and replace values from the user's answers:
[dependencies/templates/jira-cli-config.yml](dependencies/templates/jira-cli-config.yml)

Example with user values:

```yaml
server: https://company.atlassian.net
login: user@company.com
project:
  key: STAX
  type: classic
board:
  id: 0
  name: ""
  type: ""
epic:
  name: Epic Name
  link: Epic Link
installation: cloud
```

**Note:** This creates a per-project config instead of using `jira init` which only supports a single global config. This allows working with multiple JIRA projects simultaneously.

#### 2.5 Verify Connection

```bash
jira me -c .cline-project/skills/jira/.jira-config.yml
```

If using direnv with `JIRA_CONFIG_FILE` exported, you can simply run:

```bash
jira me
```

### Step 3: Execute Commands

When config exists, use it to construct jira-cli commands.

**Important:** Always use the `-c` flag to specify the project-specific config file:

```bash
jira <command> -c .cline-project/skills/jira/.jira-config.yml [options]
```

If the user has direnv configured with `JIRA_CONFIG_FILE`, the flag can be omitted.

#### Config Reference

Location: `.cline-project/skills/jira/config.json`

| Field              | Description                           |
| ------------------ | ------------------------------------- |
| `server`           | Atlassian server URL                  |
| `email`            | Login email for JIRA                  |
| `installationType` | Installation type (cloud or server)   |
| `username`         | User identifier for branch naming     |
| `projectKey`       | JIRA project key                      |
| `branchFormat`     | Template for git branch names         |
| `commitFormat`     | Template for commit messages          |
| `baseBranch`       | Default base branch (e.g., main)      |
| `labels`           | Default labels to filter issues       |
| `transitions`      | Map of transition names for the board |
| `prTemplate`       | Template for PR descriptions          |

#### Key Flags for Cline

Always use these flags for parseable output:

| Flag           | Purpose                  |
| -------------- | ------------------------ |
| `--plain`      | No pager                 |
| `--no-headers` | Omit column headers      |
| `--raw`        | JSON output              |
| `--no-input`   | Skip interactive prompts |

#### Label Usage

Labels should always be used to filter issues **unless** the `labels` array is empty in the config file.

- **If `labels` has values**: Always include `-l{label}` flag for each label
- **If `labels` is empty `[]`**: Do not include label flags (show all issues)

Example with labels:

```bash
# config.labels = ["team-alpha", "sprint-1"]
jira issue list -c .cline-project/skills/jira/.jira-config.yml -p {projectKey} -lteam-alpha -lsprint-1 --plain --no-headers
```

Example without labels (show all):

```bash
# config.labels = []
jira issue list -c .cline-project/skills/jira/.jira-config.yml -p {projectKey} --plain --no-headers
```

#### Common Operations

All examples below use `-c` flag. Omit if using direnv with `JIRA_CONFIG_FILE`.

**List issues assigned to me:**

```bash
jira issue list -c .cline-project/skills/jira/.jira-config.yml -p {projectKey} -a$(jira me -c .cline-project/skills/jira/.jira-config.yml) --plain --no-headers
```

**List issues with labels from config:**

```bash
jira issue list -c .cline-project/skills/jira/.jira-config.yml -p {projectKey} -l{label} --plain --no-headers
```

**View issue details:**

```bash
jira issue view -c .cline-project/skills/jira/.jira-config.yml {ticketId} --plain
```

**Transition issue:**

```bash
jira issue move -c .cline-project/skills/jira/.jira-config.yml {ticketId} "{transitions.inProgress}" --plain
```

**Create issue:**

```bash
jira issue create -c .cline-project/skills/jira/.jira-config.yml -p {projectKey} -t Task -s "Summary" -b "Description" --no-input --plain
```

**Add comment:**

```bash
jira issue comment add -c .cline-project/skills/jira/.jira-config.yml {ticketId} -b "Comment text" --plain
```

## Full CLI Reference

For complete command documentation, see:
[dependencies/docs/jira-cli-reference.md](dependencies/docs/jira-cli-reference.md)
