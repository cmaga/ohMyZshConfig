# vault-lib.sh -- shared helpers for vault-drift.sh, vault-freshness.sh, and
# gen-vault-rules.sh. Sourced, not executed. Keeps merge_schema, PATHRE, and
# the pass-2 symbol-identifier extraction byte-identical to lint-vault.sh so
# all four scripts agree on what counts as a path or a checkable identifier.
set -u
export LC_ALL=C

JQ=${JQ:-$(command -v jq || echo /usr/bin/jq)}
TAB=$(printf '\t')
PATHRE='^[A-Za-z0-9_.@-]+/[^ ]*[A-Za-z0-9_]$'

vault_today() { printf '%s\n' "${VAULT_TODAY:-$(date +%Y-%m-%d)}"; }

# vault_merge_schema VAULT OUT -- identical to lint-vault.sh's merge_schema().
# HERE is set by the sourcing script, pointing at this same scripts/ dir.
vault_merge_schema() {
  local vault="$1" out="$2"
  if [ -f "$vault/.vault-lint.json" ]; then
    "$JQ" -s '.[0] * .[1]' "$HERE/vault-schema.json" "$vault/.vault-lint.json" > "$out"
  else
    cp "$HERE/vault-schema.json" "$out"
  fi
}

# vault_records VAULT OUT -- pass-1 NDJSON via lint-vault.sh --records.
vault_records() {
  local vault="$1" out="$2"
  bash "$HERE/lint-vault.sh" --records "$vault" > "$out"
}

# git_dir_abs REPO FLAG -- absolutise a (possibly worktree-relative) git-dir query.
git_dir_abs() {
  local repo="$1" flag="$2" d
  d=$(git -C "$repo" rev-parse "$flag") || return 1
  case "$d" in
    /*) printf '%s\n' "$d" ;;
    *) printf '%s\n' "$repo/$d" ;;
  esac
}

# sym_ident(sym) -- lint-vault.sh pass2()'s identifier extraction+validation
# (strip from the first "(", after the last "." and ":", from the first
# space; identifier-shaped, not file-name-shaped), as an awk function so
# vault-drift.sh's vanished-symbol probe agrees with what the linter treats
# as a checkable identifier without one subprocess per symbol row.
read -r -d '' AWK_SYM_IDENT <<'EOF' || true
function sym_ident(sym,  s, i) {
  if (index(sym, "/")) return ""
  s = sym
  i = index(s, "("); if (i) s = substr(s, 1, i - 1)
  if (match(s, /.*\./)) s = substr(s, RLENGTH + 1)
  if (match(s, /.*:/)) s = substr(s, RLENGTH + 1)
  i = index(s, " "); if (i) s = substr(s, 1, i - 1)
  if (s !~ /^[A-Za-z_$][A-Za-z0-9_$-]*$/) return ""
  if (sym ~ /^[A-Za-z0-9_.-]+\.[a-z][a-z]?[a-z]?[a-z]?$/) return ""
  return s }
EOF

# flow_items: normalises a raw flow-list string (e.g. "[a, b]") or an actual
# JSON array into a clean array of strings; anything else yields [].
read -r -d '' JQ_FLOW_ITEMS <<'EOF' || true
def flow_items: if type == "array" then . elif type == "string" and test("^\\[.*\\]$") then ([.[1:-1] | scan("\\s*(\"[^\"]*\"|'[^']*'|[^,]+)") | .[0]] | map(gsub("^ +| +$"; "") | gsub("^[\"']|[\"']$"; "")) | map(select(. != ""))) else [] end;
EOF

# glob2ere(g) -- translates a vault-style glob (literal, *, ?, **, **/) into a
# POSIX ERE anchored with ^...$. A literal path passes through unchanged apart
# from metachar escaping, so this one function serves both globs and files.
read -r -d '' AWK_GLOB2ERE <<'EOF' || true
function glob2ere(g,  o) { o = g
  gsub(/[.+^$(){}|\[\]\\]/, "\\\\&", o)
  gsub(/\*\*\//, "\001", o); gsub(/\*\*/, "\002", o)
  gsub(/\*/, "[^/]*", o); gsub(/\?/, "[^/]", o)
  gsub(/\001/, "(.*/)?", o); gsub(/\002/, ".*", o)
  return "^" o "$" }
EOF
