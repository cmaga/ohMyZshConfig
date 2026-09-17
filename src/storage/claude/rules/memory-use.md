# Memory Use

Auto memory holds what has no other home: lessons from the user's corrections, the user's preferences, facts local to this user or machine, and pointers to external resources. A lesson stays in memory for as long as it keeps working.

## What Belongs Where

Write these to their home instead of memory:

| What                                                   | Home                                                                                |
| ------------------------------------------------------ | ----------------------------------------------------------------------------------- |
| Ticket status, progress, and blockers                  | Jira                                                                                |
| What merged, and when                                  | git                                                                                 |
| Decisions, constraints, architecture, and domain rules | The knowledge vault when the project has one, otherwise the project's documentation |

## How To Write Memories

### Organization

- File a lesson about a skill under a `## Skill: <name>` section of `MEMORY.md`. Create the section with the skill's first lesson, above the other sections so it stays inside the read limit.
- As a subagent, write no memory: send each skill lesson to the main session with `SendMessage` to `main`.
- File a skill lesson that arrives by message exactly like your own.

### Format

- Keep each `MEMORY.md` line to a title and a short hook; detail belongs in the topic file.
- Write a skill lesson by the bar and in the format of `~/.claude/skills/memory-review/lesson-format.md`.

### Recurrence

- When the user corrects something an existing memory already covers, append the date to that memory's `Recurrences:` line, adding the line if it is missing (e.g. `Recurrences: 2026-09-20, 2026-10-02`).
- On the third recurrence, tell the user without ending the turn — in an unattended run, carry it to the hand-back — and propose moving the lesson out of memory: name the memory, list the dates, propose its home (rule, skill, hook, or CLAUDE.md), and include draft text. For a skill lesson, recommend `/memory-review <name>` instead of drafting the edit yourself.

## Maintenance

- When Claude Code reports that `MEMORY.md` is near or over its read limit, tell the user so, and tell them that `/memory-review` is how to review memory and cut it down. Trim nothing yourself.
- Only `/memory-review` removes or rewrites a skill lesson; every other session only appends recurrences.
