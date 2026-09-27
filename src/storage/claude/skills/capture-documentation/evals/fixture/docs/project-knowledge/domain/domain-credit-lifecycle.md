---
type: domain
status: active
created: 2026-01-18
---
# Credit lifecycle

## Rules

A customer's credit balance is granted, consumed, and expired through the
flow described in [[architecture/architecture-credit-deduction-flow]] and
charged against by [[components/billing]]; the retired [[legacy-queue]] once
fed it, and the [[scheduler#Backoff policy]] paces retries.
