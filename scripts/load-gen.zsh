#!/usr/bin/env zsh
#
# load-gen.zsh - Spawn the hang-investigation worker fleet.
#
# Fleet composition (default):
#   45 synthetic workers - each in testing_grounds/<lang>/, spinning `zsh -i -c`
#                          as fast as possible to re-trigger direnv; also writes
#                          100KB files to simulate Claude BashTool activity.
#    5 real `claude -p`  - each in a different language subdir, asked to
#                          implement a small CLI budgeting app. Output not
#                          committed (testing_grounds/ is gitignored).
#
# Lifecycle:
#   --start                 spawn fleet, write PIDs to testing_grounds/.pids
#   --stop                  kill everything in .pids, remove the file
#   --status                print how many of the recorded PIDs are alive
#   --reset                 wipe testing_grounds/<lang>/ contents (preserves .envrc)
#   --synthetic-only        skip the 5 real claude workers (cost-free run)
#   --count N               cap total workers at N (default 50, max 50)
#   --duration SECS         auto-stop after SECS (optional; 0 = run until --stop)
#   --worker-mode MODE      synthetic worker behavior (default: shell-spawn)
#                           shell-spawn   = `zsh -i -c true` each iter (fires .zshrc)
#                           bashtool-sim  = re-source latest Claude shell snapshot
#                                           each iter (the actual BashTool primitive)
#   --help
#
# Lives under scripts/ (not src/deployment/) because it is a repo-local
# investigation tool, not a deployable dotfile.

set -uo pipefail

SCRIPT_DIR="${0:A:h}"
REPO_ROOT="${SCRIPT_DIR:h}"
GROUND="$REPO_ROOT/testing_grounds"
PIDFILE="$GROUND/.pids"
LOGDIR="$GROUND/.logs"

typeset -a ALL_LANGS
ALL_LANGS=(
  python javascript typescript go rust
  java kotlin swift ruby php
  csharp cpp c scala haskell
  elixir erlang clojure lua perl
  r julia dart ocaml fsharp
  nim crystal zig racket scheme
  lisp prolog smalltalk ada fortran
  cobol tcl groovy d v
  bash powershell awk sed html
  css sql graphql solidity webassembly
)

typeset -a REAL_CLAUDE_LANGS
REAL_CLAUDE_LANGS=( python go rust typescript ruby )

COMMAND=""
SYNTHETIC_ONLY=false
COUNT=50
DURATION=0
WORKER_MODE="shell-spawn"

usage() {
  sed -n '2,28p' "$0"
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --start)          COMMAND="start"; shift ;;
    --stop)           COMMAND="stop"; shift ;;
    --status)         COMMAND="status"; shift ;;
    --reset)          COMMAND="reset"; shift ;;
    --synthetic-only) SYNTHETIC_ONLY=true; shift ;;
    --count)          COUNT="$2"; shift 2 ;;
    --duration)       DURATION="$2"; shift 2 ;;
    --worker-mode)    WORKER_MODE="$2"; shift 2 ;;
    --help|-h)        usage 0 ;;
    *) echo "Unknown option: $1" >&2; usage 1 ;;
  esac
done

case "$WORKER_MODE" in
  shell-spawn|bashtool-sim) ;;
  *) echo "Error: --worker-mode must be shell-spawn or bashtool-sim" >&2; exit 1 ;;
esac

[[ -z "$COMMAND" ]] && { echo "Error: must pass --start, --stop, --status, or --reset" >&2; usage 1; }
(( COUNT > 50 )) && { echo "Error: --count cannot exceed 50" >&2; exit 1; }
(( COUNT < 1  )) && { echo "Error: --count must be >= 1" >&2; exit 1; }

mkdir -p "$LOGDIR"

# Write the synthetic worker body to a file so spawned subshells can exec it.
# Each synthetic worker: loop forever spawning interactive zsh in its subdir +
# periodic file writes. Uses zsh -i -c (interactive) so the direnv hook fires
# on every spawn - this is the primitive that reproduces the user's scenario
# of "tons of terminals triggering direnv".
WORKER_SCRIPT="$GROUND/.worker.zsh"
cat > "$WORKER_SCRIPT" <<'WORKER_EOF'
#!/usr/bin/env zsh
# Synthetic hang-investigation worker.
# Args: <lang>
# Env: WORKER_MODE = shell-spawn (default) | bashtool-sim
#
# shell-spawn:  zsh -i -c true each iteration. Loads .zshrc. Fires direnv
#               via .zshrc's lazy_direnv_hook. This is what a real terminal
#               tab's shell does on open.
# bashtool-sim: source the latest Claude Code shell snapshot in a fresh bash
#               each iteration. This mirrors what Claude's BashTool does per
#               tool call - NOT a full .zshrc load, but a snapshot re-source.
#               The snapshot contains direnv_export + lazy_direnv_hook (they
#               survive the snapshot filter), so direnv still fires per call.
set -u
lang="${1:?}"
ground="${LOAD_GEN_GROUND:?}"
mode="${WORKER_MODE:-shell-spawn}"
logfile="$ground/.logs/$lang.log"
work_dir="$ground/$lang"
cd "$work_dir" || exit 1

