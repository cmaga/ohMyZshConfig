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
| `/standup write daily`         | Generate today's paragraph, replace today's block.                                                    |
| `/standup write weekly`        | For each weekday Mon-today, fill any missing blocks. Existing blocks are untouched.                   |

Write operations refuse on Saturday/Sunday with `Standups cover weekdays only.`

## Generating a paragraph

Window for "since the last standup":

- Tue-Fri: since 1pm yesterday
- Mon: since 1pm Friday

List commits with:

```sh
git --no-pager -C <repo_path> log --since="<window>" --author="$(git -C <repo_path> config user.email)" --no-merges --pretty=format:'%h %s'
```

Summarize as one paragraph readable aloud. Focus on what was done; mention blockers or in-progress only if evident. If no commits, the paragraph is `No activity since last standup.`

## File format

Filename `MM-DD-week.md` (Sunday-anchored). One block per weekday:

```
## Mon 04-29
<paragraph>

## Tue 04-30
<paragraph>
```

## Write workflow

1. Resolve `repo_path` from `automation.toml`.
2. Ensure `.claude-artifacts/` is in `$(git -C <repo_path> rev-parse --git-common-dir)/info/exclude` (append if absent — idempotent).
3. Compute current Sunday MM-DD → `<repo_path>/.claude-artifacts/workflows/standup/MM-DD-week.md`.
4. Generate the paragraph(s) per the rules above.
5. Replace today's `## Day MM-DD` block, or insert in chronological order if absent. For `write weekly`, only insert blocks for days that have no existing entry.
6. Print the written paragraph(s) to stdout. Keep stdout clean — no decorative output. The launchd trigger (`run.zsh`) captures stdout.

## Show workflow

1. Resolve the same path.
2. If the file is missing, or `show daily` and today's block is absent, ask `Create today's entry now? [y/N]`. On yes, run the write workflow for the same scope.
3. Otherwise print the requested scope verbatim from disk.
