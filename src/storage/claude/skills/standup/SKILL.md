---
name: standup
description: Read or write the user's daily standup summary in the active repo's .claude-artifacts/workflows/standup/ directory.
disable-model-invocation: true
---

# Standup

Manage daily standup summaries for the active project. Files live at `<repo>/.claude-artifacts/workflows/standup/MM-DD-week.md`, where `MM-DD` is the Sunday that starts the week.

## Critical Rules

- Modes are `show` and `write`. Each takes `daily` or `weekly`. Bare `/standup` defaults to `show daily`.
- The active repo lives in `automation.toml` next to this file. All operations target that repo's `.claude-artifacts/workflows/standup/`.
- A ticket feeds the summary if I committed to it **or** authored a Jira comment on it in the window. Both sources feed the same entry.
- Lifecycle: project-scoped, workflow type. Cleanup of files older than two weeks is handled by `dependencies/scripts/run.zsh`.

## Modes

| Invocation                     | Behavior                                                                                              |
| ------------------------------ | ----------------------------------------------------------------------------------------------------- |
| `/standup` or `/standup show daily`  | Print today's block. Missing → ask to create, fall through to `write daily` on yes.             |
| `/standup show weekly`         | Print the full current-week file. Missing → ask to create, fall through to `write weekly` on yes.     |
| `/standup write daily`         | Generate today's entry, replace today's block.                                                        |
| `/standup write weekly`        | For each weekday Mon-today, fill any missing blocks. Existing blocks are untouched.                   |

Write operations refuse on Saturday/Sunday with `Standups cover weekdays only.`

## Generating the entry

### Window

"Since the last standup":

- Tue-Fri: since 1pm yesterday
- Mon: since 1pm Friday

Compute the window start as an absolute `YYYY-MM-DD HH:MM` timestamp — JQL needs it in that form.

### Source 1: git commits

```sh
git --no-pager -C <repo_path> log --since="<window>" --author="$(git -C <repo_path> config user.email)" --no-merges --pretty=format:'%h %s'
```

### Source 2: Jira comments I authored

Skip this source silently if `<repo_path>/.claude/skills/jira/config.json` is missing — the project isn't jira-configured. Fall back to commits only.

Otherwise:

1. Read `projectKey` and `email` from that config.
2. List candidate tickets:

   ```sh
   jira issue list -p {projectKey} -q '(assignee = currentUser() OR reporter = currentUser() OR watcher = currentUser()) AND updated >= "<window-start>"' --plain --no-headers
   ```

3. For each candidate, fetch recent comments:

   ```sh
   jira issue view {ticketId} --comments 10 --plain
   ```

4. Keep only comments authored by `email` whose timestamp falls inside the window. The result is `{ticket → [my-comments-in-window]}`. A ticket lands here even with zero commits.

If a `jira` call fails for any reason other than missing config, log the failure to stderr and continue with whatever was gathered — never block the entry on Jira.

### Summary rules

Audience is non-engineers in standup — this is a spoken update, not a ticket dump. Write 1-3 first-person sentences describing what I actually did, grouped by theme rather than one line per ticket.

- Cluster related tickets into a single thread of work. Several commits or comments across tickets that serve one goal become one phrase ("fixed and deployed new smoke tests for common pain points like GA4"), not three separate items.
- Separate shipped from in-progress. Lead with what landed, then what's still underway ("…and I'm working on annotating two forms"). Judge which is which from ticket status and commit verbs; when unsure, describe it as in-progress.
- Comment-only tickets contribute the substance of my comment — the decision, finding, blocker, or handoff — folded into the narrative.
- Plain language: describe the effect, not the mechanism. Translate tool and library names into what they do, but a short clarifying parenthetical is fine when it helps ("smoke tests (AWS Synthetics)", "Python linter").
- No ticket IDs, PR numbers, version numbers, file paths, or function names in the prose — it gets read aloud.
- Trivial commits (formatting, typo fixes, merges) earn no mention unless they were the day's actual work.

After the summary, on a new line, add a single `**Heads-up:**` line when the day's work will land on other people. Triggers: new alarms or pages going live, breaking API/schema/config changes, shared-dependency bumps, deploy windows starting, anything someone else needs to know before their next workday. Omit the line entirely when there is nothing to flag — never write "Heads-up: none."

If no commits and no in-window comments, the entry is: `No activity since last standup.`

## File format

Filename `MM-DD-week.md` (Sunday-anchored). One block per weekday:

```
## Mon 04-29
Fixed and deployed new smoke tests (AWS Synthetics) covering common pain points like GA4, and I'm working on annotating two intake forms.

**Heads-up:** new CloudWatch alarm for credit drift goes live tomorrow — on-call may see a Jira ticket auto-filed if it trips overnight.

## Tue 04-30
Turned a noisy warning log into a real alarm with a daily summary ticket, and started pinning our third-party automation steps to fixed versions.
```

## Write workflow

1. Resolve `repo_path` from `automation.toml`.
2. Ensure `.claude-artifacts/` is in `$(git -C <repo_path> rev-parse --git-common-dir)/info/exclude` (append if absent — idempotent).
3. Compute current Sunday MM-DD → `<repo_path>/.claude-artifacts/workflows/standup/MM-DD-week.md`.
4. Generate the entry per the rules above.
5. Replace today's `## Day MM-DD` block, or insert in chronological order if absent. For `write weekly`, only insert blocks for days that have no existing entry.
6. Print the written entry to stdout. Keep stdout clean — no decorative output. The launchd trigger (`run.zsh`) captures stdout.

## Show workflow

1. Resolve the same path.
2. If the file is missing, or `show daily` and today's block is absent, ask `Create today's entry now? [y/N]`. On yes, run the write workflow for the same scope.
3. Otherwise print the requested scope verbatim from disk.
4. In an interactive session, after printing today's block on `show daily`, invite refinements (see Conversational editing). Skip this on `show weekly` and on the headless automation path.

## Conversational editing

Interactive sessions only — never on the headless `write daily` automation path, which keeps stdout clean.

After showing today's entry, close with one line: `Want to tweak it? Tell me what's off.` If I reply with a correction — "I haven't deployed yet, still testing", "drop the forms, that's tomorrow", "merge the last two into one" — rewrite today's block to match, save it back to the week file, and reprint the updated block. Keep taking edits until I'm done. Only today's block changes; leave other days untouched.
