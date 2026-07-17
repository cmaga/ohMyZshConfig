# Cost tracker queries

Local VictoriaMetrics sink at `http://127.0.0.1:8428` (run by the `cost-tracker` automation). Every session pushes `claude_code.cost.usage` (USD) and `claude_code.token.usage` with labels `model`, `query_source` (main/subagent/auxiliary), `effort`, `agent_name`, `skill_name`. UI at `/vmui`; API at `/api/v1/query`.

## Discover metric names first

`usePrometheusNaming` rewrites dots to underscores and may append unit suffixes — confirm the exact names before querying:

```sh
curl -s http://127.0.0.1:8428/health
curl -s 'http://127.0.0.1:8428/api/v1/label/__name__/values' | jq -r '.data[]' | grep -i claude
```

Substitute the discovered names into the queries below (verified 2026-07-17: `claude_code_cost_usage_USD_total` / `claude_code_token_usage_tokens_total`).

Instant queries ignore samples younger than 30s (`-search.latencyOffset`) — an empty result on fresh data means wait, not missing data.

## Queries

```sh
curl -s 'http://127.0.0.1:8428/api/v1/query' --data-urlencode 'query=<PromQL>'
```

| What | PromQL |
|---|---|
| Total draw, last 7d | `sum(increase(claude_code_cost_usage_USD_total[7d]))` |
| By model | `sum by (model) (increase(claude_code_cost_usage_USD_total[7d]))` |
| Main session vs subagents | `sum by (query_source) (increase(claude_code_cost_usage_USD_total[7d]))` |
| By agent (worker/review/fan-out) | `sum by (agent_name) (increase(claude_code_cost_usage_USD_total[7d]))` |
| By effort | `sum by (effort) (increase(claude_code_cost_usage_USD_total[7d]))` |
| By skill | `sum by (skill_name) (increase(claude_code_cost_usage_USD_total[7d]))` |
| Tokens by type | `sum by (type) (increase(claude_code_token_usage_tokens_total[7d]))` |
| Daily draw series | `/api/v1/query_range` with `query=sum(increase(claude_code_cost_usage_USD_total[1d]))`, `step=1d` |

## Lever cost from queries

A lever's cost column (pt of total draw) = its slice / total over the same window:

- Worker levers: slice by `agent_name="worker-agent"`.
- Review levers: slice by `agent_name` over the review agents (code-review, plan-review, qa-planner, security-expert).
- Session levers: `query_source="main"`.
- Fan-out: subagent draw on ultracode days minus worker/review slices; size against those days' totals, not the window average — bursty levers undersize 3-4x on averages.

Cross-model options price the same token mix at the target model's rates (per-model pricing via the `claude-api` skill).
