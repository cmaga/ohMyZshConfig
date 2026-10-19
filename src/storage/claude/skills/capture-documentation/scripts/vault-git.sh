#!/usr/bin/env bash
# vault-git.sh -- git mechanics for a local vault: a docs/project-knowledge
# the code repo ignores, kept as its own git repo with no remote. A tracked
# vault already branches and merges with the code, so every command here
# leaves it alone.
#
#   vault-git.sh sync REPO         start the vault's history; give a linked
#                                  worktree a vault worktree on a branch named
#                                  after its code branch; merge each vault
#                                  branch whose code has landed
#   vault-git.sh --hook            sync from a hook's JSON (PostToolUse on
#                                  EnterWorktree); vault-audit.sh --hook runs
#                                  sync at SessionStart
#   vault-git.sh status VAULT      the vault's uncommitted files
#   vault-git.sh commit VAULT MSG  commit a local vault's changes
#
# sync prints one "vault:" line per event and nothing otherwise, so its
# output reads as hook context.
set -u
export LC_ALL=C
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/vault-lib.sh"

usage() {
  echo "usage: vault-git.sh sync REPO | --hook | status VAULT | commit VAULT MESSAGE" >&2
  exit 2
}

# main_checkout REPO -- the repo's main worktree, whose vault holds main.
main_checkout() {
  git -C "$1" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print substr($0,10); exit}'
}

# mainline MAIN -- the code a branch has landed in: origin's default branch
# when known, else whatever the main checkout has checked out.
mainline() {
  git -C "$1" rev-parse -q --verify refs/remotes/origin/HEAD 2>/dev/null ||
    git -C "$1" rev-parse -q --verify HEAD 2>/dev/null
}

start_history() {
  local v="$1"
  git -C "$v" init -q -b main >/dev/null 2>&1 || return 1
  grep -qxF '.cache/' "$v/.gitignore" 2>/dev/null || printf '.cache/\n' >> "$v/.gitignore"
  git -C "$v" add -A && git -C "$v" commit -q -m "Start the vault history" >/dev/null || return 1
  echo "vault: $VAULT_REL now keeps its own git history (local only, no remote)"
}

# pair REPO MV -- a linked worktree gets the vault on a branch named after its
# code branch. The code branch's fork point is recorded, so a branch with no
# commits of its own never counts as landed.
pair() {
  local repo="$1" mv="$2" wv="$1/$VAULT_REL" b vm
  [ -e "$wv" ] && return 0
  b=$(git -C "$repo" symbolic-ref -q --short HEAD) || return 0
  vm=$(git -C "$mv" symbolic-ref -q --short HEAD) || return 0
  mkdir -p "$(dirname "$wv")"
  if git -C "$mv" show-ref -q --verify "refs/heads/$b"; then
    git -C "$mv" worktree add -q "$wv" "$b" >/dev/null 2>&1 || return 0
  else
    git -C "$mv" worktree add -q -b "$b" "$wv" "$vm" >/dev/null 2>&1 || return 0
  fi
  git -C "$mv" config "vault.$b.base" >/dev/null 2>&1 ||
    git -C "$mv" config "vault.$b.base" "$(git -C "$repo" merge-base HEAD "$(mainline "$(main_checkout "$repo")")")"
  bash "$HERE/lint-vault.sh" --digest-write "$wv" >/dev/null 2>&1
  echo "vault: this worktree's vault is on vault branch $b; it merges into the vault's $vm when the code lands"
}

in_use() { git -C "$1" worktree list --porcelain | grep -qxF "branch refs/heads/$2"; }
drop() { git -C "$1" branch -q -d "$2" 2>/dev/null && git -C "$1" config --unset "vault.$2.base" 2>/dev/null; return 0; }

