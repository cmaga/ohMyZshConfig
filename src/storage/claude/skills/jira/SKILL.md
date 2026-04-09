---
name: jira
description: JIRA ticket management using jira-cli. Use whenever the user wants to interact with jira, create tickets, transition issues, list sprints, or any Jira-related task.
---

# JIRA Integration

Manage JIRA tickets using jira-cli by ankitpokhrel.

## Pre-flight Check

Run this check at the start of **every invocation** to detect setup state and route accordingly.

> **Path convention:** All file paths in this skill are relative to the **project root**
> (the git repository root / current working directory where Claude is invoked).
> They are NOT relative to the skill definition directory (`~/.claude/skills/jira/`).

### Detection

Check these items in order (all paths are relative to the project root):

1. **jira-cli installed?** — `command -v jira`
2. **API token available?** — `<project-root>/.envrc` exists with `JIRA_API_TOKEN`
3. **Skill config exists?** — `<project-root>/.claude/skills/jira/config.json`
4. **jira-cli config exists?** — file exists at the path specified by `$JIRA_CONFIG_FILE` (read from `.envrc`)

### Routing

**If ALL checks pass** → Load config, execute commands (see "Execute Commands" below).

**If ANY check fails** → Hard stop. Do not attempt workarounds or fallbacks. Report which
check(s) failed and tell the user:

> "Jira is not fully configured for this project. Invoke this skill in setup mode
> (e.g. 'set up jira' or 'jira setup') to complete configuration."

Then stop. Do not proceed with any jira commands.

## Setup Mode

Setup mode is triggered when the user explicitly asks to set up or configure jira
(e.g. "set up jira", "jira setup", "configure jira for this project").

Walk through these steps conversationally, asking the user for each piece of information.

### Step 1: Install jira-cli

Skip if `command -v jira` succeeds.

```bash
brew install jira-cli
```

Verify: `command -v jira`

### Step 2: Collect Configuration

Ask the user for each of these values conversationally. Present each question one at a time
or in a natural grouping:

- **server**: Atlassian URL (e.g., `https://company.atlassian.net`)
- **email**: Login email
- **installationType**: Usually "cloud"
- **username**: For branch naming (e.g., cmagana)
- **projectKey**: JIRA project key (e.g., STAX)
- **labels**: Default label filters (empty array if none)
- **transitions**: Status names for their board (backlog, inProgress, inReview, done, etc.)
- **API token**: Direct the user to https://id.atlassian.com/manage-profile/security/api-tokens to create one, then ask them to paste it

### Step 3: Write Skill Config

Create `<project-root>/.claude/skills/jira/config.json` using the collected values.
Use the template at [dependencies/templates/jira-config.json](dependencies/templates/jira-config.json)
as the structure, substituting the user's values.

### Step 4: Create .envrc

Create `<project-root>/.envrc` with:

```bash
export JIRA_API_TOKEN="<token-from-user>"
export JIRA_CONFIG_FILE="$PWD/.claude/skills/jira/.jira-config.yml"
```

Add `.envrc` to `.gitignore`:

```bash
grep -q '^\\.envrc$' .gitignore || echo '.envrc' >> .gitignore
```

Load the environment:

```bash
# If direnv is installed:
direnv allow

# Otherwise:
source .envrc
```

Verify both vars are set:

```bash
echo "TOKEN=${JIRA_API_TOKEN:+set}" && echo "CONFIG=${JIRA_CONFIG_FILE:+set}"
```

### Step 5: Initialize jira-cli

Ensure `.envrc` is loaded first, then run:

```bash
jira init
```

`jira init` reads `JIRA_CONFIG_FILE` and writes its config directly to that path.

During init, the following prompts appear. Enter the values collected in Step 2:

| Prompt              | What to enter                                         |
| ------------------- | ----------------------------------------------------- |
| Installation type   | Select "Cloud" (or the value from `installationType`) |
| Link to Jira server | Enter the `server` URL                                |
| Login email         | Enter the `email`                                     |
| Default board       | Select the appropriate board for the project          |
| Default project     | Enter the `projectKey`                                |

After init completes, verify the config was written:

```bash
test -f "$JIRA_CONFIG_FILE" && echo "OK" || echo "MISSING"
```

### Step 6: Verify Connection

```bash
jira me
```

If this returns the user's account info, setup is complete.

## Execute Commands

### Load Config (mandatory)

Before running any command, read `<project-root>/.claude/skills/jira/config.json` and substitute all `{placeholder}` values in commands with the corresponding config values.

**Jira CLI flags** (substitute into every relevant command):

- `-p {projectKey}` -- every `jira issue` command
- `-l{label}` for each entry in `config.labels` -- on `issue create` and `issue list`. Omit if the array is empty
- `config.transitions.<status>` -- use the mapped string as the target on `issue move`

**Git workflow** (substitute when creating branches, commits, or PRs):

- `branchFormat` -- interpolate `{username}`, `{ticketId}`, `{description}` to build branch names
- `commitFormat` -- interpolate `{ticketId}`, `{message}` to build commit messages
- `baseBranch` -- use as the base ref when creating feature branches
- `prTemplate` -- interpolate `{ticketId}` and use as the PR description body

Do not run any jira command without first reading this file.

### Config Reference

Location: `<project-root>/.claude/skills/jira/config.json`

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

### Non-interactive Output

jira-cli does not support `--no-pager`. For non-interactive, scriptable output use
`--plain` and `--no-headers`. These flags suppress the interactive TUI and produce
plain text suitable for parsing.

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
jira issue create -p {projectKey} -t Task -s "Summary" -b "Description" -l{label} --no-input
```

Include `-l{label}` for each label in `config.labels`. Omit if the array is empty.

For long descriptions, write content to a temp file first, then pass via stdin:

```bash
cat /tmp/description.txt | jira issue create -p {projectKey} -t Task -s "Summary" -l{label} --no-input
```

Include `-l{label}` for each label in `config.labels`. Omit if the array is empty.

**Add comment:**

```bash
jira issue comment add {ticketId} "Comment text"
```

## Full CLI Reference

For complete command documentation, see:
[dependencies/docs/jira-cli-reference.md](dependencies/docs/jira-cli-reference.md)

## Pre-flight Check (repeat for attention)

Always run the detection check at the top of this file before executing commands.
If any check fails, hard stop and direct the user to setup mode.
