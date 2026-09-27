#!/usr/bin/env bash
# vault-refactor.sh -- retire, rename, merge, supersede and split vault notes
# with the link rewrites, tombstones, aliases and index edits each one needs.
#
#   vault-refactor.sh rename    VAULT OLD NEW                              [--apply]
#   vault-refactor.sh merge     VAULT LOSER SURVIVOR                       [--apply]
#   vault-refactor.sh retire    VAULT NOTE --reason merged|split|removed|wrong
#                                     [--replaced-by X] [--consider a,b] [--why "..."] [--apply]
#   vault-refactor.sh supersede VAULT OLD NEW                              [--apply]
#   vault-refactor.sh split     VAULT NOTE --plan FILE                     [--apply]
#
# Names are basenames without .md (bucket/basename also accepted). Preview is
# the default: it prints every site as file:line with -/+ lines, a "!" line
# for anything that would not resolve, and an out-of-vault: block for
# references outside docs/project-knowledge (git grep). --apply performs the
# edits; it is refused (exit 1) while any "!" line stands.
#
# Exit: 0 ok, 1 apply refused, 2 usage, 3 clobber / ADR rename / pointer chain /
# ambiguous basename / invalid reason / a split result still over the size limit.
#
# split plan file: one line per new note, tab separated:
#   new-basename<TAB>bucket<TAB>heading[<TAB>heading...]
# A heading names a section (any level, text without the #s); the section runs
# to the next heading of the same or a higher level. The first heading becomes
# the new note's H1; the note opens with "Split from [[NOTE]] (date)."; the
# parent keeps each moved heading with "Moved to [[new]]."; Reusable-surface
# entries whose path is mentioned only in moved sections move along;
# [[NOTE#Heading]] links are rewritten vault-wide. _index.md is never touched
# by split. An item "surface:<path-prefix>" routes every Reusable-surface
# entry under that prefix to the line's note (a line may hold only such
# items: the note is then a surface note pointing back at the parent); when
# any line routes by prefix, mention-based moves are off and entries no
# prefix claims stay with the parent.

set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=vault-lib.sh
. "$HERE/vault-lib.sh"

usage() { sed -n '2,29p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }

CMD="${1:-}"; VAULT_ARG="${2:-}"
case "$CMD" in rename|merge|retire|supersede|split) ;; *) usage ;; esac
[ -n "$VAULT_ARG" ] && [ -d "$VAULT_ARG" ] || usage
shift 2

APPLY=0; REASON=""; REPLACED_BY=""; CONSIDER=""; WHY=""; PLAN=""; POS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1 ;;
    --reason) shift; REASON="${1:-}" ;;
    --replaced-by) shift; REPLACED_BY="${1:-}" ;;
    --consider) shift; CONSIDER="${1:-}" ;;
    --why) shift; WHY="${1:-}" ;;
    --plan) shift; PLAN="${1:-}" ;;
    -*) usage ;;
    *) POS="$POS${POS:+ }$1" ;;
  esac
  shift
done
set -- $POS

VAULT=$(cd "$VAULT_ARG" && pwd -P)
REPO=$(git -C "$VAULT" rev-parse --show-toplevel 2>/dev/null) || REPO="$VAULT"
RELV="${VAULT#"$REPO"/}"
TMP=$(mktemp -d) || { echo "vault-refactor: cannot create temp dir" >&2; exit 2; }
trap 'rm -rf "$TMP"' EXIT
vault_merge_schema "$VAULT" "$TMP/schema.json"
NOTE_FAIL=$("$JQ" -r '.sizes.note_fail // 61440' "$TMP/schema.json")
INDEX=$("$JQ" -r '[.hubs|to_entries[]|select(.value.type=="index")|.key][0] // "_index.md"' "$TMP/schema.json")
TODAY=$(vault_today)
# the backticked span of a Reusable-surface entry that is its path: a slash
# path or a bare file name with a code/config extension (never a dotted symbol)
PATHRE='^(\./)?([A-Za-z0-9_.-]+/)+[A-Za-z0-9_.*{}-]+$|^[A-Za-z0-9_-]+\.(py|js|ts|tsx|jsx|mjs|sh|zsh|bash|md|toml|yaml|yml|json|sql|service|timer|env|txt|cfg|ini|tf|Makefile)$'
EM=$(printf '\342\200\224')
BANG=0

note_files() {
  find "$VAULT" -name '*.md' -not -path '*/.obsidian/*' -not -path '*/.cache/*' -not -path '*/_fragments/*' \
    -not -path "$VAULT/_digest.md" | sort
}

