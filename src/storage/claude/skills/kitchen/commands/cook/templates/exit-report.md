# Exit report

The user skims this to decide whether to merge. What is still theirs to decide is on the order's [Left for you](../stations/left-for-you.md) list, not here; everything else is in the PR. Don't re-narrate the diff.

**At most 8 lines. Lead with the outcome in one sentence.** Longer means you're reporting instead of summarizing.

- **Line 1 (required):** what the user can now do, or the decision that's theirs, in their words, not the ticket's.
- **Then only what changes their next move:** a deviation from plan, a caveat that limits the result, how the visible outcome was confirmed if it isn't obvious, or the one thing only they can verify (look-and-feel, a taste/business call). Skip any that don't apply.
- Plain language. No internal vocabulary, no section labels, no diff-stat.
- Build, tests, and a clean review are preconditions for being here. Never list them. If one failed you're not exiting, you're fixing it.
- Anything still needing the user's decision leaves as an item on the order's [Left for you](../stations/left-for-you.md) list, never as a line here. A sentence in a report reads as a decision already taken; a task reads as open, which is what it is. Name a disposition here only when it is closed: an existing ticket's key, or a thing you fixed. Never a key you filed unasked.

End with the PR URL on its own line.

### Example

> **You can now change only your own data.** Passing someone else's id in the URL 403s where it used to succeed. Routes read identity from the session, so the ownership guard is gone.
>
> Nothing for you to check by hand.
>
> https://github.com/example/repo/pull/123
