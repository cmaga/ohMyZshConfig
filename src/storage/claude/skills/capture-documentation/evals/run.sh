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

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE="$HERE/fixture"
CHANGE="$HERE/change"
EXPECTED="$HERE/expected"

SCRIPTS="$HERE/../scripts"
LINT="$SCRIPTS/lint-vault.sh"
SEARCH="$SCRIPTS/vault-search.sh"
MENTIONS="$SCRIPTS/vault-mentions.sh"
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

# KNOWN lint-vault.sh BUG (report-only, not fixed here -- see the eval's final
# report): direct `--changed VAULT_ROOT` resolves repo=$(git -C "$VAULT"
# rev-parse --show-toplevel) (symlink-resolved) but vault=$(cd "$VAULT" &&
# pwd) (symlink-preserving). Under mktemp's default TMPDIR, which sits behind
# a symlink on macOS (/tmp -> /private/tmp, /var -> /private/var), those two
# disagree, so do_changed()'s relvault="${vault#"$repo"/}" prefix-strip is a
# silent no-op: relvault keeps the full absolute vault path instead of
# becoming repo-relative. git diff/ls-files still run fine against that
# absolute pathspec, but the later `case "$rp" in "$relvault"/*.md)` match
# tests it against git's repo-*relative* output, which can never match --
# touched.txt stays empty and do_changed() takes its clean early-exit. This
# is why `changed` below is byte-identical to `changed-none`: --changed
# cannot see the overlay/padding at all on this platform. --hook does not
# hit this, because it derives repo from the hook JSON's cwd and builds
# vault from that same already-resolved repo, so the two stay consistent;
# hook-block (below) is what actually demonstrates the SIZE_NOTE_LIMIT fail.
"$LINT" --changed "$VAULT" >"$WORK/c_out" 2>"$WORK/c_err"
C_RC=$?
C_OUT="$(cat "$WORK/c_out")"; C_ERR="$(cat "$WORK/c_err")"
finish_case changed

"$JQ" -n --arg cwd "$REPO" '{cwd: $cwd, stop_hook_active: false}' > "$WORK/hook_block.json"
"$LINT" --hook <"$WORK/hook_block.json" >"$WORK/c_out" 2>"$WORK/c_err"
C_RC=$?
C_OUT="$(cat "$WORK/c_out")"; C_ERR="$(cat "$WORK/c_err")"
finish_case hook-block

"$JQ" -n --arg cwd "$REPO" '{cwd: $cwd, stop_hook_active: true}' > "$WORK/hook_stopactive.json"
"$LINT" --hook <"$WORK/hook_stopactive.json" >"$WORK/c_out" 2>"$WORK/c_err"
C_RC=$?
C_OUT="$(cat "$WORK/c_out")"; C_ERR="$(cat "$WORK/c_err")"
finish_case hook-stop-active

echo "evals: $OK_COUNT ok, $FAIL_COUNT failed"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
exit 0
