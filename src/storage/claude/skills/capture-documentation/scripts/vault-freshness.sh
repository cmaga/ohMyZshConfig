#!/usr/bin/env bash
# vault-freshness.sh -- ranks vault notes by review urgency: missing surface
# symbols/paths (from the linter), overdue decision revisits (revisit_if date: items), overdue
# time-based cadence, and notes that have never been verified.
set -u
export LC_ALL=C
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/vault-lib.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
TODAY=$(vault_today)

usage() {
  echo "usage: vault-freshness.sh VAULT [--lint-json FILE] [--count] [--json]" >&2
  exit 2
}

VAULT="${1:-}"
[ -n "$VAULT" ] && [ -d "$VAULT" ] || usage
shift

LINT_JSON=""
COUNT_ONLY=0
JSON_OUT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --lint-json) shift; LINT_JSON="${1:-}"; [ -n "$LINT_JSON" ] || usage ;;
    --count) COUNT_ONLY=1 ;;
    --json) JSON_OUT=1 ;;
    *) usage ;;
  esac
  shift
done

vault_merge_schema "$VAULT" "$TMP/schema.json"
vault_records "$VAULT" "$TMP/recs.ndjson"

if [ -n "$LINT_JSON" ]; then
  cp "$LINT_JSON" "$TMP/lint.json"
else
  bash "$HERE/lint-vault.sh" --format json "$VAULT" > "$TMP/lint.json" || true
fi

