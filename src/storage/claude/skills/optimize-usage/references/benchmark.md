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
./run-suite.zsh 5 -P 4   # 5 reps/cell through 4 parallel workers (default); -P 1 = serial
```

- Metric = `total_cost_usd` from `claude -p --output-format json`. Per-model weights
  track API prices and the session limit is price-weighted, so this dollar figure is
  proportional to session-limit draw. It is a limit proxy, not a bill.
- Output: per-cell cost, CV, turns, and `cost/turn`; plus each lever position's cost as
  a ratio vs the opus/high baseline, averaged across tasks.
- Cost of a run: 8 cells x N reps x 3 tasks (the 7-cell 2026-08-04 run measured $32 at
  N=5). At the measured CV of ~18%, **n≈9/cell resolves a 25% effect; N=5 resolves ~40%.**
  Each cell burns real session limit — run when you have headroom, not near a limit.
- One invocation of a 5-rep suite at `-P 4` (~40 min) fits the 60-min Bash cap that
  forced the 2026-08-04 run into five sequential 1-rep invocations. Jobs write per-job
  TSV fragments merged at the end; `summarize.py` is unchanged. On the first parallel
  suite, sanity-check CV against the 2026-08-04 sequential run and the `ccreate` column
  for a cache-write burst before treating results as comparable.

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

## Findings (2026-08-04 full run — 105 runs, N=5/cell, all pass; bound: claude-opus-5, claude-sonnet-5, claude-fable-5, claude-haiku-4-5)

- fable is ~2.1x opus per unit work — the one model step that tracks its API price ratio.
- sonnet measures 0.86x opus (directional — below this run's resolution), far shallower
  than its 0.6x price ratio: model cost still does not track price in general.
- haiku is ~0.18x opus, robust across tasks.
- Effort on opus: max +22%, xhigh +11% (directional), low -26% vs high. The pilot's
  "max +48%" (2026-07-18, 30 runs, pre-Opus-5 binding) did not replicate. medium had
  no cell in this run (added 2026-08-06; unmeasured until the next suite).
- Cheapest model stays task-dependent (sonnet per-task 0.97/0.67/0.95); the cross-task
  average is the figure that predicts limit draw.
- Sonnet cost accounting verified against the standard price schedule, not the intro
  rates that expire 2026-08-31 — the ratio will not jump when they do.
