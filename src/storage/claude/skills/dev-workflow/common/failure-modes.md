# Failure modes

What can actually go wrong, listed against the scaffold before any code exists. The model supplies the obvious ones; the user supplies the ones a model would not think of. That second half is the entire point of the step, so the list exists to be reacted to, not to be complete.

## Shape

- One bullet per edge case. Concise.
- Grouped under the integration point it belongs to — an endpoint, a user flow, a whole user story.
- No categories, no severity ranking, no taxonomy of any kind.

## Working through it (`large`)

One integration point at a time. Present its bullets, discuss, take the user's additions, then stop and wait. Never open the next integration point unasked.

In `medium`, produce the full list without stopping.

## Where each one goes

- Observable at the integration point → becomes a tester test ([tests first](tests-first.md)).
- Observable only inside a function body → becomes a line on that worker's task card.

Never send the second kind to the tester. The tester writes against the scaffold's surface, so an edge case it cannot observe there is one it will have to invent semantics for.

## Example

> **POST /transactions/sync**
>
> - Same institution linked twice — second link must not create a second item
> - Item revoked mid-sync — partial results already written
> - Webhook arrives during backfill
> - Two transactions, same amount, same day, different institutions — legitimately distinct, must not dedup
