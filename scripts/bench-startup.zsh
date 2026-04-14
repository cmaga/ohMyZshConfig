#!/usr/bin/env zsh
#
# bench-startup.zsh - Profile and benchmark zsh interactive shell startup
#
# Modes:
#   --label NAME [--count N]                    Parallel spawn (default mode)
#   --sequential --label NAME [--count N]       One shell at a time (no cross-warming)
#   --profile [--iterations N]                  zprof: which function is slow
#   --trace                                     xtrace with per-line timestamps
#   --purge                                     (macOS) drop FS page cache between runs
#   --compare                                   Side-by-side table from log
#
# WHY the modes matter:
#   Parallel (default) is fast to run but misleading: 20 shells spawned at once
#   share FS page cache, so each shell after the first reads nvm.sh and plugin
#   files from memory. Result: the bench reports a small cold-cache penalty
#   even when real interactive iTerm tabs hang for many seconds on truly cold
#   disk. Use --sequential (and --purge if you have sudo) to reproduce that.
#   Use --profile to find where the time is going.
#

set -uo pipefail
zmodload zsh/datetime

SCRIPT_DIR="${0:A:h}"
LOG_FILE="$SCRIPT_DIR/bench-results.log"
COUNT=20
ITERATIONS=3
LABEL=""
MODE="parallel"  # parallel | sequential | profile | trace | compare
PURGE=false
TIMEOUT=60

while [[ $# -gt 0 ]]; do
  case "$1" in
    --label)       LABEL="$2"; shift 2 ;;
    --count)       COUNT="$2"; shift 2 ;;
    --iterations)  ITERATIONS="$2"; shift 2 ;;
    --sequential)  MODE="sequential"; shift ;;
    --profile)     MODE="profile"; shift ;;
    --trace)       MODE="trace"; shift ;;
    --compare)     MODE="compare"; shift ;;
    --purge)       PURGE=true; shift ;;
    --help|-h)
      sed -n '2,18p' "$0"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Attempt to drop macOS FS page cache. Needs sudo cached (or NOPASSWD).
# Returns 0 on success, 1 if skipped.
maybe_purge() {
  $PURGE || return 1
  [[ "$OSTYPE" == darwin* ]] || return 1
  if sudo -n purge 2>/dev/null; then
    return 0
  else
    echo "  (--purge requested but sudo not cached; skipping)" >&2
    PURGE=false
    return 1
  fi
}

# Time one `zsh -i -c exit` invocation, writing elapsed seconds (3 decimals) to stdout.
# Returns the zsh exit code.
time_one_shell() {
  local start end rc
  start=$EPOCHREALTIME
  zsh -i -c exit 2>/dev/null
  rc=$?
  end=$EPOCHREALTIME
  printf "%.3f" $(( end - start ))
  return $rc
}

