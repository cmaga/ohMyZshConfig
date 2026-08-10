---
name: jira
description: JIRA ticket management using jira-cli. Use whenever the user wants to interact with jira, create tickets, transition issues, list sprints, or any Jira-related task.
---

# JIRA Integration

Manage JIRA tickets using jira-cli by ankitpokhrel.

## Generic Jira Guidance

- If jira tickets need to be linked or are related this needs to be done explicitly through jira. Adding tickets to descriptions is not enough.
- When creating a ticket try to keep it problem and outcome oriented, provide enough context so that anyone can read the ticket and know exactly what needs to be done and leave the implementation up to them. The exception is if we have done our due diligence the user, is asked and explicitly decides to provide a recommended implementation.

## Configuration Gate

Setup establishes four prerequisites — jira-cli installed, `config.json`,
`.jira-config.yml`, and a token in `~/.netrc` — plus one correctness invariant:
`project.type` matches the real project. Once setup completes these hold, so do
**not** re-run the full battery on every invocation.

> **Path convention:** All file paths in this skill are relative to the **project root**
> (the git repository root / current working directory where Claude is invoked).
> They are NOT relative to the skill definition directory (`~/.claude/skills/jira/`).

### Normal path

Reading `<project-root>/.claude/skills/jira/config.json` is already mandatory
before any command (see "Load Config"). That read **is** the gate:

- **Config loads** → proceed. Trust that setup wired up the rest.
- **Config missing** → the project was never set up. Hard stop and route to setup
  (message below). Don't run the detection battery first.

### On command failure

Branch on the error — the two classes have different fixes:

- **Missing prerequisite** — `jira: command not found`, "config not found", HTTP
  401, or a hang despite `--no-input`. Run the **Full detection battery**, then
  route to setup.
- **Field rejection** — Jira names a field it will not accept, e.g. `Field
  'customfield_10014' cannot be set. It is not on the appropriate screen, or
  unknown.` Every prerequisite is present and the config *values* are wrong. Run
  battery check 5 and correct `.jira-config.yml`. Never route this to setup —
  setup rewrites the same values. Never work around it with raw REST calls.

If all five checks pass and the command still fails, report the API's own error
verbatim and stop.

### Full detection battery (setup verification & failure diagnosis only)

Not for routine invocations. Run during setup's final verify, or to diagnose a
command failure above. Check in order (paths relative to the project root unless
stated otherwise):

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

5. **`project.type` matches the real project?** — existence is not correctness.
   The config value must equal the project's `style` from the API; a mismatch
   makes jira-cli send epic fields the project rejects (see Step 4).

   `HOST` is `server` from `config.json` without its scheme; `PROJECT_KEY` is
   `projectKey`. `curl -n` reads the same `~/.netrc` token the wrapper uses.

   ```bash
   curl -s -n "https://${HOST}/rest/api/3/project/${PROJECT_KEY}" | jq -r '.style'
   grep -A2 '^project:' .claude/skills/jira/.jira-config.yml | grep 'type:'
   ```

   Both must read `next-gen`, or both `classic`. Fix the config, not the project.

### Routing to setup

Hard stop. Do not attempt workarounds or fallbacks. Report what's missing and tell
the user:

> "Jira is not fully configured for this project. Invoke this skill in setup mode
> (e.g. 'set up jira' or 'jira setup') to complete configuration."

Then stop. Do not proceed with any jira commands.

## Setup Mode

Trigger phrases: "set up jira", "jira setup", "configure jira", "initialize the jira skill".

**Two rules, non-negotiable:**

1. Do not run `jira init`. The deployed `jira()` zsh wrapper hard-fails on any `jira` invocation until `.jira-config.yml` exists, so init cannot bootstrap through it. Claude writes `.jira-config.yml` directly.
2. Do not ask the user to paste commands via `!`. Once Claude has the values, Claude writes the files itself.

Goal: one round of questions, then done. Everything else is derived from the environment.

### Step 1: Install jira-cli and jq

```bash
command -v jira || brew install jira-cli
command -v jq   || brew install jq
```

### Step 2: Silent discovery

Run these in parallel and absorb the results — no intermediate prompts to the user:

```bash
# Atlassian hosts already known to ~/.netrc
awk '/^machine .*atlassian\.net/ {print $2}' ~/.netrc 2>/dev/null

# Sibling jira-cli configs in peer projects (file shape only — see Step 4)
find ~/dev -maxdepth 5 -path '*/.claude/skills/jira/.jira-config.yml' 2>/dev/null

# Identity hints
git config user.email; git config user.name; whoami
```

