#!/usr/bin/env bash
# run-probes.sh -- reader probes against the synthetic ticketing vault (L19,
# Phase 1). Measures whether a Claude reader, given only the fixture repo
# and the deployed reader rules, answers questions correctly and abstains
# where the vault is silent.
#
#   run-probes.sh [--model haiku|sonnet] [--judge-model haiku|sonnet]
#                 [--replicates N] [--jobs N] [--rule-line TEXT] [--label TEXT]
#                 [--regress] [--dry] [--force]
#
# Builds a scratch repo under mktemp -d from fixture/ with a CLAUDE.md that
# points at the vault (plus --rule-line, an extra reader-rule sentence under
# test), then runs every probe in probes.jsonl N times with
# `claude -p ... --disallowedTools Write,Edit,Bash` from the repo root. A
# probe with expect.regex is judged mechanically (every regex must match,
# no not_regex may); the rest go to one judge call with judge.md and the
# reference answer. The receipt lands at
# receipts/<corpus8>-<prompt8>-<models8>-<rubric8>.json (git hash-object of
# the fixture tree listing, probes.jsonl plus the rule line, the two model
# names, judge.md); an existing receipt makes the run a no-op unless
# --force. --dry builds the scratch repo, prints the hashes and the receipt
# path, and runs nothing. --regress compares the receipt to
# receipts/baseline-<corpus8>-<rubric8>.json: exit 1 on any fixture lint
# FAIL/WARN count increase, a category pass-count drop beyond
# max(0.5, 2 x the baseline's replicate noise), or a pass-to-fail flip on a
# safety probe (KU, ABS, DRIFT). Exit 0 ok, 1 regression, 2 usage or a
# missing tool.
set -u
export LC_ALL=C
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$HERE/../../scripts"
FIXTURE="$HERE/fixture"
PROBES="$HERE/probes.jsonl"
JUDGE_FILE="$HERE/judge.md"
RECEIPTS="$HERE/receipts"
JQ=${JQ:-$(command -v jq || echo /usr/bin/jq)}

MODEL=haiku; JUDGE=haiku; REPL=3; JOBS=4; RULE_LINE=""; LABEL=""; REGRESS=0; DRY=0; FORCE=0
usage() { sed -n '2,29p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
while [ $# -gt 0 ]; do
  case "$1" in
    --model) shift; MODEL="${1:-}" ;;
    --judge-model) shift; JUDGE="${1:-}" ;;
    --replicates) shift; REPL="${1:-}" ;;
    --jobs) shift; JOBS="${1:-}" ;;
    --rule-line) shift; RULE_LINE="${1:-}" ;;
    --label) shift; LABEL="${1:-}" ;;
    --regress) REGRESS=1 ;;
    --dry) DRY=1 ;;
    --force) FORCE=1 ;;
    *) usage ;;
  esac
  shift
done
case "$MODEL" in haiku|sonnet) ;; *) usage ;; esac
case "$JUDGE" in haiku|sonnet) ;; *) usage ;; esac
case "$REPL$JOBS" in *[!0-9]*|'') usage ;; esac
[ "$REPL" -ge 1 ] && [ "$JOBS" -ge 1 ] || usage
[ -f "$PROBES" ] && [ -f "$JUDGE_FILE" ] && [ -d "$FIXTURE" ] || { echo "run-probes: fixture, probes.jsonl or judge.md missing" >&2; exit 2; }
command -v git >/dev/null || { echo "run-probes: git is required" >&2; exit 2; }
[ "$DRY" = 1 ] || command -v claude >/dev/null || { echo "run-probes: claude is not on PATH" >&2; exit 2; }
# The pre-commit hook may invoke this with git's hook environment set.
unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE GIT_PREFIX GIT_COMMON_DIR

