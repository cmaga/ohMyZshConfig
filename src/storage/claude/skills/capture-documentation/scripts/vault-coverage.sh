#!/usr/bin/env bash
# vault-coverage.sh -- how much of a caller-supplied symbol population the
# vault anchors, and which important symbols it misses.
#
#   vault-coverage.sh VAULT POPULATION.tsv [--src LABEL] [--propose N] [--json] [--out DIR]
#
# POPULATION.tsv holds one "symbol<TAB>path" row per item, most important
# first; the caller builds it (jcodemunch get_symbol_importance, a grep, a
# hand list) and the script never mines one itself. The path may be blank.
# Each row gets the first label that fits:
#   EXCLUDED         a _coverage-exclusions.md entry matches (path glob or
#                    exact symbol)
#   ANCHORED         symbol and path sit in one Reusable-surface entry
#   DRIFT            anchored, but the linter reports the entry as
#                    SURFACE_SYMBOL_MISSING / SURFACE_PATH_MISSING
#   HOMONYM          the symbol is anchored at a different path
#   DECLARED_ABSENT  a note's "None - ..." surface stanza names the path or
#                    its directory
#   MENTIONED        the symbol appears in prose outside surfaces and fences
#   FILE_MENTIONED   the path does
#   OMITTED          nothing in the vault knows it
# Output: the OMITTED, HOMONYM, DRIFT, MENTIONED and FILE_MENTIONED rows in
# population order as "LABEL<TAB>symbol<TAB>path<TAB>detail", then
# "coverage NN% (src=LABEL, N anchored of M)" over the non-excluded rows (or
# "coverage null (<5 items)"), then "STALE <entry>" for each exclusion that
# matched nothing. --propose N writes DIR/<symbol>.md brief stubs for the
# first N OMITTED or HOMONYM rows (DIR defaults to VAULT/.cache/coverage).
# --json prints {src, rows, anchored, total, coverage, stale} instead.
# Exit 0; 2 on usage.
set -u
export LC_ALL=C
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=vault-lib.sh
. "$HERE/vault-lib.sh"

usage() { sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
[ $# -ge 2 ] || usage
VAULT="${1%/}"; POP="$2"; shift 2
[ -d "$VAULT" ] && [ -f "$POP" ] || usage
SRC=caller; PROPOSE=0; JSON=0; OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --src) shift; SRC="${1:-}" ;;
    --propose) shift; PROPOSE="${1:-0}"; case "$PROPOSE" in ''|*[!0-9]*) usage ;; esac ;;
    --json) JSON=1 ;;
    --out) shift; OUT="${1:-}" ;;
    *) usage ;;
  esac
  shift
done
[ -n "$OUT" ] || OUT="$VAULT/.cache/coverage"
REPO=$(git -C "$VAULT" rev-parse --show-toplevel 2>/dev/null) || REPO="$VAULT"
TMP=$(mktemp -d) || exit 2
trap 'rm -rf "$TMP"' EXIT
TAB=$(printf '\t')

vault_records "$VAULT" "$TMP/recs.ndjson" || exit 2
bash "$HERE/lint-vault.sh" --format json "$VAULT" > "$TMP/lint.json" 2>/dev/null

# surfaces: sym<TAB>path<TAB>note
"$JQ" -r 'select(.surface.entries) | .path as $n | .surface.entries[] | .spath as $p | .syms[] | "\(.)\t\($p)\t\($n)"' "$TMP/recs.ndjson" > "$TMP/surf.tsv"
# drifted entries: sym<TAB>path
"$JQ" -r '.findings[] | select(.code == "SURFACE_SYMBOL_MISSING" or .code == "SURFACE_PATH_MISSING") | .msg | capture("^(?<s>[^ ]+) @ (?<p>.+)$") | "\(.s)\t\(.p)"' "$TMP/lint.json" 2>/dev/null | sort -u > "$TMP/drift.tsv"

