---
type: decision
status: superseded
created: 2026-03-02
superseded_by: "[[ADR-003-hold-seats-with-queue]]"
governs: [src/booking/**]
---
# ADR-001: Hold seats with a 10-minute TTL

> Status: SUPERSEDED by [[ADR-003-hold-seats-with-queue]] — read that instead.

## Context

Two users could pick the same seat; the first to pay should get it.

## Decision

A hold reserves the seat for 10 minutes. When the timer lapses the seat
returns to the pool; see [[components/booking]] for the timer.

## Consequences

Users lost seats mid-checkout when the timer ran out; the queue in
[[ADR-003-hold-seats-with-queue]] replaced the timer.
