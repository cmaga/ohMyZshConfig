#!/usr/bin/env zsh
# Drive the full benchmark: every (task x model x effort) cell, REPS each, launched
# in interleaved order so no single lever aligns with cache-warm/cold launch position.
# Jobs run through a parallel worker pool; each writes its own TSV fragment, merged
# in launch order into one timestamped results file (no concurrent-append races).
# Usage: run-suite.zsh [reps] [-P workers]   (defaults: 3 reps, 4 workers; -P 1 = serial)

set -u
SCRIPT_DIR="${0:A:h}"

REPS=3
WORKERS=4
while (( $# > 0 )); do
  case "$1" in
    -P) (( $# >= 2 )) || { print "usage: run-suite.zsh [reps] [-P workers]" >&2; exit 2 }
        WORKERS="$2"; shift 2 ;;
    <->) REPS="$1"; shift ;;
    *) print "usage: run-suite.zsh [reps] [-P workers]" >&2; exit 2 ;;
  esac
done

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
  "opus medium"
  "opus low"
)

# Build the job list: outer loop = rep, then task. Each (rep, task) block starts
# the cell list one position later than the last, so every cell takes every launch
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
TOTAL=${#JOBS}

# Number the jobs so fragments merge back in launch order.
typeset -a NUMBERED
n=1
for j in $JOBS; do
  NUMBERED+=("${(l:4::0:)n}|$j")
  (( n++ ))
done

FRAG_DIR="$(mktemp -d)"
trap 'rm -rf "$FRAG_DIR"' EXIT

print "Running $TOTAL jobs (${#TASKS} tasks x ${#CELLS} cells x $REPS reps) with $WORKERS workers...\n"

# Worker: parse "idx|task|model effort|rep", run the cell into its own fragment,
# then re-print run-cell's line prefixed with a completed-so-far counter (counted
# from fragment files, so concurrent finishers may briefly share a number).
export SUITE_SCRIPT_DIR="$SCRIPT_DIR" SUITE_FRAG_DIR="$FRAG_DIR" SUITE_TOTAL="$TOTAL"
print -l -- $NUMBERED | xargs -P "$WORKERS" -I{} zsh -c '
  set -u
  job="$1"
  idx="${job%%|*}"; rest="${job#*|}"
  task="${rest%%|*}"; rest="${rest#*|}"
  cell="${rest%%|*}"; rep="${rest##*|}"
  out="$("$SUITE_SCRIPT_DIR/run-cell.zsh" "$task" ${=cell} "$rep" "$SUITE_FRAG_DIR/job-$idx.tsv" 2>&1)"
  k="$(command ls "$SUITE_FRAG_DIR" | wc -l | tr -d " ")"
  print -r -- "[${(l:3:: :)k}/$SUITE_TOTAL]$out"
' _ {}

# Merge fragments (each carries its own header) in launch order.
typeset -a FRAGS
FRAGS=("$FRAG_DIR"/job-*.tsv(Non))
if (( ${#FRAGS} == 0 )); then
  print "no result fragments — every job failed before writing a row" >&2
  exit 1
fi
head -1 "${FRAGS[1]}" > "$RESULTS"
for f in $FRAGS; do tail -n +2 "$f" >> "$RESULTS"; done
(( ${#FRAGS} == TOTAL )) || print "WARN: only ${#FRAGS}/$TOTAL jobs produced results" >&2

print "\n"
python3 "$SCRIPT_DIR/summarize.py" "$RESULTS"
