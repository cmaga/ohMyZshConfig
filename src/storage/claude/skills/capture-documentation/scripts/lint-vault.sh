#!/usr/bin/env bash
# lint-vault.sh -- rules-as-data linter for docs/project-knowledge vaults.
#
#   lint-vault.sh [--format text|json] VAULT_ROOT [file ...]   whole vault, or only these notes
#   lint-vault.sh [--format text|json] --changed VAULT_ROOT    scope = git change set vs HEAD
#   lint-vault.sh --hook                                       SubagentStop JSON on stdin; exit 0 or 2
#   lint-vault.sh --next-adr VAULT_ROOT                        prints ADR-NNN, exit 0
#
# Exit: 0 clean, 1 FAIL present (--changed/--hook: any *introduced* FAIL), 2 usage/internal error.
#
# Rules live in vault-schema.json (deep-merged with an optional <vault>/.vault-lint.json override
# via `jq -s '.[0] * .[1]'` -- array-valued keys REPLACE wholesale on override, they do not
# concatenate; that is jq's native `*` behaviour and is intentional here, not a bug).
#
# Four passes: (1) awk turns each note into one NDJSON record (frontmatter, headings, links,
# surface entries, byte/line-length counters); (2) shell greps the sibling repo to check
# "## Reusable surface" claims still resolve; (2b) shell asks git whether the code region behind
# a surface claim moved since the note last touched it (only when the scope is explicit -- a file
# list or --changed/--hook -- never in a bare whole-vault run); (3) jq applies the schema to
# produce raw findings, independently per class (an unknown bucket no longer suppresses the other
# checks -- orphan/size/basename findings still fire even when BUCKET_UNKNOWN also fires); (4) jq
# applies the exceptions allowlist and, for --changed/--hook, diffs against a HEAD-shadow tree to
# separate introduced findings from pre-existing DRIFT.

set -u

JQ=${JQ:-$(command -v jq || echo /usr/bin/jq)}
export LC_ALL=C

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUARD="$HERE/../../../hooks/guard-vault-write.sh"

json_esc() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

usage() {
  cat >&2 <<'EOF'
usage: lint-vault.sh [--format text|json] VAULT_ROOT [file ...]
       lint-vault.sh [--format text|json] --changed VAULT_ROOT
       lint-vault.sh --hook
       lint-vault.sh --next-adr VAULT_ROOT
EOF
}

