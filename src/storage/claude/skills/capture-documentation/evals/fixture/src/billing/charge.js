// Minimal billing charge path used only as a resolution target for vault surface entries.

function chargeCustomer(customerId, amountCents) {
  if (amountCents <= 0) throw new Error('amount must be positive');
  return { customerId, amountCents, status: 'charged' };
}

module.exports = { chargeCustomer };
