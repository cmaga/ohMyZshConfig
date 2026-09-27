#!/usr/bin/env bash
# lint-vault.sh -- rules-as-data linter for docs/project-knowledge vaults.
#
#   lint-vault.sh [--format text|json] VAULT_ROOT [file ...]   whole vault, or only these notes
#   lint-vault.sh [--format text|json] --changed VAULT_ROOT    scope = git change set vs HEAD
#   lint-vault.sh --hook                                       SubagentStop JSON on stdin; exit 0 or 2
#   lint-vault.sh --next-adr VAULT_ROOT                        prints ADR-NNN, exit 0
#   lint-vault.sh --records VAULT_ROOT                         pass-1-only NDJSON dump, exit 0
#   lint-vault.sh --digest-write VAULT_ROOT                    (re)writes the digest hub, exit 0
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
       lint-vault.sh --records VAULT_ROOT
       lint-vault.sh --digest-write VAULT_ROOT
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
function unwiki(s,   o, inner, d) {
  o = ""
  while (match(s, /\[\[[^]]+\]\]/)) {
    inner = substr(s, RSTART + 2, RLENGTH - 4)
    d = index(inner, "|")
    o = o substr(s, 1, RSTART - 1) (d ? substr(inner, d + 1) : inner)
    s = substr(s, RSTART + RLENGTH)
  }
  return o s
}
function firstsent(s,   n, i, w, bt, out, W) {
  n = split(s, W, " ")
  out = ""
  for (i = 1; i <= n; i++) {
    w = W[i]
    bt += gsub(/`/, "`", w)
    out = (out == "" ? w : out " " w)
    if (bt % 2 == 0 && w ~ /[.!?]$/ && w !~ /\.\.\.$/ && w !~ /^(e\.g\.|i\.e\.|etc\.|vs\.|cf\.)$/) return out
  }
  return out
}
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
function gclose() {
  if (gopen) gl = add(gl, sprintf("{\"line\":%d,\"term\":\"%s\",\"link\":%s}", gline, esc(gterm), (glink ? "true" : "false")))
  gopen = 0
}
function flush(   s) {
  if (path == "") return
  emit()
  gclose()
  s = unwiki(hp); gsub(/<!--[^>]*-->/, "", s); s = firstsent(s)
  if (length(s) > 120) { s = substr(s, 1, 120); sub(/ [^ ]*$/, "", s) }
  printf "{\"path\":\"%s\",\"bytes\":%d,\"maxline\":%d,\"maxline_no\":%d,\"fm_open\":%s,\"fm_close\":%s,\"fm\":{%s},\"fm_line\":{%s},\"fm_bad\":[%s],\"fm_dup\":[%s],", \
    esc(path), bytes, maxline, maxline_no, (fmo ? "true" : "false"), (fmc ? "true" : "false"), fm, fml, fmbad, fmdup
  printf "\"h1\":%s,\"first\":%s,\"banner\":%s,\"h2\":[%s],\"heads\":[%s],\"links\":[%s],", \
    (h1 == "" ? "null" : h1), (first == "" ? "null" : first), (banner == "" ? "null" : banner), h2, heads, links
  printf "\"hook\":%s,\"markers\":[%s],\"governs\":%s,\"applies_to\":%s,\"gloss\":[%s],", \
    (s == "" ? "null" : "\"" esc(s) "\""), mk, (gov == "" ? "null" : "\"" esc(gov) "\""), (app == "" ? "null" : "\"" esc(app) "\""), gl
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
  hz = hdone = 0; hp = gov = app = mk = gl = gterm = gopen = glink = ""
  isdec = (path ~ /^decisions\//); if (!isdec) hz = 1
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
      if (v ~ /^[|>]/ || (v ~ /^\[/ && v !~ /^\[\[/ && !(k ~ /^(aliases|governs|applies_to|sources)$/ && v ~ /^\[.*\]$/)) || v ~ /^[{&*!]/) { fmbad = add(fmbad, pos(FNR, $0)); next }
      if (v ~ /^".*"$/ || (length(v) > 1 && substr(v, 1, 1) == q && substr(v, length(v), 1) == q)) v = substr(v, 2, length(v) - 2)
      if (k in seen) fmdup = add(fmdup, "\"" k "\"")
      seen[k] = 1
      fm = add(fm, "\"" k "\":\"" esc(v) "\""); fml = add(fml, "\"" k "\":" FNR)
      if (k == "governs") gov = v; if (k == "applies_to") app = v
      if (v ~ /\[\[/) { l = v; while (match(l, /\[\[[^]]+\]\]/)) { links = add(links, sprintf("{\"line\":%d,\"wiki\":\"%s\",\"fm\":true}", FNR, esc(substr(l, RSTART + 2, RLENGTH - 4)))); l = substr(l, RSTART + RLENGTH) } }
    } else fmbad = add(fmbad, pos(FNR, $0))
    next
  }
}
/^[ \t]*(```|~~~)/ { fence = !fence; if (hp != "") hdone = 1; gclose(); next }
fence { next }
{
  line = $0
  if (match(line, /^#+ /)) {
    lvl = RLENGTH - 1; t = trim(substr(line, RLENGTH + 1)); sub(/[ #]+$/, "", t)
    heads = add(heads, "\"" esc(t) "\"")
    if (hp != "") hdone = 1
    if (isdec) hz = (lvl == 2 && t == "Decision")
    gclose(); if (path == GLOSS && lvl == 3) { gopen = 1; gterm = t; gline = FNR; glink = 0 }
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
  if (!hdone && line !~ /^#/) {
    if (line ~ /^[ \t]*$/) { if (hp != "") hdone = 1 }
    else if (line ~ /^[ \t]*(>|[-*+][ \t]|[0-9]+[.)][ \t]|\|)/) { if (hp != "") hdone = 1 }
    else if (hz) hp = (hp == "" ? trim(line) : hp " " trim(line))
  }
  if (path == GLOSS) {
    if (line ~ /^[-*]?[ \t]*\*\*/) { gclose(); gopen = 1; gline = FNR; gterm = line; sub(/^[-*]?[ \t]*\*\*/, "", gterm); sub(/\*\*.*/, "", gterm); glink = 0 }
    else if (line ~ /^[ \t]*$/) gclose()
    if (gopen && (line ~ /\[\[/ || line ~ /\]\(/)) glink = 1
  }
  l = nocode(line)
  while (match(l, /\[\[[^]]+\]\]/)) { links = add(links, sprintf("{\"line\":%d,\"wiki\":\"%s\"}", FNR, esc(substr(l, RSTART + 2, RLENGTH - 4)))); l = substr(l, RSTART + RLENGTH) }
  l = line; gsub(/`[^`]*`/, "", l)
  while (match(l, /\]\([^) ]+\.md(#[^)]*)?\)/)) { t = substr(l, RSTART + 2, RLENGTH - 3); if (t !~ /^[a-z]+:/) links = add(links, sprintf("{\"line\":%d,\"md\":\"%s\"}", FNR, esc(t))); l = substr(l, RSTART + RLENGTH) }
  ml = line
  while (match(ml, /[Aa]s of [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/)) {
    mk = add(mk, sprintf("{\"line\":%d,\"kind\":\"asof\",\"date\":\"%s\",\"text\":\"\",\"evid\":%s}", \
      FNR, substr(ml, RSTART + RLENGTH - 10, 10), (line ~ /Amendment \([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\)/) ? "true" : "false"))
    ml = substr(ml, RSTART + RLENGTH)
  }
  ml = line
  while (match(ml, /<!-- recheck [^:>]*:[^>]*-->/)) {
    mseg = substr(ml, RSTART, RLENGTH)
    mcol = index(mseg, ":")
    mdate = trim(substr(mseg, 14, mcol - 14))
    mtext = substr(mseg, mcol + 1); sub(/-->$/, "", mtext); mtext = trim(mtext)
    mk = add(mk, sprintf("{\"line\":%d,\"kind\":\"recheck\",\"date\":\"%s\",\"text\":\"%s\",\"evid\":%s}", \
      FNR, esc(mdate), esc(mtext), (line ~ /Amendment \([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\)/) ? "true" : "false"))
    ml = substr(ml, RSTART + RLENGTH)
  }
  ml = line
  while (match(ml, /\((until|deprecated) [0-9][^ )]*[^)]*\)/)) {
    mseg = substr(ml, RSTART, RLENGTH)
    minner = substr(mseg, 2, length(mseg) - 2)
    msp = index(minner, " ")
    mkind = substr(minner, 1, msp - 1)
    mrest = substr(minner, msp + 1)
    msp2 = index(mrest, " ")
    if (msp2) { mdate = substr(mrest, 1, msp2 - 1); mrest = substr(mrest, msp2 + 1) }
    else { mdate = mrest; mrest = "" }
    sub(/^[ \t]+/, "", mrest)
    if (index(mrest, EM) == 1) mrest = substr(mrest, 4)
    else if (substr(mrest, 1, 1) == "-") mrest = substr(mrest, 2)
    else mrest = ""
    mrest = trim(mrest)
    mk = add(mk, sprintf("{\"line\":%d,\"kind\":\"%s\",\"date\":\"%s\",\"text\":\"%s\",\"evid\":%s}", \
      FNR, mkind, esc(mdate), esc(mrest), (line ~ /Amendment \([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\)/) ? "true" : "false"))
    ml = substr(ml, RSTART + RLENGTH)
  }
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
# Pass 2c (shell+git): provenance/governance probes. Runs unconditionally
# (both trees, like pass2) -- SOURCE_DOC_MISSING is a plain file-existence
# check with no git dependency; SOURCE_COMMIT_UNRESOLVED and the dead-glob
# checks need a repo and are skipped (not failed) outside one. Bash 3.2 ships
# on macOS, so the governs/applies_to dead-glob cache is a temp file, not an
# associative array (kept portable to Git Bash as well).
# ---------------------------------------------------------------------------
pass2c_probes() {
  local recs="$1" repo="$2" scopef="$3" out="$4"
  local ingit=0
  git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 && ingit=1
  # awk's -F'\x1f' leaves FS as the literal 3 chars "x1f" on the BSD/macOS
  # "one true awk" (no \x hex-escape support in -F) -- pass the real byte
  # via a variable instead, same as the $'\x1f' bash already uses below.
  local US; US=$(printf '\037')

  local extracted; extracted=$(mktemp "$TMP/p2c.XXXXXX")
  "$JQ" -r --slurpfile scope "$scopef" '
    ($scope[0] // []) as $sc |
    def flow: if type=="string" and test("^\\[.*\\]$") then (.[1:-1]|split(",")|map(gsub("^ +| +$";""))|map(select(.!=""))) else [] end;
    . as $r | $r.path as $p | select(($sc|length) == 0 or ($sc|index($p))) |
    ( (($r.fm.sources // "") | flow[] | select(startswith("commit:") or startswith("doc:")) | [$p, ($r.fm_line.sources // 1), "src", .]),
      (($r.fm.governs // "") | flow[] | [$p, ($r.fm_line.governs // 1), "governs", .]),
      (($r.fm.applies_to // "") | flow[] | [$p, ($r.fm_line.applies_to // 1), "applies_to", .])
    ) | join("\u001f")
  ' "$recs" 2>/dev/null > "$extracted"

  local missing_shas; missing_shas=$(mktemp "$TMP/p2c.XXXXXX")
  : > "$missing_shas"
  if [ "$ingit" = 1 ]; then
    local shas; shas=$(mktemp "$TMP/p2c.XXXXXX")
    awk -F"$US" '$3=="src" && $4 ~ /^commit:/ { s=$4; sub(/^commit:/, "", s); print s }' "$extracted" | sort -u > "$shas"
    if [ -s "$shas" ]; then
      awk '{print $0"^{commit}"}' "$shas" |
      git -C "$repo" cat-file --batch-check 2>/dev/null |
      awk '/ missing$/ { sub(/\^\{commit\} missing$/, "", $0); print $0 }' > "$missing_shas"
    fi
    rm -f "$shas"
  fi

  local gacache; gacache=$(mktemp "$TMP/p2c.XXXXXX")
  : > "$gacache"

  : > "$out"
  while IFS=$'\x1f' read -r p ln kind item; do
    [ -n "$p" ] || continue
    case "$kind" in
      src)
        case "$item" in
          commit:*)
            [ "$ingit" = 1 ] || continue
            sha="${item#commit:}"
            if awk -v s="$sha" '$0==s{f=1} END{exit !f}' "$missing_shas" 2>/dev/null; then
              printf '{"code":"SOURCE_COMMIT_UNRESOLVED","path":"%s","line":%s,"msg":"commit %s not in this repo"}\n' \
                "$(json_esc "$p")" "$ln" "$(json_esc "$sha")"
            fi
            ;;
          doc:*)
            docpath="${item#doc:}"
            if [ ! -e "$repo/$docpath" ]; then
              printf '{"code":"SOURCE_DOC_MISSING","path":"%s","line":%s,"msg":"doc: %s does not exist"}\n' \
                "$(json_esc "$p")" "$ln" "$(json_esc "$docpath")"
            fi
            ;;
        esac
        ;;
      governs|applies_to)
        [ "$ingit" = 1 ] || continue
        local dead found
        found=$(awk -F"$US" -v k="$kind" -v it="$item" '$1==k && $2==it {print $3; exit}' "$gacache" 2>/dev/null)
        if [ -n "$found" ]; then
          dead="$found"
        else
          if [ -z "$(git -C "$repo" ls-files -- ":(glob)$item" 2>/dev/null | head -n1)" ]; then dead=1; else dead=0; fi
          printf '%s\x1f%s\x1f%s\n' "$kind" "$item" "$dead" >> "$gacache"
        fi
        if [ "$dead" = 1 ]; then
          local code="GOVERNS_DEAD_GLOB"; [ "$kind" = "applies_to" ] && code="APPLIES_TO_DEAD_GLOB"
          printf '{"code":"%s","path":"%s","line":%s,"msg":"%s matches no file at HEAD"}\n' \
            "$code" "$(json_esc "$p")" "$ln" "$(json_esc "$item")"
        fi
        ;;
    esac
  done < "$extracted" > "$out"

  rm -f "$extracted" "$missing_shas" "$gacache"
}

# ---------------------------------------------------------------------------
# gen-vault-rules.sh is a sibling script that does not exist yet (step 2);
# the -r guard keeps this inert until it lands. Same tab/JSON convention as
# the guard awk below, minus the vroot strip -- the sibling already prints
# paths rooted at .claude/rules/vault/.
# ---------------------------------------------------------------------------
rules_check() {
  local repo="$1" out="$2"
  [ -d "$repo/.claude/rules/vault" ] && [ -r "$HERE/gen-vault-rules.sh" ] || return 0
  bash "$HERE/gen-vault-rules.sh" --check "$repo" 2>/dev/null |
  awk -F'\t' '
    function esc(s) { gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s); return s }
    /^STALE / { printf "{\"code\":\"RULES_STALE\",\"path\":\"%s\",\"line\":0,\"msg\":\"stale; run gen-vault-rules.sh\"}\n", esc(substr($0,7)); next }
    /^EXTRA / { printf "{\"code\":\"RULES_STALE\",\"path\":\"%s\",\"line\":0,\"msg\":\"extra; not generated by gen-vault-rules.sh\"}\n", esc(substr($0,7)); next }
    NF >= 4 { printf "{\"code\":\"%s\",\"path\":\"%s\",\"line\":%s,\"msg\":\"%s\"}\n", esc($1), esc($2), ($3 + 0), esc($4); next }
  ' >> "$out"
  return 0
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
# attached. $R/$S/$REG/$G/$P are NDJSON slurps (arrays already); $schema is a
# single-object file, unwrapped via $schema[0]. Split into three heredocs so
# --digest-write can run a slice of the same pipeline (DIGEST_DEF + PRELUDE +
# a call to digest_text) without also paying for or depending on CHECKS.
# digest_text is defined BEFORE the prelude on purpose: jq has no forward
# references between sibling top-level defs, so if digest_text is going to
# stand alone in DIGEST_JQ it cannot call the prelude's bucket/base/etc (those
# would not exist yet at digest_text's own definition site) -- it carries its
# own tiny copies instead.
# ---------------------------------------------------------------------------
read -r -d '' DIGEST_DEF <<'JQEOF' || true
def digest_text($R; $sc; $inbound; $hubThr; $vname):
  def bucket: if test("/") then split("/")[0] else "" end;
  def base: split("/")[-1] | rtrimstr(".md");
  def cap: (.[0:1] | ascii_upcase) + .[1:];
  ([ $R[] | select($sc.hubs[.path] == null and $sc.buckets[.path|bucket] != null) |
     (.path|bucket) as $bkt | (.path|base) as $bs |
     { path: .path, bkt: $bkt, bs: $bs,
       title: (.h1.text // $bs),
       hook: (.hook // ""),
       status: (.fm.status // ""),
       deg: ([ ($inbound[.path] // [])[] | select($sc.hubs[.] == null) ] | length)
     } | . + { hub: (.deg >= $hubThr) }
   ]) as $notes0 |
  def sectionOf:
    if (.status == "superseded" or .status == "deprecated" or .status == "rescinded") then "Retired"
    elif (.bkt == "plan" or .bkt == "research") and .status == "closed" then "Optional"
    else (.bkt | cap) end;
  ($notes0 | map(. + {section: sectionOf})) as $notes |
  ($sc.buckets | keys_unsorted | map(cap)) as $bktNames |
  ($bktNames + ["Retired","Optional"]) as $sectionOrder |
  def entry($n; $tier):
    ($n.hook) as $h0 |
    (if $tier >= 1 and ($n.section == "Retired" or $n.section == "Optional") then "" else $h0 end) as $h1 |
    (if $tier >= 2 and (($h1 | length) > 60) then ($h1[0:60] | sub(" [^ ]*$"; "")) else $h1 end) as $h2 |
    (if $tier >= 3 and ($n.hub | not) then "" else $h2 end) as $hookf |
    if $tier >= 4 and $n.section == "Retired" then
      "- [\($n.title)](\($n.path))"
    else
      "- [\($n.title)](\($n.path))"
      + (if $hookf != "" then ": " + $hookf else "" end)
      + (if $n.hub then " (hub)" else "" end)
      + (if $n.status != "" and $n.status != "active" then " · " + $n.status else "" end)
    end;
  def render($tier):
    ($notes | group_by(.section) | map({key: .[0].section, value: (sort_by(.bs))}) | from_entries) as $bySec |
    ("# \($vname) digest\n\n> Generated by lint-vault.sh --digest-write; do not edit. Start here, then open the note.\n"
     + ([ $sectionOrder[] | select($bySec[.] != null and (($bySec[.] | length) > 0)) |
          "\n## \(.)\n" + (($bySec[.] | map(entry(.; $tier) + "\n")) | add)
        ] | add // ""));
  (first(range(0;5) | render(.) | select((. | utf8bytelength) <= 12288)) // render(4))
;
JQEOF

read -r -d '' PASS3_PRELUDE <<'JQEOF' || true
$schema[0] as $sc |
def f($r; $c; $line; $msg): {code: $c, path: $r.path, line: $line, msg: $msg};
def bucket: if test("/") then split("/")[0] else "" end;
def base: split("/")[-1] | rtrimstr(".md");
def norm: ascii_downcase | gsub("-"; " ") | gsub("[^a-z0-9 ]"; "") | gsub(" +"; " ") | ltrimstr(" ") | rtrimstr(" ");
def normpath: reduce (split("/")[]) as $s ([]; if $s == ".." then .[:-1] elif ($s == "." or $s == "") then . else . + [$s] end) | join("/");
def isflow: type == "string" and test("^\\[.*\\]$");
def flow: if type=="string" and test("^\\[.*\\]$") then (.[1:-1]|split(",")|map(gsub("^ +| +$";""))|map(select(.!=""))) else [] end;
def datechk($r; $k): ($r.fm[$k]) as $v | if $v == null then empty elif ($v | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$") | not) or ((try (($v + "T00:00:00Z") | fromdateiso8601 | strftime("%Y-%m-%d")) catch "") != $v) then f($r; "DATE_INVALID"; ($r.fm_line[$k] // 1); "\($k) \($v)") elif $v > $today then f($r; "DATE_FUTURE"; ($r.fm_line[$k] // 1); "\($k) \($v)") else empty end;
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
       elif ($n | test("^ADR-[0-9]+$") | not) and ($n | test($sc.ticket_pattern)) then {kind: "ticket"}
       else {kind: "missing"} end)
  end;
[ $R[] | select(($sc.hubs[.path].type // "") != "digest") | . as $r | .links[] | . + (resolve($r.path)) | .src = $r.path ] as $L |
($L | map(select(.kind == "note" and .to != .src)) | group_by(.to) | map({key: .[0].to, value: (map(.src) | unique)}) | from_entries) as $inbound |
($L | group_by(.src) | map({key: .[0].src, value: .}) | from_entries) as $Lby |
($sc.hubs | to_entries | map(select(.value.type == "index")) | .[0].key // "_index.md") as $indexPath |
($sc.hubs | to_entries | map(select(.value.type == "digest")) | .[0].key // "_digest.md") as $digestPath |
([ $R[] | select($sc.hubs[.path] == null) | .path as $p | [ ($inbound[$p] // [])[] | select($sc.hubs[.] == null) ] | length ] | sort) as $deg |
(if ($deg|length) == 0 then 0 else $deg[((($deg|length) * 0.9) | ceil) - 1] end) as $p90 |
([5, $p90] | max) as $hubThr |
($R | map(select((.fm.superseded_by // "") != "") | .path as $p | .fm_line.superseded_by as $ln |
   ([ ($Lby[$p] // [])[] | select(.fm and .line == $ln and .kind == "note") ][0]) as $sl |
   select($sl != null) | {key: $p, value: $sl.to}) | from_entries) as $succ |
def walk_succ($p): [limit(($succ | length) + 2; $p | recurse($succ[.] // empty))];
($R | map(.path as $p | .surface.entries[]? | .line as $ln | .syms[]? | {sym: ., path: $p, line: $ln})) as $allSurf |
($allSurf | group_by(.sym) | map(select((map(.path) | unique | length) > 1)) | flatten) as $dupSurf |
JQEOF

read -r -d '' PASS3_CHECKS <<'JQEOF' || true
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
      (($sc.field_patterns // {}) | to_entries[] | . as $e | select($r.fm[$e.key] and (($r.fm[$e.key] | test($e.value)) | not)) | f($r; "ENUM_INVALID"; ($r.fm_line[$e.key] // 1); "\($e.key) \($r.fm[$e.key])")),
      (["created","last_verified","revisit_by"][] | datechk($r; .)),
      (if $r.fm.status == "superseded" and (($r.fm.superseded_by // "") == "") then f($r; "SUPERSEDED_BY_REQUIRED"; ($r.fm_line.status // 1); "superseded without superseded_by") else empty end),
      (if ($r.fm.superseded_by // "") != "" then
         (if $r.fm.status != "superseded" then f($r; "SUPERSEDED_BY_STRAY"; ($r.fm_line.superseded_by // 1); "status is \($r.fm.status)") else empty end),
         (if ($r.fm.superseded_by | test("^\\[\\[[^]]+\\]\\]$") | not) then f($r; "SUPERSEDED_BY_FORMAT"; ($r.fm_line.superseded_by // 1); $r.fm.superseded_by)
          else (([ ($Lby[$r.path] // [])[] | select(.fm) ])[0] as $sl | if $sl and $sl.kind != "note" then f($r; "SUPERSEDED_BY_UNRESOLVED"; $sl.line; $sl.raw) else empty end)
          end)
       else empty end),
      (if $succ[$r.path] then
         $succ[$r.path] as $t |
         (if ([ ($Lby[$t] // [])[] | select((.fm|not) and .kind == "note" and .to == $r.path) ] | length) == 0
          then f($r; "SUPERSEDED_BY_NO_BACKLINK"; ($r.fm_line.superseded_by // 1); "\($t) never links back") else empty end),
         (walk_succ($r.path) as $w | (($w[1:]) | index($r.path)) as $i |
          if $i != null and (($w[0:$i+1]) | min) == $r.path then f($r; "SUPERSESSION_CYCLE"; ($r.fm_line.superseded_by // 1); ($w[0:$i+2] | join(" -> "))) else empty end)
       else empty end),
      (if $r.fm.basis and (["user-stated","inferred"] | index($r.fm.basis) | not) then f($r; "BASIS_ENUM"; ($r.fm_line.basis // 1); "basis \($r.fm.basis)") else empty end),
      (if $r.fm.sources then
         (if ($r.fm.sources | isflow | not) then f($r; "SOURCE_REF_FORMAT"; ($r.fm_line.sources // 1); "sources is not a flow list [..]")
          else
            ($r.fm.sources | flow[] | select(test("^(ticket:[^ ,]+|pr:[0-9]+|commit:[0-9a-f]{7,40}|doc:[^ ,]+)$") | not) | f($r; "SOURCE_REF_FORMAT"; ($r.fm_line.sources // 1); .)),
            ($r.fm.sources | flow[] | select(startswith("ticket:")) | select((ltrimstr("ticket:") | test($sc.ticket_pattern)) | not) | f($r; "SOURCE_TICKET_PATTERN"; ($r.fm_line.sources // 1); .))
          end)
       else empty end),
      (if $r.fm.basis == "inferred" and ((($r.fm.sources // "") | flow | length) == 0) then f($r; "BASIS_INFERRED_NO_SOURCES"; ($r.fm_line.basis // 1); "inferred with no sources") else empty end),
      (if ($bs.optional | index("governs")) and $r.fm.status == "active" and $r.fm.governs == null then f($r; "GOVERNS_MISSING"; ($r.fm_line.status // 1); "active with no governs: [..]") else empty end),
      (["governs","applies_to"][] | . as $k | select($r.fm[$k] != null and ($r.fm[$k] | isflow | not)) | f($r; "GOVERNS_FORMAT"; ($r.fm_line[$k] // 1); "\($k): not a flow list [..]"))
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
      (if $r.banner != null and $succ[$r.path] then
         ([ ($Lby[$r.path] // [])[] | select((.fm|not) and .line == $r.banner.line) ][0]) as $bl |
         if $bl and $bl.kind == "note" and $bl.to != $succ[$r.path] then f($r; "BANNER_SUCCESSOR_MISMATCH"; $r.banner.line; "banner names \($bl.to), superseded_by is \($succ[$r.path])") else empty end
       else empty end),
      (if $st == "amended" and (([ $r.h2[].text | select(startswith("Amendment")) ]) | length) == 0 then f($r; "AMENDMENT_MISSING"; 1; "status amended, no ## Amendment") else empty end)
     else empty end),
    (if $bs.surface == "required" and $r.surface == null then f($r; "SURFACE_MISSING"; 1; "no ## Reusable surface") else empty end),
    (if $r.surface != null and $bs.surface == "forbidden" then f($r; "SURFACE_OUT_OF_SCOPE"; $r.surface.line; $b) else empty end),
    (if $r.surface != null and (($r.surface.entries | length) == 0) and ($r.surface.none | not) then f($r; "SURFACE_EMPTY"; $r.surface.line; "no entries, no None stanza") else empty end),
    (($S | map(select(.path == $r.path)))[]? | select(.st != "ok") | f($r; ({path: "SURFACE_PATH_MISSING", nopath: "SURFACE_ENTRY_FORMAT", symbol: "SURFACE_SYMBOL_MISSING"}[.st]); .line; "\(.sym) @ \(.spath)")),
    ($dupSurf[] | select(.path == $r.path) | f($r; "SURFACE_DUPLICATE_HOME"; .line; .sym)),
    ($REG | map(select(.path == $r.path))[] | f($r; "SURFACE_REGION_CHANGED"; .line; .msg)),
    ($P | map(select(.path == $r.path))[] | f($r; .code; .line; .msg)),
    (if $b == "decisions" then
       ($dupAdrGroups[]? | select(any(.[]; .path == $r.path)) | f($r; "ADR_NUMBER_DUPLICATE"; 1; "ADR number \((.[0].n)) used by \(([.[].path]) | join(", "))"))
     else empty end)
   else empty end),

  (if $hub == null and ($dupBasenamePaths | index($r.path)) then f($r; "BASENAME_DUPLICATE"; 1; "basename \($file | rtrimstr(".md")) also used in another bucket") else empty end),

  (if $hub == null then
     (if $outc == 0 then f($r; "ORPHAN_NO_OUTBOUND"; 1; "0 resolved outbound links") else empty end),
     (if ($inb | length) == 0 then f($r; "ORPHAN_NO_INBOUND"; 1; "0 notes link here")
      elif $inbNonHub == 0 then f($r; "ORPHAN_HUB_ONLY_INBOUND"; 1; "only a hub links here")
      else empty end),
     (if $byPath[$indexPath] and $inbNonHub >= $hubThr and ((any(($Lby[$indexPath] // [])[]; .kind == "note" and .to == $r.path)) | not) then f($r; "HUB_MISSING_FROM_INDEX"; 1; "hub-ranked (\($inbNonHub) inbound) but not linked from \($indexPath)") else empty end)
   else empty end),

  (if $r.first == null then f($r; "EMPTY_NOTE"; 1; "no content after the H1") else empty end),

  (if (($hub.type // "") != "digest") then
     ($r.markers // []) as $M |
     ($M[] | select(.kind == "asof") | . as $a | select(($M | map(select(.kind == "recheck" and .line == $a.line)) | length) == 0) | f($r; "MARKER_RECHECK_MISSING"; $a.line; "as of \($a.date) without a recheck comment")),
     ($M[] | select(.kind != "asof") | select((.date | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$")) | not) | f($r; "MARKER_DATE_FORMAT"; .line; "\(.kind) \(.date)")),
     ($M[] | select(.kind != "asof") | select(.text == "") | f($r; "MARKER_REASON_MISSING"; .line; "\(.kind) \(.date) has no reason")),
     ($M[] | select($b == "decisions" and (.kind == "until" or .kind == "deprecated") and (.evid | not)) | . as $mk |
       select((any(($Lby[$r.path] // [])[]; .line == $mk.line and ((.wiki // "") | startswith("#") | not))) | not) |
       f($r; "MARKER_ADR_EVIDENCE"; $mk.line; "\($mk.kind) \($mk.date) cites no [[link]] or Amendment (date)")),
     ($M[] | select(.kind == "recheck" and (.date | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$")) and .date <= $today) | f($r; "MARKER_RECHECK_DUE"; .line; "recheck \(.date) is due"))
   else empty end),
  (if $hub.type == "glossary" then ($r.gloss[]? | select(.link | not) | f($r; "GLOSSARY_ENTRY_NO_LINK"; .line; .term)) else empty end),

  (if ($hub.type // "") == "digest" then empty
   elif $hub != null then
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
  elif .kind == "note" and .md != null and ($sc.hubs[$l.src] == null) then f($r; "LINK_INTERNAL_MD"; .line; .raw)
  else empty end
),
( $G[]? | {code, path, line, msg} ),
(if $totalBytes and ($totalBytes > $sc.sizes.vault_info) then {code: "SIZE_VAULT", path: ".", line: 0, msg: "vault is \($totalBytes) bytes"} else empty end),
(if $hasDigest == "1" then
   (if $digest != digest_text($R; $sc; $inbound; $hubThr; $vname) then {code: "DIGEST_STALE", path: $digestPath, line: 1, msg: "differs from --digest-write output"} else empty end)
 else {code: "DIGEST_MISSING", path: $digestPath, line: 0, msg: "no digest; run --digest-write"} end)
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

PASS3_JQ="$DIGEST_DEF"$'\n'"$PASS3_PRELUDE"$'\n'"$PASS3_CHECKS"
DIGEST_JQ="$DIGEST_DEF"$'\n'"$PASS3_PRELUDE"$'\n''digest_text($R; $sc; $inbound; $hubThr; $vname)'

pass3() {
  local recs="$1" surf="$2" region="$3" guard="$4" probe="$5" schema="$6" has="$7" dfile="$8" out="$9"
  "$JQ" -n --slurpfile R "$recs" --slurpfile S "$surf" --slurpfile REG "$region" --slurpfile G "$guard" \
    --slurpfile P "$probe" --slurpfile schema "$schema" --arg today "$(date +%Y-%m-%d)" \
    --arg vname "$VNAME" --arg hasDigest "$has" --rawfile digest "$dfile" "$PASS3_JQ" > "$out"
}

# ---------------------------------------------------------------------------
# Pass 1 driver: resolves the glossary hub path from the schema (awk needs it
# verbatim to gate glossary-entry extraction to that one file) and the literal
# em-dash (awk octal escapes don't match multi-byte UTF-8, see header note).
# ---------------------------------------------------------------------------
pass1() {
  local tree="$1" schema="$2" out="$3"
  local files0; files0=$(mktemp "$TMP/p1.XXXXXX")
  local gloss
  gloss=$("$JQ" -r '[.hubs|to_entries[]|select(.value.type=="glossary")|.key][0] // "glossary.md"' "$schema")
  find "$tree" -name '*.md' -not -path '*/.obsidian/*' -not -path '*/.cache/*' -print0 | sort -z > "$files0"
  if [ -s "$files0" ]; then
    xargs -0 awk -v root="$tree/" -v q="'" -v DASH=" — " -v EM="$(printf '\342\200\224')" -v GLOSS="$gloss" \
      -v PATHRE="^[A-Za-z0-9_.@-]+/[^ ]*[A-Za-z0-9_]$" "$PASS1_AWK" < "$files0" > "$out"
  else
    : > "$out"
  fi
  rm -f "$files0"
}

# ---------------------------------------------------------------------------
# Orchestration: run passes 1-3 over one tree (current working tree, or a
# HEAD-shadow tree for --changed/--hook baselines). do_extras=0 skips
# region-changed, guard scanning, and rules_check entirely -- used only for
# baselines, since content/region checks are always reported as introduced,
# never diffed.
# ---------------------------------------------------------------------------
lint_tree() {
  local tree="$1" repo="$2" schema="$3" scopef="$4" do_extras="$5" out="$6"
  local pfx; pfx=$(mktemp "$TMP/lt.XXXXXX"); rm -f "$pfx"
  pass1 "$tree" "$schema" "${pfx}.recs.ndjson"
  pass2 "${pfx}.recs.ndjson" "$repo" "$scopef" "${pfx}.surf.ndjson"
  pass2c_probes "${pfx}.recs.ndjson" "$repo" "$scopef" "${pfx}.probe.ndjson"
  if [ "$do_extras" = 1 ]; then
    pass2b_region "${pfx}.recs.ndjson" "$repo" "${tree#"$repo"/}" "HEAD" "$scopef" "${pfx}.region.ndjson"
    guard_scan "$tree" "${pfx}.recs.ndjson" "$scopef" "${pfx}.guard.ndjson"
    rules_check "$repo" "${pfx}.guard.ndjson"
  else
    : > "${pfx}.region.ndjson"
    : > "${pfx}.guard.ndjson"
  fi
  local digestPath has dfile
  digestPath=$("$JQ" -r '[.hubs|to_entries[]|select(.value.type=="digest")|.key][0] // "_digest.md"' "$schema")
  dfile="${pfx}.digest.md"
  if [ -f "$tree/$digestPath" ]; then cp "$tree/$digestPath" "$dfile"; has=1; else : > "$dfile"; has=0; fi
  pass3 "${pfx}.recs.ndjson" "${pfx}.surf.ndjson" "${pfx}.region.ndjson" "${pfx}.guard.ndjson" "${pfx}.probe.ndjson" "$schema" "$has" "$dfile" "$out"
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
    (map(select(.code != "MARKER_RECHECK_DUE")) |
     map(if (.code | endswith("_LIMIT")) and .sev == "fail" then
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

if [ "${1:-}" = "--records" ]; then
  VAULT="${2:-}"
  [ -n "$VAULT" ] && [ -d "$VAULT" ] || { usage; exit 2; }
  VAULT=$(cd "$VAULT" && pwd -P)
  TMP=$(mktemp -d) || { echo "lint-vault: cannot create temp dir" >&2; exit 2; }
  trap 'rm -rf "$TMP"' EXIT
  merge_schema "$VAULT" "$TMP/schema.json" || exit 2
  pass1 "$VAULT" "$TMP/schema.json" "$TMP/recs.ndjson"
  cat "$TMP/recs.ndjson"
  exit 0
fi

if [ "${1:-}" = "--digest-write" ]; then
  VAULT="${2:-}"
  [ -n "$VAULT" ] && [ -d "$VAULT" ] || { usage; exit 2; }
  VAULT=$(cd "$VAULT" && pwd -P)
  TMP=$(mktemp -d) || { echo "lint-vault: cannot create temp dir" >&2; exit 2; }
  trap 'rm -rf "$TMP"' EXIT
  merge_schema "$VAULT" "$TMP/schema.json" || exit 2
  pass1 "$VAULT" "$TMP/schema.json" "$TMP/recs.ndjson"
  digestPath=$("$JQ" -r '[.hubs|to_entries[]|select(.value.type=="digest")|.key][0] // "_digest.md"' "$TMP/schema.json")
  "$JQ" -j -n --slurpfile R "$TMP/recs.ndjson" --slurpfile schema "$TMP/schema.json" \
    --arg vname "$(basename "$VAULT")" "$DIGEST_JQ" > "$TMP/digest.md" && cp "$TMP/digest.md" "$VAULT/$digestPath"
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
  VNAME=$(basename "$VAULT")
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
VNAME=$(basename "$VAULT")

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
