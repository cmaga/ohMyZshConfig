# Exit report

The user skims this to decide whether to merge and what's still theirs to do. Everything else is in the PR — don't re-narrate the diff.

**≤ 8 lines. Lead with the outcome in one sentence.** Longer means you're reporting instead of summarizing.

- **Line 1 (required):** what the user can now do, or the decision that's theirs — in their words, not the ticket's.
- **Then only what changes their next move:** a deviation from plan, a caveat that limits the result, how the visible outcome was confirmed if it isn't obvious, or the one thing only they can verify (look-and-feel, a taste/business call). Skip any that don't apply.
- Plain language. No internal vocabulary, no section labels, no diff-stat.
- Build, tests, and a clean review are preconditions for being here — never list them. If one failed you're not exiting, you're fixing it.
- List every deferred item and unfixed review finding with its disposition — the follow-up ticket key, or one line flagging it for the user's decision. This is where "nothing left as prose" is enforced: a finding with no home here has none.

End with `Run cleanup <TICKET> after merge.` then the PR URL on its own line.

### Example

> **You can now change only your own data** — passing someone else's id in the URL 403s where it used to succeed. Routes read identity from the session, so the ownership guard is gone.
>
> Nothing for you to check by hand; one edge case I couldn't fold in without doubling the ticket is filed as KRAT-190.
>
> Run `cleanup KRAT-188` after merge.
>
> https://github.com/example/repo/pull/123