# Format + append results block to LOG_FILE. Takes label, times array (newline-separated).
append_results() {
  local label="$1" times_str="$2" timeouts="$3"
  local -a times
  times=("${(f)times_str}")
  local completed=${#times}
  local min max avg median mid sum t

  if (( completed == 0 )); then
    min="N/A"; max="N/A"; avg="N/A"; median="N/A"
  else
    local -a sorted
    sorted=(${(on)times})
    min="${sorted[1]}"
    max="${sorted[-1]}"
    sum=0
    for t in "${sorted[@]}"; do sum=$(( sum + t )); done
    avg=$(printf "%.3f" $(( sum / completed )))
    mid=$(( (completed + 1) / 2 ))
    if (( completed % 2 == 0 )); then
      median=$(printf "%.3f" $(( (sorted[mid] + sorted[mid + 1]) / 2.0 )))
    else
      median="${sorted[mid]}"
    fi
  fi

  echo ""
  echo "Results ($label):"
  echo "  Completed: $completed"
  echo "  Timed out: $timeouts"
  echo "  Min:       ${min}s"
  echo "  Max:       ${max}s"
  echo "  Avg:       ${avg}s"
  echo "  Median:    ${median}s"
  if (( completed > 0 )); then
    echo ""
    echo "Individual times (sorted):"
    for t in "${sorted[@]}"; do echo "  ${t}s"; done
  fi

  {
    echo "--- $label ---"
    echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Mode: $MODE"
    echo "Purge: $PURGE"
    echo "Spawned: $((completed + timeouts))"
    echo "Completed: $completed"
    echo "Timed out: $timeouts"
    echo "Min: ${min}s"
    echo "Max: ${max}s"
    echo "Avg: ${avg}s"
    echo "Median: ${median}s"
    if (( completed > 0 )); then
      echo "Raw: ${(j:,:)sorted}"
    fi
    echo ""
  } >> "$LOG_FILE"
  echo ""
  echo "Results appended to $LOG_FILE"
}

# =============================================================================
# MODE: compare
# =============================================================================
mode_compare() {
  [[ -f "$LOG_FILE" ]] || { echo "No results log at $LOG_FILE"; exit 1; }
  echo ""
  echo "=========================================="
  echo "  ZSH Startup Benchmark Comparison"
  echo "=========================================="
  echo ""
  awk '
    /^--- / { label = $2; labels[n++] = label; next }
    /^Mode:/ { mode[label] = $2 }
    /^Spawned:/ { spawned[label] = $2 }
    /^Completed:/ { completed[label] = $2 }
    /^Timed out:/ { timedout[label] = $3 }
    /^Min:/ { min[label] = $2 }
    /^Max:/ { max[label] = $2 }
    /^Avg:/ { avg[label] = $2 }
    /^Median:/ { median[label] = $2 }
    /^Timestamp:/ { ts[label] = $2 " " $3 }
    END {
      printf "%-15s", "Metric"
      for (i = 0; i < n; i++) printf "  %-17s", labels[i]
      printf "\n%-15s", "----"
      for (i = 0; i < n; i++) printf "  %-17s", "----"
      printf "\n"
      for (metric in order) delete order[metric]
      metrics[0]="Timestamp"; metrics[1]="Mode"; metrics[2]="Spawned"
      metrics[3]="Completed"; metrics[4]="Timed out"
      metrics[5]="Min"; metrics[6]="Max"; metrics[7]="Avg"; metrics[8]="Median"
      metric_count = 9
      for (m = 0; m < metric_count; m++) {
        name = metrics[m]
        printf "%-15s", name
        for (i = 0; i < n; i++) {
          if (name == "Timestamp") v = ts[labels[i]]
          else if (name == "Mode") v = mode[labels[i]] ? mode[labels[i]] : "-"
          else if (name == "Spawned") v = spawned[labels[i]]
          else if (name == "Completed") v = completed[labels[i]]
          else if (name == "Timed out") v = timedout[labels[i]]
          else if (name == "Min") v = min[labels[i]]
          else if (name == "Max") v = max[labels[i]]
          else if (name == "Avg") v = avg[labels[i]]
          else v = median[labels[i]]
          printf "  %-17s", v
        }
        printf "\n"
      }
    }
  ' "$LOG_FILE"
  echo ""
}

# =============================================================================
# MODE: parallel (default — backward compat)
# =============================================================================
mode_parallel() {
  [[ -z "$LABEL" ]] && { echo "Error: --label is required" >&2; exit 1; }
  maybe_purge
  echo "Benchmarking (parallel): $COUNT shells spawned concurrently, label=$LABEL"

  local tmpdir=$(mktemp -d)
  trap "rm -rf $tmpdir" EXIT

  local -a pids
  for i in $(seq 1 $COUNT); do
    (
      zmodload zsh/datetime
      local start=$EPOCHREALTIME
      zsh -i -c exit 2>/dev/null &
      local shell_pid=$!
      (sleep $TIMEOUT && kill $shell_pid 2>/dev/null) &
      local watchdog_pid=$!
      wait $shell_pid 2>/dev/null
      local rc=$?
      kill $watchdog_pid 2>/dev/null
      wait $watchdog_pid 2>/dev/null
      local end=$EPOCHREALTIME
      local elapsed=$(printf "%.3f" $(( end - start )))
      if (( rc == 0 )); then
        echo "$elapsed" > "$tmpdir/$i.time"
      elif (( ${elapsed%.*} >= TIMEOUT )); then
        echo "TIMEOUT" > "$tmpdir/$i.time"
      else
        echo "$elapsed" > "$tmpdir/$i.time"
      fi
    ) &
    pids+=($!)
  done
  for pid in "${pids[@]}"; do wait $pid 2>/dev/null || true; done

  local times="" timeouts=0
  for i in $(seq 1 $COUNT); do
    local f="$tmpdir/$i.time"
    if [[ -f "$f" ]]; then
      local v=$(cat "$f")
      if [[ "$v" == "TIMEOUT" ]]; then
        (( timeouts++ ))
      else
        times+="${v}"$'\n'
      fi
    else
      (( timeouts++ ))
    fi
  done

  append_results "$LABEL" "${times%$'\n'}" $timeouts
}

# =============================================================================
# MODE: sequential — one at a time, no cross-warming
# =============================================================================
mode_sequential() {
  [[ -z "$LABEL" ]] && { echo "Error: --label is required" >&2; exit 1; }
  echo "Benchmarking (sequential): $COUNT shells one at a time, label=$LABEL"
  if $PURGE; then
    echo "  --purge: dropping FS cache between each spawn"
  fi

  local times="" timeouts=0 i elapsed rc
  for i in $(seq 1 $COUNT); do
    maybe_purge
    elapsed=$(time_one_shell)
    rc=$?
    if (( rc == 0 )); then
      echo "  shell $i: ${elapsed}s"
      times+="${elapsed}"$'\n'
    else
      echo "  shell $i: FAILED (rc=$rc)"
      (( timeouts++ ))
    fi
  done

  append_results "$LABEL" "${times%$'\n'}" $timeouts
}

# =============================================================================
# MODE: profile — zprof a single shell startup
# =============================================================================
mode_profile() {
  echo "Profiling zsh startup with zprof ($ITERATIONS iteration(s))..."
  echo "  Uses ZDOTDIR override to prepend zmodload zsh/zprof before your .zshrc"
  echo ""

  local zdot=$(mktemp -d)
  trap "rm -rf $zdot" EXIT

  cat > "$zdot/.zshrc" <<'EOF'
zmodload zsh/zprof
[[ -f "$HOME/.zshrc" ]] && source "$HOME/.zshrc"
zprof
EOF

  for i in $(seq 1 $ITERATIONS); do
    echo "=============================================="
    echo "  zprof run $i/$ITERATIONS"
    echo "=============================================="
    maybe_purge
    ZDOTDIR="$zdot" zsh -i -c exit 2>&1 | sed -n '/^num[[:space:]]\+calls/,$p' | head -40
    echo ""
  done
}

# =============================================================================
# MODE: trace — xtrace with per-line timestamps, summarize hottest lines
# =============================================================================
mode_trace() {
  echo "Tracing zsh startup with xtrace + timestamps..."
  local zdot=$(mktemp -d)
  local trace_file=$(mktemp)
  trap "rm -rf $zdot $trace_file" EXIT

  cat > "$zdot/.zshrc" <<'EOF'
zmodload zsh/datetime
PS4='+%D{%s.%6.}|%N:%i> '
setopt xtrace
[[ -f "$HOME/.zshrc" ]] && source "$HOME/.zshrc"
unsetopt xtrace
EOF

  maybe_purge
  local start=$EPOCHREALTIME
  ZDOTDIR="$zdot" zsh -i -c exit 2> "$trace_file"
  local end=$EPOCHREALTIME
  local total=$(printf "%.3f" $(( end - start )))

  echo "Total wall time: ${total}s"
  echo "Trace lines: $(wc -l < $trace_file)"
  echo ""
  echo "Top 20 slowest individual lines (delta from previous xtrace event):"
  echo ""
  awk -F'|' '
    /^\+[0-9]+\.[0-9]+\|/ {
      ts = substr($1, 2) + 0
      loc = $2
      if (prev_ts > 0) {
        delta = ts - prev_ts
        line = prev_loc
        if (delta > 0) {
          deltas[line] += delta
          counts[line]++
        }
      }
      prev_ts = ts
      prev_loc = loc
    }
    END {
      for (l in deltas) printf "%.4fs  %5d  %s\n", deltas[l], counts[l], l
    }
  ' "$trace_file" | sort -rn | head -20
}

# =============================================================================
# Dispatch
# =============================================================================
case "$MODE" in
  compare)     mode_compare ;;
  sequential)  mode_sequential ;;
  profile)     mode_profile ;;
  trace)       mode_trace ;;
  parallel)    mode_parallel ;;
  *) echo "Unknown mode: $MODE" >&2; exit 1 ;;
esac
