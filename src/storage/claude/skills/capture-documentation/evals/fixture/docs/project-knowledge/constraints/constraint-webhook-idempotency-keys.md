---
type: constraint
status: active
created: 2026-01-16
severity: blocking
---
# Webhook idempotency keys required

## Context

Every inbound webhook handler must dedupe on an idempotency key. See
[[components/billing]] for the consumer.

## Reusable surface

- `requireIdempotencyKey` — a rule with no path reference at all, exercising SURFACE_ENTRY_FORMAT.
- `anotherMissingFn` — `src/billing/does-not-exist.js` — a path that does not exist, exercising SURFACE_PATH_MISSING.
- `notARealExport` — `src/billing/charge.js` — a symbol never defined in that file, exercising SURFACE_SYMBOL_MISSING.