# land MAIN MV -- merge each vault branch whose code branch is fully in the
# mainline (by patch, so rebased landings count) into the vault's main.
land() {
  local main="$1" mv="$2" up vm b base tip
  up=$(mainline "$main") || return 0
  vm=$(git -C "$mv" symbolic-ref -q --short HEAD) || return 0
  git -C "$mv" worktree prune
  git -C "$mv" for-each-ref --format='%(refname:short)' refs/heads |
  while IFS= read -r b; do
    [ "$b" = "$vm" ] && continue
    if git -C "$mv" merge-base --is-ancestor "$b" "$vm"; then
      in_use "$mv" "$b" || drop "$mv" "$b"
      continue
    fi
    if ! git -C "$main" show-ref -q --verify "refs/heads/$b"; then
      echo "vault: vault branch $b has notes but its code branch is gone; ask the user whether to merge it (git -C $mv merge --no-ff $b) or drop it (git -C $mv branch -D $b)"
      continue
    fi
    tip=$(git -C "$main" rev-parse "refs/heads/$b")
    base=$(git -C "$mv" config "vault.$b.base") || continue
    [ "$tip" = "$base" ] && continue
    git -C "$main" cherry "$up" "$tip" | grep -q '^+' && continue
    # Someone is editing the vault's main; the next session merges instead.
    [ -z "$(git -C "$mv" status --porcelain)" ] || continue
    if git -C "$mv" merge -q --no-ff -m "Merge vault branch $b; its code has landed" "$b" >/dev/null 2>&1; then
      echo "vault: merged vault branch $b; its code has landed"
      in_use "$mv" "$b" || drop "$mv" "$b"
    else
      git -C "$mv" merge --abort >/dev/null 2>&1
      echo "vault: vault branch $b conflicts with the vault's $vm; tell the user, who merges it by hand (git -C $mv merge --no-ff $b)"
    fi
  done
}

sync() {
  local repo main mv lock
  repo=$(git -C "$1" rev-parse --show-toplevel 2>/dev/null) || return 0
  repo=$(cd "$repo" && pwd -P) || return 0
  main=$(main_checkout "$repo")
  main=$(cd "${main:-/nonexistent}" 2>/dev/null && pwd -P) || return 0
  mv="$main/$VAULT_REL"
  [ -d "$mv" ] || return 0
  git -C "$main" check-ignore -q "$VAULT_REL" || return 0
  [ -z "$(git -C "$main" ls-files -- "$VAULT_REL" | head -n 1)" ] || return 0
  vault_is_local "$mv" || start_history "$mv" || return 0
  # Sessions starting together take turns; a lock left by a killed run expires.
  lock="$(git_dir_abs "$mv" --git-dir)/vault-sync.lock"
  find "$lock" -maxdepth 0 -mmin +10 -exec rmdir {} \; 2>/dev/null
  mkdir "$lock" 2>/dev/null || return 0
  trap "rmdir '$lock' 2>/dev/null" EXIT
  [ "$repo" = "$main" ] || pair "$repo" "$mv"
  land "$main" "$mv"
}

case "${1:-}" in
  sync)
    [ -n "${2:-}" ] || usage
    sync "$2" ;;
  --hook)
    in=$(cat)
    dir=$(printf '%s' "$in" | "$JQ" -r '.tool_response.worktreePath // .tool_response.worktree_path // .tool_response.path // .cwd // empty' 2>/dev/null)
    [ -n "$dir" ] && [ -d "$dir" ] || dir=$PWD
    out=$(sync "$dir")
    [ -n "$out" ] && "$JQ" -n --arg c "$out" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $c}}'
    exit 0 ;;
  status)
    [ -d "${2:-}" ] || usage
    v=$(cd "$2" && pwd -P)
    if vault_is_local "$v"; then git -C "$v" status --short
    else git -C "$(vault_code_repo "$v")" status --short -- "$v"; fi ;;
  commit)
    [ -d "${2:-}" ] && [ -n "${3:-}" ] || usage
    v=$(cd "$2" && pwd -P)
    vault_is_local "$v" || { echo "vault-git: this vault is committed with the code; the caller commits it"; exit 0; }
    git -C "$v" add -A || exit 1
    git -C "$v" diff --cached --quiet && { echo "vault-git: nothing to commit"; exit 0; }
    git -C "$v" commit -q -m "$3" && git -C "$v" log -1 --format='vault-git: committed %h %s' ;;
  *) usage ;;
esac
