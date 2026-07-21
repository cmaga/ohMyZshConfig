# Lever benchmark

Measures each lever position's cost by solving a fixed set of outcome-defined coding
tasks at that position and reading Claude Code's own per-run token accounting. Replaces
the old repricing method, which only saw per-token price and never that a more capable
model finishes in fewer turns. Lever effect = per-turn price x turn count; the benchmark
measures both.

Harness lives in [`../benchmark/`](../benchmark/). Read its [README](../benchmark/README.md).

## Run it

```sh
cd <skill>/benchmark
./test-guards.zsh        # deterministic self-test, no session cost — run first
./run-suite.zsh 5        # 5 reps/cell; prints the summary table
```

- Metric = `total_cost_usd` from `claude -p --output-format json`. Per-model weights
  track API prices and the session limit is price-weighted, so this dollar figure is
  proportional to session-limit draw. It is a limit proxy, not a bill.
- Output: per-cell cost, CV, turns, and `cost/turn`; plus each lever position's cost as
  a ratio vs the opus/high baseline, averaged across tasks.
- Cost of a run: ~7 cells x N reps x 3 tasks. At CV ~16%, **N=5-7 resolves a 25% effect.**
  Each cell burns real session limit — run when you have headroom, not near a limit.

## What it covers

- Directly measurable headless: **session model** (`--model`) and **session effort**
  (`--effort`). Both verified to bind. Models are requested by alias; the harness reads
  the bound model back and family-checks it, so a misresolving alias (e.g. `--model
  haiku` binds Sonnet, probed 2026-07-21 — it keeps a full ID in CELLS) drops loudly.
- **Not yet covered:** review/worker/fan-out/vault-scribe model+effort (levers 3-8). They need an
  agent-frontmatter-swap runner that does not exist yet. Until it does, those rows stay
  estimated, not measured.

## Turning ratios into the cost column

The benchmark gives a per-unit-work cost ratio per position (e.g. haiku ~0.2x baseline).
The levers.md cost column records that ratio directly. There is no slice-share term:
the usage-capture pipeline (cost tracker + session-log analysis) was retired 2026-07-21 —
its agent attribution could not measure per-lever slices, and it was not worth the
maintenance — so levers are ranked by ratio and impact, not pt-of-total-draw.

## Findings that overturned the old table (2026-07-18, 30-run pilot, 3 tasks)

- Model cost does NOT track the API price ratio: opus is ~1x sonnet per unit work, not
  2.5x. The old "opus barely cheaper than fable, sonnet much cheaper" spacing is wrong.
- Which model is cheapest is task-dependent (opus wins at debugging, sonnet at
  spec-implementation); the average across tasks is the figure that predicts limit draw.
- haiku is ~-80% vs sonnet, robust across tasks.
- Session effort is a real cost lever (max is ~+48% over high) — a cost fact, distinct
  from the quality claim that the steps are near-equivalent.