# resolve NAME -> vault-relative path of the one note with that basename.
resolve() {
  local name="$1" hits
  name="${name%.md}"
  case "$name" in
    */*) [ -f "$VAULT/$name.md" ] && { printf '%s\n' "$name.md"; return 0; }; return 1 ;;
  esac
  hits=$(note_files | while IFS= read -r f; do rel="${f#"$VAULT"/}"; case "$rel" in */"$name.md") printf '%s\n' "$rel" ;; esac; done)
  [ -n "$hits" ] || return 1
  if [ "$(printf '%s\n' "$hits" | wc -l | tr -d ' ')" -gt 1 ]; then
    echo "vault-refactor: ambiguous basename $name: $(printf '%s' "$hits" | tr '\n' ' ')" >&2; exit 3
  fi
  printf '%s\n' "$hits"
}
bucket_of() { printf '%s\n' "${1%%/*}"; }
base_of() { local b; b="${1##*/}"; printf '%s\n' "${b%.md}"; }
fm_get() { awk -v k="$2" 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f&&index($0,k":")==1{v=substr($0,length(k)+2); sub(/^[ \t]+/,"",v); gsub(/^"|"$/,"",v); print v; exit}' "$1"; }
h1_of() { awk '/^# /{sub(/^# /,""); print; exit}' "$1"; }
retired_status() { local st; st=$(fm_get "$VAULT/$1" status); case "$st" in deprecated|superseded) return 0 ;; esac; return 1; }

# fm_set FILE KEY VALUE: replace the key line or insert it before the closing ---
fm_set() {
  local f="$1" k="$2" v="$3"
  awk -v k="$k" -v v="$v" '
    NR==1 && $0=="---" { infm=1; print; next }
    infm && $0=="---" { if (!done) print k ": " v; infm=0; print; next }
    infm && index($0, k ":")==1 { print k ": " v; done=1; next }
    { print }' "$f" > "$TMP/fm.tmp" && mv "$TMP/fm.tmp" "$f"
}
fm_del() {
  local f="$1" k="$2"
  awk -v k="$k" 'NR==1 && $0=="---" { infm=1; print; next } infm && $0=="---" { infm=0; print; next } infm && index($0, k ":")==1 { next } { print }' "$f" > "$TMP/fm.tmp" && mv "$TMP/fm.tmp" "$f"
}
fm_add_alias() {
  local f="$1" a="$2" cur
  cur=$(fm_get "$f" aliases)
  if [ -z "$cur" ]; then fm_set "$f" aliases "[$a]"
  else
    case "$cur" in *"$a"*) return 0 ;; esac
    fm_set "$f" aliases "[${cur#[}"; fm_set "$f" aliases "$(printf '%s' "$cur" | sed 's/\]$//'), $a]"
  fi
}

# set_banner FILE TEXT [truncate HISTORY_LINE]: the banner is the first body
# line after the H1; an existing banner block (> lines) is replaced. With a
# third argument the body after the banner is replaced by that one line.
set_banner() {
  local f="$1" banner="$2" hist="${3:-}"
  awk -v banner="$banner" -v hist="$hist" '
    function tail() { if (hist != "") { print ""; print hist; exit } }
    /^# / && !h1 { print; h1=1; next }
    h1 && !placed {
      if ($0 ~ /^[ \t]*$/) next
      if ($0 ~ /^> *Status:/) { print ""; print banner; inb=1; placed=1; next }
      print ""; print banner; placed=1; tail(); print ""; print; next
    }
    inb { if ($0 ~ /^>/) next; inb=0; tail(); if ($0 !~ /^[ \t]*$/) print "" }
    { print }
    END { if (placed && inb) tail() }' "$f" > "$TMP/bn.tmp" && mv "$TMP/bn.tmp" "$f"
}

# index_lines NAME BUCKET -> line numbers in _index.md that link the note
index_lines() {
  local name="$1" bkt="$2"
  [ -f "$VAULT/$INDEX" ] || return 0
  grep -n -E "\[\[($bkt/)?$name(\]\]|\||#)|\]\($bkt/$name\.md" "$VAULT/$INDEX" | cut -d: -f1
}
index_remove() {
  local name="$1" bkt="$2" ln
  for ln in $(index_lines "$name" "$bkt" | sort -rn); do sed -i.bak "${ln}d" "$VAULT/$INDEX"; done
  rm -f "$VAULT/$INDEX.bak"
}
index_suffix() {
  local name="$1" bkt="$2" text="$3" ln
  for ln in $(index_lines "$name" "$bkt"); do
    if ! sed -n "${ln}p" "$VAULT/$INDEX" | grep -qiE 'superseded|deprecated'; then
      awk -v n="$ln" -v t="$text" 'NR==n { print $0 " " t; next } { print }' "$VAULT/$INDEX" > "$TMP/ix.tmp" && mv "$TMP/ix.tmp" "$VAULT/$INDEX"
    fi
  done
}

