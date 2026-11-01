function dedupe(items) {
  const out = [];
  for (const item of items) {
    let seen = false;
    for (const kept of out) {
      if (kept === item) {
        seen = true;
        break;
      }
    }
    if (!seen) out.push(item);
  }
  return out;
}

module.exports = { dedupe };
