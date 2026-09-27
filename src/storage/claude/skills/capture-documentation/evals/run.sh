#!/usr/bin/env bash
# run.sh -- golden-output eval suite for lint-vault.sh, guard-vault-write.sh,
# vault-search.sh, and vault-mentions.sh.
#
#   bash evals/run.sh            run every case, diff against expected/*.txt
#   bash evals/run.sh --update   rewrite expected/*.txt from actual output
#
# Builds a throwaway git repo under $TMPDIR from fixture/ (never touches the
# real ~/.claude/ or the checked-in fixture/), runs each case against it, and
# normalizes output (temp path stripped, LC_ALL=C, no dates/timing) so a run
# is byte-identical across machines and across repeated invocations.
set -u

JQ=${JQ:-$(command -v jq || echo /usr/bin/jq)}
export LC_ALL=C
# The pre-commit hook runs this suite with git's hook environment set; a
# relative GIT_INDEX_FILE breaks every git call inside the scratch repos.
unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE GIT_PREFIX GIT_COMMON_DIR
# Pins vault_today() (vault-lib.sh) so vault-freshness.sh's cadence/revisit
# math and vault-drift.sh's flag "opened" date are wall-clock independent --
# without this, every rank4/revisit_by comparison would drift with the
# machine's real date and could never produce a stable golden file.
export VAULT_TODAY=2026-09-26

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE="$HERE/fixture"
CHANGE="$HERE/change"
EXPECTED="$HERE/expected"

SCRIPTS="$HERE/../scripts"
LINT="$SCRIPTS/lint-vault.sh"
SEARCH="$SCRIPTS/vault-search.sh"
MENTIONS="$SCRIPTS/vault-mentions.sh"
DRIFT="$SCRIPTS/vault-drift.sh"
FRESHNESS="$SCRIPTS/vault-freshness.sh"
GENRULES="$SCRIPTS/gen-vault-rules.sh"
AUDIT="$SCRIPTS/vault-audit.sh"
REFACTOR="$SCRIPTS/vault-refactor.sh"
GUARD="$HERE/../../../hooks/guard-vault-write.sh"

ARG="${1:-}"
case "$ARG" in
  --update) MODE=update ;;
  "") MODE=check ;;
  *) echo "usage: $0 [--update]" >&2; exit 2 ;;
esac

