#!/usr/bin/env zsh
# Run ONE benchmark cell: pin session model+effort, solve a fixed outcome-defined task,
# capture per-run token accounting from Claude Code's own JSON, verify the bound model,
# and grade with a HIDDEN checker the model never saw (catches overfit to visible tests).
#
# Usage: run-cell.zsh <task> <model-alias-or-id> <effort> <rep> [results.tsv]
# outcome: pass | overfit (visible ok, hidden fail) | cheated (edited checker) | fail

set -u
SCRIPT_DIR="${0:A:h}"
TASK="$1"; MODEL="$2"; EFFORT="$3"; REP="$4"
RESULTS="${5:-$HOME/.claude-artifacts/skills/optimize-usage/results.tsv}"
mkdir -p "${RESULTS:h}"
TDIR="$SCRIPT_DIR/tasks/$TASK"
[[ -d "$TDIR" ]] || { print "no such task: $TASK" >&2; exit 2 }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
# Give the model everything EXCEPT the hidden checker and the prompt file.
for f in "$TDIR"/*(.N); do
  case "${f:t}" in
    hidden_check.py|prompt.txt) ;;
    *) cp "$f" "$WORK/${f:t}" ;;
  esac
done
CHECK_HASH_BEFORE="$(shasum "$WORK/check.py" | awk '{print $1}')"
PROMPT="$(<"$TDIR/prompt.txt")"

OUT="$WORK/out.json"
if [[ -n "${BENCH_SOLVER:-}" ]]; then
  # Test hook: run an injected solver instead of Claude, to exercise grading paths.
  # stderr passes through — solver failures must be visible, not silently graded.
  ( cd "$WORK" && eval "$BENCH_SOLVER" >"$OUT" )
  CLI_RC=$?
else
  ( cd "$WORK" && claude -p "$PROMPT" \
      --model "$MODEL" --effort "$EFFORT" \
      --output-format json --permission-mode bypassPermissions \
      >"$OUT" 2>/dev/null )
  CLI_RC=$?
fi
[[ -s "$OUT" ]] || print "WARN: no output JSON ($TASK $MODEL/$EFFORT rep $REP, rc=$CLI_RC) — row will drop as bound-model mismatch" >&2

# --- grade ---
CHECK_HASH_AFTER="$(shasum "$WORK/check.py" 2>/dev/null | awk '{print $1}')"
( cd "$WORK" && python3 check.py        >/dev/null 2>&1 ); VIS=$?
cp "$TDIR/hidden_check.py" "$WORK/hidden_check.py"
( cd "$WORK" && python3 hidden_check.py >/dev/null 2>&1 ); HID=$?

if [[ "$CHECK_HASH_AFTER" != "$CHECK_HASH_BEFORE" ]]; then
  OUTCOME=cheated
elif [[ $HID -eq 0 ]]; then
  OUTCOME=pass
elif [[ $VIS -eq 0 ]]; then
  OUTCOME=overfit
else
  OUTCOME=fail
fi

python3 - "$OUT" "$TASK" "$MODEL" "$EFFORT" "$REP" "$OUTCOME" "$CLI_RC" "$RESULTS" <<'PY'
import json, sys, os, datetime
out, task, model, effort, rep, outcome, cli_rc, results = sys.argv[1:9]
try: d = json.load(open(out))
except Exception: d = {}
usage = d.get("usage") or {}
mu = d.get("modelUsage") or {}
bound, best = "?", -1
for m, v in mu.items():
    tok = (v.get("inputTokens", 0) or 0) + (v.get("cacheCreationInputTokens", 0) or 0)
    if tok > best: best, bound = tok, m
row = [
    datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
    task, model, effort, rep, bound, outcome,
    str(d.get("num_turns", "")), f'{d.get("total_cost_usd", 0):.6f}',
    str(usage.get("input_tokens", "")), str(usage.get("output_tokens", "")),
    str(usage.get("cache_read_input_tokens", "")), str(usage.get("cache_creation_input_tokens", "")),
]
new = not os.path.exists(results)
with open(results, "a") as f:
    if new: f.write("ts\ttask\tmodel\teffort\trep\tbound_model\toutcome\tturns\tcost_usd\tin\tout\tcread\tccreate\n")
    f.write("\t".join(row) + "\n")
flag = "" if outcome == "pass" else f"  <-- {outcome.upper()}"
print(f"  {task:16} {model:26} eff={effort:5} rep={rep}  {outcome:7} "
      f"turns={d.get('num_turns','?'):>2} cost=${d.get('total_cost_usd',0):.4f}{flag}")
if cli_rc != "0": print(f"    WARNING: claude exited {cli_rc}")
PY