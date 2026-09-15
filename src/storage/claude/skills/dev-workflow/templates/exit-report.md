# Exit report

The user skims this to decide whether to merge. What is still theirs to decide is on the [loose-end tracker](../common/exit.md#the-loose-end-tracker), not here; everything else is in the PR — don't re-narrate the diff.

**≤ 8 lines. Lead with the outcome in one sentence.** Longer means you're reporting instead of summarizing.

- **Line 1 (required):** what the user can now do, or the decision that's theirs — in their words, not the ticket's.
- **Then only what changes their next move:** a deviation from plan, a caveat that limits the result, how the visible outcome was confirmed if it isn't obvious, or the one thing only they can verify (look-and-feel, a taste/business call). Skip any that don't apply.
- Plain language. No internal vocabulary, no section labels, no diff-stat.
- Build, tests, and a clean review are preconditions for being here — never list them. If one failed you're not exiting, you're fixing it.
- Anything still needing the user's decision leaves as a task on the [loose-end tracker](../common/exit.md#the-loose-end-tracker), never as a line here. A sentence in a report reads as a decision already taken; a task reads as open, which is what it is. Name a disposition here only when it is closed — an existing ticket's key, or a thing you fixed. Never a key you filed unasked.

End with `Run cleanup <TICKET> after merge.` then the PR URL on its own line.

An unattended run already merged, deployed, and cleaned up. Drop the cleanup line, say where the change is now live, and give the merged PR URL.

The run that finishes a hand-walked spec's **last** component says the spec is complete on its integration branch once this PR merges, and names what closing it takes — a PR into the project's base branch and a worktree on the integration branch to run it from — as the user's call to make, not a thing already done.

A component inside a [chain](../common/spec-run.md) has merged nothing and deployed nothing — its reader is the chain parent, not the user. Drop the cleanup line, and add the one thing the parent cannot reconstruct: **how to exercise this component by hand**, in steps someone can replay on the integration branch. The chain collapses those into the list the user tests before merging, and nobody else will be alive to write it.

### Example

> **You can now change only your own data** — passing someone else's id in the URL 403s where it used to succeed. Routes read identity from the session, so the ownership guard is gone.
>
> Nothing for you to check by hand.
>
> Run `cleanup KRAT-188` after merge.
>
> https://github.com/example/repo/pull/123
