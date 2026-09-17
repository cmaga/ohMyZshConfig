# Edge cases

What can actually go wrong, listed against the scaffold before any code exists. Nothing waits on it: post the full list in the same message as the tester dispatch — a list posted on its own ends the turn.

## Integration points

An integration point is a distinct component of the system with its own surface — a REST endpoint, a background job, a user flow. Not a file, not a function.

## Format

- One bullet per edge case. Concise.
- Grouped under the integration point it belongs to.
- No categories, no severity ranking, no taxonomy of any kind.

## Where each one goes

- Observable at the integration point → becomes a tester test ([tests first](tests-first.md)).
- Observable only inside a function body → becomes a line on that worker's task card.

Never send the second kind to the tester. The tester writes against the scaffold's surface, so an edge case it cannot observe there is one it will have to invent semantics for.

## Example

> **The sync endpoint** — pulls transactions from the bank and writes them to us
>
> - The same bank gets linked twice — the second link has to attach to the existing item rather than make another one
> - A customer revokes our access halfway through a sync, after some transactions are already written
> - The bank sends us an update while we are still pulling that customer's history for the first time
> - Two genuinely different transactions share an amount, a day and an account — same key, but both have to survive
