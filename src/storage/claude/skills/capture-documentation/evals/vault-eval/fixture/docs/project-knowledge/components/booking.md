---
type: component
status: active
created: 2026-03-02
last_verified: 2026-05-22
---
# Booking

Owns holds and the per-seat queue described in
[[decisions/ADR-003-hold-seats-with-queue]]; the lifecycle is in
[[domain/domain-hold-lifecycle]]. The timer from
[[decisions/ADR-001-hold-seats-with-ttl]] is gone (until 2026-06-01 — the
`expireHolds` job was deleted; see [[ADR-003-hold-seats-with-queue]]).
Files: `src/booking/reserve.js`, `src/booking/queue.js`.

## Reusable surface

- `reserveSeat` — `src/booking/reserve.js` — takes a hold by enqueueing the user on the seat.
- `releaseHold` — `src/booking/reserve.js` — drops a hold.
- `queue` — `src/booking/queue.js` — the per-seat queue object.
