#!/usr/bin/env zsh
#
# bench-startup.zsh - Profile and benchmark zsh interactive shell startup
#
# Modes:
#   --label NAME [--count N]                    Parallel spawn (default mode)
#   --sequential --label NAME [--count N]       One shell at a time (no cross-warming)
#   --profile [--iterations N]                  zprof: which function is slow
#   --trace                                     xtrace with per-line timestamps
#   --direnv-only --label NAME [--count N]      Time `direnv export zsh` only (no shell)
#   --purge                                     (macOS) drop FS page cache between runs
#   --compare                                   Side-by-side table from log
#
# Investigation flags (compose with modes above):
#   --target-dir DIR                            cd DIR before each spawn (defaults to $PWD)
#   --timeout SECS                              Per-spawn watchdog (default 60)
#   --no-direnv                                 Set DIRENV_DISABLE=1 for spawned zsh
#   --with-sample                               macOS `sample` on any spawn > threshold
#   --sample-threshold SECS                     Threshold for --with-sample (default 0.4)
#   --sys-snapshot                              Log syspolicyd/vm_stat/memory/top per spawn
#
# WHY the modes matter:
#   Parallel (default) is fast to run but misleading: 20 shells spawned at once
#   share FS page cache, so each shell after the first reads nvm.sh and plugin
#   files from memory. Result: the bench reports a small cold-cache penalty
#   even when real interactive iTerm tabs hang for many seconds on truly cold
#   disk. Use --sequential (and --purge if you have sudo) to reproduce that.
#   Use --profile to find where the time is going.
#
#   --target-dir is how we compare $HOME (no direnv fire) vs a project dir
#   (direnv fires on startup). --no-direnv is the causal control: does the
#   hang persist without direnv? --with-sample dumps a kernel+userspace stack
#   of the slow shell so we can see WHERE it's blocked.
#

set -uo pipefail
zmodload zsh/datetime

SCRIPT_DIR="${0:A:h}"
LOG_FILE="$SCRIPT_DIR/bench-results.log"
SYS_LOG="$SCRIPT_DIR/bench-sys.log"
SAMPLE_DIR="$SCRIPT_DIR/bench-samples"
COUNT=20
ITERATIONS=3
LABEL=""
MODE="parallel"  # parallel | sequential | profile | trace | direnv-only | compare
PURGE=false
TIMEOUT=60
TARGET_DIR=""
NO_DIRENV=false
WITH_SAMPLE=false
SYS_SNAPSHOT=false
SAMPLE_THRESHOLD_S=0.4  # default; override with --sample-threshold SECS

while [[ $# -gt 0 ]]; do
  case "$1" in
    --label)        LABEL="$2"; shift 2 ;;
    --count)        COUNT="$2"; shift 2 ;;
    --iterations)   ITERATIONS="$2"; shift 2 ;;
    --timeout)      TIMEOUT="$2"; shift 2 ;;
    --target-dir)        TARGET_DIR="$2"; shift 2 ;;
    --no-direnv)         NO_DIRENV=true; shift ;;
    --with-sample)       WITH_SAMPLE=true; shift ;;
    --sample-threshold)  SAMPLE_THRESHOLD_S="$2"; shift 2 ;;
    --sys-snapshot)      SYS_SNAPSHOT=true; shift ;;
    --sequential)   MODE="sequential"; shift ;;
    --profile)      MODE="profile"; shift ;;
    --trace)        MODE="trace"; shift ;;
    --direnv-only)  MODE="direnv-only"; shift ;;
    --compare)      MODE="compare"; shift ;;
    --purge)        PURGE=true; shift ;;
    --help|-h)
      sed -n '2,30p' "$0"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Default target dir: current working dir (preserves old behavior).
[[ -z "$TARGET_DIR" ]] && TARGET_DIR="$PWD"
if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Error: --target-dir does not exist: $TARGET_DIR" >&2
  exit 1
fi
TARGET_DIR="${TARGET_DIR:A}"  # resolve to absolute

$WITH_SAMPLE && mkdir -p "$SAMPLE_DIR"

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

