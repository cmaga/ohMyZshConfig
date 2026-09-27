// Charged on confirmation, never on hold (ADR-002).
export function chargeOnConfirm(bookingId, amountCents) {
  return gateway.charge({ bookingId, amountCents });
}
export function refundWithin24h(bookingId) {
  return gateway.refund({ bookingId });
}
