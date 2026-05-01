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

Window for "since the last standup":

- Tue-Fri: since 1pm yesterday
- Mon: since 1pm Friday

List commits with:

```sh
git --no-pager -C <repo_path> log --since="<window>" --author="$(git -C <repo_path> config user.email)" --no-merges --pretty=format:'%h %s'
```

Format the entry as a bulleted list. The audience is non-engineers in standup — write so a product manager understands without context.

- One bullet per Jira ticket. Group commits under their ticket key.
- Shape: `- TICKET-### — what shipped or moved, in plain language.`
- Translate tool and library names into what they do. `ruff` → "Python linter", `hypothesis` → "property-based test library", `rsync` → "file sync tool". When in doubt, describe the effect, not the tool.
- Drop PR numbers, version numbers, file paths, function names, and other engineer-only identifiers.
- Commits with no Jira key: group under a final `- Misc — …` bullet, or omit if trivial.

After the bullets, on a new line, add a single `**Heads-up:**` line when the day's work will land on other people. Triggers: new alarms or pages going live, breaking API/schema/config changes, shared-dependency bumps, deploy windows starting, anything someone else needs to know before their next workday. Omit the line entirely when there is nothing to flag — never write "Heads-up: none."

If no commits, the entry is a single bullet: `- No activity since last standup.`

## File format

Filename `MM-DD-week.md` (Sunday-anchored). One block per weekday:

```
## Mon 04-29
- STAX-1431 — fixed a flaky nightly test that was masking real failures
- STAX-1256 — locked third-party automation steps to specific versions so a hijacked one cannot run in our pipeline

**Heads-up:** new CloudWatch alarm for credit drift goes live tomorrow — on-call may see a Jira ticket auto-filed if it trips overnight.

## Tue 04-30
- STAX-1282 — turned an existing warning log into a real alarm with a daily summary ticket
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
