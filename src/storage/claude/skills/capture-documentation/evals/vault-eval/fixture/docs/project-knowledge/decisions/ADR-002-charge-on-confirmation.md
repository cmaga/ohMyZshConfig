---
type: decision
status: amended
created: 2026-03-05
governs: [src/payments/charge.js]
---
# ADR-002: Charge on confirmation, never on hold

> Status: AMENDED 2026-06-10 — refunds are allowed within 24 hours of confirmation; see the Amendment below.

## Context

Charging at hold time meant refunding every abandoned hold.

## Decision

The card is charged only when the user confirms the booking
(`chargeOnConfirm` in [[components/payments]]). A hold costs nothing.

## Consequences

No refunds for abandoned holds. Confirmed bookings were final until the
amendment below.

## Amendment (2026-06-10)

A confirmed booking can be refunded within 24 hours of confirmation
(`refundWithin24h`); after that it is final. See
[[domain/domain-refund-policy]].