# prose corpus: note<TAB>text, frontmatter, fences and Reusable surface out
: > "$TMP/prose.tsv"
"$JQ" -r '.path' "$TMP/recs.ndjson" | while IFS= read -r n; do
  awk -v n="$n" '
    NR == 1 && $0 == "---" { infm = 1; next }
    infm { if ($0 == "---") infm = 0; next }
    /^[ \t]*(```|~~~)/ { fence = !fence; next }
    fence { next }
    /^## / { insurf = ($0 ~ /^## Reusable surface/); next }
    insurf { next }
    NF { print n "\t" $0 }' "$VAULT/$n"
done >> "$TMP/prose.tsv"

# None stanzas: note<TAB>backticked span
: > "$TMP/absent.tsv"
"$JQ" -r '.path' "$TMP/recs.ndjson" | while IFS= read -r n; do
  awk -v n="$n" '
    /^## / { insurf = ($0 ~ /^## Reusable surface/); next }
    insurf && /^[-*]?[ \t]*None/ { s = $0; while (match(s, /`[^`]+`/)) { print n "\t" substr(s, RSTART + 1, RLENGTH - 2); s = substr(s, RSTART + RLENGTH) } }' "$VAULT/$n"
done >> "$TMP/absent.tsv"

# exclusions: pattern<TAB>reason (entries without a reason are the linter's business)
: > "$TMP/excl.tsv"
if [ -f "$VAULT/_coverage-exclusions.md" ]; then
  awk '/^- `[^`]+` +(-|\xe2\x80\x94) +./ { s = $0; match(s, /`[^`]+`/); pat = substr(s, RSTART + 1, RLENGTH - 2); rest = substr(s, RSTART + RLENGTH); sub(/^ +(-|\xe2\x80\x94) +/, "", rest); print pat "\t" rest }' "$VAULT/_coverage-exclusions.md" > "$TMP/excl.tsv"
fi