WORK=$(mktemp -d) || { echo "run.sh: cannot create temp dir" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
WORK_REAL="$(cd "$WORK" && pwd -P)"

must() {
  if ! "$@" >"$WORK/must.log" 2>&1; then
    echo "run.sh: setup step failed: $*" >&2
    cat "$WORK/must.log" >&2
    exit 2
  fi
}

# normalize STREAM : strip the temp root (both the logical and physical form,
# in case a platform resolves TMPDIR through a symlink) so captured output is
# stable across machines and across repeated runs on the same machine.
normalize() {
  sed -e "s#$WORK_REAL#<tmp>#g" -e "s#$WORK#<tmp>#g"
}

# gen_dots N : print N '.' bytes, no trailing newline. String-doubling keeps
# this O(log N) instead of an O(N) awk/printf loop, so padding a 500KB+ note
# stays fast enough for the whole-vault under-5s budget.
gen_dots() {
  local n="$1" s="."
  [ "$n" -le 0 ] && return 0
  while [ "${#s}" -lt "$n" ]; do s="$s$s"; done
  printf '%s' "${s:0:$n}"
}

# append_long_line FILE LEN : append one line of LEN '.' chars. This becomes
# the note's/hub's single longest line -- SIZE_LINE/SIZE_HUB_LINE(_LIMIT) are
# each a single per-note finding keyed off the max line, not one per line.
append_long_line() {
  local f="$1" len="$2"
  [ -s "$f" ] && [ -n "$(tail -c 1 "$f")" ] && printf '\n' >> "$f"
  { gen_dots "$len"; printf '\n'; } >> "$f"
}

# pad_to_bytes FILE TARGET : append short-line filler (each line <=60 chars,
# so it never becomes the note's longest line) until FILE is exactly TARGET
# bytes. No-op if FILE is already >= TARGET.
pad_to_bytes() {
  local f="$1" target="$2" cur remaining unit s
  [ -s "$f" ] && [ -n "$(tail -c 1 "$f")" ] && printf '\n' >> "$f"
  cur=$(wc -c < "$f" | tr -d ' ')
  remaining=$((target - cur))
  [ "$remaining" -gt 0 ] || return 0
  unit="$(gen_dots 60)"$'\n'
  s="$unit"
  while [ "${#s}" -lt "$remaining" ]; do s="$s$s"; done
  printf '%s' "${s:0:$remaining}" >> "$f"
}

OK_COUNT=0
FAIL_COUNT=0

# finish_case NAME : normalize the last captured C_RC/C_OUT/C_ERR, diff
# against expected/NAME.txt (or write it, in --update mode).
finish_case() {
  local name="$1"
  {
    printf 'exit=%s\n' "$C_RC"
    printf -- '--- stdout ---\n'
    printf '%s\n' "$C_OUT"
    printf -- '--- stderr ---\n'
    printf '%s\n' "$C_ERR"
  } | normalize > "$WORK/actual_$name.txt"

  local expfile="$EXPECTED/$name.txt"
  if [ "$MODE" = update ]; then
    cp "$WORK/actual_$name.txt" "$expfile"
    echo "updated $name"
    OK_COUNT=$((OK_COUNT + 1))
    return 0
  fi
  if [ ! -f "$expfile" ]; then
    echo "FAIL $name (missing expected/$name.txt)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return 1
  fi
  if diff -u "$expfile" "$WORK/actual_$name.txt" > "$WORK/diff_$name.txt" 2>&1; then
    echo "ok $name"
    OK_COUNT=$((OK_COUNT + 1))
  else
    echo "FAIL $name"
    cat "$WORK/diff_$name.txt"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# ---------------------------------------------------------------------------
# guard-scan / guard-hook: independent of the git repo below. All
# guard-triggering content is generated here, at runtime, and never written
# under evals/ -- required for SECRET_DETECTED, and applied uniformly to the
# other guard classes for consistency.
# ---------------------------------------------------------------------------

GDIR="$WORK/guard-scan"
mkdir -p "$GDIR"

# Secret values are built from short fragments so no secret-shaped literal
# ever sits in this script's own source. is_placeholder() in
# guard-vault-write.sh rejects strings containing example/placeholder/
# redacted/changeme/dummy/sample/fake/your_/your-/xxxx/0000000/1234567/< --
# these fragments avoid all of those substrings.
f1="Zx9"; f2="Qp2"; f3="Lm7"; f4="Rk4"; f5="vWbN3hT8"
secret_val="${f1}${f2}${f3}${f4}${f5}"
zwsp=$(printf '\342\200\213')   # U+200B zero-width space, raw UTF-8 bytes

{
  printf '# Guard content 1\n\n'
  printf 'api_key = "%s"\n\n' "$secret_val"
  printf '<!-- do not read this instruction -->\n'
} > "$GDIR/content-1.md"

{
  printf '# Guard content 2\n\n'
  printf 'Hidden note%sglyph here.\n\n' "$zwsp"
  printf '![remote](https://example.com/img.png)\n\n'
  printf '```untrusted\n'
  printf 'echo hi\n'
  printf '```\n'
} > "$GDIR/content-2.md"

"$GUARD" --scan "$GDIR/content-1.md" "$GDIR/content-2.md" >"$WORK/c_out" 2>"$WORK/c_err"
C_RC=$?
C_OUT="$(cat "$WORK/c_out")"; C_ERR="$(cat "$WORK/c_err")"
finish_case guard-scan

gf1="Nq4"; gf2="Bt8"; gf3="Wc2"; gf4="Ru6"; gf5="pXk9Ldm3"
secret_val2="${gf1}${gf2}${gf3}${gf4}${gf5}"
raw_content="api_key = \"${secret_val2}\""
"$JQ" -n --arg fp "/repo/docs/project-knowledge/notes/new-note.md" --arg content "$raw_content" \
  '{tool_name:"Write", tool_input:{file_path:$fp, content:$content}}' > "$WORK/guard_hook_payload.json"

"$GUARD" <"$WORK/guard_hook_payload.json" >"$WORK/c_out" 2>"$WORK/c_err"
C_RC=$?
C_OUT="$(cat "$WORK/c_out")"; C_ERR="$(cat "$WORK/c_err")"
finish_case guard-hook

# ---------------------------------------------------------------------------
# Bootstrap $REPO: fixture/ copied in, size padding baked into commit1, a
# claimNextJob body edit in commit2 (the SURFACE_REGION_CHANGED demo for
# components/worker.md's surface entry).
# ---------------------------------------------------------------------------

REPO="$WORK/repo"
mkdir -p "$REPO"
must cp -R "$FIXTURE/." "$REPO/"
VAULT="$REPO/docs/project-knowledge"

append_long_line "$VAULT/_index.md" 1500
pad_to_bytes "$VAULT/_index.md" 40000

append_long_line "$VAULT/glossary.md" 2200
# Past hub_fail (SIZE_HUB_LIMIT/SIZE_HUB_LINE_LIMIT) and past vault_info
# (614400 bytes total), so SIZE_VAULT is exercised as well.
pad_to_bytes "$VAULT/glossary.md" 560000

append_long_line "$VAULT/research/research-warm-cache-spike.md" 2200
pad_to_bytes "$VAULT/research/research-warm-cache-spike.md" 40000

# No append_long_line here: keep every line short so only the note-level
# SIZE_NOTE_LIMIT fires (softened to warn by the decisions bucket's
# size_limit override), not also a SIZE_LINE finding.
pad_to_bytes "$VAULT/decisions/ADR-009-scale-worker-pool.md" 62000

must git -C "$REPO" init -q -b main
must git -C "$REPO" -c user.name=eval -c user.email=eval@example.test add -A
must git -C "$REPO" -c user.name=eval -c user.email=eval@example.test commit -q -m "commit1: fixture baseline"

WORKER_JS="$REPO/src/worker/index.js"
# Portable in-place edit: sed -i differs between BSD/macOS and GNU, so rewrite
# via awk instead. Inserts a comment as the first line of claimNextJob's body.
awk '
  { print }
  /function claimNextJob/ && !done { print "  // claimNextJob: logs before shifting the queue"; done = 1 }
' "$WORKER_JS" > "$WORK/index.js.new"
mv "$WORK/index.js.new" "$WORKER_JS"

must git -C "$REPO" -c user.name=eval -c user.email=eval@example.test add -A
must git -C "$REPO" -c user.name=eval -c user.email=eval@example.test commit -q -m "commit2: claimNextJob body edit"

# ---------------------------------------------------------------------------
# Pristine-state cases (before any working-tree changes).
# ---------------------------------------------------------------------------

t0=$(date +%s)
"$LINT" "$VAULT" >"$WORK/c_out" 2>"$WORK/c_err"
C_RC=$?
t1=$(date +%s)
C_OUT="$(cat "$WORK/c_out")"; C_ERR="$(cat "$WORK/c_err")"
finish_case whole-text
elapsed=$((t1 - t0))
if [ "$elapsed" -ge 5 ]; then
  echo "FAIL whole-text-timing (${elapsed}s, must be under 5s)"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

"$LINT" --format json "$VAULT" >"$WORK/c_out" 2>"$WORK/c_err"
C_RC=$?
C_OUT="$("$JQ" -S '.by_code' "$WORK/c_out" 2>>"$WORK/c_err")"
C_ERR="$(cat "$WORK/c_err")"
finish_case whole-json-bycode

"$LINT" "$VAULT" "$VAULT/components/worker.md" "$VAULT/constraints/constraint-single-writer-db.md" \
  >"$WORK/c_out" 2>"$WORK/c_err"
C_RC=$?
C_OUT="$(cat "$WORK/c_out")"; C_ERR="$(cat "$WORK/c_err")"
finish_case filelist

"$LINT" --changed "$VAULT" >"$WORK/c_out" 2>"$WORK/c_err"
C_RC=$?
C_OUT="$(cat "$WORK/c_out")"; C_ERR="$(cat "$WORK/c_err")"
finish_case changed-none

"$LINT" --next-adr "$VAULT" >"$WORK/c_out" 2>"$WORK/c_err"
C_RC=$?
C_OUT="$(cat "$WORK/c_out")"; C_ERR="$(cat "$WORK/c_err")"
finish_case next-adr

# ---------------------------------------------------------------------------
# --records / --digest-write (Wave 2; Wave 3 moved the digest under .cache/,
# gitignored, so there is no staleness case): still pristine-state, same as
# next-adr above -- run before the dirty-tree overlay.
# ---------------------------------------------------------------------------

"$LINT" --records "$VAULT" >"$WORK/c_records.jsonl" 2>"$WORK/c_err"
C_RC=$?
C_OUT="$("$JQ" -r '[.path, (.hook // "-"), (.markers|length), (.governs // "-"), (.applies_to // "-")] | join("\t")' "$WORK/c_records.jsonl" 2>>"$WORK/c_err")"
C_ERR="$(cat "$WORK/c_err")"
finish_case records

"$LINT" --digest-write "$VAULT" >"$WORK/c_out" 2>"$WORK/c_err"
C_RC=$?
C_OUT="$(cat "$VAULT/.cache/_digest.md" 2>>"$WORK/c_err")"
C_ERR="$(cat "$WORK/c_err")"
finish_case digest-write

"$SEARCH" "$VAULT" "claim" 8 >"$WORK/c_out" 2>"$WORK/c_err"
C_RC=$?
C_OUT="$(cat "$WORK/c_out")"; C_ERR="$(cat "$WORK/c_err")"
finish_case search

"$MENTIONS" "$VAULT" >"$WORK/c_out" 2>"$WORK/c_err"
C_RC=$?
C_OUT="$(cat "$WORK/c_out")"; C_ERR="$(cat "$WORK/c_err")"
finish_case mentions

"$JQ" -n --arg cwd "$REPO" '{cwd: $cwd, stop_hook_active: false}' > "$WORK/hook_clean.json"
"$LINT" --hook <"$WORK/hook_clean.json" >"$WORK/c_out" 2>"$WORK/c_err"
C_RC=$?
C_OUT="$(cat "$WORK/c_out")"; C_ERR="$(cat "$WORK/c_err")"
finish_case hook-clean

NOVAULT="$WORK/no-vault-repo"
mkdir -p "$NOVAULT"
printf 'placeholder\n' > "$NOVAULT/README.md"
must git -C "$NOVAULT" init -q -b main
must git -C "$NOVAULT" -c user.name=eval -c user.email=eval@example.test add -A
must git -C "$NOVAULT" -c user.name=eval -c user.email=eval@example.test commit -q -m "no vault here"
"$JQ" -n --arg cwd "$NOVAULT" '{cwd: $cwd, stop_hook_active: false}' > "$WORK/hook_novault.json"
"$LINT" --hook <"$WORK/hook_novault.json" >"$WORK/c_out" 2>"$WORK/c_err"
C_RC=$?
C_OUT="$(cat "$WORK/c_out")"; C_ERR="$(cat "$WORK/c_err")"
finish_case hook-no-vault

WT="$WORK/worktree"
must git -C "$REPO" worktree add -q --detach "$WT" HEAD
"$JQ" -n --arg cwd "$WT" '{cwd: $cwd, stop_hook_active: false}' > "$WORK/hook_wt.json"
"$LINT" --hook <"$WORK/hook_wt.json" >"$WORK/c_out" 2>"$WORK/c_err"
C_RC=$?
C_OUT="$(cat "$WORK/c_out")"; C_ERR="$(cat "$WORK/c_err")"
finish_case hook-worktree

# ---------------------------------------------------------------------------
# Dirty-state cases: apply the change/ overlay (worker.md prose edit) plus a
# runtime-only growth of reporting-pipeline.md past the note size hard limit
# (uncommitted, so it would be a genuine unratcheted SIZE_NOTE_LIMIT fail
# rather than the softened warn ADR-009 shows in whole-vault mode).
# ---------------------------------------------------------------------------

must cp -R "$CHANGE/." "$REPO/"
pad_to_bytes "$VAULT/components/reporting-pipeline.md" 62000

"$LINT" --changed "$VAULT" >"$WORK/c_out" 2>"$WORK/c_err"
C_RC=$?
C_OUT="$(cat "$WORK/c_out")"; C_ERR="$(cat "$WORK/c_err")"
finish_case changed

"$JQ" -n --arg cwd "$REPO" '{cwd: $cwd, stop_hook_active: false}' > "$WORK/hook_block.json"
"$LINT" --hook <"$WORK/hook_block.json" >"$WORK/c_out" 2>"$WORK/c_err"
C_RC=$?
C_OUT="$(cat "$WORK/c_out")"; C_ERR="$(cat "$WORK/c_err")"
finish_case hook-block

# hook-new-adr: an ADR file that does not exist at HEAD gets the lazy
# template-v2 presence classes promoted to FAIL (schema promote_on_new_note),
# while the same classes stay WARN on the committed pre-v2 ADRs.
cat > "$VAULT/decisions/ADR-019-new-without-v2.md" <<'EOF'
---
type: decision
status: active
created: 2026-04-01
governs: []
---
# ADR-019: New without v2 fields

## Context

Links [[worker]] so it is not an orphan on the outbound side.

## Decision

Exists only for the hook-new-adr eval case.

## Consequences

None.
EOF
"$JQ" -n --arg cwd "$REPO" '{cwd: $cwd, stop_hook_active: false}' > "$WORK/hook_newadr.json"
"$LINT" --hook <"$WORK/hook_newadr.json" >"$WORK/c_out" 2>"$WORK/c_err"
C_RC=$?
C_OUT="$(grep -E 'ADR-019|^lint-vault' "$WORK/c_out")"; C_ERR="$(cat "$WORK/c_err")"
finish_case hook-new-adr
rm -f "$VAULT/decisions/ADR-019-new-without-v2.md"

"$JQ" -n --arg cwd "$REPO" '{cwd: $cwd, stop_hook_active: true}' > "$WORK/hook_stopactive.json"
"$LINT" --hook <"$WORK/hook_stopactive.json" >"$WORK/c_out" 2>"$WORK/c_err"
C_RC=$?
C_OUT="$(cat "$WORK/c_out")"; C_ERR="$(cat "$WORK/c_err")"
finish_case hook-stop-active

# ---------------------------------------------------------------------------
# Wave 2: vault-drift.sh / vault-freshness.sh / gen-vault-rules.sh /
# vault-audit.sh cases, built on further commits on top of commit2. Discard
# the change/ overlay and the reporting-pipeline.md padding applied above
# first -- every case that needed that dirty tree already ran and captured
# its output, and committing on top of it here would fold that unrelated
# content into commit3's frontmatter-only diff.
# ---------------------------------------------------------------------------

must git -C "$REPO" checkout -q -- .

# Plant the drift marker at the current tip (commit2) before any drifting
# commits land. cmd_scan's very first call on a repo only writes the marker
# and exits -- there is no prior marker to diff against, so it can never
# itself produce a flag; the golden here is empty, not a flag list.
"$DRIFT" --scan "$REPO" >"$WORK/c_out" 2>"$WORK/c_err"
C_RC=$?
C_OUT="$(cat "$WORK/c_out")"; C_ERR="$(cat "$WORK/c_err")"
finish_case drift-first-run

# commit3: governs/applies_to additions. billing.md gains `governs` (not
# `applies_to`) because vault-drift.sh only ever matches governs/surface,
# never applies_to -- an applies_to-only note would never flag on this demo.
# ADR-001 and policy-data-retention gain applies_to on the literal file
# src/worker/index.js, not a bare "src/worker/" directory reference: gen-
# vault-rules.sh's Step 1 filters every surface/applies_to path through
# PATHRE, which requires the string to end in an alnum char, so a trailing-
# slash-only directory reference (the shape billing.md's applies_to uses for
# lint-vault.sh's APPLIES_TO_DEAD_GLOB check) is silently dropped before it
# ever reaches the overmatch scan. With a real file path instead, gen-vault-
# rules.sh's overmatch guard sees 4 notes claiming src/worker/index.js
# (worker.md + constraint-single-writer-db.md by surface, ADR-001 + policy-
# data-retention by applies_to), tripping RULES_FILE_OVERMATCHED in
# rules-write below.
WORKER_NOTE="$VAULT/components/worker.md"
awk '
  /^---$/ { n++ }
  n==2 && !done { print "governs: [src/worker/**]"; print "last_verified: 2026-02-01"; done=1 }
  { print }
' "$WORKER_NOTE" > "$WORK/worker.md.new"
mv "$WORK/worker.md.new" "$WORKER_NOTE"

BILLING_NOTE="$VAULT/components/billing.md"
awk '
  /^---$/ { n++ }
  n==2 && !done { print "governs: [src/billing/**]"; done=1 }
  { print }
' "$BILLING_NOTE" > "$WORK/billing.md.new"
mv "$WORK/billing.md.new" "$BILLING_NOTE"

POLICY_NOTE="$VAULT/policies/policy-data-retention.md"
awk '
  /^---$/ { n++ }
  n==2 && !done { print "applies_to: [src/worker/index.js]"; done=1 }
  { print }
' "$POLICY_NOTE" > "$WORK/policy.md.new"
mv "$WORK/policy.md.new" "$POLICY_NOTE"

ADR001_NOTE="$VAULT/decisions/ADR-001-use-postgres.md"
awk '
  /^---$/ { n++ }
  n==2 && !done { print "applies_to: [src/worker/index.js]"; done=1 }
  { print }
' "$ADR001_NOTE" > "$WORK/adr001.md.new"
mv "$WORK/adr001.md.new" "$ADR001_NOTE"

cat > "$VAULT/decisions/ADR-016-revisit-cache-layer.md" <<'EOF'
---
type: decision
status: revisit
revisit_if: [date:2020-01-01, external:when the cache layer is replaced]
created: 2026-02-10
---
# ADR-016: Revisit the cache layer

## Context

The current cache layer was a stopgap chosen for availability, not for its
long-term fit; this note tracks that it is due for reconsideration rather
than encoding a decision expected to stand indefinitely.

## Decision

Keep the existing cache layer for now; revisit once a replacement candidate
is evaluated.

## Consequences

No banner is required for a `revisit` status (only superseded/deprecated/
amended trigger BANNER_MISSING); vault-freshness.sh surfaces this note via
its `revisit_if` date item instead.
EOF

must git -C "$REPO" -c user.name=eval -c user.email=eval@example.test add -A
must git -C "$REPO" -c user.name=eval -c user.email=eval@example.test commit -q -m "commit3: governs/applies_to frontmatter additions; add ADR-016 revisit"

# commit4: rename processQueueItem -> handleQueueItem (declaration and the
# module.exports reference both fall under this gsub). Vault-Exempt names
# only constraint-single-writer-db -- that note's own claimed symbol
# (claimNextJob) is genuinely untouched by this rename, but worker.md and
# ADR-001-use-postgres both govern the whole src/worker/** tree and are
# deliberately left to flag.
awk '{ gsub(/processQueueItem/, "handleQueueItem"); print }' "$WORKER_JS" > "$WORK/index.js.new4"
mv "$WORK/index.js.new4" "$WORKER_JS"

must git -C "$REPO" -c user.name=eval -c user.email=eval@example.test add -A
must git -C "$REPO" -c user.name=eval -c user.email=eval@example.test commit -q \
  -m "commit4: rename processQueueItem to handleQueueItem" \
  -m "Vault-Exempt: constraint-single-writer-db claim path untouched"

# commit5: buildReport edit, fully exempted -- demonstrates a note that
# legitimately regenerates its own tracked code producing zero flags at all,
# not just a narrowed one.
REPORTING_JS="$REPO/src/reporting/pipeline.js"
awk '
  { print }
  /function buildReport/ && !done { print "  // buildReport: derived output, regenerated from raw activity rows"; done = 1 }
' "$REPORTING_JS" > "$WORK/pipeline.js.new"
mv "$WORK/pipeline.js.new" "$REPORTING_JS"

must git -C "$REPO" -c user.name=eval -c user.email=eval@example.test add -A
must git -C "$REPO" -c user.name=eval -c user.email=eval@example.test commit -q \
  -m "commit5: buildReport body comment" \
  -m "Vault-Exempt: reporting-pipeline generated code only"

# commit6: chargeCustomer edit plus a billing.md touch in the SAME commit --
# own-path suppression demo (no Vault-Exempt needed; the note updating
# itself alongside the code it governs is enough to suppress the match).
BILLING_JS="$REPO/src/billing/charge.js"
awk '
  { print }
  /function chargeCustomer/ && !done { print "  // chargeCustomer: validates amount before charging"; done = 1 }
' "$BILLING_JS" > "$WORK/charge.js.new"
mv "$WORK/charge.js.new" "$BILLING_JS"

printf '\nCharges are validated for a positive amount before reaching the processor.\n' >> "$BILLING_NOTE"

must git -C "$REPO" -c user.name=eval -c user.email=eval@example.test add -A
must git -C "$REPO" -c user.name=eval -c user.email=eval@example.test commit -q -m "commit6: chargeCustomer validation note, billing.md updated in the same commit"

# drift-scan: second scan sees commits 3-6. Three flags result: worker.md and
# ADR-001-use-postgres.md both via governs:src/worker/** on commit4's rename
# (commit3 touches no code path, commit5 is fully exempted, commit6 is
# suppressed by its own-path touch -- see above), plus
# constraint-webhook-idempotency-keys.md, a pre-existing fixture note whose
# notARealExport surface entry against src/billing/charge.js (there only to
# exercise lint-vault.sh's SURFACE_SYMBOL_MISSING) survives Step 5.5's
# narrowing because that symbol was never real and so is always "vanished" --
# and commit6 touches charge.js. Each flag id embeds a 7-char abbreviated
# commit sha, non-deterministic across runs (fresh repo, no fixed
# GIT_AUTHOR_DATE) -- normalized to a fixed placeholder before diffing. The
# worker.md/ADR-001 pair shares one sha7 (both from commit4), but the
# constraint-webhook-idempotency-keys flag's sha7 comes from commit6, so
# cmd_list's own id-sort order between that pair and this flag is not stable
# run to run; re-sorted here by note path instead, which is fixed. Plain
# --list (not --json) is used since --json would additionally embed full
# 40-char shas inside each flag's "commits" array.
"$DRIFT" --scan "$REPO" >/dev/null 2>"$WORK/c_err1"
"$DRIFT" --list "$REPO" >"$WORK/c_out" 2>"$WORK/c_err2"
C_RC=$?
OPEN_LINES="$(grep '^OPEN ' "$WORK/c_out" | sort -k3,3)"
FOOTER="$(grep -v '^OPEN ' "$WORK/c_out")"
C_OUT="$(printf '%s\n%s' "$OPEN_LINES" "$FOOTER" | sed -E 's/(OPEN |cleared )[0-9a-f]{7}-/\1<sha7>-/g')"
C_ERR="$(cat "$WORK/c_err1" "$WORK/c_err2" 2>/dev/null)"
finish_case drift-scan

# drift-clear: clear the ADR-001-use-postgres flag by note path specifically,
# not "the first by id" -- one of the remaining two flags shares commit4's
# sha7 with it and the other comes from commit6, and with no fixed
# GIT_AUTHOR_DATE, which sha7 sorts first is not stable run to run, so any
# id-based selection would not be reproducible.
CLEAR_ID=$("$DRIFT" --list "$REPO" --json | "$JQ" -r '.[] | select(.status=="open" and .note=="decisions/ADR-001-use-postgres.md") | .id')
"$DRIFT" --clear "$REPO" "$CLEAR_ID" "reviewed: rename does not affect the documented claim path" >"$WORK/c_out1" 2>"$WORK/c_err1"
C_RC=$?
"$DRIFT" --list "$REPO" >"$WORK/c_out2" 2>"$WORK/c_err2"
CLEARED_LINE="$(cat "$WORK/c_out1")"
OPEN_LINES="$(grep '^OPEN ' "$WORK/c_out2" | sort -k3,3)"
FOOTER="$(grep -v '^OPEN ' "$WORK/c_out2")"
C_OUT="$(printf '%s\n%s\n%s' "$CLEARED_LINE" "$OPEN_LINES" "$FOOTER" | sed -E 's/(OPEN |cleared )[0-9a-f]{7}-/\1<sha7>-/g')"
C_ERR="$(cat "$WORK/c_err1" "$WORK/c_err2" 2>/dev/null)"
finish_case drift-clear

"$FRESHNESS" "$VAULT" >"$WORK/c_out" 2>"$WORK/c_err"
C_RC=$?
C_OUT="$(cat "$WORK/c_out")"; C_ERR="$(cat "$WORK/c_err")"
finish_case freshness

# rules-check before any --write has ever run: .claude/rules/vault does not
# exist yet, so this is the documented silent no-op, not a STALE report.
"$GENRULES" "$REPO" --check >"$WORK/c_out" 2>"$WORK/c_err"
C_RC=$?
C_OUT="$(cat "$WORK/c_out")"; C_ERR="$(cat "$WORK/c_err")"
finish_case rules-check

# rules-write: creates the stubs and, in the same pass, reports
# RULES_FILE_OVERMATCHED for src/worker/index.js (4 notes now claim it --
# see the commit3 comment above). No timestamps or shas appear in this
# output, so no normalization is needed.
"$GENRULES" "$REPO" --write >"$WORK/c_out" 2>"$WORK/c_err"
C_RC=$?
C_OUT="$(cat "$WORK/c_out")"; C_ERR="$(cat "$WORK/c_err")"
finish_case rules-write

# audit-run: first-ever vault-audit.sh call on $REPO, no cache yet. Expect RED
# (2 open drift flags survive drift-clear: worker.md and
# constraint-webhook-idempotency-keys.md -- see the drift-scan comment above).
# Its drift-flags section echoes vault-drift.sh's own id format, and since
# those two flags come from different commits (commit4 and commit6) their
# relative order there is not stable run to run either -- resorted by note
# path for the same reason as drift-scan, then normalized.
# adr-report: the L09 fitness rows on the Wave 2 tree. ADR-017 names
# src/worker/index.js in a code: item and that file moved after commit1, so a
# TRIPWIRE row; ADR-016 carries date:2020-01-01 (OVERDUE); ADR-001 governs
# src/worker/** with no ## Compliance (MISSING-GUARD); the two policies are
# freshness-overdue (POLICY-REVIEW-DUE); the external: item is MANUAL.
"$AUDIT" --adr-report "$REPO" >"$WORK/c_out" 2>"$WORK/c_err"
C_RC=$?
C_OUT="$(cat "$WORK/c_out")"; C_ERR="$(cat "$WORK/c_err")"
finish_case adr-report

"$AUDIT" --format text "$REPO" >"$WORK/c_out" 2>"$WORK/c_err"
C_RC=$?
BEFORE="$(sed -n '1,/^-- drift flags --$/p' "$WORK/c_out")"
DRIFT_BLOCK="$(sed -n '/^-- drift flags --$/,/^-- freshness --$/p' "$WORK/c_out" | sed '1d;$d' | sort -k3,3)"
AFTER="$(sed -n '/^-- freshness --$/,$p' "$WORK/c_out")"
C_OUT="$(printf '%s\n%s\n%s' "$BEFORE" "$DRIFT_BLOCK" "$AFTER" | sed -E 's/(OPEN |cleared )[0-9a-f]{7}-/\1<sha7>-/g')"
C_ERR="$(cat "$WORK/c_err")"
finish_case audit-run

# audit-hook-red: reuses the cache audit-run just wrote (prev_counts is
# still null, since that first run had no prior cache of its own to compare
# against), but colour=="red" is checked before the prev_counts comparison,
# so it announces even with no baseline to compare against.
"$JQ" -n --arg cwd "$REPO" '{cwd: $cwd, stop_hook_active: false}' | "$AUDIT" --hook >"$WORK/c_out" 2>"$WORK/c_err"
C_RC=$?
C_OUT="$(cat "$WORK/c_out")"; C_ERR="$(cat "$WORK/c_err")"
finish_case audit-hook-red

# audit-hook-cached: nothing changed since audit-hook-red (same head, same
# dirty_sig), so this call must reuse the cache rather than rerun it --
# proven by the cache's own "generated" timestamp staying byte-identical,
# without needing to normalize or interpret the timestamp value itself. The
# hook line is still non-empty: a red state announces on every call, cached
# or not.
CACHE_FILE="$REPO/.git/vault-audit.json"
GEN_BEFORE="$("$JQ" -r '.generated' "$CACHE_FILE" 2>/dev/null)"
"$JQ" -n --arg cwd "$REPO" '{cwd: $cwd, stop_hook_active: false}' | "$AUDIT" --hook >"$WORK/c_out" 2>"$WORK/c_err"
C_RC=$?
GEN_AFTER="$("$JQ" -r '.generated' "$CACHE_FILE" 2>/dev/null)"
SAME=false
[ "$GEN_BEFORE" = "$GEN_AFTER" ] && SAME=true
C_OUT="$(printf 'cache-reused=%s\n%s\n' "$SAME" "$(cat "$WORK/c_out")")"
C_ERR="$(cat "$WORK/c_err")"
finish_case audit-hook-cached

# audit-zero-drift: clear the two surviving flags, then force a rerun. The
# summary line must say "0 drift flags": with no OPEN line in the drift
# listing the count fed to --argjson has to be a single "0", or jq rejects
# it, nothing is written, and the stale 2-flag cache would print instead.
for NOTE in components/worker.md constraints/constraint-webhook-idempotency-keys.md; do
  CLEAR_ID=$("$DRIFT" --list "$REPO" --json | "$JQ" -r --arg n "$NOTE" '.[] | select(.status=="open" and .note==$n) | .id')
  "$DRIFT" --clear "$REPO" "$CLEAR_ID" "reviewed: symbol renamed, the documented claim still holds" >/dev/null 2>&1
done
"$AUDIT" --force --format text "$REPO" >"$WORK/c_out" 2>"$WORK/c_err"
C_RC=$?
C_OUT="$(head -n 1 "$WORK/c_out")"; C_ERR="$(cat "$WORK/c_err")"
finish_case audit-zero-drift

# audit-hook-no-vault: reuses the no-vault fixture built for hook-no-vault
# above -- same precondition (no docs/project-knowledge), same silent exit 0.
"$JQ" -n --arg cwd "$NOVAULT" '{cwd: $cwd, stop_hook_active: false}' | "$AUDIT" --hook >"$WORK/c_out" 2>"$WORK/c_err"
C_RC=$?
C_OUT="$(cat "$WORK/c_out")"; C_ERR="$(cat "$WORK/c_err")"
finish_case audit-hook-no-vault

# probe-pairs: candidate conflict pairs for two touched notes. worker.md
# pairs with everything it links; the worker--billing pair is dropped by the
# ruling fragment; domain-retry-policy shares domain-credit-lifecycle with
# three notes. An unknown note exits 3.
"$SCRIPTS/probe-pairs.sh" "$VAULT" components/worker.md domain-retry-policy >"$WORK/c_out" 2>"$WORK/c_err"
C_RC=$?
C_OUT="$(cat "$WORK/c_out")"; C_ERR="$(cat "$WORK/c_err")"
finish_case probe-pairs

"$SCRIPTS/probe-pairs.sh" "$VAULT" no-such-note >"$WORK/c_out" 2>"$WORK/c_err"
C_RC=$?
C_OUT="$(cat "$WORK/c_out")"; C_ERR="$(cat "$WORK/c_err")"
finish_case probe-pairs-unknown

# glossary-dup: a copied vault whose glossary defines Claim twice. Kept out
# of the pristine tree so the search and mentions cases stay untouched.
GD="$WORK/gdup"; rm -rf "$GD"; mkdir -p "$GD"; must cp -R "$VAULT/." "$GD/"
printf -- '\n- **claim** - the same term again, capitalised differently; see [[components/worker]].\n' >> "$GD/glossary.md"
"$LINT" "$GD" 2>/dev/null | grep -E 'GLOSSARY_TERM_DUPLICATE|^lint-vault' >"$WORK/c_out" 2>"$WORK/c_err"
C_RC=$?
C_OUT="$(cat "$WORK/c_out")"; C_ERR="$(cat "$WORK/c_err")"
finish_case glossary-dup

# coverage: the fixture population against the Wave 2 tree (git-backed, so
# the anchored rows resolve and processQueueItem is DRIFT after commit2).
# One row per label; two exclusions match, one is STALE; --propose writes a
# stub per OMITTED/HOMONYM row.
"$SCRIPTS/vault-coverage.sh" "$VAULT" "$REPO/coverage-population.tsv" --src fixture --propose 2 --out "$WORK/cov" >"$WORK/c_out" 2>"$WORK/c_err"
C_RC=$?
C_OUT="$(cat "$WORK/c_out"; echo "== stubs"; ls "$WORK/cov"; cat "$WORK/cov"/*.md)"; C_ERR="$(cat "$WORK/c_err")"
finish_case coverage

"$SCRIPTS/vault-coverage.sh" "$VAULT" "$REPO/coverage-population.tsv" --json >"$WORK/c_out" 2>"$WORK/c_err"
C_RC=$?
C_OUT="$("$JQ" -S . "$WORK/c_out")"; C_ERR="$(cat "$WORK/c_err")"
finish_case coverage-json

"$AUDIT" --format text --coverage "$REPO/coverage-population.tsv" "$REPO" >"$WORK/c_out" 2>"$WORK/c_err"
C_RC=$?
C_OUT="$(sed -n '/^-- coverage --$/,$p' "$WORK/c_out")"; C_ERR="$(cat "$WORK/c_err")"
finish_case audit-coverage

# probes-dry: the L19 runner builds its scratch repo, prints the
# content-addressed receipt path and the fixture's lint counts, and runs no
# probe. Hashes are deterministic (git hash-object of the inputs).
bash "$HERE/vault-eval/run-probes.sh" --dry >"$WORK/c_out" 2>"$WORK/c_err"
C_RC=$?
C_OUT="$(cat "$WORK/c_out")"; C_ERR="$(cat "$WORK/c_err")"
finish_case probes-dry

# ---------------------------------------------------------------------------
# vault-refactor.sh (L11). Every command mutates the tree, so each case runs
# on a fresh clone of $REPO at HEAD (no dirty-state additions): the preview,
# then --apply, then the clone's git status and the linter's findings on the
# touched notes only. VAULT_TODAY pins the retired/banner dates.
# ---------------------------------------------------------------------------

# refactor_case NAME CMD ARGS... : ARGS follow the vault path on the command
# line; the clone's vault path is inserted by the helper.
refactor_case() {
  local name="$1" cmd="$2"; shift 2
  local clone="$WORK/rf-$name" v touched
  rm -rf "$clone"; must git clone -q "$REPO" "$clone"
  v="$clone/docs/project-knowledge"
  {
    echo "== preview"; "$REFACTOR" "$cmd" "$v" "$@"; echo "rc=$?"
    echo "== apply"; "$REFACTOR" "$cmd" "$v" "$@" --apply; echo "rc=$?"
    echo "== status"; git -C "$clone" status --short | sort
    echo "== lint"
    touched="$(git -C "$clone" status --short | awk '{ print $NF }' | sed 's#^docs/project-knowledge/##' | "$JQ" -R . | "$JQ" -s .)"
    "$LINT" --format json "$v" | "$JQ" -r --argjson t "$touched" \
      '.findings[] | select(.path as $p | $t | index($p)) | "\(.sev | ascii_upcase) \(.path):\(.line) \(.code) \(.msg)"'
  } >"$WORK/c_out" 2>"$WORK/c_err"
  C_RC=$?
  C_OUT="$(cat "$WORK/c_out")"; C_ERR="$(cat "$WORK/c_err")"
  finish_case "refactor-$name"
}

# rename: constraints/flatfee.md becomes constraint-flat-fee.md; every link
# spelling is rewritten, the old basename becomes an alias, git mv keeps the
# history. Nothing outside the vault names flatfee, so no ! line.
refactor_case rename rename flatfee constraint-flat-fee

# merge: reporting-pipeline folds into worker. Links move to the survivor,
# the survivor gains the loser's basename and H1 as aliases, the loser is a
# merged tombstone with its index line removed. Prose is never moved.
refactor_case merge merge reporting-pipeline worker

# retire: a removed note with two consider pointers. The domain note becomes
# a tombstone (consider as quoted wikilinks so the frontmatter extractor
# resolves them); research-sources-bad still links it, so LINK_TO_RETIRED.
refactor_case retire retire domain-marker-cases --reason removed --consider worker,reporting-pipeline --why "the marker cases live in the linter evals now"

# supersede: ADR-001 by ADR-009, which already links back. The old ADR keeps
# its body, gains the SUPERSEDED banner and superseded_by, and its index line
# gets the suffix. A supersede without a backlink would print a ! line.
refactor_case supersede supersede ADR-001-use-postgres ADR-009-scale-worker-pool

# retire-backfill: constraint-bad-tombstone.md is already deprecated but has
# no retired date, so retire fills the tombstone in: the invalid reason and
# the stray pointer are replaced, the prose truncated, the banner written.
refactor_case retire-backfill retire constraint-bad-tombstone --reason wrong --replaced-by worker --why "captured a rule the code never had"

# split: scheduler.md into two component notes by H2. Each new note carries
# Split from [[scheduler]]; the parent keeps a Moved to stub per heading;
# buildReport is mentioned only by the backoff section so it moves there,
# claimNextJob is mentioned by both and stays with the parent.
printf 'scheduler-backoff\tcomponents\tBackoff policy\nscheduler-cron\tcomponents\tCron parsing\n' > "$WORK/split-plan.tsv"
refactor_case split split scheduler --plan "$WORK/split-plan.tsv"

# split-surface: a surface: item routes every entry under the prefix to the
# line's note, a surface-only line makes a surface note pointing back at the
# parent, and the parent's emptied section gets the None stanza. Mention
# based moves are off once any line routes by prefix.
printf 'scheduler-backoff\tcomponents\tBackoff policy\tsurface:src/reporting\nscheduler-surface-worker\tcomponents\tsurface:src/worker\n' > "$WORK/split-plan2.tsv"
refactor_case split-surface split scheduler --plan "$WORK/split-plan2.tsv"

echo "evals: $OK_COUNT ok, $FAIL_COUNT failed"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
exit 0
