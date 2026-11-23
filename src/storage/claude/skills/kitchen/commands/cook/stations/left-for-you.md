# Left for you

A PR is finished code: no question rides on it. The design calls that are the user's were put to them before the code, at the [chef's table](chefs-table.md). What only the user can decide after that is asked in the session when they are there (`manual` and `guided`) and decided by the escalation agent when they are not (`auto`), so an `auto` order past the chef's table reaches its PR unless it cannot run at all ([Autonomy](../../../SKILL.md#autonomy)). This is how a candidate is routed.

## Discovered issues

A problem found mid-order is routed when found, never parked as prose.

- **Fix it.** The one question is whether the fix can ride this branch, not whether it is in scope. This is the cheapest moment the fix will ever have.
- Leave it only when it genuinely cannot ride: a different subsystem, a design decision the user owns, a scope that would double the diff. If your own answer is that it rides, that answer is final: fold it. Otherwise it is a triage candidate, with your recommendation and why it could not ride. A third candidate means re-asking whether any could have been fixed.
- **Search before proposing.** `ticket.zsh search "<terms>"` through the `ticket-provider` skill, once per distinctive term, then read every close candidate with `ticket.zsh get`; search component and file names too. An existing ticket ends the matter: cite its key.
- **A fix that cannot ride becomes a ticket.** In `auto`, file it through the `ticket-provider` skill without asking, record it with `kitchen.zsh filed <KEY> <TICKET> <WHY>`, and cite it in the PR description under Approach. That is safe because a ticket enters the line only when the user takes it. In `guided`, ask the user whether to file it, as [below](#with-the-user-here).
- **Before adding a validator that refuses a configuration, grep the tests for the field it would refuse.** A defect-guard test is the record of *we tried that*.

## What qualifies

One test: **can you settle this by looking?** If yes, look, settle it, and it never reaches the user. What survives is three kinds:

- A **fix that genuinely could not ride the branch**: a discovered issue, or a review finding classed **Tech debt**.
- A review finding classed **Design**, never yours to decide alone.
- An **`[ASSUMED: ...]` that was a strategic call**, decided alone because nobody was there to ask.

Everything else fails: a finding you fixed, anything a ticket already owns, an `[ASSUMED]` settled by reading code, context with no decision attached. **If you cannot write it as a question only the user can answer, it is not one.**

## Triage

Decide what you can first. A candidate your own recommendation would fold is folded now, never sent on and never asked. The rest goes to the escalation agent (the escalation role), in one dispatch for the whole batch, told to spawn nothing and cap its return. Send each candidate with its evidence: `file:line`, the finding or marker verbatim, the ticket search result. It returns one verdict per candidate:

- **`fold`**: the fix rides this branch. It needs no decision only the user can make and does not double the diff. Never judge it on the ticket's scope or the defect's age. It names the fix.
- **`escalate`**: it cannot ride the branch, or only the user can answer it; it needs knowledge or authority only they hold. It names that, and gives its recommendation.

Apply every `fold` yourself, one commit per fold (a fixup when it corrects a branch commit), run [taste](../../taste/taste.md) step 4 on them, send the final reviewer the re-review brief as taste step 5 does, and re-run the tests the folds affect. Record each verdict with `kitchen.zsh decide`, the `file:line` or command behind it as the evidence. A candidate that turns up later goes through this same triage.

Each `escalate` then goes by the order's mode:

- **`auto`**: a fix that cannot ride is filed as a ticket and cited in the PR, as above. A Design finding or a product call is decided by the escalation agent's own recommendation, recorded with `kitchen.zsh decide`, listed in the PR description under Approach, and sets `review=true "review_why=decided alone: <the call>"`. A better design than the decided one, or a change to what the ticket says to keep, is never made: build the decided one, file the alternative as a follow-up ticket with `kitchen.zsh filed`, and cite it in the PR.
- **`co-write` and `guided`**: asked of the user, as below, a better design or a change to what the ticket keeps included.
- **`manual`**: the user writes the code; the gate reports these as findings.

## The cap

**More than three tickets filed or calls made alone means the order deferred instead of finishing.** Go back and fix the ones that could have ridden the branch. Zero is the common outcome.

## With the user here

In a `co-write` or `guided` session, present the `escalate` items one at a time: what it is, why it could not ride the branch, the escalation agent's recommendation and yours where they differ. Then stop. The user decides; dispatch a subagent to carry out the decision, and for a ticket they say to file, record it with `kitchen.zsh filed`. **The user saying `next` advances.** Never present two at once. Nothing is held for them afterward: the PR does not wait on an answer.

> **Concurrent venue probes on the trader's start floor: file it, or leave it?**
>
> This branch took the pre-READY floor past the 90s missed-heartbeat clock: three of the four bounded startup steps are venue probes, so one silent venue spends 3x30s. The fix is to run them under a single bound, a different subsystem's concurrency change, which is why it could not ride this diff.
>
> It costs nothing while the desk is dark and costs stopped quoting the moment anything is armed. No open ticket covers it; I searched. **I'd file it and link it to the arming ticket.**
