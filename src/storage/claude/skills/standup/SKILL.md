---
name: standup
description: Draft the daily standup summary, capture post-standup items and notes, and post reviewed time entries to Harvest. Manual weekday ritual; slash-invoked only.
disable-model-invocation: true
---

# Standup

Draft a plain-language summary of recent work, let me review and tweak it, and on `done` post it to Harvest as that day's time entry. The standup file (summary + post-standup + notes, for the meeting) lives at `<repo>/.claude-artifacts/workflows/standup/MM-DD-week.md`, Sunday-anchored.

## Critical Rules

- This posts **real (unsubmitted) Harvest entries**. In interactive mode nothing is posted until I type `done`.
- Fill every **unposted day from yesterday back to the most recent day already in Harvest** — normally just yesterday, more if I missed days. Skip days with no activity.
- Entry hours are a **7h placeholder**; the Sunday reconciler sets final hours. Never post hours ≥8 — that value is the manual-entry marker.
- Post through `$HOME/.local/share/cmagana-automations/timesheet/harvest-post.zsh` — it resolves Harvest credentials and the project/task.
- `auto` mode is headless (the Sunday reconciler calls it): gather and post without review, and **never overwrite a day that already has a note**.

## Modes

| Invocation              | Behavior                                                                                  |
| ----------------------- | ----------------------------------------------------------------------------------------- |
| `/standup`              | Draft summaries for all unposted days (last entry → yesterday), show them, take tweaks; post on `done`. |
| `/standup YYYY-MM-DD`   | Same, for one specific day (manual backfill).                                              |
| `/standup auto`         | Headless: gather and post all unposted days, no review. The Sunday reconciler calls this.  |
| `/standup show [weekly]`| Print summaries (+ post-standup + notes) from the file. No gathering, no posting.          |

## Which days to fill

1. Resolve `repo_path` from `automation.toml` next to this file.
2. Look at the last ~10 days ending **yesterday**. A day is **unposted** if Harvest has no entry for it yet (the reconciler's `harvest-post.zsh` checks this; you can also list recent entries to see the gap).
3. Fill each unposted day that has activity. Leave days that already have an entry untouched — `harvest-post.zsh` without `--force` preserves them, so reviewed and manual days are never clobbered.

Normally only yesterday is unposted. If I missed standups, the gap (e.g., Monday + Tuesday) all fills at once, each reviewable. On Sunday the reconciler's `auto` run fills Friday + Saturday this way.

## Gathering a day's work

For day `D` (`YYYY-MM-DD`):

```sh
git --no-pager -C <repo_path> log --since="D 00:00:00" --until="D 23:59:59" --author="$(git -C <repo_path> config user.email)" --no-merges --pretty=format:'%h %s'
```

If `<repo_path>/.claude/skills/jira/config.json` exists, also gather Jira activity dated `D` — comments I authored on `D` and tickets I resolved on `D` (read `projectKey`/`email` from that config; JQL `resolved >= "D 00:00" AND resolved <= "D 23:59"`). Skip Jira silently if the config is missing. If a Jira call fails, log to stderr and continue with commits.

If a day has no commits and no Jira activity, it has no entry — skip it.

## Summary rules

Audience is non-engineers in standup — a spoken update, not a ticket dump. Write 1-3 first-person sentences describing what I did that day, grouped by theme rather than one line per ticket.

- Cluster related tickets into a single thread of work, not three separate items.
- Plain language: describe the effect, not the mechanism. Translate tool names into what they do; a short clarifying parenthetical is fine ("smoke tests (AWS Synthetics)").
- No ticket IDs, PR numbers, version numbers, file paths, or function names.
- Trivial commits (formatting, typo fixes, merges) earn no mention unless they were the day's actual work.

## Interactive flow (`/standup` or `/standup <date>`)

1. Determine the unposted day(s) and gather each.
2. Draft each day's summary and print it, newest first:

   ```
   ## Wed 06-17
   Fixed the GA4 deploy check and shipped two new library forms.
   ```

3. Take my tweaks conversationally (see Conversational editing), including post-standup items and notes.
4. On **`done`**, for each day: write its block to the week file, then post to Harvest:

   ```sh
   $HOME/.local/share/cmagana-automations/timesheet/harvest-post.zsh <D> --note "<summary>" --force
   ```

   `--force` makes my reviewed note authoritative. Hours stay at the placeholder (or my manual value, untouched). Print what was posted.

## Auto flow (`/standup auto`, headless)

For each unposted day with activity: gather, draft the summary, write the file block, and post **without `--force`**:

```sh
$HOME/.local/share/cmagana-automations/timesheet/harvest-post.zsh <D> --note "<summary>"
```

Fill-only: it sets the note only if the day has none, so a reviewed note is never overwritten. No prompts, no edit invite — keep stdout to one status line per day.

## Post-standup and Notes (interactive only)

Two user-authored sections per block, below the summary, in this order:

- **Post standup** — questions or points to raise at standup.
- **Notes** — free-form notes captured during standup.

I fill them on request; they are never auto-generated and never posted to Harvest.

## Conversational editing (interactive only)

After showing the draft, close with: `Want to tweak it? Tell me what's off, or "done" to post.` Then:

- Corrections ("I haven't deployed yet", "merge the last two") rewrite that day's summary.
- "bring up …" / "ask about …" appends a bullet to **Post standup**.
- "note: …" appends a bullet to **Notes**.
- **`done`** writes the file and posts to Harvest (see Interactive flow step 4).

Only the days in this session change; leave other days untouched.

## File format

Filename `MM-DD-week.md` (Sunday-anchored). One block per day:

```
## Wed 06-17
Fixed the GA4 deploy check and shipped two new library forms.

**Post standup:**
- ask whether the canary should page on-call or just file a ticket

**Notes:**
- signup form has two hidden fields to confirm with design
```

`auto` mode writes only the summary line (no post-standup/notes).

## Show workflow

1. Resolve the path. If the file or the requested block is missing, say so.
2. `show` prints today's summary (+ its post-standup/notes if present); `show weekly` prints each day's `## Day MM-DD` header and summary. Read verbatim from the file — no gathering, no posting.
