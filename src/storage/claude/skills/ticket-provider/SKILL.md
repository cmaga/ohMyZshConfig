---
name: ticket-provider
description: Ticket tracker operations (Jira, Taskei) behind one interface, configured per project. Use when reading, filing, commenting on, claiming, moving, or searching tickets, when the user names Jira, Taskei, SIM, or a ticket key like ABC-123, or when setting up a project's tracker ("set up ticket provider", "set up jira", "set up taskei").
---

# Ticket Provider

Every tracker operation goes through `ticket.zsh`, so callers never name a tracker. The project's config says which one it uses; the provider's mode holds what only that tracker needs.

```bash
T=~/.claude/skills/ticket-provider/dependencies/scripts/ticket.zsh
```

Shell variables do not survive between Bash calls: start every command with that assignment. Other skills call the same script `ticket.zsh`.

## Critical Rules

- **Reach the tracker only through `$T`.** Use `$T raw ...` for an operation the interface lacks, never the provider's CLI directly: `$T` is what finds the project's config, and a bare CLI files against whichever tracker it was set up for last.
- **Every change carries a comment saying why.** A move takes its comment as an argument; a field edit through `raw` is followed by `$T comment`.

## Config

One file per project, never committed: `<main checkout>/.claude/ticket-provider/config.json`. Every worktree reaches it through git's common dir, so nothing is copied into worktrees. Setup adds `.claude/ticket-provider/` to `$(git rev-parse --git-common-dir)/info/exclude`.

| Field | Meaning |
| --- | --- |
| `provider` | `jira` or `taskei`, which picks the mode below |
| `me` | The user's display name exactly as the tracker shows an assignee; `holder` compares against it |
| `ready` | The ready queue, the user's own board, which setup finds from the tickets the commit log names: a JQL string for jira, `{"labels": [...], "unassigned": false, "board": "<url>"}` for taskei |
| `moments` | The tracker's value for each point where work moves a ticket: `start` (work begins), `review` (PR open), `merged` (PR merged) |
| `jira` / `taskei` | The provider's own fields; see its mode |

No config means the project was never set up: stop and run setup in the provider's mode. Git settings (base branch, branch and commit formats) belong to the `git-provider` skill, not here.

## Operations

`$T` with no arguments prints usage; its header lists every command. A `BODY` is literal text or `@/path/to/file`; write anything taken from a ticket or a PR to a file with the Write tool and pass `@<file>`, never inline.

| Need | Command |
| --- | --- |
| Read a ticket, every comment included | `$T get KEY` |
| Who holds it | `$T holder KEY` prints `me`, `none`, or a name |
| The ready queue | `$T ready [N]` |
| Find duplicates or related work | `$T search "TEXT" [N]` |
| Start work | `$T claim KEY` (assigns to the user, moves with `moments.start`) |
| Move it | `$T move KEY MOMENT BODY`, MOMENT one of `start`, `review`, `merged`; to take a ticket yourself use `claim`, which also assigns it |
| Comment | `$T comment KEY BODY` |
| File one | `$T create "TITLE" BODY [--parent KEY] [--type TYPE]` prints the new key |
| Relate two | `$T link KEY OTHER` |
| Attach a file | `$T attach KEY FILE`; exit 3 means the provider has none, so post the content as a comment |
| Link to it | `$T url KEY` |

Keep a ticket problem- and outcome-oriented: enough context that anyone can tell what needs doing, with the implementation left to whoever does it unless the user chose one. Relate tickets with `link`; a key in a description does not relate them.

## Modes

| Mode | Use for |
| --- | --- |
| [jira](modes/jira.md) | Setup, jira-cli rules that prevent hangs, failure triage |
| [taskei](modes/taskei.md) | Setup, bdei behavior, the MCP fallback for sprints, boards, and workflow steps |

Read the mode for setup, for any `raw` call, and whenever a command fails.
