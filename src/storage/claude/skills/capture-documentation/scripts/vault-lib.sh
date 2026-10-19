# vault-lib.sh -- shared helpers for vault-drift.sh, vault-freshness.sh, and
# gen-vault-rules.sh. Sourced, not executed. Keeps merge_schema, PATHRE, and
# the pass-2 symbol-identifier extraction byte-identical to lint-vault.sh so
# all four scripts agree on what counts as a path or a checkable identifier.
set -u
export LC_ALL=C

JQ=${JQ:-$(command -v jq || echo /usr/bin/jq)}
# A native Windows jq.exe writes CRLF unless given -b, and the stray CR breaks
# every downstream read; route "$JQ" through -b there.
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*)
  [ "$JQ" = jq_lf ] && JQ=$(command -v jq)
  JQ_BIN=$JQ; jq_lf() { "$JQ_BIN" -b "$@"; }; JQ=jq_lf ;;
esac
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

# A local vault is one the code repo ignores and that keeps its own git repo
# (vault-git.sh starts it), so a note's history lives in the vault, not in
# the code repo. A tracked vault is committed with the code.
VAULT_REL=docs/project-knowledge
vault_is_local() { [ -e "$1/.git" ]; }

# vault_code_repo DIR -- physical top level of the code repo for a path in a
# vault, stepping out of a local vault's own repo to the repo it sits in.
vault_code_repo() {
  local top outer
  top=$(git -C "$1" rev-parse --show-toplevel 2>/dev/null) || return 1
  top=$(cd "$top" && pwd -P) || return 1
  if outer=$(git -C "$top/.." rev-parse --show-toplevel 2>/dev/null) &&
     outer=$(cd "$outer" && pwd -P) && [ "$top" = "$outer/$VAULT_REL" ]; then
    top=$outer
  fi
  printf '%s\n' "$top"
}

# vault_history VAULT REPO -- sets HREPO, the repo holding the notes' history,
# and HPRE, the vault's path prefix inside it ("" for a local vault).
vault_history() {
  if vault_is_local "$1"; then HREPO=$1; HPRE=""
  else HREPO=$2; HPRE="${1#"$2"/}/"; fi
}

# vault_note_commit REPO VAULT NOTE -- the code commit NOTE was last written
# against. A tracked note's last commit is one; a local note maps its last
# vault commit on the first-parent line (a landed branch counts from its
# merge) to the code commit current at that time.
vault_note_commit() {
  local repo="$1" vault="$2" note="$3" t
  if vault_is_local "$vault"; then
    t=$(git -C "$vault" log -1 --first-parent --format=%ct -- "$note" 2>/dev/null)
    [ -n "$t" ] && git -C "$repo" rev-list -1 --before="@$t" HEAD 2>/dev/null
  else
    git -C "$repo" log -1 --format=%H -- "${vault#"$repo"/}/$note" 2>/dev/null
  fi
  return 0
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
