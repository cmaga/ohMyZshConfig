#!/usr/bin/env zsh
#
# bench-startup.zsh - Benchmark zsh interactive shell startup time
#
# Usage:
#   ./bench-startup.zsh --label before
#   ./bench-startup.zsh --label after
#   ./bench-startup.zsh --label before --count 30
#   ./bench-startup.zsh --compare
#

set -uo pipefail
zmodload zsh/datetime

SCRIPT_DIR="${0:A:h}"
LOG_FILE="$SCRIPT_DIR/bench-results.log"
COUNT=20
LABEL=""
COMPARE=false
TIMEOUT=30

while [[ $# -gt 0 ]]; do
  case "$1" in
    --label)  LABEL="$2"; shift 2 ;;
    --count)  COUNT="$2"; shift 2 ;;
    --compare) COMPARE=true; shift ;;
    --help)
      echo "Usage: $0 --label <name> [--count N]"
      echo "       $0 --compare"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# --compare mode: parse log and print side-by-side report
if $COMPARE; then
  if [[ ! -f "$LOG_FILE" ]]; then
    echo "No results log found at $LOG_FILE"
    exit 1
  fi
  echo ""
  echo "=========================================="
  echo "  ZSH Startup Benchmark Comparison"
  echo "=========================================="
  echo ""

  # Parse labeled sections from the log
  awk '
    /^--- / {
      label = $2
      next
    }
    /^Spawned:/ { spawned[label] = $2 }
    /^Completed:/ { completed[label] = $2 }
    /^Timed out:/ { timedout[label] = $3 }
    /^Min:/ { min[label] = $2 }
    /^Max:/ { max[label] = $2 }
    /^Avg:/ { avg[label] = $2 }
    /^Median:/ { median[label] = $2 }
    /^Timestamp:/ { ts[label] = $2 " " $3 }
    END {
      # Collect labels in order
      n = 0
      for (l in ts) { labels[n++] = l }

      printf "%-20s", "Metric"
      for (i = 0; i < n; i++) printf "  %-15s", labels[i]
      printf "\n"

      printf "%-20s", "----"
      for (i = 0; i < n; i++) printf "  %-15s", "----"
      printf "\n"

      printf "%-20s", "Timestamp"
      for (i = 0; i < n; i++) printf "  %-15s", ts[labels[i]]
      printf "\n"

      printf "%-20s", "Spawned"
      for (i = 0; i < n; i++) printf "  %-15s", spawned[labels[i]]
      printf "\n"

      printf "%-20s", "Completed"
      for (i = 0; i < n; i++) printf "  %-15s", completed[labels[i]]
      printf "\n"

      printf "%-20s", "Timed out"
      for (i = 0; i < n; i++) printf "  %-15s", timedout[labels[i]]
      printf "\n"

      printf "%-20s", "Min"
      for (i = 0; i < n; i++) printf "  %-15s", min[labels[i]]
      printf "\n"

      printf "%-20s", "Max"
      for (i = 0; i < n; i++) printf "  %-15s", max[labels[i]]
      printf "\n"

      printf "%-20s", "Avg"
      for (i = 0; i < n; i++) printf "  %-15s", avg[labels[i]]
      printf "\n"

      printf "%-20s", "Median"
      for (i = 0; i < n; i++) printf "  %-15s", median[labels[i]]
      printf "\n"
    }
  ' "$LOG_FILE"
  echo ""
  exit 0
fi

if [[ -z "$LABEL" ]]; then
  echo "Error: --label is required (e.g. --label before)"
  exit 1
fi

echo "Benchmarking zsh startup: $COUNT parallel shells, label=$LABEL, timeout=${TIMEOUT}s"

TMPDIR_BENCH=$(mktemp -d)
trap "rm -rf $TMPDIR_BENCH" EXIT

# Spawn N parallel zsh instances, each writing its own timing to a file
# Uses a background watchdog for timeout since macOS lacks `timeout` by default
pids=()
for i in $(seq 1 $COUNT); do
  (
    zmodload zsh/datetime
    start=$EPOCHREALTIME
    zsh -i -c exit 2>/dev/null &
    local shell_pid=$!
    (sleep $TIMEOUT && kill $shell_pid 2>/dev/null) &
    local watchdog_pid=$!
    wait $shell_pid 2>/dev/null
    rc=$?
    kill $watchdog_pid 2>/dev/null
    wait $watchdog_pid 2>/dev/null
    end=$EPOCHREALTIME
    elapsed=$(printf "%.3f" $(( end - start )))
    if (( rc == 0 )); then
      echo "$elapsed" > "$TMPDIR_BENCH/$i.time"
    elif (( ${elapsed%.*} >= TIMEOUT )); then
      echo "TIMEOUT" > "$TMPDIR_BENCH/$i.time"
    else
      echo "$elapsed" > "$TMPDIR_BENCH/$i.time"
    fi
  ) &
  pids+=($!)
done

echo "Spawned $COUNT shells, waiting..."

# Wait for all
for pid in "${pids[@]}"; do
  wait $pid 2>/dev/null || true
done

echo "All shells finished. Collecting results..."

# Collect results
times=()
timeouts=0
completed=0

for i in $(seq 1 $COUNT); do
  f="$TMPDIR_BENCH/$i.time"
  if [[ -f "$f" ]]; then
    val=$(cat "$f")
    if [[ "$val" == "TIMEOUT" ]]; then
      (( timeouts++ ))
    else
      times+=("$val")
      (( completed++ ))
    fi
  else
    (( timeouts++ ))
  fi
done

# Sort times
sorted=(${(on)times})

if (( completed == 0 )); then
  echo "All $COUNT shells timed out after ${TIMEOUT}s!"
  min="N/A"
  max="N/A"
  avg="N/A"
  median="N/A"
else
  min="${sorted[1]}"
  max="${sorted[-1]}"

  # Calculate average
  sum=0
  for t in "${sorted[@]}"; do
    sum=$(( sum + t ))
  done
  avg=$(printf "%.3f" $(( sum / completed )))

  # Calculate median
  mid=$(( (completed + 1) / 2 ))
  if (( completed % 2 == 0 )); then
    median=$(printf "%.3f" $(( (sorted[mid] + sorted[mid + 1]) / 2.0 )))
  else
    median="${sorted[mid]}"
  fi

  echo ""
  echo "Results ($LABEL):"
  echo "  Spawned:   $COUNT"
  echo "  Completed: $completed"
  echo "  Timed out: $timeouts"
  echo "  Min:       ${min}s"
  echo "  Max:       ${max}s"
  echo "  Avg:       ${avg}s"
  echo "  Median:    ${median}s"
  echo ""
  echo "Individual times (sorted):"
  for t in "${sorted[@]}"; do
    echo "  ${t}s"
  done
fi

# Append to log
{
  echo "--- $LABEL ---"
  echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "Spawned: $COUNT"
  echo "Completed: $completed"
  echo "Timed out: $timeouts"
  echo "Min: ${min}s"
  echo "Max: ${max}s"
  echo "Avg: ${avg}s"
  echo "Median: ${median}s"
  echo "Raw: ${(j:,:)sorted}"
  echo ""
} >> "$LOG_FILE"

echo "Results appended to $LOG_FILE"
