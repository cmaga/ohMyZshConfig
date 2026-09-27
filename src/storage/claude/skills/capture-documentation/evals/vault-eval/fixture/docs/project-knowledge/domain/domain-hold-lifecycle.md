---
type: domain
status: active
created: 2026-05-20
---
# Hold lifecycle

A hold moves through five states: queued (behind another hold on the
seat), active (head of the queue), confirmed (paid, now a booking),
released (dropped by the user or by
[[constraints/constraint-single-hold-per-user]]), and expired. Expired
survives from [[decisions/ADR-001-hold-seats-with-ttl]] only for holds
created before 2026-05-20; no new hold expires. State changes live in
[[components/booking]]; the confirmed transition charges via
[[components/payments]].