TMP=$(mktemp -d) || exit 2
trap 'rm -rf "$TMP"' EXIT
SCR="$TMP/repo"
mkdir -p "$SCR" "$RECEIPTS" "$TMP/runs"
cp -R "$FIXTURE/." "$SCR/"
{
  printf '# Ticketing service\n\n'
  printf 'The knowledge vault for this project is `docs/project-knowledge/`. Answer questions about the project from the vault and the code under `src/`, and name the note or file each answer came from. When the vault does not record something, say so.\n'
  [ -n "$RULE_LINE" ] && printf '\n%s\n' "$RULE_LINE"
} > "$SCR/CLAUDE.md"
git -C "$SCR" init -q .
git -C "$SCR" -c user.name=probe -c user.email=probe@example.invalid add -A
git -C "$SCR" -c user.name=probe -c user.email=probe@example.invalid commit -q -m "probe fixture"

# hashes
CORPUS8=$( (cd "$FIXTURE" && find . -type f -not -path './.git/*' | LC_ALL=C sort | while IFS= read -r f; do printf '%s %s\n' "$(git hash-object "$f")" "$f"; done) | git hash-object --stdin | cut -c1-8)
PROMPT8=$( { cat "$PROBES"; printf '%s' "$RULE_LINE"; } | git hash-object --stdin | cut -c1-8)
MODELS8=$(printf '%s/%s' "$MODEL" "$JUDGE" | git hash-object --stdin | cut -c1-8)
RUBRIC8=$(git hash-object "$JUDGE_FILE" | cut -c1-8)
RECEIPT="$RECEIPTS/$CORPUS8-$PROMPT8-$MODELS8-$RUBRIC8.json"
BASELINE="$RECEIPTS/baseline-$CORPUS8-$RUBRIC8.json"
NPROBES=$(grep -c . "$PROBES")

# fixture lint counts travel with the receipt so a mechanical regression
# (a fixture edit that broke a note) is caught before any probe is read.
bash "$SCRIPTS/lint-vault.sh" --format json "$SCR/docs/project-knowledge" > "$TMP/lint.json" 2>/dev/null
"$JQ" '{fail, warn, by_code}' "$TMP/lint.json" > "$TMP/lint_counts.json"

if [ "$DRY" = 1 ]; then
  printf 'probes: %s\nreplicates: %s\nmodel: %s\njudge: %s\nhashes: corpus=%s prompt=%s models=%s rubric=%s\nreceipt: %s\nbaseline: %s\nfixture lint: %s\n' \
    "$NPROBES" "$REPL" "$MODEL" "$JUDGE" "$CORPUS8" "$PROMPT8" "$MODELS8" "$RUBRIC8" \
    "receipts/$(basename "$RECEIPT")" "receipts/$(basename "$BASELINE")$([ -f "$BASELINE" ] || printf ' (absent)')" \
    "$("$JQ" -c '{fail, warn}' "$TMP/lint_counts.json")"
  exit 0
fi

if [ -f "$RECEIPT" ] && [ "$FORCE" = 0 ]; then
  echo "run-probes: receipt exists, nothing to run: receipts/$(basename "$RECEIPT")"
