---
type: component
status: active
created: 2026-03-05
last_verified: 2026-06-10
---
# Payments

Charges on confirmation per [[decisions/ADR-002-charge-on-confirmation]],
refunds per [[domain/domain-refund-policy]], and the gateway webhook gate
per [[constraints/constraint-idempotent-webhooks]]. Files:
`src/payments/charge.js`, `src/payments/webhooks.js`.

## Reusable surface

- `chargeOnConfirm` — `src/payments/charge.js` — the only charge path.
- `refundWithin24h` — `src/payments/charge.js` — the only refund path.
