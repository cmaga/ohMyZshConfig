# Lever benchmark harness

Measures how much each Claude Code config lever changes subscription session-limit
consumption, by solving a fixed set of outcome-defined coding tasks at each lever
position and reading Claude Code's own per-run token accounting.

Replaces the old approach of repricing a fixed token mix at each model's rates, which
could only see per-token price and never that a more capable model finishes in fewer
turns. Lever effect = per-turn price x turn count; this harness measures both.

## What it measures

- Metric: `total_cost_usd` from `claude -p --output-format json`. Because per-model
  weights track API prices and the session limit is price-weighted, this dollar figure
  is proportional to session-limit draw. It is a limit proxy, not a bill.
- Only levers observable in a headless run: session model (`--model`) and session
  effort (`--effort`). Both verified to bind.

## Design decisions (each earned from a failure)

- Aliases with family-checked read-back. Models are requested by alias (`opus`, not a
  pinned ID) so version bumps need no edits; every run's bound model is read back from
  `modelUsage` and must contain the requested family, so a misresolving alias drops the
  row loudly. Exception: haiku keeps a full ID in CELLS — `--model haiku` binds Sonnet
  (probed 2026-07-21).
- `cd` into the fixture dir before running. Without it the model runs the checker in
  the wrong directory and the task silently fails.
- Hidden grading. The model sees `check.py` (happy path); grading uses `hidden_check.py`
  (edge cases it never sees), so overfitting to visible tests is caught, not rewarded.
- Anti-cheat. `check.py` is hashed before/after; editing it is flagged `cheated`.
- Rotated interleaving. Cells run in blocks per (rep, task), and each block starts the
  cell list one position later, so every cell takes every run position and cache-warm/
  cold drift cannot align with one cell. (Measured: the tool-def cache block is a flat
  ~13K tokens/run; run-to-run cost variance is driven by turn count, not warmth.)
- Parallel pool with per-job fragments. Jobs launch in rotated order, `-P` at a time;
  each appends to its own TSV fragment, merged in launch order afterward — the
  alternative, concurrent appends to one shared file, loses rows silently. Same-model
  jobs in flight together can each pay a cache write where serial paid once (cents —
  visible in the `ccreate` column).

## Files

- `tasks/<name>/` — `prompt.txt`, source files, `check.py` (visible), `hidden_check.py`
  (grading only). Fresh copy per rep in a `mktemp` dir. Tasks: `fix-bugs` (debug),
  `implement-stats` (spec-to-code), `merge-intervals` (edge-case-heavy).
- `run-cell.zsh <task> <model-id> <effort> <rep>` — one run; appends a TSV row.
  Honors `BENCH_SOLVER` to inject a fake solver in place of Claude (used by the test):
  the value is eval'd inside the temp workdir (use absolute paths or inline logic —
  relative paths to your own files will not resolve), and its stdout becomes the run's
  JSON (echo `{}` for a free run with no cost fields). Example:
  `BENCH_SOLVER='cat > mathkit.py <<PY ...fixed source... PY
  echo "{}"' ./run-cell.zsh fix-bugs claude-haiku-4-5-20251001 high 1` — see
  test-guards.zsh for four working solvers.
- `run-suite.zsh [reps] [-P workers]` — interleaved grid over all tasks x cells through
  a parallel worker pool (default 4 workers; `-P 1` = serial); per-job TSV fragments
  merged in launch order into one timestamped results file; prints the summary with a
  `[k/total]` counter per completed job.
- `summarize.py` — per-cell table, cross-task lever effects, CV, N-needed.
- `test-guards.zsh` — deterministic self-test of all four grading outcomes
  (pass/overfit/cheated/fail) with no Claude call and no session cost. Run it first.

## What it does NOT measure (honest limits)

- Subagent levers (review/worker/fan-out model+effort). They need agent-frontmatter
  swaps and cannot be read back from a single headless run; deferred.
- Effort is unobservable after the fact — no log or JSON field records it. Trust that
  `--effort` bound only because output-token volume moves with it.
- Small task set. Lever effects are averaged across tasks to generalize, but two toy
  tasks is a narrow basis. Add tasks to widen it.
- The metric assumes weights track price and the limit is price-weighted — both
  established here empirically (2-sample endpoint fit), not published by Anthropic.
