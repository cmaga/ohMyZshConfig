// Minimal billing charge path used only as a resolution target for vault surface entries.

function chargeCustomer(customerId, amountCents) {
  if (amountCents <= 0) throw new Error('amount must be positive');
  return { customerId, amountCents, status: 'charged' };
}

function formatRow(charge) {
  return `${charge.customerId}: ${charge.amountCents}`;
}

module.exports = { chargeCustomer, formatRow };