else
  # NUL-separated id, rep, question triples (a question has spaces)
  "$JQ" -j --argjson n "$REPL" '. as $p | range(1; $n + 1) | "\($p.id)\u0000\(.)\u0000\($p.question)\u0000"' "$PROBES" > "$TMP/tasks.nul"
  run_one() {
    local id="$1" rep="$2" q="$3" out
    out=$(cd "$SCR" && claude -p "$q" --model "$MODEL" --output-format json \
          --disallowedTools Write,Edit,NotebookEdit,Bash,WebFetch,WebSearch </dev/null 2>/dev/null)
    [ -n "$out" ] || out='{}'
    printf '%s' "$out" | "$JQ" -c --arg id "$id" --argjson rep "$rep" '
      {id: $id, rep: $rep, answer: (.result // ""), is_error: (if .is_error == null then true else .is_error end),
       tokens: (((.usage.input_tokens // 0) + (.usage.output_tokens // 0) + (.usage.cache_read_input_tokens // 0) + (.usage.cache_creation_input_tokens // 0))),
       cost: (.total_cost_usd // 0), duration_ms: (.duration_ms // 0)}' > "$TMP/runs/$id.$rep.json" 2>/dev/null \
      || printf '{"id":"%s","rep":%s,"answer":"","is_error":true,"tokens":0,"cost":0,"duration_ms":0}\n' "$id" "$rep" > "$TMP/runs/$id.$rep.json"
  }
  export -f run_one
  export SCR MODEL TMP JQ
  xargs -0 -P "$JOBS" -n 3 bash -c 'run_one "$0" "$1" "$2"' < "$TMP/tasks.nul"

  # judge every run
  judge_one() {
    local f="$1" id ans probe rx nrx pass=1 judged=regex verdict reason=""
    id=$("$JQ" -r '.id' "$f"); ans=$("$JQ" -r '.answer' "$f")
    probe=$("$JQ" -c --arg id "$id" 'select(.id == $id)' "$PROBES")
    if [ "$(printf '%s' "$probe" | "$JQ" -r '.expect.regex // [] | length')" -gt 0 ]; then
      while IFS= read -r rx; do [ -n "$rx" ] || continue; printf '%s' "$ans" | grep -Eiq -e "$rx" || pass=0; done <<EOF
$(printf '%s' "$probe" | "$JQ" -r '.expect.regex[]')
EOF
      while IFS= read -r nrx; do [ -n "$nrx" ] || continue; printf '%s' "$ans" | grep -Eiq -e "$nrx" && pass=0; done <<EOF
$(printf '%s' "$probe" | "$JQ" -r '.expect.not_regex // [] | .[]')
EOF
      [ -n "$ans" ] || pass=0
    else
      judged=$JUDGE
      verdict=$(cd "$TMP" && claude -p "$(cat "$JUDGE_FILE")

QUESTION:
$(printf '%s' "$probe" | "$JQ" -r '.question')

REFERENCE:
$(printf '%s' "$probe" | "$JQ" -r '.expect.reference')

ANSWER:
${ans:-(empty)}" --model "$JUDGE" --output-format json --disallowedTools Write,Edit,NotebookEdit,Bash,WebFetch,WebSearch,Read,Glob,Grep </dev/null 2>/dev/null | "$JQ" -r '.result // ""' | tr -d '\r')
      reason=$(printf '%s' "$verdict" | sed -n '2,$p' | tr '\n' ' ' | cut -c1-300)
      verdict=$(printf '%s' "$verdict" | head -n 1 | awk '{ print toupper($1) }' | tr -d '*.:')
      [ "$verdict" = PASS ] || pass=0
    fi
    "$JQ" -c --argjson pass "$pass" --arg judged "$judged" --arg reason "$reason" '. + {pass: ($pass == 1), judged_by: $judged, judge_reason: $reason}' "$f" > "$f.judged" && mv "$f.judged" "$f"
  }
  export -f judge_one
  export PROBES JUDGE JUDGE_FILE
  find "$TMP/runs" -name '*.json' -print0 | xargs -0 -P "$JOBS" -n 1 bash -c 'judge_one "$0"'

  cat "$TMP/runs"/*.json | "$JQ" -s --slurpfile probes <("$JQ" -c . "$PROBES" | "$JQ" -s .) --slurpfile lint "$TMP/lint_counts.json" \
    --arg model "$MODEL" --arg judge "$JUDGE" --argjson repl "$REPL" --arg rule "$RULE_LINE" --arg label "$LABEL" \
    --arg corpus "$CORPUS8" --arg prompt "$PROMPT8" --arg models "$MODELS8" --arg rubric "$RUBRIC8" --arg gen "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
    . as $runs |
    ($probes[0] | map(. as $p | {id: $p.id, category: $p.category, safety: ($p.safety // false),
        judged_by: ([$runs[] | select(.id == $p.id)][0].judged_by // "regex"),
        runs: ([$runs[] | select(.id == $p.id)] | sort_by(.rep) | map({rep, pass, tokens, cost, is_error, judge_reason, answer})),
        pass_rate: (([$runs[] | select(.id == $p.id) | .pass] | map(if . then 1 else 0 end) | add) / $repl)})) as $P |
    ($P | group_by(.category) | map({key: .[0].category, value: {
        n: length,
        pass_rate: ((map(.pass_rate) | add) / length),
        per_replicate: ([range(1; $repl + 1) as $r | ([.[] | .runs[] | select(.rep == $r and .pass)] | length)])}}) | from_entries) as $C |
    {version: 1, label: $label, generated: $gen, model: $model, judge_model: $judge, replicates: $repl, rule_line: $rule,
     hashes: {corpus: $corpus, prompt: $prompt, models: $models, rubric: $rubric},
     fixture_lint: $lint[0], probes: $P, categories: $C,
     totals: {pass_rate: (($P | map(.pass_rate) | add) / ($P | length)),
              tokens_per_probe: (($runs | map(.tokens) | add) / ($runs | length)),
              cost_usd: ($runs | map(.cost) | add), errors: ([$runs[] | select(.is_error)] | length)}}' > "$RECEIPT"
  echo "run-probes: wrote receipts/$(basename "$RECEIPT")"
fi

"$JQ" -r '"pass \(.totals.pass_rate * 100 | floor)% over \(.probes | length) probes x \(.replicates); tokens/probe \(.totals.tokens_per_probe | floor); errors \(.totals.errors)",
          (.categories | to_entries[] | "  \(.key): \(.value.pass_rate * 100 | floor)% (n=\(.value.n), per replicate \(.value.per_replicate | join("/")))")' "$RECEIPT"

[ "$REGRESS" = 1 ] || exit 0
[ -f "$BASELINE" ] || { echo "run-probes: no baseline for this corpus/rubric: receipts/$(basename "$BASELINE")" >&2; exit 2; }
"$JQ" -r -n --slurpfile b "$BASELINE" --slurpfile n "$RECEIPT" '
  def sd: if length < 2 then 0 else (add / length) as $m | (map((. - $m) * (. - $m)) | add / (length - 1)) | sqrt end;
  $b[0] as $B | $n[0] as $N |
  (if $B.hashes.corpus != $N.hashes.corpus or $B.hashes.rubric != $N.hashes.rubric then "REFUSED baseline corpus/rubric differ" else empty end),
  (if $N.fixture_lint.fail > $B.fixture_lint.fail then "FAIL fixture lint FAIL \($B.fixture_lint.fail) -> \($N.fixture_lint.fail)" else empty end),
  (if $N.fixture_lint.warn > $B.fixture_lint.warn then "FAIL fixture lint WARN \($B.fixture_lint.warn) -> \($N.fixture_lint.warn)" else empty end),
  ($N.categories | to_entries[] | .key as $c | .value as $nc | ($B.categories[$c] // null) as $bc |
    if $bc == null then empty else
      (($bc.per_replicate | sd) * 2) as $noise |
      (($bc.pass_rate - $nc.pass_rate) * $nc.n) as $drop |
      if $drop > ([0.5, $noise] | max) then "FAIL \($c) dropped \($drop * 100 / $nc.n | floor)% (\($bc.pass_rate * 100 | floor)% -> \($nc.pass_rate * 100 | floor)%, allowed \(([0.5, $noise] | max)) probes)" else empty end
    end),
  ($N.probes[] | select(.safety) | .id as $id | ($B.probes[] | select(.id == $id)) as $bp |
    if $bp.pass_rate >= 0.5 and .pass_rate < 0.5 then "FAIL safety flip \($id) \($bp.pass_rate) -> \(.pass_rate)" else empty end)
' > "$TMP/regress.txt"
if grep -q . "$TMP/regress.txt"; then cat "$TMP/regress.txt"; exit 1; fi
echo "regress: ok against receipts/$(basename "$BASELINE")"
exit 0
