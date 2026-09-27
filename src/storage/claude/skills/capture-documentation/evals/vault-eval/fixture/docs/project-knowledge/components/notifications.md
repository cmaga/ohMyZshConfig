---
type: component
status: active
created: 2026-04-10
aliases: [legacy-mailer, Legacy mailer]
last_verified: 2026-04-10
---
# Notifications

Sends the booking-confirmed and hold-expired emails; replaced
[[components/legacy-mailer]] in April 2026. Called from
[[architecture/architecture-booking-flow]]. Files:
`src/notifications/send.js`.

## Reusable surface

- `sendBookingEmail` — `src/notifications/send.js` — booking-confirmed email.
- `sendHoldExpiredEmail` — `src/notifications/send.js` — hold-expired email.