# label every row; rows.tsv = LABEL<TAB>sym<TAB>path<TAB>detail
: > "$TMP/rows.tsv"; : > "$TMP/hit.txt"
while IFS="$TAB" read -r sym path _rest; do
  [ -n "$sym" ] || continue
  label=""; detail="-"
  # EXCLUDED
  while IFS="$TAB" read -r pat reason; do
    [ -n "$pat" ] || continue
    if [ "$pat" = "$sym" ]; then label=EXCLUDED; detail="$pat"; break; fi
    case "$pat" in
      */*|*'*'*|*'?'*)
        [ -n "$path" ] && printf '%s\n' "$path" | awk -v pat="$pat" "$AWK_GLOB2ERE"'BEGIN { re = glob2ere(pat) } $0 ~ re { ok = 1 } END { exit !ok }' && { label=EXCLUDED; detail="$pat"; break; } ;;
    esac
  done < "$TMP/excl.tsv"
  [ "$label" = EXCLUDED ] && printf '%s\n' "$detail" >> "$TMP/hit.txt"
  # ANCHORED / DRIFT / HOMONYM
  if [ -z "$label" ]; then
    if [ -n "$path" ]; then own=$(awk -F'\t' -v s="$sym" -v p="$path" '$1 == s && $2 == p { print $3; exit }' "$TMP/surf.tsv")
    else own=$(awk -F'\t' -v s="$sym" '$1 == s { print $3; exit }' "$TMP/surf.tsv"); fi
    if [ -n "$own" ]; then
      if grep -q -F -x -e "$sym$TAB$path" "$TMP/drift.tsv"; then label=DRIFT; detail="$own"; else label=ANCHORED; detail="$own"; fi
    else
      other=$(awk -F'\t' -v s="$sym" '$1 == s { print $2 " in " $3; exit }' "$TMP/surf.tsv")
      [ -n "$other" ] && { label=HOMONYM; detail="listed at $other"; }
    fi
  fi
  # DECLARED_ABSENT
  if [ -z "$label" ] && [ -n "$path" ]; then
    da=$(awk -F'\t' -v p="$path" '$2 == p || (substr($2, length($2)) == "/" && index(p, $2) == 1) { print $1; exit }' "$TMP/absent.tsv")
    [ -n "$da" ] && { label=DECLARED_ABSENT; detail="$da"; }
  fi
  # MENTIONED / FILE_MENTIONED
  if [ -z "$label" ]; then
    m=$(grep -m1 -w -F -e "$sym" "$TMP/prose.tsv" | cut -f1)
    if [ -n "$m" ]; then label=MENTIONED; detail="$m"
    elif [ -n "$path" ]; then
      m=$(grep -m1 -F -e "$path" "$TMP/prose.tsv" | cut -f1)
      [ -n "$m" ] && { label=FILE_MENTIONED; detail="$m"; }
    fi
  fi
  [ -n "$label" ] || label=OMITTED
  printf '%s\t%s\t%s\t%s\n' "$label" "$sym" "$path" "$detail" >> "$TMP/rows.tsv"
done < "$POP"

total=$(awk -F'\t' '$1 != "EXCLUDED"' "$TMP/rows.tsv" | wc -l | tr -d ' ')
anchored=$(awk -F'\t' '$1 == "ANCHORED"' "$TMP/rows.tsv" | wc -l | tr -d ' ')
if [ "$total" -ge 5 ]; then pct=$((anchored * 100 / total)); summary="coverage ${pct}% (src=$SRC, $anchored anchored of $total)"
else pct=null; summary="coverage null (<5 items)"; fi
stale=$(cut -f1 "$TMP/excl.tsv" | while IFS= read -r pat; do [ -n "$pat" ] && ! grep -q -F -x -e "$pat" "$TMP/hit.txt" && printf '%s\n' "$pat"; done)

if [ "$PROPOSE" -gt 0 ]; then
  mkdir -p "$OUT"
  awk -F'\t' '$1 == "OMITTED" || $1 == "HOMONYM"' "$TMP/rows.tsv" | head -n "$PROPOSE" | while IFS="$TAB" read -r label sym path detail; do
    hit="not found at HEAD"
    if [ -n "$path" ] && git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
      h=$(git -C "$REPO" grep -n -w -F -e "$sym" HEAD -- "$path" 2>/dev/null | head -n 1 | sed 's/^HEAD://')
      [ -n "$h" ] && hit="$h"
    fi
    {
      printf '# Coverage brief: %s\n\n' "$sym"
      printf -- '- Symbol: `%s`\n- Path: `%s`\n- Label: %s%s\n- First hit: %s\n\n' "$sym" "${path:-?}" "$label" "$([ "$detail" != - ] && printf ' (%s)' "$detail")" "$hit"
      printf 'Fill in what it does, who calls it, and which note owns it; or add a `_coverage-exclusions.md` entry with the reason.\n'
    } > "$OUT/$sym.md"
  done
fi

if [ "$JSON" = 1 ]; then
  "$JQ" -R -s --arg src "$SRC" --argjson anchored "$anchored" --argjson total "$total" --argjson pct "$pct" --rawfile stale <(printf '%s\n' "$stale") '
    {src: $src, rows: (split("\n") | map(select(length > 0) | split("\t") | {label: .[0], symbol: .[1], path: .[2], detail: .[3]})),
     anchored: $anchored, total: $total, coverage: $pct, stale: ($stale | split("\n") | map(select(length > 0)))}' "$TMP/rows.tsv"
  exit 0
fi
for lbl in OMITTED HOMONYM DRIFT MENTIONED FILE_MENTIONED; do awk -F'\t' -v l="$lbl" '$1 == l' "$TMP/rows.tsv"; done
printf '%s\n' "$summary"
[ -n "$stale" ] && printf '%s\n' "$stale" | sed 's/^/STALE /'
exit 0
