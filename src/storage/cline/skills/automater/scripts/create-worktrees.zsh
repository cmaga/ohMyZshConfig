#!/usr/bin/env zsh
# Script: create-worktrees.zsh
# Purpose: Create git worktrees for ticket implementation with proper error handling
# Usage: create-worktrees.zsh <ticket_key> [ticket_key...]

set -euo pipefail

# Colors using ANSI-C quoting for cross-platform compatibility
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
BLUE=$'\033[0;34m'
NC=$'\033[0m'

# Hardcoded configuration
WORKTREE_DIR="./wt"
PR_TARGET="main"

# Validate arguments
if [[ $# -lt 1 ]]; then
    echo "${RED}Usage: $0 <ticket_key> [ticket_key...]${NC}"
    exit 1
fi

TICKET_KEYS=("$@")

# Track results
declare -A RESULTS
FAILED=0

# Create worktrees
for TICKET_KEY in "${TICKET_KEYS[@]}"; do
    echo "${BLUE}Creating worktree for ${TICKET_KEY}...${NC}"
    
    # Branch name is just the ticket key
    BRANCH="${TICKET_KEY}"
    WORKTREE_PATH="${WORKTREE_DIR}/${TICKET_KEY}"
    
    # Check if worktree already exists
    if [[ -d "$WORKTREE_PATH" ]]; then
        echo "${YELLOW}[SKIP]${NC} Worktree already exists: ${WORKTREE_PATH}"
        RESULTS[$TICKET_KEY]="exists"
        continue
    fi
    
    # Check for branch name conflicts
    # A branch can't be created if it's a prefix of an existing branch or vice versa
    CONFLICTING_BRANCH=$(git --no-pager branch -l "${BRANCH}/*" --format='%(refname:short)' 2>/dev/null | head -1)
    if [[ -n "$CONFLICTING_BRANCH" ]]; then
        echo "${RED}[ERROR]${NC} Cannot create branch '${BRANCH}'"
        echo "        Conflicting branch exists: ${CONFLICTING_BRANCH}"
        echo "        Git doesn't allow a branch that is a prefix of another branch."
        echo ""
        echo "        Options:"
        echo "        1. Delete the conflicting branch: git branch -d '${CONFLICTING_BRANCH}'"
        RESULTS[$TICKET_KEY]="conflict"
        FAILED=$((FAILED + 1))
        continue
    fi
    
    # Check if branch already exists (can reuse it)
    EXISTING_BRANCH=$(git --no-pager branch -l "$BRANCH" --format='%(refname:short)' 2>/dev/null)
    
    if [[ -n "$EXISTING_BRANCH" ]]; then
        echo "${YELLOW}[INFO]${NC} Branch '${BRANCH}' already exists, creating worktree from it"
        if ! git worktree add "$WORKTREE_PATH" "$BRANCH" 2>&1; then
            echo "${RED}[ERROR]${NC} Failed to create worktree from existing branch"
            RESULTS[$TICKET_KEY]="failed"
            FAILED=$((FAILED + 1))
            continue
        fi
    else
        # Create new branch from PR target
        if ! git worktree add "$WORKTREE_PATH" -b "$BRANCH" "$PR_TARGET" 2>&1; then
            echo "${RED}[ERROR]${NC} Failed to create worktree for ${TICKET_KEY}"
            RESULTS[$TICKET_KEY]="failed"
            FAILED=$((FAILED + 1))
            continue
        fi
    fi
    
    # Copy environment and Cline configuration
    [[ -f ".envrc" ]] && cp ".envrc" "${WORKTREE_PATH}/.envrc"
    [[ -d ".cline-project" ]] && cp -r ".cline-project" "${WORKTREE_PATH}/.cline-project"
    [[ -d ".clinerules" ]] && cp -r ".clinerules" "${WORKTREE_PATH}/.clinerules"
    
    # Copy all .env* files preserving directory structure (handles monorepos)
    find . -name '.env*' -type f -not -path './.git/*' -not -path "./wt/*" | while read -r envfile; do
        dest_dir="${WORKTREE_PATH}/$(dirname "$envfile")"
        mkdir -p "$dest_dir"
        cp "$envfile" "$dest_dir/"
    done
    
    # Enable direnv for the worktree
    if [[ -f "${WORKTREE_PATH}/.envrc" ]] && command -v direnv &> /dev/null; then
        (cd "${WORKTREE_PATH}" && direnv allow 2>/dev/null) || true
    fi
    
    echo "${GREEN}[OK]${NC} Worktree created: ${WORKTREE_PATH}"
    RESULTS[$TICKET_KEY]="success"
done

# Summary
echo ""
echo "${BLUE}=== Worktree Creation Summary ===${NC}"
for TICKET_KEY in "${TICKET_KEYS[@]}"; do
    STATUS="${RESULTS[$TICKET_KEY]:-unknown}"
    case "$STATUS" in
        success)
            echo "${GREEN}[OK]${NC} ${TICKET_KEY}: ${WORKTREE_DIR}/${TICKET_KEY}"
            ;;
        exists)
            echo "${YELLOW}[SKIP]${NC} ${TICKET_KEY}: already exists"
            ;;
        conflict)
            echo "${RED}[CONFLICT]${NC} ${TICKET_KEY}: branch name conflict"
            ;;
        failed)
            echo "${RED}[FAILED]${NC} ${TICKET_KEY}: worktree creation failed"
            ;;
        *)
            echo "${RED}[UNKNOWN]${NC} ${TICKET_KEY}: unknown status"
            ;;
    esac
done

if [[ $FAILED -gt 0 ]]; then
    echo ""
    echo "${RED}${FAILED} worktree(s) failed to create${NC}"
    exit 1
fi

echo ""
echo "${GREEN}All worktrees created successfully${NC}"
exit 0