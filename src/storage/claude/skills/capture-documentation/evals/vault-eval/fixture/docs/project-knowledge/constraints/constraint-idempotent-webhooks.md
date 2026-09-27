---
type: constraint
status: active
severity: blocking
created: 2026-04-02
governs: [src/payments/webhooks.js]
---
# Every gateway webhook carries an idempotency key

The gateway retries webhooks. Each carries the
`X-Ticketing-Idempotency-Key` header (`IDEMPOTENCY_HEADER` in
[[components/payments]]); a key seen before returns 200 and applies
nothing. A webhook without the header is rejected with 400, never
applied. Motivated by [[decisions/ADR-002-charge-on-confirmation]]: a
double-applied charge event would charge twice.

## Reusable surface

- `IDEMPOTENCY_HEADER` — `src/payments/webhooks.js` — the header name.
- `handleGatewayWebhook` — `src/payments/webhooks.js` — the dedupe gate.