# Resolve snapshot once per worker start (cached for the loop lifetime).
snapshot=""
if [[ "$mode" == "bashtool-sim" ]]; then
  snapshot=$(ls -t "$HOME"/.claude/shell-snapshots/snapshot-zsh-*.sh 2>/dev/null | head -1)
  if [[ -z "$snapshot" ]]; then
    echo "[error] bashtool-sim requires a Claude shell snapshot at $HOME/.claude/shell-snapshots/; falling back to shell-spawn" >> "$logfile"
    mode="shell-spawn"
  fi
fi

n=0
echo "[start] $(date '+%F %T') pid=$$ lang=$lang mode=$mode" >> "$logfile"
while true; do
  if [[ "$mode" == "bashtool-sim" ]]; then
    # Mirror Claude BashTool: fresh bash + source snapshot + run a trivial cmd.
    bash -c "source '$snapshot'; true" >/dev/null 2>&1
  else
    zsh -i -c "true" >/dev/null 2>&1
  fi
  # File-write churn (mimics Claude BashTool writing files): ~100KB of base64.
  head -c 102400 /dev/urandom | base64 > "work-$((n % 5)).txt"
  n=$((n + 1))
  if (( n % 100 == 0 )); then
    echo "[tick] $(date '+%F %T') lang=$lang iterations=$n" >> "$logfile"
  fi
done
WORKER_EOF
chmod +x "$WORKER_SCRIPT"

# Claude worker - invokes `claude -p` with a prompt designed to sustain ~30
# minutes of real agentic work per worker. Key traits of the prompt:
#   - Large feature surface so scaffolding alone cannot satisfy it.
#   - Explicit write-then-test-then-fix loop so each iteration uses BashTool
#     (this is what actually re-triggers direnv + shell startup under the
#     hang-investigation hypothesis).
#   - Forbids plan-only / summary-only responses.
#   - Tells claude to keep working through test failures, not to ask questions.
# All 5 workers get identical instructions, only the language differs.
#
# Per-worker safety: --dangerously-skip-permissions because each claude
# operates in its own testing_grounds/<lang>/ sandbox and would otherwise
# block on tool prompts. --max-budget-usd caps runaway cost per worker.
CLAUDE_SCRIPT="$GROUND/.claude-worker.zsh"
cat > "$CLAUDE_SCRIPT" <<'CLAUDE_EOF'
#!/usr/bin/env zsh
# Real-claude hang-investigation worker.
# Args: <lang>
set -u
lang="${1:?}"
ground="${LOAD_GEN_GROUND:?}"
logfile="$ground/.logs/$lang.claude.log"
work_dir="$ground/$lang"
cd "$work_dir" || exit 1
echo "[start] $(date '+%F %T') lang=$lang" >> "$logfile"

read -r -d '' PROMPT <<PROMPT_EOF || true
Build a complete personal-finance CLI application in ${lang}, from scratch, in the current directory. This is a long engagement - not a plan, not a summary, not a partial scaffold. Do not stop until every feature below exists, every test passes, and you have verified the working CLI end-to-end by actually running it.

Do NOT write a plan and exit. Do NOT ask clarifying questions. Make reasonable assumptions and implement. If you hit a blocker, pick an alternative and keep going.

Required features (all of them):
  1. Transaction CRUD: add, list, update, delete - with id, date, amount, category, type (income/expense), description.
  2. Account management: create, list, archive accounts (checking, savings, credit).
  3. Categories with monthly budget limits; warn when a category exceeds its limit.
  4. Reports: monthly income vs expenses, per-category breakdown, rolling 6-month trend.
  5. CSV import and CSV export.
  6. Recurring-transaction templates (weekly, monthly, yearly).
  7. Persistence: SQLite where idiomatic, otherwise a JSON file. Include a schema migration step.
  8. Every invalid input path has a clear error message and non-zero exit code.
  9. At least 20 unit tests covering edge cases (negative amounts, duplicate CSV rows, timezone boundaries, empty DB, malformed JSON, over-budget, archived account).
 10. Integration tests that drive the CLI end-to-end via subprocess calls and assert on stdout/stderr/exit code.
 11. README with install, every subcommand shown with an example, data file location, testing instructions, and a short architecture section.

