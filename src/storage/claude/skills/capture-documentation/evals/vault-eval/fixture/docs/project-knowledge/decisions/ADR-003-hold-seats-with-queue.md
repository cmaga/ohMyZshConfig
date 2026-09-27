---
type: decision
status: active
created: 2026-05-20
governs: [src/booking/**]
y_statement: In the context of seat holds, facing lost seats when the TTL lapsed mid-checkout, we decided for queue positions and neglected a longer TTL, to achieve a fair place for every user, accepting that a hold no longer expires on its own.
revisit_if: [data:more than 5% of holds sit queued for over an hour, code:`src/booking/queue.js` gains a priority field]
---
# ADR-003: Hold seats with a queue, not a timer

## Context

[[ADR-001-hold-seats-with-ttl]] lost seats for users who were still
paying. Support tickets peaked at 40 a week (as of 2026-05-01 <!-- recheck 2026-08-01: pull the ticket count again -->).

## Decision

A hold is a position in a per-seat queue. The head of the queue may
confirm; the rest wait. A hold is released only by the user or by
confirmation of the head. `holdSeat` in [[components/booking]] enqueues.

## Considered options

- Queue positions (chosen) - the head of the queue confirms; nobody loses a seat to a clock.
- Longer TTL (30 minutes) - rejected: the same race at a slower pace.

## Consequences

No hold expires on its own; [[constraints/constraint-single-hold-per-user]]
keeps the queue from filling with one user's holds.

## Objections considered

- Users will park holds forever - rejected: [[constraints/constraint-single-hold-per-user]] allows one hold per user.

## Compliance

- Enforced by: test - `src/booking/queue.js` `enqueue` keeps position order.
