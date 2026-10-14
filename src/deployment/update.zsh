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

git -C "$PROJECT_ROOT" pull -q --ff-only || error "Pull failed; resolve it in $PROJECT_ROOT, then run glc again"
head=$(git -C "$PROJECT_ROOT" rev-parse HEAD)
deployed=$(cat "$STATE_FILE" 2>/dev/null || true)

if [[ "$deployed" == "$head" ]]; then
    print_status "success" "Already deployed ${head:0:7}, nothing to do"
    exit 0
fi

touched() { print -r -- "$changed" | grep -qE "$1"; }

# Order matches `make deploy`: skill automations are read from ~/.claude/skills,
# so deploy-claude runs before deploy-automations.
ALL_TARGETS=(deploy-zsh deploy-git deploy-claude deploy-automations)
targets=()
if [[ -n "$deployed" ]] && git -C "$PROJECT_ROOT" cat-file -e "${deployed}^{commit}" 2>/dev/null; then
    changed=$(git -C "$PROJECT_ROOT" --no-pager diff --name-only "$deployed" "$head")
    if touched '^(Makefile|src/deployment/lib/)'; then
        targets=($ALL_TARGETS)
    else
        touched '^(src/storage/(zsh|bin|scripts)/|plugins\.txt$|src/deployment/04-)' && targets+=(deploy-zsh)
        touched '^(src/storage/git/|src/deployment/05-)' && targets+=(deploy-git)
        touched '^(src/storage/claude/|src/deployment/06-)' && targets+=(deploy-claude)
        touched '^(src/storage/automations/|src/storage/claude/skills/[^/]+/automation\.toml$|src/deployment/08-)' && targets+=(deploy-automations)
    fi
else
    targets=($ALL_TARGETS)
fi

if (( ! ${#targets} )); then
    print_status "success" "No deployable changes in ${deployed:0:7}..${head:0:7}"
else
    # Each target's full output goes to the log; only its warnings are shown,
    # or its last lines if it fails.
    LOG_FILE="${STATE_FILE:h}/deploy.log"
    : > "$LOG_FILE"
    for target in $targets; do
        print_status "info" "$target"
        # A fresh make reads the Makefile as pulled, not the one running this script.
        output=$(make --no-print-directory -C "$PROJECT_ROOT" "$target" 2>&1) && rc=0 || rc=$?
        print -r -- "$output" >> "$LOG_FILE"
        if (( rc )); then
            print -r -- "$output" | tail -n 10
            error "$target failed; full log: $LOG_FILE"
        fi
        print -r -- "$output" | grep -E '(WARNING:|\[WARN\])' || true
    done
    print_status "success" "Deployed ${head:0:7} (full log: $LOG_FILE)"
fi

print -r -- "$head" > "$STATE_FILE"
