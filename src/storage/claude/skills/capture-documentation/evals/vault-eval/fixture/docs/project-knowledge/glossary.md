---
type: glossary
status: active
created: 2026-03-01
---
# Glossary

- **Hold** - a user's claim on a seat before payment; see [[domain/domain-hold-lifecycle]].
- **Queue position** - the order of holds on one seat, which replaced the TTL; see [[decisions/ADR-003-hold-seats-with-queue]].
- **Confirmation** - the moment a hold becomes a booking and the charge fires; see [[decisions/ADR-002-charge-on-confirmation]].
- **Idempotency key** - the header that makes a repeated gateway webhook harmless; see [[constraints/constraint-idempotent-webhooks]].
