---
type: architecture
status: active
created: 2026-05-22
---
# Booking flow

1. Hold: [[components/booking]] enqueues the user on the seat.
2. Confirm: the head of the queue confirms; the hold becomes a booking.
3. Charge: [[components/payments]] charges the card once.
4. Notify: [[components/notifications]] sends the confirmation email.

The gateway's webhook closes the loop through
[[constraints/constraint-idempotent-webhooks]].
