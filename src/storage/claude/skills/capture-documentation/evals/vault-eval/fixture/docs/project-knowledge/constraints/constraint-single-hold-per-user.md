---
type: constraint
status: active
severity: high
created: 2026-05-21
governs: [src/booking/**]
---
# One live hold per user

A user holds at most one seat at a time. Taking a second hold releases
the first (`releaseHold` in [[components/booking]]). Without this the
queue in [[decisions/ADR-003-hold-seats-with-queue]] could be filled by
one user parking every seat.

## Reusable surface

- `releaseHold` — `src/booking/reserve.js` — releases a hold by id; called before a new hold is taken.
