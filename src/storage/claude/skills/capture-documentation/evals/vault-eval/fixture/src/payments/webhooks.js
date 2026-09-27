export const IDEMPOTENCY_HEADER = "X-Ticketing-Idempotency-Key";
export function handleGatewayWebhook(req) {
  const key = req.headers[IDEMPOTENCY_HEADER.toLowerCase()];
  if (seen.has(key)) return { status: 200, duplicate: true };
  seen.add(key);
  return applyEvent(req.body);
}
