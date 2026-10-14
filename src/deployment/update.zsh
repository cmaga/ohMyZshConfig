#!/bin/zsh
# Pull this repo and run only the deploy targets whose files changed since the
# last update. The last deployed commit is kept in .git/deployed-head, so a
# failed deploy is retried on the next run and a manual `git pull` is still
# caught; a clone with no record gets a full deploy. glc (aliases.zsh) runs this.

set -e

SCRIPT_DIR="${0:A:h}"
source "${SCRIPT_DIR}/lib/common.zsh"

PROJECT_ROOT="${SCRIPT_DIR:h:h}"
STATE_FILE="$(git -C "$PROJECT_ROOT" rev-parse --absolute-git-dir)/deployed-head"

git -C "$PROJECT_ROOT" pull --ff-only || error "Pull failed; resolve it in $PROJECT_ROOT, then run glc again"
head=$(git -C "$PROJECT_ROOT" rev-parse HEAD)
deployed=$(cat "$STATE_FILE" 2>/dev/null || true)

if [[ "$deployed" == "$head" ]]; then
    print_status "success" "Already deployed ${head:0:7}, nothing to do"
    exit 0
fi

touched() { print -r -- "$changed" | grep -qE "$1"; }

# Order matches `make deploy`: skill automations are read from ~/.claude/skills,
# so deploy-claude runs before deploy-automations.
targets=()
if [[ -n "$deployed" ]] && git -C "$PROJECT_ROOT" cat-file -e "${deployed}^{commit}" 2>/dev/null; then
    changed=$(git -C "$PROJECT_ROOT" --no-pager diff --name-only "$deployed" "$head")
    if touched '^(Makefile|src/deployment/lib/)'; then
        targets=(deploy)
    else
        touched '^(src/storage/(zsh|bin|scripts)/|plugins\.txt$|src/deployment/04-)' && targets+=(deploy-zsh)
        touched '^(src/storage/git/|src/deployment/05-)' && targets+=(deploy-git)
        touched '^(src/storage/claude/|src/deployment/06-)' && targets+=(deploy-claude)
        touched '^(src/storage/automations/|src/storage/claude/skills/[^/]+/automation\.toml$|src/deployment/08-)' && targets+=(deploy-automations)
    fi
else
    targets=(deploy)
fi

if (( ${#targets} )); then
    print_status "info" "Deploying: ${targets[*]}"
    # A fresh make reads the Makefile as pulled, not the one running this script.
    make -C "$PROJECT_ROOT" "${targets[@]}"
else
    print_status "success" "No deployable changes in ${deployed:0:7}..${head:0:7}"
fi

print -r -- "$head" > "$STATE_FILE"
