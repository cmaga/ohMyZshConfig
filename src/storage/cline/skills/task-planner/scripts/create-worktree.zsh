#!/usr/bin/env zsh
# Script: create-worktree.zsh
# Purpose: Create a git worktree for a single ticket
# Usage: create-worktree.zsh <ticket_key>

set -euo pipefail

# Colors using ANSI-C quoting
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
BLUE=$'\033[0;34m'
NC=$'\033[0m'

WORKTREE_DIR="./wt"
PR_TARGET="main"

if [[ $# -ne 1 ]]; then
    echo "${RED}Usage: $0 <ticket_key>${NC}"
    exit 1
fi

TICKET_KEY="$1"
BRANCH="${TICKET_KEY}"
WORKTREE_PATH="${WORKTREE_DIR}/${TICKET_KEY}"

# Check if worktree already exists
if [[ -d "$WORKTREE_PATH" ]]; then
    echo "${YELLOW}[SKIP]${NC} Worktree already exists: ${WORKTREE_PATH}"
    echo "$WORKTREE_PATH"
    exit 0
fi

# Check for branch name conflicts
CONFLICTING_BRANCH=$(git --no-pager branch -l "${BRANCH}/*" --format='%(refname:short)' 2>/dev/null | head -1)
if [[ -n "$CONFLICTING_BRANCH" ]]; then
    echo "${RED}[ERROR]${NC} Cannot create branch '${BRANCH}'"
    echo "        Conflicting branch exists: ${CONFLICTING_BRANCH}"
    echo "        Delete it first: git branch -d '${CONFLICTING_BRANCH}'"
    exit 1
fi

# Create worktree (reuse existing branch or create new)
EXISTING_BRANCH=$(git --no-pager branch -l "$BRANCH" --format='%(refname:short)' 2>/dev/null)

if [[ -n "$EXISTING_BRANCH" ]]; then
    echo "${YELLOW}[INFO]${NC} Branch '${BRANCH}' exists, creating worktree from it"
    if ! git worktree add "$WORKTREE_PATH" "$BRANCH" 2>&1; then
        echo "${RED}[ERROR]${NC} Failed to create worktree from existing branch"
        exit 1
    fi
else
    if ! git worktree add "$WORKTREE_PATH" -b "$BRANCH" "$PR_TARGET" 2>&1; then
        echo "${RED}[ERROR]${NC} Failed to create worktree for ${TICKET_KEY}"
        exit 1
    fi
fi

# Copy environment and configuration files
[[ -f ".envrc" ]] && cp ".envrc" "${WORKTREE_PATH}/.envrc"
[[ -d ".cline-project" ]] && cp -r ".cline-project" "${WORKTREE_PATH}/.cline-project"
[[ -d ".clinerules" ]] && cp -r ".clinerules" "${WORKTREE_PATH}/.clinerules"

# Copy all .env* files preserving directory structure
find . -name '.env*' -type f -not -path './.git/*' -not -path "./wt/*" | while read -r envfile; do
    dest_dir="${WORKTREE_PATH}/$(dirname "$envfile")"
    mkdir -p "$dest_dir"
    cp "$envfile" "$dest_dir/"
done

# Enable direnv
if [[ -f "${WORKTREE_PATH}/.envrc" ]] && command -v direnv &> /dev/null; then
    (cd "${WORKTREE_PATH}" && direnv allow 2>/dev/null) || true
fi

echo "${GREEN}[OK]${NC} Worktree created: ${WORKTREE_PATH}"
echo "$WORKTREE_PATH"
exit 0