# rewrite FROM TO [FILE...]: literal replacement of link prefixes outside
# fenced blocks and inline code, in every note (or the files given). Preview
# prints file:line with -/+ lines and counts sites; apply edits in place.
SITES=0
rewrite() {
  local from="$1" to="$2"; shift 2
  local files="$*" f rel out
  [ -n "$files" ] || files=$(note_files)
  for f in $files; do
    rel="${f#"$VAULT"/}"
    awk -v from="$from" -v to="$to" -v rel="$rel" -v mode="$APPLY" '
      function rep(s,  o, i) { o = ""; while ((i = index(s, from)) > 0) { o = o substr(s, 1, i - 1) to; s = substr(s, i + length(from)) } return o s }
      function rwline(s,  o, seg, i, code) { o = ""; code = 0
        while ((i = index(s, "`")) > 0) { seg = substr(s, 1, i - 1); o = o (code ? seg : rep(seg)) "`"; s = substr(s, i + 1); code = !code }
        return o (code ? s : rep(s)) }
      /^[ \t]*(```|~~~)/ { fence = !fence; if (mode) print; next }
      fence { if (mode) print; next }
      { n = rwline($0)
        if (n != $0) { sites++; if (!mode) { print rel ":" NR > "/dev/stderr"; print " - " $0 > "/dev/stderr"; print " + " n > "/dev/stderr" } }
        if (mode) print n }
      END { if (sites) print sites > "/dev/stderr" }' "$f" > "$TMP/rw.tmp" 2> "$TMP/rw.err"
    out=$(tail -n 1 "$TMP/rw.err" 2>/dev/null)
    case "$out" in ''|*[!0-9]*) out=0 ;; *) SITES=$((SITES + out)); sed '$d' "$TMP/rw.err" ;; esac
    [ "$APPLY" = 1 ] && [ "$out" -gt 0 ] && cat "$TMP/rw.tmp" > "$f"
  done
  return 0
}
rewrite_links() {  # every link spelling of OLD (bucket-qualified or bare) -> NEW
  local old="$1" oldb="$2" new="$3" newb="$4"
  rewrite "[[$old]]" "[[$new]]"; rewrite "[[$old|" "[[$new|"; rewrite "[[$old#" "[[$new#"
  rewrite "[[$oldb/$old]]" "[[$newb/$new]]"; rewrite "[[$oldb/$old|" "[[$newb/$new|"; rewrite "[[$oldb/$old#" "[[$newb/$new#"
  rewrite "]($oldb/$old.md" "]($newb/$new.md"; rewrite "](../$oldb/$old.md" "](../$newb/$new.md"
}
out_of_vault() {
  local old="$1" hits
  hits=$(git -C "$REPO" grep -n -F -e "[[$old" -e "$old.md" -- . ":!$RELV" 2>/dev/null | head -n 20)
  [ -n "$hits" ] && { echo "out-of-vault:"; printf '%s\n' "$hits" | sed 's/^/ /'; }
  return 0
}
bang() { echo "! $*"; BANG=1; }
finish() {
  if [ "$APPLY" = 1 ]; then echo "applied"; exit 0; fi
  [ "$BANG" = 1 ] && { echo "preview only; fix every ! line before --apply"; exit 0; }
  echo "preview only; re-run with --apply"; exit 0
}
refuse_if_bang() { [ "$BANG" = 1 ] && [ "$APPLY" = 1 ] && { echo "vault-refactor: --apply refused, ! lines above" >&2; exit 1; }; return 0; }

wikilist() { local out="" x; for x in $(printf '%s' "$1" | tr ',' ' '); do out="$out${out:+, }[[$(base_of "$x")]]"; done; printf '%s\n' "$out"; }
fmlist() { local out="" x; for x in $(printf '%s' "$1" | tr ',' ' '); do out="$out${out:+, }\"[[$(base_of "$x")]]\""; done; printf '[%s]\n' "$out"; }
squeeze() { awk 'NF || !blank { print } { blank = !NF }' "$1" > "$1.sq" && mv "$1.sq" "$1"; }

# --- retire ------------------------------------------------------------------
do_retire() {
  local note="$1" path bkt base h1 banner reasontxt hist
  path=$(resolve "$note") || { echo "vault-refactor: no note named $note" >&2; exit 3; }
  bkt=$(bucket_of "$path"); base=$(base_of "$path")
  case "$REASON" in merged|split|removed|wrong) ;; *) echo "vault-refactor: --reason must be merged|split|removed|wrong" >&2; exit 3 ;; esac
  [ "$REASON" = merged ] && [ -z "$REPLACED_BY" ] && { echo "vault-refactor: merged needs --replaced-by" >&2; exit 3; }
  [ "$REASON" = split ] && [ "$(printf '%s' "$CONSIDER" | tr ',' '\n' | grep -c .)" -lt 2 ] && { echo "vault-refactor: split needs --consider a,b (2+)" >&2; exit 3; }
  [ -n "$REPLACED_BY" ] && [ -n "$CONSIDER" ] && { echo "vault-refactor: exactly one of --replaced-by / --consider" >&2; exit 3; }
  local t tp
  for t in $REPLACED_BY $(printf '%s' "$CONSIDER" | tr ',' ' '); do
    if tp=$(resolve "$t"); then retired_status "$tp" && { echo "vault-refactor: $t is itself retired (pointer chain)" >&2; exit 3; }
    else bang "$t does not resolve"; fi
  done
  # a note already deprecated but without the tombstone fields is backfilled
  if [ "$bkt" = decisions ]; then retired_status "$path" && bang "$path is already retired"
  else retired_status "$path" && [ -n "$(fm_get "$VAULT/$path" retired)" ] && bang "$path is already retired"; fi
  case "$REASON" in
    merged) reasontxt="merged into $(wikilist "$REPLACED_BY")" ;;
    split) reasontxt="split into $(wikilist "$CONSIDER")" ;;
    removed) reasontxt="removed${CONSIDER:+; consider $(wikilist "$CONSIDER")}${REPLACED_BY:+; see $(wikilist "$REPLACED_BY")}" ;;
    wrong) reasontxt="recorded in error${CONSIDER:+; consider $(wikilist "$CONSIDER")}${REPLACED_BY:+; see $(wikilist "$REPLACED_BY")}" ;;
  esac
  [ -n "$WHY" ] && reasontxt="$reasontxt. $WHY"
  banner="> Status: DEPRECATED $TODAY $EM $reasontxt"
  echo "retire: $path ($REASON)"
  echo " + $banner"
  if [ "$bkt" = decisions ]; then echo " body kept (decision record)"; echo " index: suffix '$EM deprecated'"
  else echo " body -> tombstone (History: git log --follow -- $RELV/$path)"; echo " index: line removed"; fi
  refuse_if_bang
  if [ "$APPLY" = 1 ]; then
    fm_set "$VAULT/$path" status deprecated
    if [ "$bkt" = decisions ]; then
      set_banner "$VAULT/$path" "$banner"
      index_suffix "$base" "$bkt" "$EM deprecated"
    else
      fm_set "$VAULT/$path" obsoletion_reason "$REASON"
      fm_set "$VAULT/$path" retired "$TODAY"
      if [ -n "$REPLACED_BY" ]; then fm_set "$VAULT/$path" replaced_by "\"[[$(base_of "$REPLACED_BY")]]\""; fm_del "$VAULT/$path" consider
      elif [ -n "$CONSIDER" ]; then fm_set "$VAULT/$path" consider "$(fmlist "$CONSIDER")"; fm_del "$VAULT/$path" replaced_by
      else fm_del "$VAULT/$path" replaced_by; fm_del "$VAULT/$path" consider; fi
      hist="History: git log --follow -- $RELV/$path"
      set_banner "$VAULT/$path" "$banner" "$hist"
      index_remove "$base" "$bkt"
    fi
  fi
  finish
}

# --- rename -------------------------------------------------------------------
do_rename() {
  local old="$1" new="$2" path bkt base newb newpath
  path=$(resolve "$old") || { echo "vault-refactor: no note named $old" >&2; exit 3; }
  bkt=$(bucket_of "$path"); base=$(base_of "$path")
  [ "$bkt" = decisions ] && { echo "vault-refactor: an ADR keeps its number and name; supersede it instead" >&2; exit 3; }
  new="${new%.md}"; case "$new" in */*) newb="${new%%/*}"; new="${new##*/}" ;; *) newb="$bkt" ;; esac
  newpath="$newb/$new.md"
  [ -e "$VAULT/$newpath" ] && { echo "vault-refactor: $newpath exists (clobber)" >&2; exit 3; }
  [ "$new" = "$base" ] && [ "$newb" = "$bkt" ] && { echo "vault-refactor: same name" >&2; exit 3; }
  echo "rename: $path -> $newpath"
  rewrite_links "$base" "$bkt" "$new" "$newb"
  echo "sites: $SITES"
  out_of_vault "$base"
  refuse_if_bang
  if [ "$APPLY" = 1 ]; then
    mkdir -p "$VAULT/$newb"
    if git -C "$REPO" ls-files --error-unmatch -- "$RELV/$path" >/dev/null 2>&1; then git -C "$REPO" mv "$RELV/$path" "$RELV/$newpath" >/dev/null; else mv "$VAULT/$path" "$VAULT/$newpath"; fi
    fm_add_alias "$VAULT/$newpath" "$base"
  fi
  finish
}

# --- merge ---------------------------------------------------------------------
do_merge() {
  local loser="$1" survivor="$2" lp sp lb sb lbk sbk h1
  lp=$(resolve "$loser") || { echo "vault-refactor: no note named $loser" >&2; exit 3; }
  sp=$(resolve "$survivor") || { echo "vault-refactor: no note named $survivor" >&2; exit 3; }
  [ "$lp" = "$sp" ] && { echo "vault-refactor: same note" >&2; exit 3; }
  retired_status "$sp" && { echo "vault-refactor: $survivor is retired (pointer chain)" >&2; exit 3; }
  retired_status "$lp" && bang "$lp is already retired"
  lb=$(base_of "$lp"); sb=$(base_of "$sp"); lbk=$(bucket_of "$lp"); sbk=$(bucket_of "$sp")
  [ "$lbk" = decisions ] && { echo "vault-refactor: an ADR is superseded, not merged" >&2; exit 3; }
  h1=$(h1_of "$VAULT/$lp")
  echo "merge: $lp -> $sp (prose is not moved; fold it into the survivor first)"
  rewrite_links "$lb" "$lbk" "$sb" "$sbk"
  echo "sites: $SITES"
  echo " survivor aliases += $lb${h1:+, $h1}"
  echo " loser -> tombstone (merged, replaced_by [[$sb]]); index line removed"
  out_of_vault "$lb"
  refuse_if_bang
  if [ "$APPLY" = 1 ]; then
    fm_add_alias "$VAULT/$sp" "$lb"; [ -n "$h1" ] && fm_add_alias "$VAULT/$sp" "$h1"
    fm_set "$VAULT/$lp" status deprecated
    fm_set "$VAULT/$lp" obsoletion_reason merged
    fm_set "$VAULT/$lp" retired "$TODAY"
    fm_set "$VAULT/$lp" replaced_by "\"[[$sb]]\""
    set_banner "$VAULT/$lp" "> Status: DEPRECATED $TODAY $EM merged into [[$sb]]" "History: git log --follow -- $RELV/$lp"
    index_remove "$lb" "$lbk"
  fi
  finish
}

# --- supersede ------------------------------------------------------------------
do_supersede() {
  local old="$1" new="$2" op np ob nb obk
  op=$(resolve "$old") || { echo "vault-refactor: no note named $old" >&2; exit 3; }
  np=$(resolve "$new") || { echo "vault-refactor: no note named $new" >&2; exit 3; }
  obk=$(bucket_of "$op"); ob=$(base_of "$op"); nb=$(base_of "$np")
  retired_status "$np" && { echo "vault-refactor: $new is itself retired (chain)" >&2; exit 3; }
  if [ "$obk" != decisions ]; then REASON=merged; REPLACED_BY="$nb"; APPLY_SAVED=$APPLY; do_merge "$ob" "$nb"; fi
  retired_status "$op" && bang "$op is already retired"
  grep -qE "\[\[($obk/)?$ob(\]\]|\||#)" "$VAULT/$np" || bang "$np never links back to [[$ob]] (SUPERSEDED_BY_NO_BACKLINK)"
  echo "supersede: $op -> $np"
  echo " + status: superseded, superseded_by: \"[[$nb]]\""
  echo " + > Status: SUPERSEDED by [[$nb]] $EM read that instead."
  echo " index: suffix '$EM superseded by [[$nb]]'"
  refuse_if_bang
  if [ "$APPLY" = 1 ]; then
    fm_set "$VAULT/$op" status superseded
    fm_set "$VAULT/$op" superseded_by "\"[[$nb]]\""
    set_banner "$VAULT/$op" "> Status: SUPERSEDED by [[$nb]] $EM read that instead."
    index_suffix "$ob" "$obk" "$EM superseded by [[$nb]]"
  fi
  finish
}

# --- split ----------------------------------------------------------------------
do_split() {
  local note="$1" path bkt base
  path=$(resolve "$note") || { echo "vault-refactor: no note named $note" >&2; exit 3; }
  [ -n "$PLAN" ] && [ -f "$PLAN" ] || { echo "vault-refactor: split needs --plan FILE" >&2; exit 2; }
  bkt=$(bucket_of "$path"); base=$(base_of "$path")
  local src="$VAULT/$path"
  # heading map: line<TAB>level<TAB>text (outside fences)
  awk '/^[ \t]*(```|~~~)/ { f = !f; next } f { next } match($0, /^#+ /) { t = substr($0, RLENGTH + 1); sub(/[ #]+$/, "", t); print NR "\t" (RLENGTH - 1) "\t" t }' "$src" > "$TMP/heads.tsv"
  local total; total=$(wc -l < "$src" | tr -d ' ')
  local ranges_all="" n=0 line name nbkt heads
  BYPREFIX=0
  : > "$TMP/plan.tsv"
  while IFS= read -r line; do
    [ -n "$line" ] || continue; case "$line" in \#*) continue ;; esac
    name=$(printf '%s' "$line" | cut -f1); nbkt=$(printf '%s' "$line" | cut -f2); heads=$(printf '%s' "$line" | cut -f3-)
    [ -n "$name" ] && [ -n "$nbkt" ] && [ -n "$heads" ] || { bang "plan line needs name<TAB>bucket<TAB>heading: $line"; continue; }
    [ "$nbkt" = decisions ] && { bang "$name: a split section never becomes an ADR"; continue; }
    [ -e "$VAULT/$nbkt/$name.md" ] && { echo "vault-refactor: $nbkt/$name.md exists (clobber)" >&2; exit 3; }
    "$JQ" -e --arg b "$nbkt" '.buckets[$b] != null' "$TMP/schema.json" >/dev/null 2>&1 || { bang "$name: unknown bucket $nbkt"; continue; }
    local ranges="" h hl lvl endl
    : > "$TMP/sprefix.$name"
    while IFS= read -r h; do
      [ -n "$h" ] || continue
      case "$h" in surface:*) printf '%s\n' "${h#surface:}" >> "$TMP/sprefix.$name"; BYPREFIX=1; continue ;; esac
      case "$h" in "Reusable surface") bang "$name: the Reusable surface section stays with the parent; route its entries with surface:<prefix> items"; continue ;; esac
      hl=$(awk -F'\t' -v t="$h" '$3 == t { print $1 "\t" $2; exit }' "$TMP/heads.tsv")
      [ -n "$hl" ] || hl=$(awk -F'\t' -v t="$h" 'tolower($3) == tolower(t) { print $1 "\t" $2; exit }' "$TMP/heads.tsv")
      [ -n "$hl" ] || { bang "$name: heading not found: $h"; continue; }
      lvl=$(printf '%s' "$hl" | cut -f2); hl=$(printf '%s' "$hl" | cut -f1)
      [ "$lvl" = 1 ] && { bang "$name: the H1 cannot move"; continue; }
      endl=$(awk -F'\t' -v s="$hl" -v l="$lvl" -v tot="$total" '$1 > s && $2 <= l { print $1 - 1; exit } END { if (!p) print tot }' "$TMP/heads.tsv" | head -n 1)
      case "$ranges_all" in *"|$hl-"*|*"$hl-$endl"*) bang "$name: $h is already moved by another plan line" ;; esac
      ranges="$ranges${ranges:+,}$hl-$endl"
    done <<EOF