Workflow you MUST follow:
  (a) Scaffold the project using idiomatic ${lang} conventions (cargo/npm/go mod/bundle/etc).
  (b) Implement features ONE AT A TIME. After each feature: write its tests, run the full test suite, fix any failures, re-run until green. Commit the pattern "write -> run -> fix -> re-run".
  (c) After all features are in: run the full test suite again and fix anything that regressed.
  (d) Do a final polish pass: formatter, linter, docstrings/comments, README touch-up.
  (e) Manually exercise the CLI (add, list, report, import, export) via BashTool and paste the outputs into the log so the run is verifiable.

Use the Bash tool aggressively to verify your work at every step. Every file change should be followed by a test run. Working silently is fine - just keep working. Stop only when the app is built, tested, and you have personally exercised it end-to-end. No ETAs, no status updates, no premature completion.
PROMPT_EOF

claude -p "$PROMPT" \
  --dangerously-skip-permissions \
  --max-budget-usd 5 \
  --output-format text \
  >> "$logfile" 2>&1
echo "[end]   $(date '+%F %T') lang=$lang rc=$?" >> "$logfile"
CLAUDE_EOF
chmod +x "$CLAUDE_SCRIPT"

cmd_start() {
  if [[ -f "$PIDFILE" ]]; then
    local alive=0 pid
    while IFS= read -r pid; do
      kill -0 "$pid" 2>/dev/null && (( alive++ ))
    done < "$PIDFILE"
    if (( alive > 0 )); then
      echo "Error: $alive processes already alive from previous --start. Run --stop first." >&2
      exit 1
    fi
    rm -f "$PIDFILE"
  fi

  local synthetic_count real_count
  if $SYNTHETIC_ONLY; then
    synthetic_count=$COUNT
    real_count=0
  else
    real_count=$(( COUNT < 5 ? COUNT : 5 ))
    synthetic_count=$(( COUNT - real_count ))
  fi

  echo "Starting fleet: $synthetic_count synthetic + $real_count real-claude workers"
  echo "  ground: $GROUND"
  echo "  logs:   $LOGDIR"
  [[ $DURATION -gt 0 ]] && echo "  auto-stop after ${DURATION}s"
  echo ""

  : > "$PIDFILE"
  local i lang

  # Synthetic workers - pick ${synthetic_count} langs from ALL_LANGS, skipping
  # those reserved for real claudes (so each subdir only has one worker).
  typeset -a synth_langs
  if $SYNTHETIC_ONLY; then
    synth_langs=( "${ALL_LANGS[@]:0:$synthetic_count}" )
  else
    # Drop the real-claude langs, then take the first `synthetic_count` of rest.
    local -a remaining
    for lang in "${ALL_LANGS[@]}"; do
      if [[ ${REAL_CLAUDE_LANGS[(Ie)$lang]} -eq 0 ]]; then
        remaining+=("$lang")
      fi
    done
    synth_langs=( "${remaining[@]:0:$synthetic_count}" )
  fi

  echo "  synthetic worker-mode: $WORKER_MODE"
  for lang in "${synth_langs[@]}"; do
    LOAD_GEN_GROUND="$GROUND" WORKER_MODE="$WORKER_MODE" \
      nohup "$WORKER_SCRIPT" "$lang" </dev/null >/dev/null 2>&1 &
    local pid=$!
    echo "$pid" >> "$PIDFILE"
    printf "  synth  [%-14s] pid=%d\n" "$lang" "$pid"
  done

  # Real claude workers
  if ! $SYNTHETIC_ONLY; then
    for lang in "${REAL_CLAUDE_LANGS[@]:0:$real_count}"; do
      LOAD_GEN_GROUND="$GROUND" nohup "$CLAUDE_SCRIPT" "$lang" </dev/null >/dev/null 2>&1 &
      local pid=$!
      echo "$pid" >> "$PIDFILE"
      printf "  claude [%-14s] pid=%d\n" "$lang" "$pid"
    done
  fi

  echo ""
  echo "Fleet started. PIDs recorded to $PIDFILE"
  echo "Run --stop to terminate, --status to check survivors."

  if (( DURATION > 0 )); then
    echo "Auto-stopping in ${DURATION}s..."
    # Write a tiny self-invocation script so nohup can execute it cleanly.
    # The scheduler MUST survive load-gen.zsh's own exit; backgrounding with &
    # alone isn't enough if the parent shell's process group gets SIGHUP.
    local autostop_script="$GROUND/.autostop.zsh"
    cat > "$autostop_script" <<AUTOSTOP_EOF
#!/usr/bin/env zsh
sleep $DURATION
exec "$SCRIPT_DIR/load-gen.zsh" --stop
AUTOSTOP_EOF
    chmod +x "$autostop_script"
    nohup "$autostop_script" </dev/null >> "$LOGDIR/autostop.log" 2>&1 &
    local autostop_pid=$!
    echo "$autostop_pid" >> "$PIDFILE"
    echo "(auto-stop scheduler pid=$autostop_pid, will run --stop in ${DURATION}s)"
  fi
}

