const MAX_DELAY_MS = 30000;

function delayFor(attempt, base = 500) {
  const exp = Math.min(base * 2 ** attempt, MAX_DELAY_MS);
  const jitter = Math.random() * exp;
  return exp + jitter;
}

async function retry(fn, attempts = 8) {
  for (let i = 0; ; i++) {
    try {
      return await fn();
    } catch (err) {
      if (i + 1 >= attempts) throw err;
      await new Promise((r) => setTimeout(r, delayFor(i)));
    }
  }
}

module.exports = { retry, delayFor, MAX_DELAY_MS };
