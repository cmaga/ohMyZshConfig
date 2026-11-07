# Left for you

What only the user can decide never leaves as a sentence in prose, where it reads as already decided. It leaves as an item in the order's `left`, one question per item (`kitchen.zsh order set <KEY> left=@<file>`, the file a JSON array of the questions), never in the PR, and an order carrying any item waits for the user's review. This is how a candidate gets there.

## Discovered issues

A problem found mid-order is routed when found, never parked as prose.

- **Fix it.** The one question is whether the fix can ride this branch, not whether it is in scope. This is the cheapest moment the fix will ever have.
- Leave it only when it genuinely cannot ride: a different subsystem, a design decision the user owns, a scope that would double the diff. If your own answer is that it rides, that answer is final: fold it. Otherwise it is a triage candidate, with your recommendation and why it could not ride. A third candidate means re-asking whether any could have been fixed.
- **Search before proposing.** `jira issue list -p {projectKey} -q "statusCategory != Done" --plain --no-headers --columns key,status,summary` (`projectKey` from `.claude/skills/jira/config.json`), then read every close candidate; search component and file names too. An existing ticket ends the matter: cite its key.
- **File only after the user says to.** The one exception is a cleanup ticket that [taste](../../taste/taste.md) step 6 files.
- **Before adding a validator that refuses a configuration, grep the tests for the field it would refuse.** A defect-guard test is the record of *we tried that*.

## What qualifies

One test: **can you settle this by looking?** If yes, look, settle it, and it never reaches the user. What survives is three kinds:

- A **fix that genuinely could not ride the branch**: a discovered issue, or a review finding classed **Tech debt**.
- A review finding classed **Design**, never yours to decide alone.
- An **`[ASSUMED: ...]` that was a strategic call**, decided alone because nobody was there to ask.

Everything else fails: a finding you fixed, anything a ticket already owns, an `[ASSUMED]` settled by reading code, context with no decision attached. **If you cannot write it as a question only the user can answer, it is not one.**

## Triage

Decide what you can first. A candidate your own recommendation would fold is folded now, never sent on and never asked. The rest goes to the escalation agent, a `general-purpose` agent on the `escalation_model` lever, in one dispatch for the whole batch, told to spawn nothing and cap its return. Send each candidate with its evidence: `file:line`, the finding or marker verbatim, the Jira search result. It returns one verdict per candidate:

- **`fold`**: the fix rides this branch. It needs no decision only the user can make and does not double the diff. Never judge it on the ticket's scope or the defect's age. It names the fix.
- **`escalate`**: only the user can answer it; it needs knowledge or authority only they hold. It names that, and gives its recommendation.

Apply every `fold` yourself, one commit per fold (a fixup when it corrects a branch commit), send the commits through the bug review again, and re-run the tests the folds affect. Record each verdict with `kitchen.zsh decide`, the `file:line` or command behind it as the evidence. Every `escalate` becomes a `Left for you` item carrying the agent's reasoning. A candidate that turns up later goes through this same triage; nothing reaches the user any other way.

## The cap

**More than three items means the order deferred instead of finishing.** Go back and fix the ones that could have ridden the branch. Zero is the common outcome.

## With the user here

Present the items one at a time: what it is, why it could not ride the branch, the escalation agent's recommendation and yours where they differ. Then stop. The user decides; dispatch a subagent to carry out the decision. **The user saying `next` advances.** Never present two at once.

> **Concurrent venue probes on the trader's start floor: file it, or leave it?**
>
> This branch took the pre-READY floor past the 90s missed-heartbeat clock: three of the four bounded startup steps are venue probes, so one silent venue spends 3x30s. The fix is to run them under a single bound, a different subsystem's concurrency change, which is why it could not ride this diff.
>
> It costs nothing while the desk is dark and costs stopped quoting the moment anything is armed. No open ticket covers it; I searched. **I'd file it and link it to the arming ticket.**
