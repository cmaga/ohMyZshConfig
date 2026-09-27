---
type: domain
status: active
created: 2026-06-10
basis: user-stated
---
# Refund policy

A confirmed booking is refundable for 24 hours after confirmation, in
full, to the original card; after 24 hours it is final. Set by the
amendment to [[decisions/ADR-002-charge-on-confirmation]]; implemented by
`refundWithin24h` in [[components/payments]]. Abandoned holds are never
charged, so they are never refunded.
