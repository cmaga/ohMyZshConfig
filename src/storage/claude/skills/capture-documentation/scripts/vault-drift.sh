#!/usr/bin/env bash
# vault-drift.sh -- flags commits that touch code a vault note claims
# (governs/surface) without an accompanying vault edit or a Vault-Exempt:
# trailer. State lives under .git so it is shared across worktrees.
set -u
export LC_ALL=C
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/vault-lib.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
TODAY=$(vault_today)

usage() {
  echo "usage: vault-drift.sh [--scan] REPO | --list REPO [--json] | --clear REPO ID REASON | --suggest-governs NOTE" >&2
  exit 2
}

# require_repo REPO -- validates REPO is a directory and a git repo, then
# prints its absolute, symlink-resolved path.
require_repo() {
  local repo="${1:-}"
  [ -n "$repo" ] && [ -d "$repo" ] || usage
  repo=$(cd "$repo" && pwd -P) || usage
  git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || usage
  printf '%s\n' "$repo"
}

state_dir() { printf '%s\n' "$(git_dir_abs "$1" --git-common-dir)/vault-drift"; }

# probe_vanished REPO TIP IN OUT -- IN rows are "key<TAB>path<TAB>a,b,c"
# (declared symbols for that path); OUT rows are "key<TAB>path<TAB>x,y"
# listing the symbols not found as whole words in that path at TIP (empty
# third field when all are present; a path missing at TIP loses them all).
# One git cat-file --batch streams every distinct blob, and one awk pass
# probes each line against only that path's symbols: git grep -w with
# hundreds of -e patterns costs seconds, one process per path costs ~15 ms
# each, this costs ~0.2 s for 100 paths on engine.
probe_vanished() {
  local repo="$1" tip="$2" in="$3" out="$4"
  : > "$out"
  [ -s "$in" ] || return 0
  cut -f2 "$in" | sort -u | awk -v tip="$tip" '{ print tip ":" $0 " " $0 }' \
    | git -C "$repo" cat-file --batch='%(objectname) %(objecttype) %(objectsize) %(rest)' 2>/dev/null \
    | awk -v inf="$in" '
        BEGIN {
          while ((getline line < inf) > 0) {
            n = split(line, f, "\t"); if (n < 3) continue
            m = split(f[3], w, ",")
            for (i = 1; i <= m; i++) if (w[i] != "" && !((f[2] SUBSEP w[i]) in want)) {
              want[f[2] SUBSEP w[i]] = 1
              ids[f[2]] = (f[2] in ids ? ids[f[2]] "," w[i] : w[i])
            }
          }
          close(inf)
          left = 0
        }
        left > 0 {
          # Blob content (left counts bytes still to consume, LF included).
          for (i = 1; i <= cnt; i++) {
            id = cid[i]
            if ((path SUBSEP id) in hit) continue
            if (!index($0, id)) continue
            re = id; gsub(/\$/, "\\$", re)
            if ($0 ~ ("(^|[^A-Za-z0-9_])" re "([^A-Za-z0-9_]|$)")) hit[path SUBSEP id] = 1
          }
          left -= length($0) + 1
          next
        }
        {
          # Header: "<oid> blob <size> <path>" or "<tip>:<path> missing".
          if ($2 == "missing") { path = ""; cnt = 0; next }
          path = $0; sub(/^[^ ]+ [^ ]+ [^ ]+ /, "", path)
          left = $3 + 1
          cnt = split((path in ids ? ids[path] : ""), cid, ",")
        }
        END {
          while ((getline line < inf) > 0) {
            n = split(line, f, "\t"); if (n < 3) continue
            m = split(f[3], w, ","); v = ""
            for (i = 1; i <= m; i++) if (w[i] != "" && !((f[2] SUBSEP w[i]) in hit)) v = (v == "" ? w[i] : v "," w[i])
            print f[1] "\t" f[2] "\t" v
          }
        }' > "$out"
}

