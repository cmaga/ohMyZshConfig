# jira-cli Reference

Full CLI reference for jira-cli by ankitpokhrel.

**Source:** https://github.com/ankitpokhrel/jira-cli

## Installation

```bash
brew install jira-cli
```

Or download from: https://github.com/ankitpokhrel/jira-cli/releases

## Getting Started

### Cloud Server

1. Get API token from https://id.atlassian.com/manage-profile/security/api-tokens
2. Export: `export JIRA_API_TOKEN="your-token"`
3. Run: `jira init` and select "Cloud"

### Shell Completion

```bash
jira completion --help
```

## Commands

### Issue List

```bash
# List recent issues
jira issue list

# List in plain mode (non-interactive)
jira issue list --plain

# List with no headers
jira issue list --plain --no-headers

# List in JSON format
jira issue list --raw

# List in CSV format
jira issue list --csv

# List issues assigned to me
jira issue list -a$(jira me)

# List issues by status
jira issue list -s"To Do"
jira issue list -s"In Progress"

# List by priority
jira issue list -yHigh

# List by label
jira issue list -lbackend

# List issues created in last 7 days
jira issue list --created -7d

# List issues created this week
jira issue list --created week

# Execute raw JQL
jira issue list -q "summary ~ cli"
jira issue list -q "assignee = currentUser() AND resolution = unresolved"

# Combine filters
jira issue list -yHigh -s"To Do" --created month -lbackend -a$(jira me)

# Order by rank (same as UI)
jira issue list --order-by rank --reverse

# List issues I'm watching
jira issue list -w

# List unassigned issues
jira issue list -ax

# List issues with resolution
jira issue list -R"Won't do"

# List issues NOT in status (tilde is NOT operator)
jira issue list -s~Done

# View history of issues you opened
jira issue list --history
```

### Issue View

```bash
jira issue view ISSUE-1

# Show recent comments
jira issue view ISSUE-1 --comments 5
```

### Issue Create

```bash
# Interactive create
jira issue create

# Quick create with --no-input
jira issue create -tBug -s"New Bug" -yHigh -lbug -lurgent -b"Bug description" --fix-version v2.0 --no-input

# Create with epic parent
jira issue create -tStory -s"Epic during creation" -PEPIC-42

# Create from template
jira issue create --template /path/to/template.tmpl

# Create from stdin
echo "Description from stdin" | jira issue create -s"Summary" -tTask
```

### Issue Edit

```bash
jira issue edit ISSUE-1

# Edit with flags
jira issue edit ISSUE-1 -s"New Bug" -yHigh -lbug -lurgent -CBackend -b"Bug description"

# Non-interactive edit
jira issue edit ISSUE-1 -s"New updated summary" --no-input

# Remove label (use minus)
jira issue edit ISSUE-1 --label -p2 --label p1 --component -FE --component BE
```

### Issue Assign

```bash
# Interactive assign
jira issue assign

# Assign to user
jira issue assign ISSUE-1 "Jon Doe"

# Assign to self
jira issue assign ISSUE-1 $(jira me)

# Assign to default assignee
jira issue assign ISSUE-1 default

# Unassign
jira issue assign ISSUE-1 x
```

### Issue Move/Transition

```bash
# Interactive transition
jira issue move

# Move to status
jira issue move ISSUE-1 "In Progress"

# Move with comment
jira issue move ISSUE-1 "In Progress" --comment "Started working on it"

# Move and set resolution
jira issue move ISSUE-1 Done -RFixed -a$(jira me)
```

### Issue Link

```bash
# Interactive link
jira issue link

# Link issues
jira issue link ISSUE-1 ISSUE-2 Blocks

# Add remote web link
jira issue link remote ISSUE-1 https://example.com "Example text"
```

### Issue Unlink

```bash
jira issue unlink ISSUE-1 ISSUE-2
```

### Issue Clone

```bash
# Clone an issue
jira issue clone ISSUE-1

# Clone and modify
jira issue clone ISSUE-1 -s"Modified summary" -yHigh -a$(jira me)

# Clone and replace text
jira issue clone ISSUE-1 -H"find me:replace with me"
```

