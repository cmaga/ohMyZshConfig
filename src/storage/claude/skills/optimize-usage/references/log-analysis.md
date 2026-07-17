# Session-log analysis recipes

Fallback measurement path — use [cost-queries.md](cost-queries.md) against the cost tracker first; these recipes apply when the tracker is down or its history is too short.

## Where the data lives

- Main transcripts: `~/.claude/projects/<project>/<session>.jsonl`
- Subagent transcripts: `~/.claude/projects/<project>/<session>/subagents/agent-*.jsonl`; ultracode/workflow agents nest under `subagents/workflows/wf_*/`
- One JSON line per content block. Usage is a cumulative snapshot that grows across a message's lines — `output_tokens` differs across lines on roughly a third of message ids. Dedupe by taking the MAX of each usage field per `.message.id`; never keep "the first line" (`sort -u` picks an arbitrary line and undercounted output by 21M tokens in the 2026-07 calibration).
- Local logs cover this machine and a rolling window only; treat absolute totals as a sample and reason in proportions. Advisor calls are server-side and never appear here.

## Fields on assistant entries

`.type == "assistant"`, `.message.model`, `.message.usage.{input_tokens,output_tokens,cache_read_input_tokens,cache_creation_input_tokens}`, `.isSidechain`, `.timestamp` (ISO 8601), `.attributionAgent` (sidechain only — names the agent type, full coverage; it cannot distinguish turns within a type, e.g. ultracode reader vs synthesis).

`cache_creation_input_tokens` is the total of two tiers priced differently: `.message.usage.cache_creation.{ephemeral_5m_input_tokens,ephemeral_1h_input_tokens}`.

Schema drifts across Claude Code versions: run `head -1 <file> | jq .` on two or three files and confirm the fields above before trusting the recipes.

## Aggregate by model, sidechain, and agent

`SINCE` bounds the window (e.g. `2026-07-01`). Default window: 3 weeks; extend to 4 when the data is sparse; match the prior calibration window when comparing runs.

```sh
SINCE="2026-07-01"
find ~/.claude/projects -name '*.jsonl' -print0 | xargs -0 cat 2>/dev/null |
jq -rc --arg since "$SINCE" 'select(.type=="assistant" and .message.usage != null and .timestamp >= $since) |
  [.message.id, .message.model, (.isSidechain // false), (.attributionAgent // "main"),
   .message.usage.input_tokens, .message.usage.output_tokens,
   (.message.usage.cache_read_input_tokens // 0), (.message.usage.cache_creation_input_tokens // 0),
   (.message.usage.cache_creation.ephemeral_5m_input_tokens // 0),
   (.message.usage.cache_creation.ephemeral_1h_input_tokens // 0)] | @tsv' |
awk -F'\t' '{
  id=$1
  if (!(id in seen)) { seen[id]=1; key[id]=$2 FS $3 FS $4 }
  for (f=5; f<=10; f++) { v=$f+0; if (v > mx[id FS f]) mx[id FS f]=v }
} END {
  for (id in seen) {
    k=key[id]; n[k]++
    i[k]+=mx[id FS 5]; o[k]+=mx[id FS 6]; cr[k]+=mx[id FS 7]
    cc[k]+=mx[id FS 8]; c5[k]+=mx[id FS 9]; c1[k]+=mx[id FS 10]
  }
  for (k in n) printf "%s\tturns=%d\tin=%d\tout=%d\tcache_read=%d\tcache_create=%d\tcc_5m=%d\tcc_1h=%d\n", k, n[k], i[k], o[k], cr[k], cc[k], c5[k], c1[k]
}' | sort
```

## Cost-equivalent conversion

Per model, with `P_in`/`P_out` = current API price per token (fetch via the `claude-api` skill — never from memory):

```
cost = in * P_in  +  cache_read * 0.1 * P_in  +  cc_5m * 1.25 * P_in  +  cc_1h * 2.0 * P_in  +  out * P_out
```

The two cache-creation tiers must be priced separately — the 1h tier can be the majority, and pricing everything at a flat 1.25x undercounted total draw by 15% in the 2026-07 calibration. Fall back to `cache_create * 1.25 * P_in` only when the split fields are absent (older logs).

Price forward projections at the rate in force during the projection horizon (e.g. Sonnet 5 at 3/15 after the intro ends); price actuals at the rate actually paid.

Report any row whose model has no price entry as an unpriced residual — never silently drop it (`<synthetic>` rows carry zero usage and are ignorable).

This is an API-price proxy for subscription limit draw; Anthropic does not publish subscription weightings. State the assumption in every report.

## Burn-rate for fit-to-limit

Group the deduped rows by hour (`.timestamp[0:13]`) or day (`.timestamp[0:10]`) instead of agent. Daily burn varies more than 3x — compare heavy-day and heavy-session cost against the Fit-to-limit target, not the window average.

## Cross-check

`npx ccusage@latest` gives an independent per-model view (not installed globally; npx works).

- Gap beyond ~10%: the formula or a filter is wrong. Suspects in order: the dedupe method (must be max-per-field — first-line dedupe is a known breach source), the cache-creation tier split, the window filter. If none of them closes the gap, report the residual as an unresolved discrepancy — do not discard either total.
- Gap within ~10%: proceed; report both totals and the gap. The local aggregation stays authoritative for all bucket math — ccusage has no sidechain/agent attribution.
