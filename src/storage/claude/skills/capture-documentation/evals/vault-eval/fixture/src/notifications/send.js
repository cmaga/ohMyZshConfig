export function sendBookingEmail(booking) {
  return mailer.send({ to: booking.email, template: "booking-confirmed", booking });
}
export function sendHoldExpiredEmail(hold) {
  return mailer.send({ to: hold.email, template: "hold-expired", hold });
}