### Issue Delete

```bash
jira issue delete ISSUE-1

# Delete with subtasks
jira issue delete ISSUE-1 --cascade
```

### Issue Comment

```bash
# Add comment (opens editor)
jira issue comment add ISSUE-1

# Add comment inline
jira issue comment add ISSUE-1 "My comment body"

# Internal comment
jira issue comment add ISSUE-1 "My comment body" --internal

# Comment from template
jira issue comment add ISSUE-1 --template /path/to/template.tmpl

# Comment from stdin
echo "Comment from stdin" | jira issue comment add ISSUE-1
```

### Issue Worklog

```bash
# Add worklog interactively
jira issue worklog add

# Add worklog with --no-input
jira issue worklog add ISSUE-1 "2d 3h 30m" --no-input

# Add worklog with comment
jira issue worklog add ISSUE-1 "10m" --comment "This is a comment" --no-input
```

## Epic Commands

```bash
# List epics
jira epic list

# List epics in table view
jira epic list --table

# List epics reported by me
jira epic list -r$(jira me) -sOpen

# List issues in an epic
jira epic list KEY-1

# List issues in epic with filters
jira epic list KEY-1 -ax -yHigh

# Create epic
jira epic create -n"Epic epic" -s"Everything" -yHigh -lbug -lurgent -b"Epic description"

# Add issues to epic (up to 50)
jira epic add EPIC-KEY ISSUE-1 ISSUE-2

# Remove issues from epic
jira epic remove ISSUE-1 ISSUE-2
```

## Sprint Commands

```bash
# List sprints
jira sprint list

# List sprints in table view
jira sprint list --table

# List issues in current sprint
jira sprint list --current

# List issues in current sprint assigned to me
jira sprint list --current -a$(jira me)

# List issues in previous sprint
jira sprint list --prev

# List issues in next planned sprint
jira sprint list --next

# List future and active sprints
jira sprint list --state future,active

# List issues in specific sprint
jira sprint list SPRINT_ID

# List high priority issues in sprint assigned to me
jira sprint list SPRINT_ID -yHigh -a$(jira me)

# Add issues to sprint (up to 50)
jira sprint add SPRINT_ID ISSUE-1 ISSUE-2
```

## Other Commands

```bash
# Get current user
jira me

# Open project in browser
jira open

# Open issue in browser
jira open KEY-1

# List all projects
jira project list

# List all boards
jira board list

# List releases
jira release list
jira release list --project KEY
```

## Interactive Navigation

When using interactive mode (default):

- Arrow keys or `j/k/h/l` to navigate
- `g/G` to jump to top/bottom
- `CTRL+f/b` to page down/up
- `v` to view issue details
- `m` to transition issue
- `CTRL+r` or `F5` to refresh
- `Enter` to open in browser
- `c` to copy URL
- `CTRL+k` to copy issue key
- `w` or `TAB` to toggle focus in explorer view
- `q` or `Esc` to quit
- `?` for help

## Key Flags for Scripting

| Flag           | Description                  |
| -------------- | ---------------------------- |
| `--plain`      | Non-interactive table output |
| `--no-headers` | Omit column headers          |
| `--raw`        | JSON output                  |
| `--csv`        | CSV output                   |
| `--no-input`   | Skip interactive prompts     |
| `--columns`    | Specify columns to display   |

## Multiple Projects

```bash
# Use config file via env var
JIRA_CONFIG_FILE=./local_jira_config.yaml jira issue list

# Use config file via flag
jira issue list -c ./local_jira_config.yaml
```

## JQL Reference

```sql
-- My open issues
assignee = currentUser() AND resolution = unresolved

-- Issues in current sprint
sprint in openSprints()

-- Recently updated
updated >= -7d

-- By status
status = "In Progress"

-- By label
labels IN (backend, api)

-- Unassigned
assignee IS EMPTY

-- Created this week
created >= startOfWeek()

-- High priority
priority IN (High, Highest)

-- Combined
assignee = currentUser() AND status != Done AND priority = High
```
