#!/usr/bin/env zsh
# Drive the full benchmark: every (task x model x effort) cell, REPS each, executed
# in interleaved order so no single lever aligns with cache-warm/cold run position.
# Usage: run-suite.zsh [reps]   (default 3)

set -u
SCRIPT_DIR="${0:A:h}"
REPS="${1:-3}"
# One timestamped file per suite run, outside the repo and the deployed skill,
# so runs accumulate as comparable history instead of overwriting each other.
RESULTS_DIR="$HOME/.claude-artifacts/skills/optimize-usage"
mkdir -p "$RESULTS_DIR"
RESULTS="$RESULTS_DIR/bench-results-$(date +%Y%m%d-%H%M%S).tsv"

TASKS=(fix-bugs implement-stats merge-intervals)
# cells as "model effort", requested by alias; summarize.py reads the bound model
# back and family-checks it, so a misresolving alias drops loudly instead of
# poisoning data. Baseline = opus/high. Model sweep at fixed high; effort sweep on opus.
CELLS=(
  "opus high"
  "fable high"
  "sonnet high"
  "claude-haiku-4-5-20251001 high"  # full ID: the haiku alias binds Sonnet (probed 2026-07-21)
  "opus max"
  "opus xhigh"
  "opus low"
)

# Build the job list: outer loop = rep, then task. Each (rep, task) block starts
# the cell list one position later than the last, so every cell takes every run
# position and cache/load drift cannot align with one cell.
typeset -a JOBS
block=0
for r in {1..$REPS}; do
  for t in $TASKS; do
    for i in {1..${#CELLS}}; do
      JOBS+=("$t|${CELLS[$(( (i + block - 1) % ${#CELLS} + 1 ))]}|$r")
    done
    (( block++ ))
  done
done

print "Running ${#JOBS} cells (${#TASKS} tasks x ${#CELLS} cells x $REPS reps)...\n"
for j in $JOBS; do
  local task="${j%%|*}"; local rest="${j#*|}"
  local cell="${rest%%|*}"; local rep="${rest##*|}"
  "$SCRIPT_DIR/run-cell.zsh" "$task" ${=cell} "$rep" "$RESULTS"
done

print "\n"
python3 "$SCRIPT_DIR/summarize.py" "$RESULTS"