cmd_stop() {
  if [[ ! -f "$PIDFILE" ]]; then
    echo "No pidfile at $PIDFILE - nothing to stop."
    return 0
  fi
  local pid killed=0 missed=0 self=$$
  while IFS= read -r pid; do
    # Skip our own PID: cmd_stop can be invoked from the auto-stop scheduler
    # subshell, whose PID is also in the pidfile. Killing ourselves mid-cleanup
    # aborts the rest of the stop sequence (notably `rm -f "$PIDFILE"`).
    [[ "$pid" == "$self" ]] && continue
    if kill -0 "$pid" 2>/dev/null; then
      kill -TERM "$pid" 2>/dev/null
      (( killed++ ))
    else
      (( missed++ ))
    fi
  done < "$PIDFILE"

  # Sweep by pattern as a safety net: orphaned workers may not match any
  # recorded PID if they forked further, and nohup-launched claude processes
  # spawn their own subprocesses.
  pkill -TERM -f "$WORKER_SCRIPT" 2>/dev/null || true
  pkill -TERM -f "$CLAUDE_SCRIPT" 2>/dev/null || true

  # Give them 2s to exit, then SIGKILL the stragglers.
  sleep 2
  while IFS= read -r pid; do
    [[ "$pid" == "$self" ]] && continue
    kill -0 "$pid" 2>/dev/null && kill -KILL "$pid" 2>/dev/null
  done < "$PIDFILE"
  pkill -KILL -f "$WORKER_SCRIPT" 2>/dev/null || true
  pkill -KILL -f "$CLAUDE_SCRIPT" 2>/dev/null || true

  rm -f "$PIDFILE"
  echo "Stopped: killed=$killed already-gone=$missed"
}

cmd_status() {
  if [[ ! -f "$PIDFILE" ]]; then
    echo "No pidfile; fleet is not running."
    return 0
  fi
  local pid alive=0 dead=0
  while IFS= read -r pid; do
    if kill -0 "$pid" 2>/dev/null; then
      (( alive++ ))
    else
      (( dead++ ))
    fi
  done < "$PIDFILE"
  echo "Fleet status: alive=$alive dead=$dead (pidfile: $PIDFILE)"
  # Also show active worker scripts in case some spun up outside the pidfile.
  local worker_procs=$(pgrep -f "$WORKER_SCRIPT" 2>/dev/null | wc -l | tr -d ' ')
  local claude_procs=$(pgrep -f "$CLAUDE_SCRIPT" 2>/dev/null | wc -l | tr -d ' ')
  echo "Active processes: .worker.zsh=$worker_procs  .claude-worker.zsh=$claude_procs"
}

cmd_reset() {
  # Wipe per-lang work artifacts so workers don't start from inherited state
  # (stale work-*.txt, partially-built budgeting apps from prior claude runs).
  # Preserves .envrc so `direnv allow` stays valid. Calls scaffold at the end
  # to restore any auxiliary structure (e.g. heavy/bin dir).
  setopt local_options null_glob no_xtrace  # tolerate empty globs + silence xtrace
  if [[ ! -d "$GROUND" ]]; then
    echo "No testing_grounds dir - nothing to reset."
    return 0
  fi
  if [[ -f "$PIDFILE" ]]; then
    echo "Error: fleet looks active (pidfile exists). Run --stop first." >&2
    exit 1
  fi
  local d cleaned=0
  for d in "$GROUND"/*/; do
    [[ -d "$d" ]] || continue
    [[ "${d:t}" == ".logs" ]] && continue
    # Preserve .envrc; delete everything else in the subdir. Glob both
    # dotfiles and regular files, tolerate empty results.
    local f
    for f in "$d".* "$d"*; do
      [[ -e "$f" ]] || continue
      [[ "${f:t}" == ".envrc" ]] && continue
      [[ "${f:t}" == "." || "${f:t}" == ".." ]] && continue
      rm -rf "$f"
    done
    (( cleaned++ ))
  done
  # Clear logs too so tick history doesn't pile up across runs.
  rm -f "$LOGDIR"/*.log "$LOGDIR"/*.claude.log 2>/dev/null
  # Re-scaffold to restore helper structure (idempotent).
  if [[ -x "$SCRIPT_DIR/scaffold-testing-grounds.zsh" ]]; then
    "$SCRIPT_DIR/scaffold-testing-grounds.zsh" >/dev/null 2>&1 || true
  fi
  echo "Reset: cleaned $cleaned subdir(s); .envrc preserved; logs cleared; scaffold re-applied."
}

case "$COMMAND" in
  start)  cmd_start ;;
  stop)   cmd_stop ;;
  status) cmd_status ;;
  reset)  cmd_reset ;;
esac
