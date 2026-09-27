#!/usr/bin/env bash
# vault-audit.sh -- caching status rollup over lint-vault.sh, vault-drift.sh,
# and vault-freshness.sh. One JSON cache per (repo, worktree) under .git, a
# --hook mode for SessionStart that stays silent unless things got worse, and
# a CLI text/json mode for manual triage.
set -u
export LC_ALL=C
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/vault-lib.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

usage() {
  echo "usage: vault-audit.sh [--hook] [--force] [--format text|json] [REPO]" >&2
  exit 2
}

HOOK=0
FORCE=0
FORMAT=text
REPO_ARG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --hook) HOOK=1 ;;
    --force) FORCE=1 ;;
    --format) shift; FORMAT="${1:-}"; case "$FORMAT" in text|json) ;; *) usage ;; esac ;;
    -*) usage ;;
    *) REPO_ARG="$1" ;;
  esac
  shift
done
[ "$HOOK" -eq 1 ] && [ -n "$REPO_ARG" ] && usage

# Resolve REPO. --hook reads it from stdin's cwd and fails silently (exit 0)
# on anything short of a real vault; the CLI path uses usage/exit 2 instead.
if [ "$HOOK" -eq 1 ]; then
  "$JQ" --version >/dev/null 2>&1 || exit 0
  IN=$(cat)
  CWD=$(printf '%s' "$IN" | "$JQ" -r '.cwd // empty' 2>/dev/null)
  [ -n "$CWD" ] || exit 0
  REPO=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null) || exit 0
  REPO=$(cd "$REPO" && pwd -P) || exit 0
  [ -d "$REPO/docs/project-knowledge" ] || exit 0
else
  if [ -n "$REPO_ARG" ]; then
    [ -d "$REPO_ARG" ] || usage
    REPO=$(cd "$REPO_ARG" && pwd -P) || usage
  else
    REPO=$(git rev-parse --show-toplevel 2>/dev/null) || usage
    REPO=$(cd "$REPO" && pwd -P) || usage
  fi
  git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 || usage
  [ -d "$REPO/docs/project-knowledge" ] || usage
fi
VAULT="$REPO/docs/project-knowledge"

CACHE_DIR=$(git_dir_abs "$REPO" --git-dir) || { [ "$HOOK" -eq 1 ] && exit 0 || usage; }
CACHE="$CACHE_DIR/vault-audit.json"
LOCK="$CACHE.lock"

dirty_sig() {
  { git -C "$REPO" diff HEAD -- docs/project-knowledge
    git -C "$REPO" ls-files --others --exclude-standard -- docs/project-knowledge
  } | git hash-object --stdin
}

# --- rerun decision ---------------------------------------------------
need_rerun=0
if [ "$FORCE" -eq 1 ]; then
  need_rerun=1
elif [ ! -f "$CACHE" ]; then
  need_rerun=1
else
  ver=$("$JQ" -r '.version // empty' "$CACHE" 2>/dev/null)
  if [ "$ver" != "1" ]; then
    need_rerun=1
  else
    gen=$("$JQ" -r '.generated // empty' "$CACHE" 2>/dev/null)
    stale=$("$JQ" -n --arg g "$gen" 'try (((now) - ($g | fromdateiso8601)) > 604800) catch true' 2>/dev/null)
    if [ "$stale" != "false" ]; then
      need_rerun=1
    else
      dsig=$(dirty_sig)
      csig=$("$JQ" -r '.dirty_sig // empty' "$CACHE" 2>/dev/null)
      if [ "$dsig" != "$csig" ]; then
        need_rerun=1
      else
        cur_head=$(git -C "$REPO" rev-parse HEAD 2>/dev/null)
        cached_head=$("$JQ" -r '.head // empty' "$CACHE" 2>/dev/null)
        if [ "$cur_head" != "$cached_head" ]; then
          "$JQ" -r '(.anchored_paths // [])[] | "p\t" + .' "$CACHE" > "$TMP/anchors"
          "$JQ" -r '(.anchored_globs // [])[] | "g\t" + .' "$CACHE" >> "$TMP/anchors"
          if git -C "$REPO" diff --name-only "$cached_head" "$cur_head" > "$TMP/changed_paths" 2>/dev/null; then
            if awk "$AWK_GLOB2ERE" -F'\t' '
              NR==FNR { if ($1=="p") lit[$2]=1; else re[++n]=glob2ere($2); next }
              index($0,"docs/project-knowledge/")==1 { f=1; exit }
              ($0 in lit) { f=1; exit }
              { for (p in lit) if (p ~ /\/$/ && index($0,p)==1) { f=1; exit }
                for (i=1;i<=n;i++) if ($0 ~ re[i]) { f=1; exit } }
              END { exit !f }
            ' "$TMP/anchors" "$TMP/changed_paths"; then
              need_rerun=1
            fi
          else
            # A failing diff (cached head gone, e.g. after a rebase) counts
            # as intersecting -- we cannot prove it doesn't.
            need_rerun=1
          fi
        fi
      fi
    fi
  fi
