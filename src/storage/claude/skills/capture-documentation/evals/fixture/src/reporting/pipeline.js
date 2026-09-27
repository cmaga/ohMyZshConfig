// Minimal reporting pipeline used only as a resolution target for vault surface entries.

function buildReport(rows) {
  return rows.map((r) => ({ id: r.id, total: r.total }));
}

function formatRow(r) {
  return `${r.id}: ${r.total}`;
}

module.exports = { buildReport, formatRow };
