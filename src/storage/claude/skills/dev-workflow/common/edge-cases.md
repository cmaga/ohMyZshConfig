# Edge cases

What can actually go wrong, listed against the scaffold before any code exists. The model supplies the obvious ones; the user supplies the ones a model would not think of. That second half is the entire point of the step, so the list exists to be reacted to, not to be complete.

## Integration points

An integration point is a distinct component of the system with its own surface — a REST endpoint, a background job, a user flow. Not a file, not a function.

## Agreeing the list first (`large`)

Before discussing any edge case, post the components you intend to walk — your own proposed cut, one line each — and wait. The user confirms it or re-cuts it. Getting this wrong wastes the whole step: a cut that follows files instead of surfaces produces edge cases nobody can react to.

Then walk the agreed list one at a time.

## Shape

- One bullet per edge case. Concise.
- Grouped under the integration point it belongs to.
- No categories, no severity ranking, no taxonomy of any kind.

## Presenting one (`large`)

Nobody can supply the failures you missed unless they are holding the mechanism. Hand it over in four parts, in this order, every time:

1. **The change, in one line.** Restate it. Never refer back to an earlier message.
2. **Which piece this is** and what it is responsible for. Two or three sentences.
3. **How that piece works as designed.** The real mechanism, in plain language.
4. **How it can fail.** The bullets.

**Every term a bullet in part 4 uses must have been introduced in part 3.** That is the check that makes this work. A bullet reaching for vocabulary part 3 never established means part 3 is incomplete, or that bullet belongs at a different level.

Parts 1-3 are a short paragraph each, and they are repeated for every integration point. The repetition is the feature: the last plain-English contact was the user brief, several gates ago, and the design has gotten concrete since. A list that presumes the vocabulary of the scaffold lands on nothing.

Then discuss, take their additions, and stop. Never open the next integration point unasked. Unattended there is nobody to take additions from: record the list and open the next integration point yourself — including the component list, which the run cuts itself.

The last integration point is the last thing in the run that waits for the user. Everything after it runs through to the PR ([Step 6](../SKILL.md#step-6-per-tier-implementation)).

In `medium`, produce the full list in the same message as the tester dispatch — a list posted on its own ends the turn. There is no component-list gate and parts 1-3 are not needed; nobody is being asked to react to it.

## Where each one goes

- Observable at the integration point → becomes a tester test ([tests first](tests-first.md)).
- Observable only inside a function body → becomes a line on that worker's task card.

Never send the second kind to the tester. The tester writes against the scaffold's surface, so an edge case it cannot observe there is one it will have to invent semantics for.

## Example

The component list, first:

> Three pieces to walk, in this order:
>
> - **The sync endpoint** — pulls transactions from the bank and writes them to us
> - **The link flow** — what happens when a customer connects a bank
> - **The webhook handler** — what happens when the bank tells us something changed
>
> Start with the sync endpoint, or re-cut this?

Then one of them:

> **What we're building.** One shared bank connection per institution, so a customer who links the same bank twice does not get their transactions counted twice.
>
> **This piece.** The sync endpoint — the single thing that pulls transactions down from the bank and writes them to us. Everything else in the change either feeds it or reads what it wrote.
>
> **How it works.** A customer links a bank. We store that link as an *item*, and the bank hands us a token for it. When we sync, we walk every item and ask the bank for that item's transactions since we last asked — the first time, that means its entire history. Whatever comes back gets written. To keep from writing the same transaction twice, we build a key out of its amount, date and account, and refuse a second row carrying a key we already have.
>
> **How it can fail.**
>
> - The same bank gets linked twice — the second link has to attach to the existing item rather than make another one
> - A customer revokes our access halfway through a sync, after some transactions are already written
> - The bank sends us an update while we are still pulling that customer's history for the first time
> - Two genuinely different transactions share an amount, a day and an account — same key, but both have to survive
