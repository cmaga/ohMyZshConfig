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

Check these items in order (all paths are relative to the project root
unless stated otherwise):

1. **jira-cli installed?** — `command -v jira`
2. **Skill config exists?** — `<project-root>/.claude/skills/jira/config.json`
3. **jira-cli config exists?** — `<project-root>/.claude/skills/jira/.jira-config.yml`
4. **API token available in `~/.netrc`?** — an entry whose `machine`
   matches the bare host of the `server:` value in `.jira-config.yml`.
   Verify:

   ```bash
   server=$(awk '/^[[:space:]]*server:/ {sub(/^[[:space:]]*server:[[:space:]]*/, ""); gsub(/[[:space:]"'\'']/, ""); sub(/^https?:\/\//, ""); sub(/\/$/, ""); print; exit}' .claude/skills/jira/.jira-config.yml)
   awk -v m="$server" '$1=="machine" && $2==m {found=1} END {exit !found}' ~/.netrc
   ```

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

### Step 4: Add API token to ~/.netrc

The `jira()` zsh wrapper (deployed by this dotfiles repo) reads the API
token from `~/.netrc`, keyed by the Atlassian host. Append a block:

```
machine acme.atlassian.net
  login user@example.com
  password <api-token>
```

Use the **bare host** (no `https://`, no trailing slash) as the
`machine` value — it must match what the wrapper extracts from the
`server:` field in `.jira-config.yml` after stripping the scheme.

Ensure correct permissions:

```bash
[ -f ~/.netrc ] || touch ~/.netrc
chmod 600 ~/.netrc
```

`~/.netrc` is strictly user-local. Never track it in any repo.

### Step 5: Initialize jira-cli

Run `jira init` with `JIRA_CONFIG_FILE` set for the invocation only — no
shell export, no `.envrc`:

```bash
JIRA_CONFIG_FILE="$PWD/.claude/skills/jira/.jira-config.yml" jira init
```

`jira init` reads `JIRA_CONFIG_FILE` and writes its config directly to
that path.

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

If this returns the user's account info, setup is complete. The `jira`
command here is the shell wrapper — it looks up the per-project config
and token automatically; no env vars need to be exported.

## Commit recommendation

- **Commit** `.claude/skills/jira/config.json` and
  `.claude/skills/jira/.jira-config.yml` to the repo. Neither contains
  secrets. Committing them makes the skill work transparently in
  worktrees and for other teammates on the same project.
- **Never commit** `~/.netrc`. It lives only in the user's home.

## Working inside a worktree

If the skill is invoked inside a worktree (Cline Kanban spawns these)
and the worktree does not contain
`.claude/skills/jira/.jira-config.yml` (e.g. the file was gitignored in
the source repo or the worktree predates the commit that adds these
files), the config lives in the main checkout.

Find the main checkout:

```bash
git worktree list | awk 'NR==1 {print $1}'
```

The first entry is the main working directory. Copy the two files from
there into the current worktree so future `jira` invocations work
without navigation:

```bash
main=$(git worktree list | awk 'NR==1 {print $1}')
mkdir -p .claude/skills/jira
cp "$main/.claude/skills/jira/.jira-config.yml" .claude/skills/jira/
cp "$main/.claude/skills/jira/config.json"       .claude/skills/jira/
```

The token in `~/.netrc` is already user-global, so no token copy is
needed.

## Migration from direnv-based setup

Projects set up before this change kept the token in
`<project-root>/.envrc` and pointed jira-cli at
`.claude/skills/jira/.jira-config.yml` via `JIRA_CONFIG_FILE`. To move to
the netrc flow:

1. Read the token value out of `<project-root>/.envrc`.
2. Read the server host out of `.claude/skills/jira/.jira-config.yml`
   (or `config.json`'s `server` field), stripped of scheme and trailing
   slash.
3. Append to `~/.netrc`:
   ```
   machine <bare-host>
     login <email>
     password <token-from-.envrc>
   ```
   Ensure `chmod 600 ~/.netrc`.
4. **Leave `.envrc` in place.** It holds information you may still
   need, and the new wrapper ignores it. Do not delete it as part of
   this migration.
5. Confirm with `jira me` in the project dir.

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
