// Local Anthropic-protocol router for Claude Code.
//
// Replaces the LiteLLM proxy this repo used to run. LiteLLM could not serve
// this job: its router renames every upstream response header to
// `llm_provider-<name>`, and `/v1/messages` errors take a path that drops them
// entirely. Claude Code reads `anthropic-ratelimit-unified-*` off the raw
// response to tell "you hit your account limit" from "the server is throttling
// everyone", and to offer low-priority mode. Behind LiteLLM those headers never
// arrived, so a usage-limit 429 surfaced as a generic throttle with no offer.
//
// This proxy exists to keep Anthropic traffic byte-identical. It never parses,
// rewrites, or re-serializes a response: status, headers, and body stream back
// exactly as received.
//
// Routing, in order:
//   1. Any path other than /v1/messages -> Anthropic, verbatim. Claude Code
//      calls /api/oauth/usage, /api/oauth/account, /v1/models and others; they
//      carry the subscription, not the model, so they always go home.
//   2. /v1/messages naming a DeepSeek model -> DeepSeek's Anthropic-compatible
//      endpoint, with the subscription bearer swapped for the DeepSeek key.
//   3. Everything else -> Anthropic, verbatim.

import http from "node:http";

const PORT = Number(process.env.CLAUDE_PROXY_PORT ?? 4000);
const ANTHROPIC_ORIGIN = "https://api.anthropic.com";
const DEEPSEEK_ORIGIN = "https://api.deepseek.com/anthropic";

// DeepSeek silently serves an unrecognized model name as deepseek-v4-flash
// rather than erroring, so a typo would quietly bill a different model than the
// one asked for. Route only names verified against the live API and reject the
// rest, so a mistake is visible immediately.
const DEEPSEEK_MODELS = new Set(["deepseek-flash", "deepseek-v4-pro"]);

// Hop-by-hop headers are scoped to a single connection and must not be relayed
// (RFC 9110 7.6.1). `host` is dropped so fetch derives it from the target, and
// `content-length` because the body is re-sent as a buffer.
const HOP_BY_HOP = new Set([
  "connection",
  "keep-alive",
  "proxy-authenticate",
  "proxy-authorization",
  "te",
  "trailer",
  "transfer-encoding",
  "upgrade",
  "host",
  "content-length",
]);

const log = (msg) => console.error(`${new Date().toISOString()} ${msg}`);

function forwardableHeaders(nodeHeaders) {
  const out = new Headers();
  for (const [key, value] of Object.entries(nodeHeaders)) {
    if (HOP_BY_HOP.has(key.toLowerCase())) continue;
    // Node lowercases incoming header names and joins repeats into an array.
    for (const v of Array.isArray(value) ? value : [value]) {
      if (v !== undefined) out.append(key, v);
    }
  }
  return out;
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", (c) => chunks.push(c));
    req.on("end", () => resolve(Buffer.concat(chunks)));
    req.on("error", reject);
  });
}

function sendJson(res, status, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(status, {
    "content-type": "application/json",
    "content-length": Buffer.byteLength(body),
  });
  res.end(body);
}

// An Anthropic-shaped error, so Claude Code renders it as an API error rather
// than choking on a body it cannot parse.
function sendApiError(res, status, message) {
  sendJson(res, status, { type: "error", error: { type: "invalid_request_error", message } });
}

// Paths whose target depends on the model being addressed. Everything else —
// /api/oauth/*, /v1/models — belongs to the subscription and goes to Anthropic
// whatever model happens to be selected. count_tokens is model-scoped and
// DeepSeek implements it, so it has to follow its model rather than default
// home and be counted against the wrong tokenizer.
const MODEL_SCOPED_PATHS = new Set(["/v1/messages", "/v1/messages/count_tokens"]);

// The model name only decides routing on a model-scoped path.
function chooseTarget(req, body) {
  const path = (req.url ?? "/").split("?")[0];
  if (!MODEL_SCOPED_PATHS.has(path)) return { upstream: "anthropic" };

  let model;
  try {
    model = JSON.parse(body.toString("utf8"))?.model;
  } catch {
    // Unparseable body: let Anthropic return its own validation error rather
    // than inventing one here.
    return { upstream: "anthropic" };
  }

  if (typeof model !== "string" || !model.startsWith("deepseek")) {
    return { upstream: "anthropic" };
  }
  if (!DEEPSEEK_MODELS.has(model)) {
    return {
      upstream: "reject",
      message:
        `Unknown DeepSeek model '${model}'. ` +
        `Available: ${[...DEEPSEEK_MODELS].join(", ")}.`,
    };
  }
  return { upstream: "deepseek" };
}

const server = http.createServer(async (req, res) => {
  // Lets `oc` check whether the proxy is up before pointing Claude Code at it.
  if ((req.url ?? "").split("?")[0] === "/health") {
    return sendJson(res, 200, { status: "ok" });
  }

  let body;
  try {
    body = await readBody(req);
  } catch {
    return sendApiError(res, 400, "Could not read request body.");
  }

  const target = chooseTarget(req, body);
  if (target.upstream === "reject") {
    log(`400 ${target.message}`);
    return sendApiError(res, 400, target.message);
  }

  const toDeepSeek = target.upstream === "deepseek";
  const origin = toDeepSeek ? DEEPSEEK_ORIGIN : ANTHROPIC_ORIGIN;
  const headers = forwardableHeaders(req.headers);

  if (toDeepSeek) {
    const key = process.env.DEEPSEEK_API_KEY;
    if (!key) {
      return sendApiError(res, 503, "DEEPSEEK_API_KEY is not set; add it to ~/.zshrc.local.");
    }
    // The subscription token must never leave for a third party. Strip every
    // form of Anthropic credential and authenticate as DeepSeek expects.
    headers.delete("authorization");
    headers.delete("x-api-key");
    headers.set("x-api-key", key);
  }

  let upstream;
  try {
    upstream = await fetch(`${origin}${req.url}`, {
      method: req.method,
      headers,
      body: ["GET", "HEAD"].includes(req.method ?? "") ? undefined : body,
      redirect: "manual",
    });
  } catch (err) {
    log(`upstream ${origin} unreachable: ${err.message}`);
    return sendApiError(res, 502, `Could not reach ${origin}: ${err.message}`);
  }

  // The point of this proxy: relay the response untouched. Claude Code reads
  // rate-limit and low-priority headers straight off it.
  const outHeaders = {};
  for (const [key, value] of upstream.headers) {
    if (!HOP_BY_HOP.has(key.toLowerCase())) outHeaders[key] = value;
  }
  res.writeHead(upstream.status, outHeaders);

  if (!upstream.body) return res.end();

  // Stream rather than buffer, so SSE tokens reach the UI as they arrive.
  try {
    for await (const chunk of upstream.body) {
      res.write(chunk);
    }
  } catch (err) {
    log(`stream aborted: ${err.message}`);
  }
  res.end();
});

server.listen(PORT, "127.0.0.1", () => {
  log(`claude-proxy listening on 127.0.0.1:${PORT}`);
});