# Emit one line of system state to $SYS_LOG. Called around each sample if
# --sys-snapshot. Captures syspolicyd CPU+etime, concurrent direnv/zsh/perl
# counts, memory pressure (pageins, compressor state, free pages), and the
# top 3 CPU-consuming processes at sample time.
sys_snapshot() {
  local tag="$1"
  local ts=$EPOCHREALTIME
  local syspolicyd_stats="n/a"
  local mem_pressure="n/a"
  local vm_snap="n/a"
  local top_procs="n/a"
  local direnv_count=0
  local zsh_count=0
  local perl_count=0
  if [[ "$OSTYPE" == darwin* ]]; then
    local syspolicyd_pid
    syspolicyd_pid=$(pgrep syspolicyd | head -1 2>/dev/null)
    if [[ -n "$syspolicyd_pid" ]]; then
      syspolicyd_stats=$(ps -p "$syspolicyd_pid" -o pcpu=,etime=,time= 2>/dev/null | tr -s ' ' | sed 's/^ //;s/ /|/g')
    fi
    # Memory pressure: Pages free, Pages active, Pageins, Pageouts, Swapouts,
    # Compressor compressions. Each is a 4K-page count.
    vm_snap=$(vm_stat 2>/dev/null | awk -F: '
      /Pages free/            {gsub(/[.[:space:]]/,"",$2); printf "free=%s|", $2}
      /Pages active/          {gsub(/[.[:space:]]/,"",$2); printf "active=%s|", $2}
      /Pageins/               {gsub(/[.[:space:]]/,"",$2); printf "in=%s|", $2}
      /Pageouts/              {gsub(/[.[:space:]]/,"",$2); printf "out=%s|", $2}
      /Swapouts/              {gsub(/[.[:space:]]/,"",$2); printf "swapout=%s|", $2}
      /compressions:/         {gsub(/[.[:space:]]/,"",$2); printf "compr=%s", $2}
    ')
    # memory_pressure -Q is the kernel's own normal/warn/critical signal.
    mem_pressure=$(memory_pressure -Q 2>/dev/null | tr -d '\n' | sed 's/,//g;s/  */ /g' | head -c 120)
    # Top 3 CPU-consuming processes right now.
    top_procs=$(ps -Ao pcpu,pid,comm 2>/dev/null | sort -rn | awk 'NR>1 && NR<=4 {printf "%s:%s|", $3, $1}')
  fi
  direnv_count=$(pgrep -c direnv 2>/dev/null || echo 0)
  zsh_count=$(pgrep -c zsh 2>/dev/null || echo 0)
  perl_count=$(pgrep -c perl 2>/dev/null || echo 0)
  printf "%s\t%s\t%s\tsyspolicyd=%s\tdirenv=%s\tzsh=%s\tperl=%s\tvm=%s\tmem=%s\ttop=%s\n" \
    "$ts" "$LABEL" "$tag" "$syspolicyd_stats" "$direnv_count" "$zsh_count" "$perl_count" \
    "$vm_snap" "$mem_pressure" "$top_procs" \
    >> "$SYS_LOG"
}

# Build the env + cd prefix each spawn runs inside. Centralized so every mode
# respects --target-dir and --no-direnv identically.
build_spawn_cmd() {
  local env_prefix=""
  $NO_DIRENV && env_prefix="DIRENV_DISABLE=1 "
  printf 'cd %q && %s' "$TARGET_DIR" "$env_prefix"
}

# Time one `zsh -i -c exit` invocation, writing elapsed seconds (3 decimals) to stdout.
# Returns the zsh exit code. Respects --target-dir, --no-direnv, --with-sample,
# --sys-snapshot.
time_one_shell() {
  local start end rc
  local prefix="$(build_spawn_cmd)"
  $SYS_SNAPSHOT && sys_snapshot "pre"
  start=$EPOCHREALTIME

  if $WITH_SAMPLE && [[ "$OSTYPE" == darwin* ]]; then
    # Launch zsh in background so we can attach `sample` if it stalls.
    eval "$prefix zsh -i -c exit" 2>/dev/null &
    local zsh_pid=$!
    local label_suffix="${LABEL}-$(date +%s%N)"
    (
      sleep $SAMPLE_THRESHOLD_S
      if kill -0 "$zsh_pid" 2>/dev/null; then
        sample "$zsh_pid" 3 -mayDie > "$SAMPLE_DIR/${label_suffix}.txt" 2>&1 || true
      fi
    ) &
    local sampler_pid=$!
    wait "$zsh_pid"
    rc=$?
    kill "$sampler_pid" 2>/dev/null || true
    wait "$sampler_pid" 2>/dev/null || true
  else
    eval "$prefix zsh -i -c exit" 2>/dev/null
    rc=$?
  fi

  end=$EPOCHREALTIME
  $SYS_SNAPSHOT && sys_snapshot "post"
  printf "%.3f" $(( end - start ))
  return $rc
}

# Time one direnv-only invocation in the target dir. No shell.
time_one_direnv() {
  local start end rc
  $SYS_SNAPSHOT && sys_snapshot "pre"
  start=$EPOCHREALTIME
  ( cd "$TARGET_DIR" && direnv export zsh 2>/dev/null >/dev/null )
  rc=$?
  end=$EPOCHREALTIME
  $SYS_SNAPSHOT && sys_snapshot "post"
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
    echo "TargetDir: $TARGET_DIR"
    echo "NoDirenv: $NO_DIRENV"
    echo "Purge: $PURGE"
    echo "Timeout: ${TIMEOUT}s"
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
  echo "  target-dir: $TARGET_DIR  no-direnv: $NO_DIRENV  timeout: ${TIMEOUT}s"

  local prefix="$(build_spawn_cmd)"
  local tmpdir=$(mktemp -d)
  trap "rm -rf $tmpdir" EXIT

  local -a pids
  for i in $(seq 1 $COUNT); do
    (
      zmodload zsh/datetime
      local start=$EPOCHREALTIME
      eval "$prefix zsh -i -c exit" 2>/dev/null &
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
  echo "  target-dir: $TARGET_DIR  no-direnv: $NO_DIRENV  timeout: ${TIMEOUT}s"
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
# MODE: direnv-only — time `direnv export zsh` in isolation, no shell
# =============================================================================
mode_direnv_only() {
  [[ -z "$LABEL" ]] && { echo "Error: --label is required" >&2; exit 1; }
  if ! command -v direnv >/dev/null 2>&1; then
    echo "Error: direnv not on PATH" >&2
    exit 1
  fi
  if [[ ! -f "$TARGET_DIR/.envrc" ]]; then
    echo "Warn: $TARGET_DIR/.envrc does not exist - direnv will be a no-op" >&2
  fi
  echo "Benchmarking (direnv-only): $COUNT direnv exports, label=$LABEL"
  echo "  target-dir: $TARGET_DIR"

  local times="" timeouts=0 i elapsed rc
  for i in $(seq 1 $COUNT); do
    elapsed=$(time_one_direnv)
    rc=$?
    if (( rc == 0 )); then
      echo "  direnv $i: ${elapsed}s"
      times+="${elapsed}"$'\n'
    else
      echo "  direnv $i: FAILED (rc=$rc)"
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
  # Reuse the real .zcompdump so compinit doesn't regenerate from scratch in
  # every profile run. Without this, the zprof numbers overstate compinit cost.
  local dump
  for dump in "$HOME"/.zcompdump* "$HOME"/.zsh/.zcompdump*(N); do
    [[ -f "$dump" ]] && cp -p "$dump" "$zdot/"
  done

  cat > "$zdot/.zshrc" <<'EOF'
zmodload zsh/zprof
[[ -f "$HOME/.zshrc" ]] && source "$HOME/.zshrc"
zprof
EOF

  local prefix="$(build_spawn_cmd)"
  for i in $(seq 1 $ITERATIONS); do
    echo "=============================================="
    echo "  zprof run $i/$ITERATIONS (target-dir: $TARGET_DIR, no-direnv: $NO_DIRENV)"
    echo "=============================================="
    maybe_purge
    # zprof output format starts with whitespace + "num  calls" header, so
    # don't anchor to column 0. Use awk range to print from header onward.
    eval "$prefix ZDOTDIR=\"$zdot\" zsh -i -c exit" 2>&1 | awk '/num[[:space:]]+calls/,0' | head -40
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
  # Reuse the real .zcompdump. A clean ZDOTDIR makes compinit regenerate from
  # scratch every trace, inflating per-line costs by ~100ms in zrecompile.
  local dump
  for dump in "$HOME"/.zcompdump* "$HOME"/.zsh/.zcompdump*(N); do
    [[ -f "$dump" ]] && cp -p "$dump" "$zdot/"
  done

  cat > "$zdot/.zshrc" <<'EOF'
zmodload zsh/datetime
PS4='+%D{%s.%6.}|%N:%i> '
setopt xtrace
[[ -f "$HOME/.zshrc" ]] && source "$HOME/.zshrc"
unsetopt xtrace
EOF

  maybe_purge
  local prefix="$(build_spawn_cmd)"
  echo "  target-dir: $TARGET_DIR  no-direnv: $NO_DIRENV"
  local start=$EPOCHREALTIME
  eval "$prefix ZDOTDIR=\"$zdot\" zsh -i -c exit" 2> "$trace_file"
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
  compare)      mode_compare ;;
  sequential)   mode_sequential ;;
  profile)      mode_profile ;;
  trace)        mode_trace ;;
  direnv-only)  mode_direnv_only ;;
  parallel)     mode_parallel ;;
  *) echo "Unknown mode: $MODE" >&2; exit 1 ;;
esac