# ---------------------------------------------------------------------------
# Pass 1 (awk): one note -> one NDJSON record. Invoked as:
#   awk -v root="$tree/" -v q="'" -v DASH=" — " -v PATHRE="..." "$PASS1_AWK" file1 file2 ...
# DASH is the real em-dash (U+2014) surrounded by spaces, matching the bullet
# format buckets.md documents (`Symbol` — `path` — purpose) -- not an ASCII
# "--". index()/length() below are byte-offset operations under LC_ALL=C, but
# that is safe here: the UTF-8 encoding of a single codepoint never occurs as
# a sub-sequence of a different codepoint's bytes, so byte-wise index() still
# finds the exact multi-byte separator.
# The CRLF strip runs as the very first rule (program order) so every later
# rule, including the FNR==1 dispatch, sees LF-only text.
# ---------------------------------------------------------------------------
read -r -d '' PASS1_AWK <<'AWKEOF' || true
{ sub(/\r$/, "", $0) }
function esc(s) {
  gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s); gsub(/\t/, " ", s)
  gsub(/[\001-\010\013-\037]/, " ", s)
  return s
}
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function add(list, item) { return list == "" ? item : list "," item }
function pos(n, t) { return sprintf("{\"line\":%d,\"text\":\"%s\"}", n, esc(t)) }
function nocode(s,   o) {
  o = ""
  while (match(s, /`[^`]*`/)) {
    if (substr(s, RSTART, RLENGTH) !~ /\[\[/) o = o substr(s, 1, RSTART - 1) substr(s, RSTART, RLENGTH)
    else o = o substr(s, 1, RSTART - 1)
    s = substr(s, RSTART + RLENGTH)
  }
  return o s
}
function spans(s, want,   o, sp) {
  o = ""
  while (match(s, /`[^`]+`/)) {
    sp = substr(s, RSTART + 1, RLENGTH - 2); s = substr(s, RSTART + RLENGTH)
    if (want == "path" && sp ~ PATHRE) return sp
    if (want == "syms" && sp !~ PATHRE) o = add(o, "\"" esc(sp) "\"")
  }
  return want == "path" ? "" : o
}
function emit(   d, hd, rest, p) {
  if (ent == "") return
  if (ehead ~ /^[-*][ \t]*[Rr]emoved[ \t]*:/) { ent = ""; return }
  d = index(ehead, DASH); hd = d ? substr(ehead, 1, d - 1) : ehead
  d = index(ent, DASH); rest = d ? substr(ent, d + length(DASH)) : ""
  d = index(rest, DASH); if (d) rest = substr(rest, 1, d - 1)
  p = spans(hd, "path"); if (p == "") p = spans(rest, "path")
  if (p == "" && ent ~ /same file/) p = lastp
  if (p != "") lastp = p
  sent = add(sent, sprintf("{\"line\":%d,\"syms\":[%s],\"spath\":\"%s\"}", eline, spans(hd, "syms"), esc(p)))
  ent = ""
}
function flush() {
  if (path == "") return
  emit()
  printf "{\"path\":\"%s\",\"bytes\":%d,\"maxline\":%d,\"maxline_no\":%d,\"fm_open\":%s,\"fm_close\":%s,\"fm\":{%s},\"fm_line\":{%s},\"fm_bad\":[%s],\"fm_dup\":[%s],", \
    esc(path), bytes, maxline, maxline_no, (fmo ? "true" : "false"), (fmc ? "true" : "false"), fm, fml, fmbad, fmdup
  printf "\"h1\":%s,\"first\":%s,\"banner\":%s,\"h2\":[%s],\"heads\":[%s],\"links\":[%s],", \
    (h1 == "" ? "null" : h1), (first == "" ? "null" : first), (banner == "" ? "null" : banner), h2, heads, links
  printf "\"surface\":%s}\n", (sline ? sprintf("{\"line\":%d,\"none\":%s,\"entries\":[%s]}", sline, (snone ? "true" : "false"), sent) : "null")
}
FNR == 1 {
  flush()
  path = substr(FILENAME, length(root) + 1)
  fmo = fmc = infm = fence = sline = snone = insurf = eline = 0
  ent = lastp = ""
  fm = fml = fmbad = fmdup = h1 = first = banner = h2 = heads = links = sent = ""
  bytes = 0; maxline = 0; maxline_no = 0
  delete seen
}
{
  bytes += length($0) + 1
  if (length($0) > maxline) { maxline = length($0); maxline_no = FNR }
}
FNR == 1 && $0 == "---" { fmo = infm = 1; next }
infm {
  if ($0 == "---") { infm = 0; fmc = 1; next }
  if ($0 ~ /^# /) { infm = 0 }
  else {
    if ($0 ~ /^[ \t]*$/ || $0 ~ /^#/) next
    if (match($0, /^[a-z_][a-z0-9_]*:/)) {
      k = substr($0, 1, RLENGTH - 1); v = trim(substr($0, RLENGTH + 1))
      if (v ~ /^[|>]/ || (v ~ /^\[/ && v !~ /^\[\[/ && !(k == "aliases" && v ~ /^\[.*\]$/)) || v ~ /^[{&*!]/) { fmbad = add(fmbad, pos(FNR, $0)); next }
      if (v ~ /^".*"$/ || (length(v) > 1 && substr(v, 1, 1) == q && substr(v, length(v), 1) == q)) v = substr(v, 2, length(v) - 2)
      if (k in seen) fmdup = add(fmdup, "\"" k "\"")
      seen[k] = 1
      fm = add(fm, "\"" k "\":\"" esc(v) "\""); fml = add(fml, "\"" k "\":" FNR)
      if (v ~ /\[\[/) { l = v; while (match(l, /\[\[[^]]+\]\]/)) { links = add(links, sprintf("{\"line\":%d,\"wiki\":\"%s\",\"fm\":true}", FNR, esc(substr(l, RSTART + 2, RLENGTH - 4)))); l = substr(l, RSTART + RLENGTH) } }
    } else fmbad = add(fmbad, pos(FNR, $0))
    next
  }
}
/^[ \t]*(```|~~~)/ { fence = !fence; next }
fence { next }
{
  line = $0
  if (match(line, /^#+ /)) {
    lvl = RLENGTH - 1; t = trim(substr(line, RLENGTH + 1)); sub(/[ #]+$/, "", t)
    heads = add(heads, "\"" esc(t) "\"")
    if (lvl == 1 && h1 == "") h1 = pos(FNR, t)
    if (lvl == 2) h2 = add(h2, pos(FNR, t))
    if (lvl <= 2) { emit(); insurf = (lvl == 2 && t ~ /^Reusable surface/) }
    if (insurf) sline = FNR
    if (lvl == 1) next
  }
  if (first == "" && line !~ /^[ \t]*$/) first = pos(FNR, line)
  if (banner == "" && line ~ /^> *Status:/) banner = pos(FNR, line)
  if (insurf && line !~ /^#/) {
    if (line ~ /^[-*]?[ \t]*None/) snone = 1
    else if (line ~ /^[-*] /) { emit(); ent = ehead = line; eline = FNR }
    else if (ent != "" && line ~ /^[ \t]+[^ \t]/) ent = ent " " line
    else emit()
  }
  l = nocode(line)
  while (match(l, /\[\[[^]]+\]\]/)) { links = add(links, sprintf("{\"line\":%d,\"wiki\":\"%s\"}", FNR, esc(substr(l, RSTART + 2, RLENGTH - 4)))); l = substr(l, RSTART + RLENGTH) }
  l = line; gsub(/`[^`]*`/, "", l)
  while (match(l, /\]\([^) ]+\.md(#[^)]*)?\)/)) { t = substr(l, RSTART + 2, RLENGTH - 3); if (t !~ /^[a-z]+:/) links = add(links, sprintf("{\"line\":%d,\"md\":\"%s\"}", FNR, esc(t))); l = substr(l, RSTART + RLENGTH) }
}
END { flush() }
AWKEOF

# ---------------------------------------------------------------------------
# Pass 2 (shell+grep): checks each "## Reusable surface" claim against $REPO.
# Escalating probe: (1) full literal span, (2) extracted identifier at a word
# boundary, (3) Makefile-target form `^name:`. Only after all three miss is
# the entry flagged as a bad symbol. scopef is always a real file holding a
# JSON array (empty array = unrestricted).
# ---------------------------------------------------------------------------
pass2() {
  local recs="$1" repo="$2" scopef="$3" out="$4"
  "$JQ" -r --slurpfile scope "$scopef" '
    ($scope[0] // []) as $sc |
    .path as $p | select(($sc|length) == 0 or ($sc|index($p))) |
    .surface.entries[]? | [$p, .line, .spath, (.syms | join(";;"))] | join("\u001f")
  ' "$recs" 2>/dev/null |
  while IFS=$'\x1f' read -r p ln sp syms; do
    emit_surf() { printf '%s\037%s\037%s\037%s\037%s\n' "$p" "$ln" "$1" "$sp" "$2"; }
    if [ -z "$sp" ]; then
      [ -n "$syms" ] && emit_surf "${syms%%;;*}" nopath
      continue
    fi
    target="$repo/${sp%%:*}"
    if [ ! -e "$target" ]; then emit_surf "${syms%%;;*}" path; continue; fi
    while IFS= read -r sym; do
      [ -n "$sym" ] || continue
      case "$sym" in */*) continue ;; esac
      s=${sym%%(*}; s=${s##*.}; s=${s##*:}; s=${s%% *}
      re1='^[A-Za-z_$][A-Za-z0-9_$-]*$'; re2='^[A-Za-z0-9_.-]+\.[a-z]{1,4}$'
      [[ $s =~ $re1 ]] || continue
      [[ $sym =~ $re2 ]] && continue
      st=symbol
      if grep -rqF -- "$sym" "$target" 2>/dev/null; then
        st=ok
      elif grep -rqwF -- "$s" "$target" 2>/dev/null; then
        st=ok
      elif grep -rqE -- "^$s:" "$target" 2>/dev/null; then
        st=ok
      fi
      emit_surf "$sym" "$st"
    done <<< "${syms//;;/$'\n'}"
  done | "$JQ" -R -c 'split("\u001f") | {path: .[0], line: (.[1] | tonumber), sym: .[2], spath: .[3], st: .[4]}' > "$out"
}

# ---------------------------------------------------------------------------
# Pass 2b (shell+git): SURFACE_REGION_CHANGED. Only meaningful with an
# explicit scope (file list, or the touched-notes list from --changed/--hook)
# -- scopef with an empty array yields zero output by construction below, so
# a bare whole-vault run never pays for this or reports it.
# ---------------------------------------------------------------------------
pass2b_region() {
  local recs="$1" repo="$2" relvault="$3" upto="$4" scopef="$5" out="$6"
  : > "$out"
  declare -A note_commit_cache prefilter_cache
  "$JQ" -r --slurpfile scope "$scopef" '
    ($scope[0] // []) as $sc |
    .path as $p | select(($sc|length) > 0 and ($sc|index($p))) |
    .surface.entries[]? | select(.spath != "") | .line as $ln |
    .syms[]? as $sym | [$p, $ln, $sym, .spath] | join("\u001f")
  ' "$recs" 2>/dev/null |
  while IFS=$'\x1f' read -r p ln sym sp; do
    spath="${sp%%:*}"
    nc="${note_commit_cache[$p]:-}"
    if [ -z "$nc" ]; then
      nc=$(git -C "$repo" log -1 --format=%H -- "$relvault/$p" 2>/dev/null)
      [ -z "$nc" ] && nc="__none__"
      note_commit_cache[$p]="$nc"
    fi
    [ "$nc" = "__none__" ] && continue
    ckey="$p"$'\x1f'"$spath"
    pf="${prefilter_cache[$ckey]:-}"
    if [ -z "$pf" ]; then
      if [ -n "$(git -C "$repo" log -1 "$nc..$upto" -- "$spath" 2>/dev/null)" ]; then pf="changed"; else pf="same"; fi
      prefilter_cache[$ckey]="$pf"
    fi
    [ "$pf" = "same" ] && continue
    esym=$(printf '%s' "$sym" | sed 's/[.[\*^$]/\\&/g')
    hit=$(git -C "$repo" log --format=%H -L ":$esym:$spath" "$nc..$upto" 2>/dev/null)
    rc=$?
    if [ "$rc" -eq 128 ]; then
      hit=$(git -C "$repo" log -1 -S"$sym" "$nc..$upto" -- "$spath" 2>/dev/null)
    fi
    if [ -n "$hit" ]; then
      printf '{"code":"SURFACE_REGION_CHANGED","path":"%s","line":%s,"msg":"region around %s in %s changed since the note last touched it"}\n' \
        "$(json_esc "$p")" "$ln" "$(json_esc "$sym")" "$(json_esc "$spath")"
    fi
  done > "$out"
}

# ---------------------------------------------------------------------------
# Content-class findings via guard-vault-write.sh --scan (shared protocol).
# One vault-wide GUARD_ABSENT/info finding if the script is missing/unreadable.
# ---------------------------------------------------------------------------
guard_scan() {
  local vault="$1" recs="$2" scopef="$3" out="$4"
  if [ ! -r "$GUARD" ]; then
    printf '{"code":"GUARD_ABSENT","path":".","line":0,"msg":"guard-vault-write.sh not found"}\n' > "$out"
    return 0
  fi
  local list
  list=$("$JQ" -r --slurpfile scope "$scopef" '
    ($scope[0] // []) as $sc | .path as $p | select(($sc|length) == 0 or ($sc|index($p))) | $p
  ' "$recs" 2>/dev/null)
  if [ -z "$list" ]; then : > "$out"; return 0; fi
  local absfiles=()
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    absfiles+=("$vault/$rel")
  done <<< "$list"
  if [ "${#absfiles[@]}" -eq 0 ]; then : > "$out"; return 0; fi
  bash "$GUARD" --scan "${absfiles[@]}" 2>/dev/null |
  awk -F'\t' -v vroot="$vault/" '
    function esc(s) { gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s); return s }
    {
      f = $2
      if (index(f, vroot) == 1) f = substr(f, length(vroot) + 1)
      printf "{\"code\":\"%s\",\"path\":\"%s\",\"line\":%s,\"msg\":\"guard: %s\"}\n", esc($1), esc(f), ($3 + 0), esc($4)
    }
  ' > "$out"
}

# ---------------------------------------------------------------------------
# Pass 3 (jq): schema + parsed notes -> raw findings with sev/fix/hint
# attached. $R/$S/$REG/$G are NDJSON slurps (arrays already); $schema is a
# single-object file, unwrapped via $schema[0].
# ---------------------------------------------------------------------------
read -r -d '' PASS3_JQ <<'JQEOF' || true
$schema[0] as $sc |
def f($r; $c; $line; $msg): {code: $c, path: $r.path, line: $line, msg: $msg};
def bucket: if test("/") then split("/")[0] else "" end;
def base: split("/")[-1] | rtrimstr(".md");
def norm: ascii_downcase | gsub("-"; " ") | gsub("[^a-z0-9 ]"; "") | gsub(" +"; " ") | ltrimstr(" ") | rtrimstr(" ");
def normpath: reduce (split("/")[]) as $s ([]; if $s == ".." then .[:-1] elif ($s == "." or $s == "") then . else . + [$s] end) | join("/");
($R | map({key: .path, value: .}) | from_entries) as $byPath |
($R | group_by(.path | base) | map({key: (.[0].path | base), value: map(.path)}) | from_entries) as $byBase |
def resolve($src):
  if .md then
    (.md | split("#")) as $p
    | ((($src | split("/")[:-1] | join("/")) + "/" + $p[0]) | normpath) as $t
    | {anchor: ($p[1] // ""), raw: .md} + (if $byPath[$t] then {kind: "note", to: $t} else {kind: "missing"} end)
  else
    (.wiki | split("|")[0] | rtrimstr("\\")) as $x
    | ($x | split("#")) as $p
    | ($p[0] | ltrimstr("./") | rtrimstr(".md") | ltrimstr(" ") | rtrimstr(" ")) as $n
    | {anchor: ($p[1:] | join("#")), raw: .wiki} +
      (if $n == "" then {kind: "note", to: $src}
       elif ($n | test("/")) then (if $byPath[$n + ".md"] then {kind: "note", to: ($n + ".md")} else {kind: "missing"} end)
       elif (($byBase[$n] // []) | length) == 1 then {kind: "note", to: $byBase[$n][0]}
       elif (($byBase[$n] // []) | length) > 1 then {kind: "ambiguous", cands: $byBase[$n]}
       elif ($n | test("^ADR-[0-9]+$")) and (([$R[].path | select(startswith("decisions/" + $n + "-"))]) | length) == 1
         then {kind: "note", to: (([$R[].path | select(startswith("decisions/" + $n + "-"))])[0])}
       elif ($n | test($sc.ticket_pattern)) then {kind: "ticket"}
       else {kind: "missing"} end)
  end;
[ $R[] | . as $r | .links[] | . + (resolve($r.path)) | .src = $r.path ] as $L |
($L | map(select(.kind == "note" and .to != .src)) | group_by(.to) | map({key: .[0].to, value: (map(.src) | unique)}) | from_entries) as $inbound |
($L | group_by(.src) | map({key: .[0].src, value: .}) | from_entries) as $Lby |
($R | map(.path as $p | .surface.entries[]? | .line as $ln | .syms[]? | {sym: ., path: $p, line: $ln})) as $allSurf |
($allSurf | group_by(.sym) | map(select((map(.path) | unique | length) > 1)) | flatten) as $dupSurf |
($R | map(select($sc.hubs[.path] == null)) | map({path: .path, bkt: (.path | bucket), bs: (.path | base)})
   | group_by(.bs) | map(select((map(.bkt) | unique | length) > 1)) | flatten | map(.path)) as $dupBasenamePaths |
($R | map(select((.path | bucket) == "decisions")) | map({path: .path, n: (.path | split("/")[-1] | capture("^ADR-(?<n>[0-9]{3})-").n)})
   | group_by(.n) | map(select(length > 1))) as $dupAdrGroups |
($R | map(.bytes) | add) as $totalBytes |
(
  $R[] | . as $r | ($r.path | bucket) as $b | ($r.path | split("/")[-1]) as $file |
  ($sc.hubs[$r.path]) as $hub | ($sc.buckets[$b]) as $bs |
  ([ ($Lby[$r.path] // [])[] | select(.kind == "note" and .to != $r.path) ] | length) as $outc |
  (($inbound[$r.path] // [])) as $inb |
  ([$inb[] | select($sc.hubs[.] == null)] | length) as $inbNonHub |

  (if $hub == null and $bs == null then f($r; "BUCKET_UNKNOWN"; 1; "bucket \"\($b)\" not in schema") else empty end),

  (if $hub == null and $bs != null then
    (if ($r.fm_open | not) then f($r; "FM_MISSING_OPEN"; 1; "no frontmatter") else empty end),
    (if $r.fm_open and ($r.fm_close | not) then f($r; "FM_MISSING_CLOSE"; 1; "frontmatter never closed") else empty end),
    ($r.fm_bad[] | f($r; "FM_UNSUPPORTED_SYNTAX"; .line; .text)),
    ($r.fm_dup[] | f($r; "FM_DUPLICATE_KEY"; 1; .)),
    (if $r.fm_open then
      ($bs.required[] | select(($r.fm[.] // "") == "") | f($r; "FIELD_REQUIRED"; 1; "missing \(.)")),
      ($r.fm | keys[] | select(. as $k | (($bs.required + $bs.optional) + ($sc.optional_global // [])) | index($k) | not) | f($r; "FIELD_UNKNOWN"; ($r.fm_line[.] // 1); .)),
      (if $r.fm.type and $r.fm.type != $bs.type then f($r; "TYPE_BUCKET_MISMATCH"; ($r.fm_line.type // 1); "type \($r.fm.type) in \($b)/ (expected \($bs.type))") else empty end),
      (if $r.fm.status and ($sc.status | index($r.fm.status) | not) then f($r; "ENUM_INVALID"; ($r.fm_line.status // 1); "status \($r.fm.status)")
       elif $r.fm.status and $bs.statuses and ($bs.statuses | index($r.fm.status) | not) then f($r; "STATUS_UNEXPECTED"; ($r.fm_line.status // 1); "status \($r.fm.status) in \($b)/")
       else empty end),
      (($bs.enums // {}) | to_entries[] | . as $e | select($r.fm[$e.key] and (($e.value | index($r.fm[$e.key])) | not)) | f($r; "ENUM_INVALID"; ($r.fm_line[$e.key] // 1); "\($e.key) \($r.fm[$e.key])")),
      (if $r.fm.created then
         (if ($r.fm.created | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$") | not) or ((try (($r.fm.created + "T00:00:00Z") | fromdateiso8601 | strftime("%Y-%m-%d")) catch "") != $r.fm.created)
          then f($r; "DATE_INVALID"; ($r.fm_line.created // 1); $r.fm.created)
          elif $r.fm.created > $today then f($r; "DATE_FUTURE"; ($r.fm_line.created // 1); $r.fm.created)
          else empty end)
       else empty end),
      (if $r.fm.status == "superseded" and (($r.fm.superseded_by // "") == "") then f($r; "SUPERSEDED_BY_REQUIRED"; ($r.fm_line.status // 1); "superseded without superseded_by") else empty end),
      (if ($r.fm.superseded_by // "") != "" then
         (if $r.fm.status != "superseded" then f($r; "SUPERSEDED_BY_STRAY"; ($r.fm_line.superseded_by // 1); "status is \($r.fm.status)") else empty end),
         (if ($r.fm.superseded_by | test("^\\[\\[[^]]+\\]\\]$") | not) then f($r; "SUPERSEDED_BY_FORMAT"; ($r.fm_line.superseded_by // 1); $r.fm.superseded_by)
          else (([ ($Lby[$r.path] // [])[] | select(.fm) ])[0] as $sl | if $sl and $sl.kind != "note" then f($r; "SUPERSEDED_BY_UNRESOLVED"; $sl.line; $sl.raw) else empty end)
          end)
       else empty end)
     else empty end),
    (if (($file | rtrimstr(".md")) | test($bs.filename) | not) then f($r; "FILENAME_PATTERN"; 1; $file) else empty end),
    (if $bs.sections then
      ($bs.sections as $want | [ $r.h2[].text ] as $have |
        ($want[] | select(. as $w | ($have | index($w)) | not) | f($r; "SECTION_MISSING"; 1; "## \(.)")),
        (([ $want[] | . as $w | ($have | index($w)) | select(. != null) ]) as $order | if $order != ($order | sort) then f($r; "SECTION_ORDER"; 1; "sections out of order") else empty end)),
      (([$file | capture("^(?<n>ADR-[0-9]{3})") | .n] | .[0]) as $n | if $n and (($r.h1.text // "") | startswith($n + ":") | not) then f($r; "ADR_TITLE_MISMATCH"; ($r.h1.line // 1); ($r.h1.text // "no H1")) else empty end)
     else empty end),
    (if $bs.banner then
      ($r.fm.status // "") as $st |
      (($r.banner.text // "") | sub("^> *Status: *"; "") | (split(" ")[0] // "") | ascii_upcase | rtrimstr(",")) as $kw |
      (if ($st == "superseded" or $st == "deprecated" or $st == "amended") and $r.banner == null then f($r; "BANNER_MISSING"; 1; "status \($st), no > Status: banner")
       elif $r.banner != null and $r.first.line != $r.banner.line then f($r; "BANNER_NOT_FIRST"; $r.banner.line; "banner is not the first body line")
       else empty end),
      (if $r.banner != null and (($st | ascii_upcase) != $kw) and ($st != "revisit" or $kw != "ACTIVE") then f($r; "BANNER_STATUS_MISMATCH"; $r.banner.line; "status \($st), banner says \($kw)") else empty end),
      (if $r.banner != null and $kw == "SUPERSEDED" and (($r.banner.text | test("\\[\\[")) | not) then f($r; "BANNER_NO_LINK"; $r.banner.line; $r.banner.text) else empty end),
      (if $st == "amended" and (([ $r.h2[].text | select(startswith("Amendment")) ]) | length) == 0 then f($r; "AMENDMENT_MISSING"; 1; "status amended, no ## Amendment") else empty end)
     else empty end),
    (if $bs.surface == "required" and $r.surface == null then f($r; "SURFACE_MISSING"; 1; "no ## Reusable surface") else empty end),
    (if $r.surface != null and $bs.surface == "forbidden" then f($r; "SURFACE_OUT_OF_SCOPE"; $r.surface.line; $b) else empty end),
    (if $r.surface != null and (($r.surface.entries | length) == 0) and ($r.surface.none | not) then f($r; "SURFACE_EMPTY"; $r.surface.line; "no entries, no None stanza") else empty end),
    (($S | map(select(.path == $r.path)))[]? | select(.st != "ok") | f($r; ({path: "SURFACE_PATH_MISSING", nopath: "SURFACE_ENTRY_FORMAT", symbol: "SURFACE_SYMBOL_MISSING"}[.st]); .line; "\(.sym) @ \(.spath)")),
    ($dupSurf[] | select(.path == $r.path) | f($r; "SURFACE_DUPLICATE_HOME"; .line; .sym)),
    ($REG | map(select(.path == $r.path))[] | f($r; "SURFACE_REGION_CHANGED"; .line; .msg)),
    (if $b == "decisions" then
       ($dupAdrGroups[]? | select(any(.[]; .path == $r.path)) | f($r; "ADR_NUMBER_DUPLICATE"; 1; "ADR number \((.[0].n)) used by \(([.[].path]) | join(", "))"))
     else empty end)
   else empty end),

  (if $hub == null and ($dupBasenamePaths | index($r.path)) then f($r; "BASENAME_DUPLICATE"; 1; "basename \($file | rtrimstr(".md")) also used in another bucket") else empty end),

  (if $hub == null then
     (if $outc == 0 then f($r; "ORPHAN_NO_OUTBOUND"; 1; "0 resolved outbound links") else empty end),
     (if ($inb | length) == 0 then f($r; "ORPHAN_NO_INBOUND"; 1; "0 notes link here")
      elif $inbNonHub == 0 then f($r; "ORPHAN_HUB_ONLY_INBOUND"; 1; "only a hub links here")
      else empty end)
   else empty end),

  (if $r.first == null then f($r; "EMPTY_NOTE"; 1; "no content after the H1") else empty end),

  (if $hub != null then
     (if $r.bytes > $sc.sizes.hub_fail then f($r; "SIZE_HUB_LIMIT"; 1; "hub is \($r.bytes) bytes (limit \($sc.sizes.hub_fail))") + {bytes: $r.bytes}
      elif $r.bytes > $sc.sizes.hub_warn then f($r; "SIZE_HUB"; 1; "hub is \($r.bytes) bytes")
      else empty end),
     (if $r.maxline > $sc.sizes.hub_line_fail then f($r; "SIZE_HUB_LINE_LIMIT"; $r.maxline_no; "line is \($r.maxline) chars (limit \($sc.sizes.hub_line_fail))") + {bytes: $r.maxline}
      elif $r.maxline > $sc.sizes.hub_line_warn then f($r; "SIZE_HUB_LINE"; $r.maxline_no; "line is \($r.maxline) chars")
      else empty end)
   else
     (if $r.bytes > $sc.sizes.note_fail then f($r; "SIZE_NOTE_LIMIT"; 1; "note is \($r.bytes) bytes (limit \($sc.sizes.note_fail))") + {bytes: $r.bytes}
      elif $r.bytes > $sc.sizes.note_warn then f($r; "SIZE_NOTE"; 1; "note is \($r.bytes) bytes")
      else empty end),
     (if $r.maxline > $sc.sizes.line_warn then f($r; "SIZE_LINE"; $r.maxline_no; "line is \($r.maxline) chars") else empty end)
   end)
),
(
  $L[] | select(.fm | not) | . as $l | {path: .src} as $r |
  if .kind == "missing" then f($r; "LINK_UNRESOLVED"; .line; .raw)
  elif .kind == "ambiguous" then f($r; "LINK_AMBIGUOUS"; .line; "\(.raw) -> \((.cands) | join(", "))")
  elif .kind == "note" and (.anchor != "") and (($byPath[.to].heads // []) | map(norm) | index($l.anchor | norm) | not) then f($r; "ANCHOR_UNRESOLVED"; .line; .raw)
  elif .kind == "note" and .md != null then f($r; "LINK_INTERNAL_MD"; .line; .raw)
  else empty end
),
( $G[]? | {code, path, line, msg} ),
(if $totalBytes and ($totalBytes > $sc.sizes.vault_info) then {code: "SIZE_VAULT", path: ".", line: 0, msg: "vault is \($totalBytes) bytes"} else empty end)
| . + (
    ($sc.buckets[(.path | bucket)] // {}) as $ovb |
    { sev: (
        if .code == "SIZE_NOTE_LIMIT" and $ovb.size_limit then $ovb.size_limit
        elif (.code == "ORPHAN_NO_INBOUND" or .code == "ORPHAN_NO_OUTBOUND" or .code == "ORPHAN_HUB_ONLY_INBOUND") and $ovb.orphan then $ovb.orphan
        else ($sc.classes[.code].severity // "fail") end
      ),
      fix: ($sc.classes[.code].fix // "manual"),
      hint: ($sc.classes[.code].hint // "")
    }
  )
| select(.sev != "off")
JQEOF

pass3() {
  local recs="$1" surf="$2" region="$3" guard="$4" schema="$5" out="$6"
  "$JQ" -n --slurpfile R "$recs" --slurpfile S "$surf" --slurpfile REG "$region" --slurpfile G "$guard" \
    --slurpfile schema "$schema" --arg today "$(date +%Y-%m-%d)" "$PASS3_JQ" > "$out"
}

# ---------------------------------------------------------------------------
# Orchestration: run passes 1-3 over one tree (current working tree, or a
# HEAD-shadow tree for --changed/--hook baselines). do_extras=0 skips
# region-changed and guard scanning entirely -- used only for baselines,
# since content/region checks are always reported as introduced, never diffed.
# ---------------------------------------------------------------------------
lint_tree() {
  local tree="$1" repo="$2" schema="$3" scopef="$4" do_extras="$5" out="$6"
  local pfx; pfx=$(mktemp "$TMP/lt.XXXXXX"); rm -f "$pfx"
  find "$tree" -name '*.md' -not -path '*/.obsidian/*' -not -path '*/.cache/*' -print0 | sort -z > "${pfx}.files0"
  if [ -s "${pfx}.files0" ]; then
    xargs -0 awk -v root="$tree/" -v q="'" -v DASH=" — " -v PATHRE="^[A-Za-z0-9_.@-]+/[^ ]*[A-Za-z0-9_]$" "$PASS1_AWK" < "${pfx}.files0" > "${pfx}.recs.ndjson"
  else
    : > "${pfx}.recs.ndjson"
  fi
  pass2 "${pfx}.recs.ndjson" "$repo" "$scopef" "${pfx}.surf.ndjson"
  if [ "$do_extras" = 1 ]; then
    pass2b_region "${pfx}.recs.ndjson" "$repo" "${tree#"$repo"/}" "HEAD" "$scopef" "${pfx}.region.ndjson"
    guard_scan "$tree" "${pfx}.recs.ndjson" "$scopef" "${pfx}.guard.ndjson"
  else
    : > "${pfx}.region.ndjson"
    : > "${pfx}.guard.ndjson"
  fi
  pass3 "${pfx}.recs.ndjson" "${pfx}.surf.ndjson" "${pfx}.region.ndjson" "${pfx}.guard.ndjson" "$schema" "$out"
  local rc=$?
  rm -f "${pfx}".*
  return $rc
}

merge_schema() {
  local vault="$1" out="$2"
  if [ -f "$vault/.vault-lint.json" ]; then
    "$JQ" -s '.[0] * .[1]' "$HERE/vault-schema.json" "$vault/.vault-lint.json" > "$out"
  else
    cp "$HERE/vault-schema.json" "$out"
  fi
}

load_exceptions() {
  local vault="$1" out="$2"
  if [ -f "$vault/.vault-lint-exceptions" ]; then
    sed 's/#.*//' "$vault/.vault-lint-exceptions" | awk 'NF>=2 {printf "{\"code\":\"%s\",\"path\":\"%s\"}\n", $1, $2}'
  fi | "$JQ" -s . > "$out"
}

note_count() {
  find "$1" -name '*.md' -not -path '*/.obsidian/*' -not -path '*/.cache/*' | wc -l | tr -d ' '
}

# ---------------------------------------------------------------------------
# Pass 4a: whole-vault / file-list assembly (no baseline, no drift).
# ---------------------------------------------------------------------------
assemble_whole() {
  local raw="$1" exc="$2" only="$3" n="$4" out="$5"
  "$JQ" -s --slurpfile exc "$exc" --slurpfile only "$only" --argjson n "$n" '
    $exc[0] as $exc | ($only[0] // []) as $only |
    def hit($e): .code == $e.code and (.path == $e.path or (($e.path | endswith("*")) and (.path | startswith($e.path | rtrimstr("*")))));
    . as $all |
    ([ $exc[] | . as $e | select(([ $all[] | select(hit($e)) ] | length) == 0) | {code: "EXCEPTION_STALE", path: ".vault-lint-exceptions", line: 0, msg: "\($e.code) \($e.path)", sev: "warn", fix: "auto", hint: "allowlist entry matches nothing; delete it"} ]) as $stale |
    (([ $all[] | . as $x | select((any($exc[]; . as $e | $x | hit($e))) | not) ]) + $stale) as $withStale |
    ($withStale | map(select(($only | length) == 0 or (.path as $p | $only | index($p)) or .code == "EXCEPTION_STALE"))
      | map(if (.code | endswith("_LIMIT")) and .sev == "fail" then . + {sev: "warn"} else . end)) as $scoped |
    ($scoped | sort_by([{fail:0,drift:1,warn:2,info:3}[.sev] // 9, .path, .line])) as $F |
    { ok: (([ $F[] | select(.sev == "fail") ] | length) == 0),
      notes: $n,
      fail: ([ $F[] | select(.sev == "fail") ] | length),
      warn: ([ $F[] | select(.sev == "warn") ] | length),
      drift: 0,
      by_code: ($F | group_by(.code) | map({key: .[0].code, value: length}) | from_entries),
      findings: $F }
  ' "$raw" > "$out"
}

do_whole() {
  local vault="$1" repo="$2" only="$3" pscope="$4" out="$5"
  local raw="$TMP/whole.raw.ndjson"
  lint_tree "$vault" "$repo" "$TMP/schema.json" "$pscope" 1 "$raw" || return 2
  assemble_whole "$raw" "$TMP/exc.json" "$only" "$(note_count "$vault")" "$out"
}

# ---------------------------------------------------------------------------
# --changed: touched = git diff --name-only HEAD, plus untracked (both
# scoped to the vault subtree); baseline is a shadow tree with every touched
# note restored (or removed, if new) to its HEAD content via `git show`.
# ---------------------------------------------------------------------------
build_baseline() {
  local vault="$1" repo="$2" relvault="$3" touched="$4" basedir="$5"
  rm -rf "$basedir"; mkdir -p "$basedir"
  ( cd "$vault" && find . -type f -not -path '*/.git/*' -print0 ) |
  while IFS= read -r -d '' rel; do
    rel="${rel#./}"
    mkdir -p "$basedir/$(dirname "$rel")"
    cp "$vault/$rel" "$basedir/$rel"
  done
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    local repoRel="$relvault/$rel"
    mkdir -p "$basedir/$(dirname "$rel")"
    if git -C "$repo" cat-file -e "HEAD:$repoRel" 2>/dev/null; then
      git -C "$repo" show "HEAD:$repoRel" > "$basedir/$rel" 2>/dev/null
    else
      rm -f "$basedir/$rel"
    fi
  done < "$touched"
}

assemble_changed() {
  local cur="$1" base="$2" exc="$3" n="$4" touched="$5" out="$6"
  "$JQ" -s --slurpfile B "$base" --slurpfile exc "$exc" --slurpfile touched "$touched" --argjson n "$n" '
    ($touched[0] // []) as $touched | $exc[0] as $exc | $B as $baseAll |
    def hit($e): .code == $e.code and (.path == $e.path or (($e.path | endswith("*")) and (.path | startswith($e.path | rtrimstr("*")))));
    (map(if (.code | endswith("_LIMIT")) and .sev == "fail" then
           (. as $x | ([ $baseAll[] | select(.code == $x.code and .path == $x.path) ]) as $b |
            if ($b | length) == 0 then $x
            elif ($x.bytes // 0) > ($b[0].bytes // 0) then $x
            else ($x + {sev: "warn"}) end)
         else . end)) as $curRatcheted |
    (([ $curRatcheted[] | . as $x | select((any($exc[]; . as $e | $x | hit($e))) | not) ])
      + ([ $exc[] | . as $e | select(([ $curRatcheted[] | select(hit($e)) ] | length) == 0) | {code: "EXCEPTION_STALE", path: ".vault-lint-exceptions", line: 0, msg: "\($e.code) \($e.path)", sev: "warn", fix: "auto", hint: "allowlist entry matches nothing; delete it"} ])
    ) as $curFiltered |
    ([ $baseAll[] | . as $x | select((any($exc[]; . as $e | $x | hit($e))) | not) ]) as $baseFiltered |
    ($baseFiltered | map({key: (.code + "\u0001" + .path + "\u0001" + .msg), value: true}) | from_entries) as $baseKeys |
    ($curFiltered | map(select((($baseKeys[.code + "\u0001" + .path + "\u0001" + .msg]) // false) | not))) as $introduced |
    ($curFiltered | map(select(.sev == "fail" and (($baseKeys[.code + "\u0001" + .path + "\u0001" + .msg]) // false) and (.path as $p | $touched | index($p)))) | map(. + {sev: "drift"})) as $drift |
    (($introduced + $drift) | sort_by([{fail:0,drift:1,warn:2,info:3}[.sev] // 9, .path, .line])) as $F |
    { ok: (([ $F[] | select(.sev == "fail") ] | length) == 0),
      notes: $n,
      fail: ([ $F[] | select(.sev == "fail") ] | length),
      warn: ([ $F[] | select(.sev == "warn") ] | length),
      drift: ([ $F[] | select(.sev == "drift") ] | length),
      by_code: ($F | group_by(.code) | map({key: .[0].code, value: length}) | from_entries),
      findings: $F }
  ' "$cur" > "$out"
}

do_changed() {
  local vault="$1" repo="$2" out="$3"
  merge_schema "$vault" "$TMP/schema.json" || return 2
  load_exceptions "$vault" "$TMP/exc.json"
  local relvault="${vault#"$repo"/}"
  {
    git -C "$repo" diff --name-only HEAD -- "$relvault" 2>/dev/null
    git -C "$repo" ls-files --others --exclude-standard -- "$relvault" 2>/dev/null
  } | sort -u > "$TMP/touched_repo_rel.txt"
  : > "$TMP/touched.txt"
  while IFS= read -r rp; do
    [ -n "$rp" ] || continue
    case "$rp" in
      "$relvault"/*.md) printf '%s\n' "${rp#"$relvault"/}" >> "$TMP/touched.txt" ;;
    esac
  done < "$TMP/touched_repo_rel.txt"
  if [ ! -s "$TMP/touched.txt" ]; then
    "$JQ" -n --argjson n "$(note_count "$vault")" '{ok: true, notes: $n, fail: 0, warn: 0, drift: 0, by_code: {}, findings: []}' > "$out"
    return 0
  fi
  "$JQ" -R . "$TMP/touched.txt" | "$JQ" -s . > "$TMP/touched.json"
  lint_tree "$vault" "$repo" "$TMP/schema.json" "$TMP/touched.json" 1 "$TMP/cur.raw.ndjson" || return 2
  build_baseline "$vault" "$repo" "$relvault" "$TMP/touched.txt" "$TMP/base" || return 2
  lint_tree "$TMP/base" "$repo" "$TMP/schema.json" "$TMP/touched.json" 0 "$TMP/base.raw.ndjson" || return 2
  assemble_changed "$TMP/cur.raw.ndjson" "$TMP/base.raw.ndjson" "$TMP/exc.json" "$(note_count "$vault")" "$TMP/touched.json" "$out"
}

# ---------------------------------------------------------------------------
# --next-adr: scans every worktree's working tree, plus the committed tree of
# every local branch and origin/HEAD, for decisions/ADR-NNN-*.md.
# ---------------------------------------------------------------------------
next_adr() {
  local vault="$1" repo="$2"
  local relvault="${vault#"$repo"/}"
  local max=0 n
  while IFS= read -r wt; do
    [ -n "$wt" ] || continue
    [ -d "$wt/$relvault/decisions" ] || continue
    while IFS= read -r f; do
      case "$f" in
        ADR-[0-9][0-9][0-9]-*)
          n=${f#ADR-}; n=${n%%-*}; n=$((10#$n))
          [ "$n" -gt "$max" ] && max=$n
          ;;
      esac
    done < <(ls -1 "$wt/$relvault/decisions" 2>/dev/null)
  done < <(git -C "$repo" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print substr($0,10)}')
  while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    while IFS= read -r f; do
      case "$f" in
        ADR-[0-9][0-9][0-9]-*)
          n=${f#ADR-}; n=${n%%-*}; n=$((10#$n))
          [ "$n" -gt "$max" ] && max=$n
          ;;
      esac
    done < <(git -C "$repo" ls-tree -r --name-only "$ref" -- "$relvault/decisions" 2>/dev/null | xargs -n1 basename 2>/dev/null)
  done < <(git -C "$repo" for-each-ref --format='%(refname)' refs/heads refs/remotes/origin/HEAD 2>/dev/null)
  printf 'ADR-%03d\n' "$((max + 1))"
}

# ===========================================================================
# Mode dispatch
# ===========================================================================

if [ "${1:-}" = "--next-adr" ]; then
  VAULT="${2:-}"
  [ -n "$VAULT" ] && [ -d "$VAULT" ] || { usage; exit 2; }
  VAULT=$(cd "$VAULT" && pwd -P)
  REPO=$(git -C "$VAULT" rev-parse --show-toplevel 2>/dev/null) || { usage; exit 2; }
  next_adr "$VAULT" "$REPO"
  exit 0
fi

if [ "${1:-}" = "--hook" ]; then
  IN=$(cat)
  cwd=$(printf '%s' "$IN" | "$JQ" -r '.cwd // empty' 2>/dev/null)
  stop_active=$(printf '%s' "$IN" | "$JQ" -r '.stop_hook_active // false' 2>/dev/null)
  [ -n "$cwd" ] || exit 0
  [ "$stop_active" = "true" ] && exit 0
  REPO=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0
  VAULT="$REPO/docs/project-knowledge"
  [ -d "$VAULT" ] || exit 0
  TMP=$(mktemp -d 2>/dev/null) || exit 0
  trap 'rm -rf "$TMP"' EXIT
  ENV="$TMP/env.json"
  if ! do_changed "$VAULT" "$REPO" "$ENV" 2>/dev/null; then exit 0; fi
  # ".ok // \"error\"" would be wrong here: jq's // fires on false the same as
  # null, so a legitimate ok:false (the case this hook exists to catch) would
  # be misread as the error sentinel and silently exit 0. Null-check instead.
  ok=$("$JQ" -r 'if .ok == null then "error" else (.ok | tostring) end' "$ENV" 2>/dev/null)
  [ "$ok" = "true" ] && exit 0
  [ "$ok" = "error" ] || [ -z "$ok" ] && exit 0
  {
    "$JQ" -r '.findings[] | select(.sev == "fail") | "FAIL \(.path):\(.line) \(.code) \(.msg)"' "$ENV" 2>/dev/null
    "$JQ" -r '[.findings[] | select(.sev == "drift")][0:40][] | "DRIFT \(.path):\(.line) \(.code) \(.msg)"' "$ENV" 2>/dev/null
    echo 'Fix every FAIL above before handing off. Copy each DRIFT line into the handoff as "Drift found: <what the vault states> - <what the code shows>".'
  } >&2
  exit 2
fi

FORMAT=text
if [ "${1:-}" = "--format" ]; then FORMAT="${2:-text}"; shift 2 2>/dev/null || { usage; exit 2; }; fi
case "$FORMAT" in text|json) ;; *) usage; exit 2 ;; esac

CHANGED=0
if [ "${1:-}" = "--changed" ]; then CHANGED=1; shift; fi

VAULT="${1:-}"
[ -n "$VAULT" ] && [ -d "$VAULT" ] || { usage; exit 2; }
shift
VAULT=$(cd "$VAULT" && pwd -P)
REPO=$(git -C "$VAULT" rev-parse --show-toplevel 2>/dev/null) || REPO="$VAULT"

TMP=$(mktemp -d) || { echo "lint-vault: cannot create temp dir" >&2; exit 2; }
trap 'rm -rf "$TMP"' EXIT
printf '[]' > "$TMP/empty_scope.json"

merge_schema "$VAULT" "$TMP/schema.json" || exit 2
load_exceptions "$VAULT" "$TMP/exc.json"

ENV="$TMP/env.json"
if [ "$CHANGED" = 1 ]; then
  [ "$#" -eq 0 ] || { usage; exit 2; }
  do_changed "$VAULT" "$REPO" "$ENV" || exit 2
else
  : > "$TMP/only_list.txt"
  for f in "$@"; do
    d=$(cd "$(dirname "$f")" 2>/dev/null && pwd -P) || { echo "lint-vault: no such file: $f" >&2; exit 2; }
    a="$d/$(basename "$f")"
    printf '%s\n' "${a#"$VAULT"/}" >> "$TMP/only_list.txt"
  done
  "$JQ" -R . "$TMP/only_list.txt" | "$JQ" -s . > "$TMP/only.json"
  if [ "$#" -gt 0 ]; then cp "$TMP/only.json" "$TMP/probe_scope.json"; else cp "$TMP/empty_scope.json" "$TMP/probe_scope.json"; fi
  do_whole "$VAULT" "$REPO" "$TMP/only.json" "$TMP/probe_scope.json" "$ENV" || exit 2
fi

if [ "$FORMAT" = json ]; then
  "$JQ" . "$ENV"
else
  "$JQ" -r '
    (.findings[] | "\(.sev | ascii_upcase) \(.path):\(.line) \(.code) \(.msg)"),
    (if (.drift // 0) > 0 then "lint-vault: \(.fail) FAIL, \(.warn) WARN, \(.drift) DRIFT across \(.notes) notes"
     else "lint-vault: \(.fail) FAIL, \(.warn) WARN across \(.notes) notes" end)
  ' "$ENV"
fi

ok=$("$JQ" -r '.ok' "$ENV" 2>/dev/null)
[ "$ok" = "true" ] && exit 0
exit 1
