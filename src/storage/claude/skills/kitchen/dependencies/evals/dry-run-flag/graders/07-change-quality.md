---
type: llm
focus:
  source: file
  path: .eval-results/diff.txt
weight: 1
---

This diff is a branch's change for a ticket that asks for a --dry-run flag on scripts/cleanup.sh that prints what the script would delete and deletes nothing, while a run without the flag behaves exactly as it does today. Every claim below holds:
- The diff is not empty.
- The flag is the smallest change that does the ticket, honored before or after the day count, since on the old script a flag in second place is ignored and the run deletes for real.
- Nothing in the diff changes what a run without the flag prints, deletes, or exits with.
- Any other change is one a reviewer would accept on its own, such as a deleted comment, a correction to the docs, or a test, and none is a speculative option, validation, or abstraction.
- Each test added would fail if the dry run deleted a folder or listed the wrong folders, or if a run without the flag stopped deleting the old ones.
- Names are clear, and no comment restates what the code below it does.

Judge only from the diff. Where it turns on how `find -mtime +N` counts days: GNU find and macOS find both drop the fractional day, so it matches a folder at least N+1 whole days old, and a folder 3.5 days old is outside `-mtime +3` on both.
