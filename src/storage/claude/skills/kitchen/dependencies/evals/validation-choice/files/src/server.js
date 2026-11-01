import { createServer } from 'node:http';

const orders = [];

async function readJson(req) {
  let body = '';
  for await (const chunk of req) body += chunk;
  return JSON.parse(body);
}

export const server = createServer(async (req, res) => {
  if (req.method === 'POST' && req.url === '/orders') {
    const order = await readJson(req);
    orders.push({ ...order, id: orders.length + 1 });
    res.writeHead(201, { 'content-type': 'application/json' });
    return res.end(JSON.stringify(orders.at(-1)));
  }
  if (req.method === 'GET' && req.url === '/orders') {
    res.writeHead(200, { 'content-type': 'application/json' });
    return res.end(JSON.stringify(orders));
  }
  res.writeHead(404).end();
});

if (import.meta.url === `file://${process.argv[1]}`) server.listen(process.env.PORT ?? 3000);