fi

# --- lock ---------------------------------------------------------------
got_lock=0
if [ "$need_rerun" -eq 1 ]; then
  mkdir -p "$CACHE_DIR"
  if mkdir "$LOCK" 2>/dev/null; then
    got_lock=1
  else
    lock_age=999999
    lock_mtime=$(stat -f %m "$LOCK" 2>/dev/null || stat -c %Y "$LOCK" 2>/dev/null || echo "")
    if [ -n "$lock_mtime" ]; then
      now_s=$(date +%s)
      lock_age=$((now_s - lock_mtime))
    fi
    if [ "$lock_age" -gt 120 ]; then
      rmdir "$LOCK" 2>/dev/null
      mkdir "$LOCK" 2>/dev/null && got_lock=1
    fi
  fi

  if [ "$got_lock" -eq 0 ]; then
    if [ "$HOOK" -eq 1 ]; then
      exit 0
    fi
    waited=0
    while [ -d "$LOCK" ] && [ "$waited" -lt 30 ]; do
      sleep 1
      waited=$((waited + 1))
    done
    need_rerun=0
  fi
fi

# --- run pipeline (only while holding the lock) --------------------------
if [ "$need_rerun" -eq 1 ] && [ "$got_lock" -eq 1 ]; then
  trap 'rmdir "$LOCK" 2>/dev/null; rm -rf "$TMP"' EXIT

  bash "$HERE/lint-vault.sh" --format json "$VAULT" > "$TMP/lint.json" 2>/dev/null || true
  [ -s "$TMP/lint.json" ] || echo '{}' > "$TMP/lint.json"
  bash "$HERE/vault-drift.sh" --scan "$REPO" >/dev/null 2>&1 || true
  bash "$HERE/vault-drift.sh" --list "$REPO" > "$TMP/drift.txt" 2>/dev/null || true
  bash "$HERE/vault-freshness.sh" "$VAULT" --lint-json "$TMP/lint.json" --json > "$TMP/freshness.json" 2>/dev/null || true
  [ -s "$TMP/freshness.json" ] || echo '{}' > "$TMP/freshness.json"

  # grep -c prints "0" itself on no match (exit 1); an "|| echo 0" here
  # would yield "0\n0", which --argjson rejects and no cache gets written.
  DRIFT_OPEN=$(grep -c '^OPEN ' "$TMP/drift.txt" 2>/dev/null); DRIFT_OPEN=${DRIFT_OPEN:-0}
  "$JQ" -R -s 'split("\n") | map(select(length>0 and startswith("OPEN ")))' "$TMP/drift.txt" > "$TMP/drift_lines.json"

  # Anchors for the NEXT run's rerun decision: re-derive from the vault as it
  # stands right now, the same sources vault-drift.sh itself matches against.
  vault_records "$VAULT" "$TMP/recs.ndjson"
  "$JQ" -r "$JQ_FLOW_ITEMS"'.governs | flow_items[]?' "$TMP/recs.ndjson" 2>/dev/null | sort -u > "$TMP/anchored_globs.txt"
  "$JQ" -r --arg pathre "$PATHRE" '
    (.surface.entries // [])[] | .spath as $raw
    | select($raw != "") | select(($raw|contains("...")) | not) | select($raw | test($pathre))
    | ($raw | split(":")[0])
  ' "$TMP/recs.ndjson" 2>/dev/null | sort -u > "$TMP/anchored_paths.txt"
  "$JQ" -R -s 'split("\n") | map(select(length>0))' "$TMP/anchored_paths.txt" > "$TMP/anchored_paths.json"
  "$JQ" -R -s 'split("\n") | map(select(length>0))' "$TMP/anchored_globs.txt" > "$TMP/anchored_globs.json"

  RECHECK_DUE=$("$JQ" -r '.by_code.MARKER_RECHECK_DUE // 0' "$TMP/lint.json" 2>/dev/null); RECHECK_DUE=${RECHECK_DUE:-0}
  "$JQ" -r '.findings[]? | select(.code=="MARKER_RECHECK_DUE") | "\(.sev|ascii_upcase) \(.path):\(.line) \(.code) \(.msg)"' "$TMP/lint.json" 2>/dev/null > "$TMP/recheck_lines.txt"
  "$JQ" -R -s 'split("\n") | map(select(length>0))' "$TMP/recheck_lines.txt" > "$TMP/recheck_lines.json"

  FAIL=$("$JQ" -r '.fail // 0' "$TMP/lint.json" 2>/dev/null); FAIL=${FAIL:-0}
  WARN=$("$JQ" -r '.warn // 0' "$TMP/lint.json" 2>/dev/null); WARN=${WARN:-0}
  INFO=$("$JQ" -r '[.findings[]? | select(.sev=="info")] | length' "$TMP/lint.json" 2>/dev/null); INFO=${INFO:-0}
  OVERDUE=$("$JQ" -r '.overdue // 0' "$TMP/freshness.json" 2>/dev/null); OVERDUE=${OVERDUE:-0}
  DRIFTED=$("$JQ" -r '.drifted // 0' "$TMP/freshness.json" 2>/dev/null); DRIFTED=${DRIFTED:-0}

  if [ "$FAIL" -gt 0 ] || [ "$DRIFT_OPEN" -gt 0 ]; then
    COLOUR=red
  elif [ "$WARN" -gt 0 ] || [ "$OVERDUE" -gt 0 ] || [ "$RECHECK_DUE" -gt 0 ]; then
    COLOUR=yellow
  else
    COLOUR=green
  fi

  PREV_COUNTS=null
  [ -f "$CACHE" ] && PREV_COUNTS=$("$JQ" -c '.counts // null' "$CACHE" 2>/dev/null) && [ -n "$PREV_COUNTS" ] || PREV_COUNTS=null

  HEAD_NOW=$(git -C "$REPO" rev-parse HEAD 2>/dev/null)
  DSIG_NOW=$(dirty_sig)
  GEN_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  "$JQ" -n \
    --argjson version 1 \
    --arg head "$HEAD_NOW" \
    --arg vault_tree "$VAULT" \
    --arg dirty_sig "$DSIG_NOW" \
    --argjson prev_counts "$PREV_COUNTS" \
    --slurpfile LINT "$TMP/lint.json" \
    --slurpfile FRESH "$TMP/freshness.json" \
    --slurpfile AP "$TMP/anchored_paths.json" \
    --slurpfile AG "$TMP/anchored_globs.json" \
    --slurpfile DL "$TMP/drift_lines.json" \
    --slurpfile RL "$TMP/recheck_lines.json" \
    --argjson fail "$FAIL" --argjson warn "$WARN" --argjson info "$INFO" \
    --argjson drift_open "$DRIFT_OPEN" --argjson overdue "$OVERDUE" \
    --argjson drifted "$DRIFTED" --argjson recheck_due "$RECHECK_DUE" \
    --arg colour "$COLOUR" \
    --arg generated "$GEN_TS" \
    '{
      version: $version,
      head: $head,
      vault_tree: $vault_tree,
      anchored_paths: $AP[0],
      anchored_globs: $AG[0],
      dirty_sig: $dirty_sig,
      counts: {fail: $fail, warn: $warn, info: $info, drift_open: $drift_open,
               overdue: $overdue, drifted: $drifted, recheck_due: $recheck_due},
      by_code: ($LINT[0].by_code // {}),
      colour: $colour,
      prev_counts: $prev_counts,
      findings: ($LINT[0].findings // []),
      drift_lines: $DL[0],
      freshness_rows: ($FRESH[0].rows // []),
      recheck_lines: $RL[0],
      generated: $generated
    }' > "$TMP/cache.new.json"
  mv "$TMP/cache.new.json" "$CACHE"
  rmdir "$LOCK" 2>/dev/null
fi

# --- output ---------------------------------------------------------------
[ -f "$CACHE" ] || { [ "$HOOK" -eq 1 ] && exit 0 || { echo "vault-audit: no cache and nothing to run" >&2; exit 2; }; }

if [ "$HOOK" -eq 1 ]; then
  LINE=$("$JQ" -r --arg base "$(basename "$REPO")" \
    --arg script "bash ~/.claude/skills/capture-documentation/scripts/vault-audit.sh" '
    def term(n; word; prevn):
      (if (prevn != null) and (n > prevn)
       then ((n|tostring) + " " + word + " (+" + ((n - prevn)|tostring) + ")")
       else ((n|tostring) + " " + word) end);
    .counts as $c | (.prev_counts // null) as $p |
    (
      if (.colour == "red") then true
      elif ($p == null) then false
      else (
        ($c.fail > ($p.fail // 0)) or
        ($c.warn > ($p.warn // 0)) or
        ($c.drift_open > ($p.drift_open // 0)) or
        ($c.overdue > ($p.overdue // 0)) or
        ($c.recheck_due > ($p.recheck_due // 0))
      )
      end
    ) as $should |
    if $should then
      "vault-audit (" + $base + "): " + (.colour|ascii_upcase) + " - " +
      term($c.fail; "FAIL"; ($p.fail // null)) + ", " +
      term($c.warn; "WARN"; ($p.warn // null)) + ", " +
      term($c.drift_open; "drift flags"; ($p.drift_open // null)) + ", " +
      term($c.overdue; "reviews overdue"; ($p.overdue // null)) + ", " +
      term($c.recheck_due; "rechecks due"; ($p.recheck_due // null)) + ". Run: " + $script
    else "" end
  ' "$CACHE" 2>/dev/null)
  [ -n "$LINE" ] && printf '%s\n' "$LINE"
  exit 0
fi

if [ "$FORMAT" = json ]; then
  cat "$CACHE"
  COLOUR=$("$JQ" -r '.colour // "green"' "$CACHE")
  [ "$COLOUR" = "red" ] && exit 1
  exit 0
fi

# text format
"$JQ" -r --arg base "$(basename "$REPO")" '
  def term(n; word; prevn):
    (if (prevn != null) and (n > prevn)
     then ((n|tostring) + " " + word + " (+" + ((n - prevn)|tostring) + ")")
     else ((n|tostring) + " " + word) end);
  .counts as $c | (.prev_counts // null) as $p |
  "vault-audit (" + $base + "): " + (.colour|ascii_upcase) + " - " +
  term($c.fail; "FAIL"; ($p.fail // null)) + ", " +
  term($c.warn; "WARN"; ($p.warn // null)) + ", " +
  term($c.drift_open; "drift flags"; ($p.drift_open // null)) + ", " +
  term($c.overdue; "reviews overdue"; ($p.overdue // null)) + ", " +
  term($c.recheck_due; "rechecks due"; ($p.recheck_due // null)) + "."
' "$CACHE"

"$JQ" -r '
  def cat:
    if (.code | test("^(LINK_|ANCHOR_|SUPERSEDED_BY_)")) then "links"
    elif (.code | test("^(BANNER_|SUPERSESSION_)")) then "banners"
    elif (.code | test("^SURFACE_")) then "anchors"
    elif (.code | test("^ORPHAN_")) then "orphans"
    else "other" end;
  (.findings // [])[] | . + {_cat: cat}
' "$CACHE" > "$TMP/findings_tagged.jsonl" 2>/dev/null

render_section() {
  local key="$1"
  local lines
  lines=$("$JQ" -r --arg k "$key" 'select(._cat==$k) | "\(.sev|ascii_upcase) \(.path):\(.line) \(.code) \(.msg)"' "$TMP/findings_tagged.jsonl" 2>/dev/null)
  if [ -n "$lines" ]; then
    printf -- '-- %s --\n' "$key"
    printf '%s\n' "$lines"
  fi
}
render_section links
render_section banners
render_section anchors
render_section orphans
render_section other

DRIFT_LINES=$("$JQ" -r '(.drift_lines // [])[]?' "$CACHE" 2>/dev/null)
if [ -n "$DRIFT_LINES" ]; then
  printf -- '-- drift flags --\n'
  printf '%s\n' "$DRIFT_LINES"
fi

FRESH_LINES=$("$JQ" -r '(.freshness_rows // [])[]? | "\(.reason)\t\(.path)\t\(.detail)"' "$CACHE" 2>/dev/null)
if [ -n "$FRESH_LINES" ]; then
  printf -- '-- freshness --\n'
  printf '%s\n' "$FRESH_LINES"
fi

RECHECK_LINES=$("$JQ" -r '(.recheck_lines // [])[]?' "$CACHE" 2>/dev/null)
if [ -n "$RECHECK_LINES" ]; then
  printf -- '-- rechecks due --\n'
  printf '%s\n' "$RECHECK_LINES"
fi

echo "Triage: ~/.claude/skills/capture-documentation/references/drift-triage.md"

COLOUR=$("$JQ" -r '.colour // "green"' "$CACHE")
[ "$COLOUR" = "red" ] && exit 1
exit 0