# Step 1: per-note cadence resolution -> notes.tsv. Decisions always get -1
# (rank 4/5 never apply to them); everything else resolves review_cadence,
# then bucket defaults (plan/research while open), then the vault max_age.
"$JQ" -r '
  ($SC[0]) as $sc
  | . as $r
  | ($r.path | split("/")[0]) as $bucket
  | select(($sc.hubs[$r.path] // null) == null)
  | ($r.fm.status // "") as $status
  | ($r.fm.created // "") as $created
  | ($r.fm.last_verified // "") as $last_verified
  | ($r.fm.revisit_if // "") as $ri
  | (if ($ri | type) == "string" and ($ri | test("^\\[.*\\]$")) then ($ri[1:-1] | split(",") | map(gsub("^ +| +$"; "")) | map(select(. != ""))) else [] end) as $items
  | ([ $items[] | select(startswith("date:")) | ltrimstr("date:") ] | sort | .[0] // "") as $revisit_by
  | ([ $items[] | select(startswith("date:") | not) ] | join("; ")) as $revisit_when
  | (if $bucket == "decisions" then
       {cd: -1, src: ""}
     else
       ($r.fm.review_cadence // "") as $rc
       | (if ($rc != "" and ($sc.freshness.cadence_days | has($rc))) then
            {cd: $sc.freshness.cadence_days[$rc], src: ("cadence:" + $rc)}
          elif ($rc != "" and ($rc | test("^[0-9]+d$"))) then
            {cd: ($rc | capture("^(?<n>[0-9]+)d$").n | tonumber), src: ("cadence:" + $rc)}
          elif (($bucket == "plan" or $bucket == "research") and $status != "closed") then
            {cd: $sc.freshness.buckets[$bucket], src: ("bucket:" + $bucket)}
          else
            {cd: $sc.freshness.max_age_days, src: "max_age"}
          end)
     end) as $cad
  | [$r.path, $bucket, $status, $created, $last_verified, ($cad.cd | tostring), $cad.src, $revisit_by, $revisit_when]
  | @tsv
' --slurpfile SC "$TMP/schema.json" "$TMP/recs.ndjson" > "$TMP/notes.tsv"

# Step 2: SURFACE_SYMBOL_MISSING / SURFACE_PATH_MISSING findings, raw msg
# kept intact -- the awk pass below splits "sym @ spath" itself.
"$JQ" -r '
  .findings[]?
  | select(.code == "SURFACE_SYMBOL_MISSING" or .code == "SURFACE_PATH_MISSING")
  | [.code, .path, .msg] | @tsv
' "$TMP/lint.json" > "$TMP/lint.tsv" 2>/dev/null || : > "$TMP/lint.tsv"

# Step 3: one awk pass emits "rank<TAB>reason<TAB>path<TAB>detail" rows.
# rank1/3 come straight from lint.tsv; rank2/4/5 come from notes.tsv using
# the civil-calendar day arithmetic (Howard Hinnant's algorithms, verified
# days("2026-09-26") == 20722). rank4 (overdue) and rank5 (never-verified)
# are independent conditions, same as rank1/rank3 can both fire for one
# note -- a note can be both overdue and never-verified at once, which is
# why rank5 is informational-only and excluded from the overdue/drifted
# counts rather than folded into rank4.
awk -F'\t' -v today="$TODAY" '
function dfc(y,m,d,  era,yoe,doy,doe) { if (m<=2) y--; era=int((y>=0?y:y-399)/400); yoe=y-era*400
  doy=int((153*(m+(m>2?-3:9))+2)/5)+d-1; doe=yoe*365+int(yoe/4)-int(yoe/100)+doy; return era*146097+doe-719468 }
function cfd(z,  era,doe,yoe,y,doy,mp,d,m) { z+=719468; era=int((z>=0?z:z-146096)/146097); doe=z-era*146097
  yoe=int((doe-int(doe/1460)+int(doe/36524)-int(doe/146096))/365); y=yoe+era*400
  doy=doe-(365*yoe+int(yoe/4)-int(yoe/100)); mp=int((5*doy+2)/153); d=doy-int((153*mp+2)/5)+1
  m=mp+(mp<10?3:-9); if (m<=2) y++; return sprintf("%04d-%02d-%02d",y,m,d) }
function days(s) { split(s,a,"-"); return dfc(a[1]+0,a[2]+0,a[3]+0) }
BEGIN { td = days(today) }
FNR == NR {
  code = $1; path = $2; msg = $3
  at = index(msg, " @ ")
  if (at > 0) { sym = substr(msg, 1, at - 1); spath = substr(msg, at + 3) } else { sym = msg; spath = "" }
  if (code == "SURFACE_SYMBOL_MISSING") print "1\tsymbol-missing\t" path "\t" sym
  else if (code == "SURFACE_PATH_MISSING") print "3\tpaths\t" path "\t" spath
  next
}
{
  path = $1; bucket = $2; created = $4; last_verified = $5
  cadence = $6; cadence_src = $7; revisit_by = $8; revisit_when = $9
  if (bucket == "decisions") {
    if (revisit_by != "" && days(revisit_by) <= td) {
      detail = "date:" revisit_by (revisit_when != "" ? "; " revisit_when : "")
      print "2\trevisit\t" path "\t" detail
    }
    next
  }
  if (last_verified == "" && created == "") next
  base = (last_verified != "" ? last_verified : created)
  due = days(base) + (cadence + 0)
  if (due <= td) {
    print "4\ttime\t" path "\t" "due " cfd(due) " (" cadence_src ", " cadence "d)"
  }
  if (last_verified == "") {
    print "5\tnever-verified\t" path "\t" "created " created
  }
}
' "$TMP/lint.tsv" "$TMP/notes.tsv" > "$TMP/rows.tsv"

sort -t "$TAB" -k1,1n -k3,3 "$TMP/rows.tsv" > "$TMP/rows.sorted.tsv"
cut -f2- "$TMP/rows.sorted.tsv" > "$TMP/final.tsv"

read -r N M <<EOF
$(awk -F'\t' '$1<=4{n++} ($1==1||$1==3){m++} END{printf "%d %d", n+0, m+0}' "$TMP/rows.tsv")
EOF

if [ "$JSON_OUT" -eq 1 ]; then
  "$JQ" -R -s --argjson overdue "$N" --argjson drifted "$M" '
    split("\n") | map(select(length>0)) | map(split("\t"))
    | map({reason: .[0], path: .[1], detail: (.[2] // "")})
    | {overdue: $overdue, drifted: $drifted, rows: .}
  ' "$TMP/final.tsv"
  exit 0
fi

if [ "$COUNT_ONLY" -eq 1 ]; then
  [ "$N" -eq 0 ] && exit 0
  echo "vault-freshness: $N overdue ($M drifted)"
  exit 0
fi

cat "$TMP/final.tsv"
echo "vault-freshness: $N overdue ($M drifted)"
exit 0
