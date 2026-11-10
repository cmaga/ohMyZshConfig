# Taskei

Amazon's tracker (also reached as SIM, `i.amazon.com`, `issues.amazon.com`). `ticket.zsh` drives it with `bdei`, a Taskei-backed CLI from the `gtei` toolbox tool that authenticates with the Midway session. It runs bdei from `.claude/ticket-provider/`, where `.beads/config.json` names the project's room, and sets `BEADS_ACTOR=$USER` so claims are made as the user's alias.

## Config

`.claude/ticket-provider/config.json`, shaped like [config.taskei.json](../dependencies/templates/config.taskei.json):

| Field | Meaning |
| --- | --- |
| `me` | The `.assignee` value `ticket.zsh raw show <KEY> --json` prints for a ticket assigned to the user: Taskei's display name, such as `Lixuan Luo` |
| `ready.labels` | Taskei tags the user's own board already filters on, empty when it filters on none; bdei calls tags labels |
| `ready.unassigned` | `true` to take only unassigned tickets |
| `ready.board` | The user's board as a Taskei URL; when set, `ticket.zsh ready` runs its `f=` filter inside the room through SIM search, the issues.amazon.com backend Taskei shares, with the Midway cookie, newest-updated first, up to 100 tickets |
| `moments.*` | A bdei status: `open`, `in_progress`, `deferred`, or `closed`; `closed` closes the ticket with the move's comment as its reason |
| `taskei.roomId` | The room's UUID |
| `taskei.prefix` | The key prefix the room's tickets carry, such as `CARD` |
| `taskei.labels` | Tags added to every ticket filed; may be empty. Room labels are not tags: after `create`, add each `labels:` ID in `ready.board`'s filter with builder-mcp `TaskeiUpdateTask` `addLabels`, so the ticket lands on the user's board |

## Setup

1. **Install bdei:** `command -v bdei || { toolbox registry add s3://buildertoolbox-registry-gtei-us-west-2/tools.json && toolbox install gtei; }`. Every call needs a valid Midway session; on an auth error ask the user to run `mwinit`.
2. **Find the room:** read a recent ticket key from the commit log (`git log -200 --format=%B | grep -oE '[A-Z][A-Z0-9]+-[0-9]+'`), then read that ticket through the builder-mcp `TaskeiGetTask` tool: its `room.id` is the room, its key prefix is the prefix. With no ticket in the log, ask the user for one.
3. **Find `me`:** take a ticket assigned to the user (`TaskeiListTasks` with `assignee: currentUser`), then after step 5 read its `.[0].assignee` with `ticket.zsh raw show <KEY> --json` and write that string exactly. With no such ticket, ask the user for their name as Taskei shows it.
4. **Ready queue and moments:** find the board the user works from instead of asking for it. Read up to 10 of the tickets the commit log names (`TaskeiGetTask`); the room label most of them carry (`localLabels`, `inheritedLabels`) scopes the board. Write it to `ready.board` as `https://taskei.amazon.dev/rooms/<roomId>/tasks?f=labels%3A<labelId>+AND+status%3AOpen&d=board` and show the user that link to confirm; ask only when no label is shared. Write `ready.labels` only from tags that board already filters on; never invent a tag, and never ask the user to tag tickets for kitchen. Set `ready.unassigned` to `false` unless the user says otherwise. Default the moments to `start: in_progress`, `review: in_progress`, `merged: closed`.
5. **Write** `config.json`, run `cd .claude/ticket-provider && bdei init -q --room <roomId> --prefix <prefix>`, and add `.claude/ticket-provider/` to `$(git rev-parse --git-common-dir)/info/exclude`.
6. **Verify:** `ticket.zsh raw ping` prints ok, `ticket.zsh get <a known key>` reads it, and `ticket.zsh ready 5` shows the user the first keys the queue would take.

## bdei behavior

- **Always cap a list.** `ready` and `list` page through the whole room unless given `--max-items` (their `--limit` is only a page size); `search` stops at `--limit`, 50 by default. `ticket.zsh` passes the caps; pass them on any `raw` list too.
- **Claiming is best-effort.** Taskei has no compare-and-swap; `bdei update --claim` refuses a ticket another actor holds, and `--if-assignee` / `--if-status` guard other writes.
- **Search hits other rooms' keys.** A result whose key has a second prefix (`CARD-CARDCTRL-710`) belongs to a linked room; read it before treating it as a duplicate.
- **No attachments.** Post the content as a comment in markdown; for a long document, link to where it lives.
- `ticket.zsh raw --help` lists every command; `raw history KEY`, `raw dep add`, and `raw children EPIC` cover what the interface does not.

## MCP fallback

bdei has no room-label, sprint, kanban board, or workflow-step filters (`ready.board` covers room labels for the ready queue), and its statuses do not reach a room's custom workflow steps (such as "Ready for Release"). For those, use the builder-mcp Taskei tools with the room from the config: `TaskeiListTasks` (`roomId`, `sprint`, `kanbanBoard`, `workflowStep`) and `TaskeiUpdateTask` (`workflowAction`, `addSprints`, `addKanbanBoards`). Every such change still carries a comment saying why (`postCommentMessage`).
