# Status

The user wants to know what the pipeline did and what waits on them. Catch them up in the shape of the [ketchup](../cook/stations/ketchup.md) station: what waits on them first, then what happened, then every call they own with what they need to make it from your reply alone.

1. **Gather.** Run `kitchen.zsh status` once; it marks everything it shows as seen, so a second run shows nothing new. Per project it lists what happened since the user last looked (merged, dropped, decided alone, promoted, notices), then the `PROMOTE`, `QUEUED`, `BLOCKED`, and `REVIEW` rows that wait on them, then a count of the rest. No project listed means none is registered: say so, offer `/kitchen open`, and stop. For each `QUEUED` and `REVIEW` row, read the order (`kitchen.zsh order get <KEY>`) and, for a PR, its live state through the `git-provider` skill, not the order's last word on it.
2. **Write the catch-up** per the ketchup station, with what `kitchen.zsh status` marked new as the point to catch up from. Each merged, dropped, promoted, or decided-alone line becomes one plain sentence on what changed for the user; a decision made alone keeps its evidence. Act on a notice only when the user asks.
3. **The calls**, one bullet each, riskiest first, with the ticket or PR link, what it changes for users, the evidence behind your pick, its risk, and your pick:
   - `QUEUED`: work that needs the user's call before it can become an order, with intake's question. A `[catering]` row is specced or planned with the user, never by the scheduler: offer to start or carry it on here with `/kitchen cook <KEY>`.
   - `BLOCKED`: a ready order that waits on a dropped one and starts only once the user brings that one back (`kitchen.zsh signoff <KEY> @<file>`) or takes it out of the waiting order's `after` (`kitchen.zsh order set <KEY> after=@<file>`).
   - `PROMOTE`: a kind of slip the gate keeps catching that nothing checks yet, with its catches indented under it. They are asked together, as one call, per [taste](../taste/taste.md) step 6's real-slip case.
   - `REVIEW`: the PR and why it waits (in parentheses on the row). The user approves on the PR and the scheduler merges it; anything else they take up in the order's own session, which `kitchen review <KEY>` on the row opens. On GitHub, where no one can approve their own PR, they comment `approve` instead. A `[catering]` PR (its spec, or its final PR to the base branch) is the exception: the user merges it themselves, and only `/kitchen cook <KEY>` acts on its comments.
4. **Act on the user's answers**, in their words:
   - An answer to a ticket in the review queue: write it to a file and run `kitchen.zsh signoff <KEY> @<file>`. The work becomes an order, and the scheduler starts it on its next pass.
   - Promotions: per taste step 6's real-slip case, from the project's folder.
   - Drop an order: write their reason to a file, run `kitchen.zsh order set <KEY> status=86 reason=@<file>`, and comment the reason on the ticket.
   - Bring a dropped one back (`kitchen.zsh order list 86` lists them): `kitchen.zsh signoff <KEY> @<file>` with their words; for a `[catering]` one, `kitchen.zsh order set <KEY> status=review-queue`, then offer `/kitchen cook <KEY>`. A parked one (its reason starts `parked:`) comes back once what parked it is fixed.
5. **When nothing happened and nothing waits**, say so in one line.
