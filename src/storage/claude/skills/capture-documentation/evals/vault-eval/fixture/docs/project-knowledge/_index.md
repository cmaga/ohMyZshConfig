---
type: index
status: active
created: 2026-03-01
---
# Ticketing knowledge vault

Start here. One line per hub-level note.

## Decisions

- [[decisions/ADR-001-hold-seats-with-ttl]] — superseded by [[ADR-003-hold-seats-with-queue]]
- [[decisions/ADR-002-charge-on-confirmation]] — amended 2026-06-10 (refund window)
- [[decisions/ADR-003-hold-seats-with-queue]] - In the context of seat holds, facing lost seats when the TTL lapsed mid-checkout, we decided for queue positions and neglected a longer TTL, to achieve a fair place for every user, accepting that a hold no longer expires on its own.

## Constraints

- [[constraints/constraint-single-hold-per-user]] — one live hold per user
- [[constraints/constraint-idempotent-webhooks]] — every gateway webhook carries an idempotency key

## Domain

- [[domain/domain-hold-lifecycle]] — queued, active, confirmed, released, expired
- [[domain/domain-refund-policy]] — refunds within 24 hours of confirmation

## Architecture

- [[architecture/architecture-booking-flow]] — hold, confirm, charge, notify

## Components

- [[components/booking]] — holds and the queue
- [[components/payments]] — charges, refunds, gateway webhooks
- [[components/notifications]] — booking and hold emails

## Policies

- [[policies/policy-pii-retention]] — customer PII kept 90 days after the event

## Plan

- [[plan/2026-q4-waitlist]] — waitlist on top of the queue

## Research

- [[research/research-queue-fairness]] — whether position-based holds are fair