cmd_scan() {
  local repo vault b tip state marker_file flags_file marker
  repo=$(require_repo "${1:-}")
  vault="$repo/docs/project-knowledge"
  [ -d "$vault" ] || usage

  b=$(git -C "$repo" symbolic-ref -q refs/remotes/origin/HEAD 2>/dev/null || true)
  b=${b#refs/remotes/origin/}
  if [ -n "$b" ] && git -C "$repo" show-ref -q --verify "refs/heads/$b"; then
    :
  elif git -C "$repo" show-ref -q --verify refs/heads/main; then
    b=main
  else
    b=HEAD
  fi
  tip=$(git -C "$repo" rev-parse "$b") || usage

  state=$(state_dir "$repo")
  mkdir -p "$state"
  marker_file="$state/marker"
  flags_file="$state/flags.jsonl"
  [ -f "$flags_file" ] || : > "$flags_file"

  if [ ! -f "$marker_file" ]; then
    printf '%s\n' "$tip" > "$state/marker.tmp"
    mv "$state/marker.tmp" "$marker_file"
    exit 0
  fi
  marker=$(cat "$marker_file")
  if [ "$marker" = "$tip" ]; then
    exit 0
  fi
  if ! git -C "$repo" cat-file -e "${marker}^{commit}" 2>/dev/null; then
    echo "vault-drift: marker $marker not found (gc or force-push); resetting to $tip" >&2
    printf '%s\n' "$tip" > "$state/marker.tmp"
    mv "$state/marker.tmp" "$marker_file"
    exit 0
  fi

  vault_records "$vault" "$TMP/recs.ndjson"

  # Step 3: patterns TSV (note<TAB>kind<TAB>spec). governs entries are
  # written before surface/surfacedir entries so the matching pass below
  # can give governs first-match priority per note (dedup is by insertion
  # order via !seen[], not sort -u, to preserve that priority).
  "$JQ" -r "$JQ_FLOW_ITEMS"'
    . as $r
    | ($r.governs | flow_items[]?) as $g
    | [$r.path, "governs", $g] | @tsv
  ' "$TMP/recs.ndjson" > "$TMP/pat.governs" 2>/dev/null || : > "$TMP/pat.governs"

  "$JQ" -r --arg pathre "$PATHRE" '
    . as $r
    | ($r.surface.entries // [])[]
    | .spath as $raw
    | select($raw != "")
    | select(($raw | contains("...")) | not)
    | select($raw | test($pathre))
    | ($raw | split(":")[0]) as $s
    | [$r.path, (if ($s | endswith("/")) then "surfacedir" else "surface" end), $s]
    | @tsv
  ' "$TMP/recs.ndjson" > "$TMP/pat.surface" 2>/dev/null || : > "$TMP/pat.surface"

  cat "$TMP/pat.governs" "$TMP/pat.surface" | awk '!seen[$0]++' > "$TMP/pat"

  # Symbols TSV (note<TAB>spath<TAB>ident), spath stripped of :suffix the
  # same way as above so it lines up with the touched-path column later.
  "$JQ" -r '
    . as $r
    | ($r.surface.entries // [])[]
    | select(.spath != "" and ((.spath | contains("...")) | not))
    | (.spath | split(":")[0]) as $s
    | (.syms // [])[] as $sym
    | [$r.path, $s, $sym]
    | @tsv
  ' "$TMP/recs.ndjson" > "$TMP/sym.raw" 2>/dev/null || : > "$TMP/sym.raw"

  awk -F'\t' "$AWK_SYM_IDENT"'
    NF >= 3 { id = sym_ident($3); if (id != "") print $1 "\t" $2 "\t" id }
  ' "$TMP/sym.raw" > "$TMP/sym"

  # Step 4: one git-log call over the whole range.
  git -C "$repo" log --first-parent --reverse --name-status -M \
    --format='%x00%H%x00%B%x00' "$marker..$tip" | tr '\0' '\001' > "$TMP/log"

  # Step 5: match touched paths against patterns. RS="\001" makes the log
  # a repeating (sha, body, name-status) cycle preceded by one artifact
  # empty record (from the format string's leading %x00); FNR (not NR)
  # drives the cycle so it stays aligned once we move past pat.tsv.
  awk -F'\t' "$AWK_GLOB2ERE"'
    NR==FNR {
      if (NF < 3) next
      patNote[++np] = $1; patKind[np] = $2; patSpec[np] = $3
      if ($2 == "governs") patEre[np] = glob2ere($3)
      next
    }
    FNR == 1 && $0 == "" { next }
    {
      role = (FNR - 2) % 3
      if (role < 0) role += 3
      if (role == 0) {
        curH = $0
        delete exempt
      } else if (role == 1) {
        m = split($0, BL, "\n")
        for (i = 1; i <= m; i++) {
          if (BL[i] ~ /^Vault-Exempt:[ \t]+[^ \t]+[ \t]+[^ \t]/) {
            t = BL[i]
            sub(/^Vault-Exempt:[ \t]+/, "", t)
            split(t, tok, /[ \t]+/)
            b = tok[1]
            sub(/\.md$/, "", b)
            exempt[b] = 1
          }
        }
      } else {
        delete touched
        delete donenote
        m = split($0, L, "\n")
        for (i = 1; i <= m; i++) {
          nf = split(L[i], F, "\t")
          if (nf < 2) continue
          p = F[2]
          if (index(p, "docs/project-knowledge/") == 1) {
            touched[substr(p, length("docs/project-knowledge/") + 1)] = 1
          }
        }
        for (i = 1; i <= m; i++) {
          nf = split(L[i], F, "\t")
          if (nf < 2) continue
          status = substr(F[1], 1, 1)
          p = F[2]
          newp = (nf >= 3 ? F[3] : "")
          for (k = 1; k <= np; k++) {
            note = patNote[k]; kind = patKind[k]; spec = patSpec[k]
            bn = note
            sub(/\.md$/, "", bn); sub(/^.*\//, "", bn)
            if (bn in exempt) continue
            if (note in touched) continue
            key = note SUBSEP p
            if (key in donenote) continue
            ok = 0
            if (kind == "governs") { if (p ~ patEre[k]) ok = 1 }
            else if (kind == "surface") { if (p == spec) ok = 1 }
            else { if (index(p, spec) == 1) ok = 1 }
            if (ok) {
              donenote[key] = 1
              print curH "\t" note "\t" p "\t" status "\t" newp "\t" kind ":" spec
            }
          }
        }
      }
    }
  ' "$TMP/pat" RS=$'\001' "$TMP/log" > "$TMP/matches.tsv"

  if [ ! -s "$TMP/matches.tsv" ]; then
    printf '%s\n' "$tip" > "$state/marker.tmp"
    mv "$state/marker.tmp" "$marker_file"
    exit 0
  fi

  # Step 5.5: narrow surface/surfacedir matches. A D/R status always flags
  # (the note's claimed path disappeared or moved); any other status
  # (typically M) only flags when at least one of the note's declared
  # symbols for that exact path is gone at tip -- computed here, before
  # the merge, so a dropped match never reaches flags.jsonl. governs
  # matches stay unconditional regardless of status.
  awk -F'\t' '
    { kind = $6; sub(/:.*/, "", kind)
      if (kind == "governs" || $4 == "D" || $4 == "R") next
      key = $2 SUBSEP $3
      if (!(key in seen)) { seen[key] = 1; print $2 "\t" $3 }
    }
  ' "$TMP/matches.tsv" > "$TMP/probe.pairs"

  : > "$TMP/probe.todo"
  if [ -s "$TMP/probe.pairs" ]; then
    awk -F'\t' '
      NR==FNR { key = $1 SUBSEP $2; idents[key] = (key in idents ? idents[key] "," $3 : $3); next }
      { key = $1 SUBSEP $2; if (key in idents) print $1 "\t" $2 "\t" idents[key] }
    ' "$TMP/sym" "$TMP/probe.pairs" > "$TMP/probe.todo"
  fi

  probe_vanished "$repo" "$tip" "$TMP/probe.todo" "$TMP/probe.out"
  awk -F'\t' '$3 != "" { print $1 "\t" $2 }' "$TMP/probe.out" > "$TMP/probe.vanished.tsv"

  awk -F'\t' '
    NR==FNR { ok[$1 SUBSEP $2] = 1; next }
    { kind = $6; sub(/:.*/, "", kind)
      if (kind == "governs" || $4 == "D" || $4 == "R" || (($2 SUBSEP $3) in ok)) print
    }
  ' "$TMP/probe.vanished.tsv" "$TMP/matches.tsv" > "$TMP/matches.filtered.tsv"
  mv "$TMP/matches.filtered.tsv" "$TMP/matches.tsv"

  if [ ! -s "$TMP/matches.tsv" ]; then
    printf '%s\n' "$tip" > "$state/marker.tmp"
    mv "$state/marker.tmp" "$marker_file"
    exit 0
  fi

  # Step 6: merge into flags.jsonl (jq handles the id-uniqueness counter
  # and the open-flag merge in one pass; see comments inside the program).
  cat > "$TMP/merge.jq" <<'JQEOF'
def basename: split("/") | last | sub("\\.md$"; "");
(split("\n") | map(select(length>0)) | map(split("\t"))
 | map({sha:.[0], note:.[1], path:.[2], status:.[3],
        newpath:(.[4] // ""), via:(.[5] // "")})
) as $rows
| ($rows | group_by(.note + "\u0000" + .path)) as $groups
| ($groups | map({
     key: (.[0].note + "\u0000" + .[0].path),
     note: .[0].note,
     path: .[0].path,
     via: .[0].via,
     shas: (map(.sha) | reduce .[] as $s ([]; if index($s) then . else . + [$s] end)),
     change: (.[-1].status),
     renamed_to: (if (.[-1].status | startswith("R")) then .[-1].newpath else null end)
   })) as $gmeta
| $F as $existing
| ($existing | map(select(.status=="open")) | map(.note + "\u0000" + .path)) as $openKeys
| (reduce $existing[] as $rec
     ({updated: [], touched: []};
      ($rec.note + "\u0000" + $rec.path) as $k
      | (($gmeta | map(select(.key == $k)) | .[0]) // null) as $m
      | if ($rec.status == "open" and $m != null) then
          ($rec
           | .commits = ((.commits + $m.shas) | reduce .[] as $s ([]; if index($s) then . else . + [$s] end))
           | .change = $m.change
           | .renamed_to = $m.renamed_to) as $newrec
          | {updated: (.updated + [$newrec]),
             touched: (.touched + [{id: $rec.id, note: $rec.note, path: $rec.path, renamed_to: $m.renamed_to}])}
        else
          {updated: (.updated + [$rec]), touched: .touched}
        end
     )) as $passB
| ($gmeta | map(. as $g | select(($openKeys | index($g.key)) == null))) as $newGroups
| ($existing | reduce .[] as $r ({}; .[($r.note|basename)] = ((.[($r.note|basename)] // 0) + 1))) as $baseCounts0
| (reduce $newGroups[] as $g
     ({counts: $baseCounts0, out: [], touched: []};
      ($g.note | basename) as $bn
      | ((.counts[$bn] // 0) + 1) as $n
      | ($g.shas[0][0:7]) as $sha7
      | ({id: ($sha7 + "-" + $bn + "-" + ($n|tostring)),
          status: "open", opened: $today, commits: $g.shas,
          note: $g.note, via: $g.via, path: $g.path,
          change: $g.change, renamed_to: $g.renamed_to,
          vanished: [], cleared_by: null, reason: null}) as $rec
      | {counts: (.counts + {($bn): $n}),
         out: (.out + [$rec]),
         touched: (.touched + [{id: $rec.id, note: $rec.note, path: $rec.path, renamed_to: $rec.renamed_to}])}
     )) as $passC
| {flags: ($passB.updated + $passC.out), touched: ($passB.touched + $passC.touched)}
JQEOF

  "$JQ" -R -s -f "$TMP/merge.jq" --arg today "$TODAY" --slurpfile F "$flags_file" \
    "$TMP/matches.tsv" > "$TMP/merged.json"

  "$JQ" -c '.flags[]' "$TMP/merged.json" > "$TMP/flags.stage1.ndjson"
  "$JQ" -r '.touched[] | [.id, .note, .path, (.renamed_to // "")] | @tsv' "$TMP/merged.json" > "$TMP/touched.tsv"

  # Step 6 (cont.): $TMP/todo lines only for (note,path) pairs that have
  # declared symbols, so step 7 only probes targets worth probing.
  awk -F'\t' '
    NR==FNR { key = $1 SUBSEP $2; idents[key] = (key in idents ? idents[key] "," $3 : $3); next }
    { key = $2 SUBSEP $3
      if (key in idents) {
        target = ($4 != "" ? $4 : $3)
        print $1 "\t" target "\t" idents[key]
      }
    }
  ' "$TMP/sym" "$TMP/touched.tsv" > "$TMP/todo"

  # Step 7: vanished-symbol probe via git grep at TIP (one batched call).
  probe_vanished "$repo" "$tip" "$TMP/todo" "$TMP/probe2.out"
  cut -f1,3 "$TMP/probe2.out" > "$TMP/vanished.tsv"

  "$JQ" -R -s '
    split("\n") | map(select(length>0)) | map(split("\t"))
    | map({(.[0]): ((.[1] // "") | split(",") | map(select(length>0)))})
    | add // {}
  ' "$TMP/vanished.tsv" > "$TMP/vanished.json"

  "$JQ" -c --slurpfile VJ "$TMP/vanished.json" '
    ($VJ[0]) as $v
    | if ($v[.id] != null) then .vanished = $v[.id] else . end
  ' "$TMP/flags.stage1.ndjson" > "$state/flags.jsonl.tmp"
  mv "$state/flags.jsonl.tmp" "$flags_file"

  # Marker written last: a crash before this point simply re-scans next time.
  printf '%s\n' "$tip" > "$state/marker.tmp"
  mv "$state/marker.tmp" "$marker_file"
  exit 0
}

cmd_list() {
  local repo json=0 state flags_file
  repo=$(require_repo "${1:-}")
  shift || usage
  while [ $# -gt 0 ]; do
    case "$1" in
      --json) json=1 ;;
      *) usage ;;
    esac
    shift
  done
  state=$(state_dir "$repo")
  flags_file="$state/flags.jsonl"
  [ -f "$flags_file" ] || { mkdir -p "$state"; : > "$flags_file"; }

  if [ "$json" -eq 1 ]; then
    "$JQ" -s '[.[] | select(.status == "open")]' "$flags_file"
  else
    "$JQ" -r 'select(.status == "open") | "OPEN \(.id) \(.note) \(.path) \(.change) via=\(.via) commits=\(.commits | length) vanished=\(.vanished | join(","))"' "$flags_file" \
      | sort -k2,2
    echo "vault-drift: $("$JQ" -s '[.[] | select(.status=="open")] | length' "$flags_file") open"
  fi
  exit 0
}

cmd_clear() {
  [ $# -eq 3 ] || usage
  local repo="$1" id="$2" reason="$3" state flags_file sha
  repo=$(require_repo "$repo")
  [ -n "$reason" ] || usage
  state=$(state_dir "$repo")
  flags_file="$state/flags.jsonl"
  [ -f "$flags_file" ] || { echo "vault-drift: no flags recorded for $repo" >&2; exit 1; }
  sha=$(git -C "$repo" rev-parse HEAD)

  "$JQ" -c --arg id "$id" --arg sha "$sha" --arg r "$reason" '
    if .id == $id and .status == "open"
    then .status = "cleared" | .cleared_by = $sha | .reason = $r
    else . end
  ' "$flags_file" > "$state/flags.jsonl.tmp"

  if cmp -s "$flags_file" "$state/flags.jsonl.tmp"; then
    rm -f "$state/flags.jsonl.tmp"
    exit 1
  fi
  mv "$state/flags.jsonl.tmp" "$flags_file"
  echo "cleared $id"
  exit 0
}

cmd_suggest_governs() {
  local note="${1:-}" notedir reporoot
  [ -n "$note" ] && [ -f "$note" ] || usage
  notedir=$(cd "$(dirname "$note")" && pwd -P)
  reporoot=$(git -C "$notedir" rev-parse --show-toplevel) || usage

  grep -oE '`[^`]+`' "$note" | sed -e 's/^`//' -e 's/`$//' > "$TMP/spans.raw"

  : > "$TMP/spans.ok"
  while IFS= read -r s; do
    [ -n "$s" ] || continue
    case "$s" in *'...'*) continue ;; esac
    [[ "$s" =~ $PATHRE ]] || continue
    s=${s%%:*}
    case "$s" in docs/*|tests/*) continue ;; esac
    if git -C "$reporoot" ls-files --error-unmatch -- "$s" >/dev/null 2>&1 || [ -e "$reporoot/$s" ]; then
      printf '%s\n' "$s" >> "$TMP/spans.ok"
    fi
  done < "$TMP/spans.raw"
  sort -u -o "$TMP/spans.ok" "$TMP/spans.ok"

  awk -F/ '
    { path = $0
      n = split(path, parts, "/")
      dir = parts[1]
      for (i = 2; i < n; i++) dir = dir "/" parts[i]
      count[dir]++
      list[dir] = (dir in seen ? list[dir] "\n" path : path)
      seen[dir] = 1
    }
    END {
      for (d in count) {
        if (count[d] >= 3) print d "/*"
        else print list[d]
      }
    }
  ' "$TMP/spans.ok" | sort -u
  exit 0
}

case "${1:-}" in
  --list) shift; cmd_list "$@" ;;
  --clear) shift; cmd_clear "$@" ;;
  --suggest-governs) shift; cmd_suggest_governs "$@" ;;
  --scan) shift; cmd_scan "$@" ;;
  ""|--*) usage ;;
  *) cmd_scan "$@" ;;
esac
