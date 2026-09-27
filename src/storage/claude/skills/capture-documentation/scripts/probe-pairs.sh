#!/usr/bin/env bash
# probe-pairs.sh -- candidate conflict pairs for the notes a change touches.
#
#   probe-pairs.sh VAULT NOTE...
#
# NOTE is a vault-relative path, bucket/basename, or a basename. For each
# one, prints NOTE<TAB>OTHER<TAB>reason, one line per pair, where reason is
#   links              the two notes link each other directly (either way)
#   shares <target>    both link the same non-hub note that at most 8 notes
#                      link in all (a shared, specific subject)
#   surface <path>     both own a Reusable-surface entry at that path
# A pair named by a _fragments/rulings/*.md file (both wikilinks) is dropped:
# the humans already ruled it harmless. Hubs, retired notes and the note
# itself never pair. Output is sorted; exit 0 with no output when nothing
# pairs, 2 on usage, 3 when a NOTE does not resolve.
set -u
export LC_ALL=C
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=vault-lib.sh
. "$HERE/vault-lib.sh"

[ $# -ge 2 ] || { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
VAULT="${1%/}"; shift
[ -d "$VAULT" ] || { echo "probe-pairs: no such vault $VAULT" >&2; exit 2; }
TMP=$(mktemp -d) || exit 2
trap 'rm -rf "$TMP"' EXIT

vault_records "$VAULT" "$TMP/recs.ndjson" || exit 2

# rulings: one JSON array of [a, b] basenames per ruling file
: > "$TMP/rulings.ndjson"
if [ -d "$VAULT/_fragments/rulings" ]; then
  for f in "$VAULT"/_fragments/rulings/*.md; do
    [ -f "$f" ] || continue
    grep -o '\[\[[^]|#]*' "$f" | sed 's/^\[\[//; s#.*/##' | "$JQ" -R . | "$JQ" -s -c 'select(length == 2)' >> "$TMP/rulings.ndjson"
  done
fi

printf '%s\n' "$@" | "$JQ" -R . | "$JQ" -s . > "$TMP/asked.json"

"$JQ" -r -n --slurpfile R "$TMP/recs.ndjson" --slurpfile RU "$TMP/rulings.ndjson" --slurpfile asked "$TMP/asked.json" '
  def base: split("/")[-1] | rtrimstr(".md");
  ($R | map(select((.path | contains("/")) and ((.fm.status // "") | IN("deprecated", "superseded") | not)))) as $N |
  ($N | map({key: .path, value: .}) | from_entries) as $byPath |
  ($N | group_by(.path | base) | map({key: (.[0].path | base), value: map(.path)}) | from_entries) as $byBase |
  def resolve: (split("|")[0] | split("#")[0] | ltrimstr("./") | rtrimstr(".md") | gsub("^ +| +$"; "")) as $n
    | if $byPath[$n + ".md"] then $n + ".md"
      elif (($byBase[$n] // []) | length) == 1 then $byBase[$n][0]
      elif (($byBase[$n | base] // []) | length) == 1 then $byBase[$n | base][0]
      else null end;
  # resolved outbound links per note, self excluded
  ($N | map({key: .path, value: (.path as $p | [ .links[] | select(.wiki != null) | .wiki | resolve | select(. != null and . != $p) ] | unique)}) | from_entries) as $out |
  ($out | to_entries | map(.key as $s | .value[] | {to: ., from: $s}) | group_by(.to) | map({key: .[0].to, value: map(.from)}) | from_entries) as $in |
  ($N | map({key: .path, value: ([ .surface.entries[]? | .spath ] | unique)}) | from_entries) as $paths |
  ([ $RU[] | map(. ) | sort | join("|") ]) as $ruled |
  def ruled($a; $b): ([$a | base, $b | base] | sort | join("|")) as $k | $ruled | index($k) != null;
  [ $asked[0][] | . as $q | (resolve // ("\u0000" + $q)) ] as $targets |
  ($targets | map(select(startswith("\u0000")) | ltrimstr("\u0000"))) as $bad |
  if ($bad | length) > 0 then ($bad[] | "probe-pairs: no live note named \(.)\n" | halt_error(3)) else empty end,
  ( [ $targets[] | . as $p |
      # links either way
      ( ($out[$p] // []) + ($in[$p] // []) | unique[] | {a: $p, b: ., reason: "links", rank: 0} ),
      # shared specific target
      ( ($out[$p] // [])[] | . as $t | select((($in[$t] // []) | length) <= 8) | ($in[$t] // [])[] | select(. != $p) | {a: $p, b: ., reason: "shares \($t)", rank: 1} ),
      # shared surface path
      ( ($paths[$p] // [])[] | . as $sp | $paths | to_entries[] | select(.key != $p and (.value | index($sp) != null)) | {a: $p, b: .key, reason: "surface \($sp)", rank: 2} )
    ]
    | map(select(ruled(.a; .b) | not))
    | group_by([.a, .b]) | map(min_by(.rank))
    | sort_by([.a, .rank, .b])[]
    | "\(.a)\t\(.b)\t\(.reason)" )
' 2>"$TMP/err"
rc=$?
if [ "$rc" -ne 0 ]; then sed 's/^jq: error (at <unknown>): //' "$TMP/err" >&2; exit 3; fi
exit 0
