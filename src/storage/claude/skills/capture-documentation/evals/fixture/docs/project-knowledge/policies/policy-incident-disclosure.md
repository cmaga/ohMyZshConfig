---
type: policy
status: active
created: 2026-01-29
review_cadence: quarterly
---
# Incident disclosure policy

## Scope

Omits the required `steward` field, exercising FIELD_REQUIRED. Covers
disclosure obligations for [[customers/customer-selfserve-smb]].

## Reusable surface

- `chargeCustomer` — `src/billing/charge.js` — a well-formed entry that is out of scope for the policies bucket, exercising SURFACE_OUT_OF_SCOPE.
- `formatRow` — `src/billing/charge.js` — renders a charge row for the disclosure log.