$(printf '%s\n' "$heads" | tr '\t' '\n')
EOF
    [ -n "$ranges" ] || [ -s "$TMP/sprefix.$name" ] || continue
    ranges_all="$ranges_all|$ranges"
    printf '%s\t%s\t%s\n' "$name" "$nbkt" "$ranges" >> "$TMP/plan.tsv"
    n=$((n + 1))
  done < "$PLAN"
  [ "$n" -gt 0 ] || { bang "plan moved nothing"; finish; }
  # parent remainder (moved ranges replaced by pointer stubs)
  local allr; allr=$(cut -f3 "$TMP/plan.tsv" | tr '\n' ',' | sed 's/,$//')
  awk -v ranges="$allr" -v plan="$TMP/plan.tsv" '
    BEGIN { while ((getline l < plan) > 0) { split(l, P, "\t"); if (P[3] == "") continue; m = split(P[3], R, ","); for (i = 1; i <= m; i++) { split(R[i], se, "-"); S[se[1]] = se[2]; N[se[1]] = P[1] } } }
    NR in S { hdr = $0; print hdr; print ""; print "Moved to [[" N[NR] "]]."; skipto = S[NR]; next }
    skipto && NR <= skipto { if (NR == skipto) { skipto = 0; print "" } next }
    { print }' "$src" > "$TMP/parent.md"
  # each new note
  local rest_wo_surface; awk '/^## Reusable surface/ { s = 1 } /^## / && !/^## Reusable surface/ { s = 0 } !s' "$TMP/parent.md" > "$TMP/parent.prose"
  local rc=0 ntype sev
  while IFS=$'\t' read -r name nbkt ranges; do
    ntype=$("$JQ" -r --arg b "$nbkt" '.buckets[$b].type' "$TMP/schema.json")
    {
      echo "---"; echo "type: $ntype"; echo "status: active"; echo "created: $TODAY"; echo "last_verified: $TODAY"
      if [ "$nbkt" = constraints ]; then sev=$(fm_get "$src" severity); echo "severity: ${sev:-medium}"; fi
      echo "---"
    } > "$TMP/new.$name.md"
    if [ -z "$ranges" ]; then
      { echo "# $(h1_of "$src"): surface for $(tr '\n' ' ' < "$TMP/sprefix.$name" | sed 's/ $//; s/ /, /g')"; echo ""; echo "Split from [[$base]] ($TODAY). The behaviour behind these entries is described in [[$base]]; this note only anchors the symbols."; } >> "$TMP/new.$name.md"
      continue
    fi
    awk -v ranges="$ranges" -v parent="$base" -v today="$TODAY" '
      BEGIN { m = split(ranges, R, ","); for (i = 1; i <= m; i++) { split(R[i], se, "-"); S[i] = se[1]; E[i] = se[2] } }
      { L[NR] = $0 }
      END {
        for (i = 1; i <= m; i++) {
          match(L[S[i]], /^#+ /); top = RLENGTH - 1; t = substr(L[S[i]], RLENGTH + 1); sub(/[ #]+$/, "", t)
          if (i == 1) { print "# " t; print ""; print "Split from [[" parent "]] (" today ")."; print "" } else { print "## " t }
          for (n = S[i] + 1; n <= E[i]; n++) {
            l = L[n]
            if (match(l, /^#+ /)) { lv = RLENGTH - 1; nl = lv - top + (i == 1 ? 1 : 2); if (nl < 2) nl = 2; if (nl > 6) nl = 6; l = substr("######", 1, nl) substr(l, RLENGTH) }
            print l
          }
        }
      }' "$src" >> "$TMP/new.$name.md"
  done < "$TMP/plan.tsv"
  # surface entries move to the one new note whose moved text names their
  # path; a path no new note mentions, or two mention, stays with the parent
  # (the parent's own prose may still name it: the child owns the symbol,
  # the parent links the child).
  # an entry is its bullet line plus the continuation lines up to the next
  # bullet, blank line or heading; blocks travel as one line joined by \001
  awk '/^## Reusable surface/ { s = 1; next } /^## / { s = 0 }
       s && /^[-*] / { if (blk != "") print blk; blk = $0; next }
       s && blk != "" && !/^[ \t]*$/ && !/^#/ { blk = blk "\001" $0; next }
       s { if (blk != "") print blk; blk = "" }
       END { if (blk != "") print blk }' "$src" > "$TMP/surfall.txt"
  local e p owner cnt best ml
  while IFS=$'\t' read -r name nbkt ranges; do : > "$TMP/surf.$name"; done < "$TMP/plan.tsv"
  if [ -s "$TMP/surfall.txt" ] && [ "$BYPREFIX" = 1 ]; then
    while IFS= read -r e; do
      p=$(printf '%s' "${e%%$'\001'*}" | grep -o '`[^`]*`' | tr -d '`' | grep -E "$PATHRE" | head -n 1)
      [ -n "$p" ] || continue
      owner=""; best=0
      while IFS=$'\t' read -r name nbkt ranges; do
        [ -s "$TMP/sprefix.$name" ] || continue
        # the longest matching prefix wins, whichever line carries it
        ml=$(awk -v p="$p" '(p == $0 || index(p, $0 "/") == 1) && length($0) > m { m = length($0) } END { print m + 0 }' "$TMP/sprefix.$name")
        [ "$ml" -gt "$best" ] && { best=$ml; owner="$name"; }
      done < "$TMP/plan.tsv"
      [ -n "$owner" ] && printf '%s\n' "$e" >> "$TMP/surf.$owner"
    done < "$TMP/surfall.txt"
  elif [ -s "$TMP/surfall.txt" ]; then
    while IFS= read -r e; do
      p=$(printf '%s' "${e%%$'\001'*}" | grep -o '`[^`]*`' | tr -d '`' | grep -E "$PATHRE" | head -n 1)
      [ -n "$p" ] || continue
      owner=""; cnt=0
      while IFS=$'\t' read -r name nbkt ranges; do
        if grep -qF -- "$p" "$TMP/new.$name.md"; then owner="$name"; cnt=$((cnt + 1)); fi
      done < "$TMP/plan.tsv"
      [ "$cnt" = 1 ] && printf '%s\n' "$e" >> "$TMP/surf.$owner"
    done < "$TMP/surfall.txt"
  fi
  local bytes
  while IFS=$'\t' read -r name nbkt ranges; do
    if [ -s "$TMP/surf.$name" ]; then { echo ""; echo "## Reusable surface"; echo ""; tr '\001' '\n' < "$TMP/surf.$name"; } >> "$TMP/new.$name.md"
    elif [ "$nbkt" = components ]; then { echo ""; echo "## Reusable surface"; echo ""; echo "None $EM symbols stay with [[$base]]."; } >> "$TMP/new.$name.md"; fi
    squeeze "$TMP/new.$name.md"
    bytes=$(wc -c < "$TMP/new.$name.md" | tr -d ' ')
    echo "new: $nbkt/$name.md $bytes bytes ($(printf '%s' "$ranges" | tr ',' '\n' | grep -c .) sections, $(grep -c . "$TMP/surf.$name") surface entries)"
    [ "$bytes" -gt "$NOTE_FAIL" ] && { echo "! $nbkt/$name.md still over $NOTE_FAIL bytes"; rc=3; }
  done < "$TMP/plan.tsv"
  # drop moved surface entries from the parent
  local moved; cat "$TMP"/surf.* 2>/dev/null | grep -v '^$' > "$TMP/surf.moved" || true
  if [ -s "$TMP/surf.moved" ]; then
    awk -v mf="$TMP/surf.moved" 'BEGIN { while ((getline l < mf) > 0) { sub(/\001.*/, "", l); M[l] = 1 } }
      /^## Reusable surface/ { s = 1 } /^## / && !/^## Reusable surface/ { s = 0 }
      s && /^[-*] / { skip = ($0 in M); if (skip) next }
      s && skip { if (/^[ \t]*$/ || /^#/) { skip = 0; print } next }
      { print }' "$TMP/parent.md" > "$TMP/parent2.md" && mv "$TMP/parent2.md" "$TMP/parent.md"
  fi
  # a parent surface emptied by the move gets the absence stanza
  if awk '/^## Reusable surface/ { s = 1; next } /^## / { s = 0 } s && /^[-*] /' "$TMP/parent.md" | grep -q . ; then :
  elif grep -q '^## Reusable surface' "$TMP/parent.md"; then
    local names; names=$(cut -f1 "$TMP/plan.tsv" | tr '\n' ',' | sed 's/,$//')
    awk -v st="None $EM moved to $(wikilist "$names")." '/^## Reusable surface/ { print; print ""; print st; s = 1; next } /^## / { s = 0 } s && /^[ \t]*$/ { next } { print }' "$TMP/parent.md" > "$TMP/parent2.md" && mv "$TMP/parent2.md" "$TMP/parent.md"
  fi
  squeeze "$TMP/parent.md"
  local pbytes; pbytes=$(wc -c < "$TMP/parent.md" | tr -d ' ')
  echo "parent: $path $pbytes bytes after"
  [ "$pbytes" -gt "$NOTE_FAIL" ] && { echo "! $path still over $NOTE_FAIL bytes"; rc=3; }
  # anchor rewrites for moved headings
  while IFS=$'\t' read -r name nbkt ranges; do
    [ -n "$ranges" ] || continue
    for s in $(printf '%s' "$ranges" | tr ',' '\n' | cut -d- -f1); do
      h=$(awk -F'\t' -v n="$s" '$1 == n { print $3 }' "$TMP/heads.tsv")
      rewrite "[[$base#$h" "[[$name#$h"; rewrite "[[$bkt/$base#$h" "[[$nbkt/$name#$h"
    done
  done < "$TMP/plan.tsv"
  echo "anchor sites: $SITES"
  [ "$rc" = 3 ] && { [ "$APPLY" = 1 ] && echo "vault-refactor: --apply refused, a result is still over the size limit" >&2; exit 3; }
  refuse_if_bang
  if [ "$APPLY" = 1 ]; then
    while IFS=$'\t' read -r name nbkt ranges; do mkdir -p "$VAULT/$nbkt"; cp "$TMP/new.$name.md" "$VAULT/$nbkt/$name.md"; done < "$TMP/plan.tsv"
    cp "$TMP/parent.md" "$src"
  fi
  finish
}

case "$CMD" in
  rename) [ $# -eq 2 ] || usage; do_rename "$1" "$2" ;;
  merge) [ $# -eq 2 ] || usage; do_merge "$1" "$2" ;;
  retire) [ $# -eq 1 ] || usage; do_retire "$1" ;;
  supersede) [ $# -eq 2 ] || usage; do_supersede "$1" "$2" ;;
  split) [ $# -eq 1 ] || usage; do_split "$1" ;;
esac