For each discovered Atlassian host, extract login and token with this **canonical recipe** — do not roll your own awk; a sloppy variant produced a phantom 401 in a past session:

```bash
HOST=<discovered-host>
awk -v host="$HOST" '
  $1=="machine" {f=($2==host)?1:0; next}
  f && $1=="login"    {print "login=" $2}
  f && $1=="password" {print "password=" $2}
' ~/.netrc
```

Then validate the token before trusting it:

```bash
curl -s -o /dev/null -w "%{http_code}\n" -u "${EMAIL}:${TOKEN}" \
  "https://${HOST}/rest/api/3/myself"
# 200 = good. 401 = bad token; treat as "no token" and proceed to Step 5.
```

If a sibling `.jira-config.yml` matches the discovered host, read it — it supplies the file's *shape* in Step 4, never its project-specific values.

### Step 3: Ask once

Show a short summary of what was discovered (host, email, username, sibling template, token status), then issue a **single `AskUserQuestion` call** for only what could not be derived. Standard minimum:

- **Project key** — user types via "Other" (e.g., `EN`, `STAX`)
- **Transitions preset** — offer:
  - `To Do / In Progress / In Review / Done`
  - `Backlog / Selected for Development / In Progress / In Review / Done`
  - Other (user types a custom mapping)

Add a server-confirmation question **only if** discovery found multiple Atlassian hosts or none. Do not ask for server/email/username/labels when discovery answered them — default `labels` to `[]` and `username` to `$(whoami)`; the user can edit `config.json` later.

### Step 4: Derive every project-specific value

Never carry `project.type`, `epic.*`, or `issue.types` over from a sibling config
— they are per-project and per-instance, and a wrong `project.type` silently
breaks every epic operation. Derive all four from the API:

```bash
# project.type — the API calls it "style"; jira-cli takes the same two values
curl -s -u "${EMAIL}:${TOKEN}" "https://${HOST}/rest/api/3/project/${PROJECT_KEY}" | jq -r '.style'

# board.{id,name,type}
curl -s -u "${EMAIL}:${TOKEN}" "https://${HOST}/rest/agile/1.0/board?projectKeyOrId=${PROJECT_KEY}" | jq '.values[0] | {id, name, type}'

# issue.types — createmeta, NOT /rest/api/3/issuetype (that returns every type in
# the instance, with ids that do not apply to this project)
curl -s -u "${EMAIL}:${TOKEN}" "https://${HOST}/rest/api/3/issue/createmeta/${PROJECT_KEY}/issuetypes" \
  | jq -r '.issueTypes[] | "\(.id) \(.name) \(.subtask)"'
```

Then the `epic:` block, which depends on the style just derived:

- **`next-gen`** — omit the `epic:` block. Team-managed projects parent through
  the built-in `parent` field; jira-cli handles it natively once the type is right.
- **`classic`** — derive the two custom field ids for this instance. They differ
  per instance; never copy them from another config.

  ```bash
  curl -s -u "${EMAIL}:${TOKEN}" "https://${HOST}/rest/api/3/field" \
    | jq -r '.[] | select(.name=="Epic Name" or .name=="Epic Link") | "\(.name) \(.id)"'
  ```

  `Epic Name` → `epic.name`, `Epic Link` → `epic.link`.

Then write both files:

- `<project-root>/.claude/skills/jira/config.json` — structure from [dependencies/templates/jira-config.json](dependencies/templates/jira-config.json), values from discovery + user answers.
- `<project-root>/.claude/skills/jira/.jira-config.yml` — a sibling config is a
  shape template only. Fill every value above from the API.

Do not write the token into either file. It lives only in `~/.netrc`.

### Step 5: Add token to ~/.netrc (only if Step 2 found none or it 401'd)

1. Direct the user to https://id.atlassian.com/manage-profile/security/api-tokens to create one.
2. Append to `~/.netrc`, using the **bare host** (no scheme, no trailing slash) so it matches what the wrapper looks up:
   ```
   machine <bare-host>
     login <email>
     password <token>
   ```
3. `[ -f ~/.netrc ] || touch ~/.netrc && chmod 600 ~/.netrc`

`~/.netrc` is user-local. Never commit it.

### Step 6: Verify

`jira me` proves auth only. Run the **Full detection battery** — all five checks,
including the `project.type` match — and setup is complete when every one passes.

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

Do not run any jira command without first reading this file. If it's missing, stop
and route to setup (see "Configuration Gate") — that absence is the gate.

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

Not all flags work on all commands. Passing an unsupported flag aborts the
command. Generated from `jira <subcommand> --help` on jira-cli 1.7.0; regenerate
it against the installed version rather than editing cells by hand:

```bash
for c in "issue list" "issue view" "issue create" "issue edit" "issue move" \
         "issue comment add" "issue worklog add" "epic add" "epic create"; do
  out=$(eval "jira $c --help" 2>&1 | sed $'s/\033\[[0-9;]*m//g')
  row="$c"
  for f in --plain --no-headers --raw --no-input; do
    grep -q -e "$f " <<<"$out" && row="$row | Yes" || row="$row | No"
  done
  echo "$row"
done
```

| Flag           | `issue list` | `issue view` | `issue create` | `issue edit` | `issue move` | `issue comment add` | `issue worklog add` | `epic add` | `epic create` |
| -------------- | :----------: | :----------: | :------------: | :----------: | :----------: | :-----------------: | :-----------------: | :--------: | :-----------: |
| `--plain`      |     Yes      |     Yes      |       No       |      No      |      No      |         No          |         No          |     No     |      No       |
| `--no-headers` |     Yes      |      No      |       No       |      No      |      No      |         No          |         No          |     No     |      No       |
| `--raw`        |     Yes      |     Yes      |      Yes       |      No      |      No      |         No          |         No          |     No     |      No       |
| `--no-input`   |      No      |      No      |      Yes       |     Yes      |      No      |         Yes         |         Yes         |     No     |      Yes      |

### Label Usage

Use labels to filter issues when the `labels` array in config has values. Omit label flags when the array is empty.

```bash
# config.labels = ["team-alpha", "sprint-1"]
jira issue list -p {projectKey} -lteam-alpha -lsprint-1 --plain --no-headers

# config.labels = []
jira issue list -p {projectKey} --plain --no-headers
```

### Mutating Commands

> **MANDATORY — applies to every `issue create`, `issue edit`, `issue comment add`,
> and `issue worklog add` below. Both rules are required to prevent session hangs;
> a missing `--no-input` has hung sessions for hours.**
>
> - Pass `--no-input`. Without it, jira-cli prompts for missing fields, opens an
>   editor, or asks "Are you sure you want to submit?" and blocks indefinitely
>   with nothing on stdin.
> - Set Bash tool `timeout: 60000`. A healthy write completes in well under a
>   second. If it exceeds, investigate — never retry without `--no-input`.

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

**Create issue under an epic:**

`-P` sets the parent at creation. This is the normal path wherever a project
requires tickets to live under an epic — parenting after the fact is a second
round trip that gets skipped.

```bash
jira issue create -p {projectKey} -t Task -s "Summary" -b "Description" -P {epicKey} --no-input
```

`-P` is the flag that exposes a wrong `project.type`: on `next-gen` jira-cli sends
the built-in `parent` field, on `classic` it sends the `epic.link` custom field.
Get the type wrong and Jira rejects the field — see "On command failure".

**Re-parent an existing issue:**

```bash
jira epic add {epicKey} {ticketId}
```

**Edit issue:**

```bash
jira issue edit {ticketId} -s "New summary" --no-input
```

To remove a label, prefix the value with `-` and attach it with `=`:
`--label=-oldlabel --label newlabel`. The `=` form is mandatory for
removals: with a space (`--label -oldlabel`) the CLI parses `-oldlabel`
as a flag, leaves `--label` empty, and hangs on an interactive prompt
even with `--no-input` (this hung a session for two hours on 2026-06-10).

**Add comment:**

```bash
jira issue comment add {ticketId} "Comment text" --no-input
```

For multi-line or long comments, pipe via stdin (still pass `--no-input`, still cap timeout):

```bash
cat /tmp/comment.txt | jira issue comment add {ticketId} --no-input
```

**Add worklog:**

```bash
jira issue worklog add {ticketId} "2h 30m" --no-input
```

With a comment:

```bash
jira issue worklog add {ticketId} "2h 30m" --comment "Implementation work" --no-input
```

## Full CLI Reference

For complete command documentation, see:
[dependencies/docs/jira-cli-reference.md](dependencies/docs/jira-cli-reference.md)

## Configuration Gate (repeat for attention)

Do not run the full detection battery on every invocation. Loading `config.json`
is the gate: if it loads, proceed; if it's missing, route to setup. Run the
detection battery only when a command fails or during setup verification.

When a command does fail, separate a **missing prerequisite** from a **wrong
config value**. Jira naming a field it will not accept (`Field 'customfield_...'
cannot be set`) is the second kind: check `project.type` against the project's
`style`, fix the config, and re-run the same jira command. Do not route it to
setup, and do not fall back to raw REST calls.
