#!/usr/bin/env zsh
# Script: launch.zsh
# Purpose: Create worktree and spawn Claude Code instance to execute a plan
# Usage: launch.zsh --small|--medium|--large [--base <branch>] <plan-file>

set -euo pipefail

# Colors using ANSI-C quoting
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
BLUE=$'\033[0;34m'
NC=$'\033[0m'

SCRIPT_DIR="${0:A:h}"
AGENTS_DIR="${SCRIPT_DIR}/../dependencies/system-prompts"

# Parse arguments
BASE_BRANCH="main"
TIER=""
PLAN_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --small|--medium|--large)
            TIER="$1"
            shift
            ;;
        --base)
            if [[ -z "${2:-}" ]]; then
                echo "${RED}--base requires a branch name${NC}"
                exit 1
            fi
            BASE_BRANCH="$2"
            shift 2
            ;;
        *)
            PLAN_FILE="$1"
            shift
            ;;
    esac
done

if [[ -z "$TIER" || -z "$PLAN_FILE" ]]; then
    echo "${RED}Usage: $0 --small|--medium|--large [--base <branch>] <plan-file>${NC}"
    exit 1
fi

case "$TIER" in
    --small)  MODEL="haiku" ;;
    --medium) MODEL="sonnet" ;;
    --large)  MODEL="opus" ;;
esac

# Resolve plan file to absolute path
PLAN_FILE="${PLAN_FILE:A}"

# Validate plan file exists
if [[ ! -f "$PLAN_FILE" ]]; then
    echo "${RED}[ERROR]${NC} Plan file not found: ${PLAN_FILE}"
    exit 1
fi

# Derive project root from plan file location
PROJECT_ROOT=$(git -C "$(dirname "$PLAN_FILE")" rev-parse --show-toplevel 2>/dev/null) || {
    echo "${RED}[ERROR]${NC} Plan file is not inside a git repository"
    exit 1
}

# Extract ticket key from plan filename (expects plan-TICKET-size.md)
FILENAME=$(basename "$PLAN_FILE" .md)
TICKET_KEY=$(echo "$FILENAME" | sed -E 's/^plan-([A-Z]+-[0-9]+)-.+$/\1/')

if [[ -z "$TICKET_KEY" || "$TICKET_KEY" == "$FILENAME" ]]; then
    echo "${RED}[ERROR]${NC} Could not extract ticket key from filename: ${FILENAME}"
    echo "        Expected format: plan-PROJ-123-small.md"
    exit 1
fi

echo "${BLUE}=== Task Planner Launcher ===${NC}"
echo "Tier:    ${TIER#--}"
echo "Model:   ${MODEL}"
echo "Ticket:  ${TICKET_KEY}"
echo "Plan:    ${PLAN_FILE}"
echo "Project: ${PROJECT_ROOT}"
echo ""

# Step 1: Create worktree
echo "${BLUE}[1/3]${NC} Creating worktree..."
WORKTREE_PATH=$("${SCRIPT_DIR}/create-worktree.zsh" "$PROJECT_ROOT" "$TICKET_KEY" "$BASE_BRANCH" | tail -1)

if [[ ! -d "$WORKTREE_PATH" ]]; then
    echo "${RED}[ERROR]${NC} Worktree creation failed"
    exit 1
fi

# Step 2: Copy plan file into worktree
echo "${BLUE}[2/3]${NC} Copying plan to worktree..."
mkdir -p "${WORKTREE_PATH}/plans"
cp "$PLAN_FILE" "${WORKTREE_PATH}/plans/"
PLAN_BASENAME=$(basename "$PLAN_FILE")

# Step 3: Spawn Claude Code instance
echo "${BLUE}[3/3]${NC} Spawning Claude Code (${MODEL})..."

if [[ "$TIER" == "--large" ]]; then
    # Large: Opus orchestrator with agent teams
    AGENT_FILE="${AGENTS_DIR}/orchestrator.md"
    echo "${YELLOW}[INFO]${NC} Using orchestrator agent with agent teams"
    (cd "$WORKTREE_PATH" && claude \
        --model "$MODEL" \
        --system-prompt-file "$AGENT_FILE" \
        -p "Execute the implementation plan at plans/${PLAN_BASENAME}") &
else
    # Small/Medium: Single implementer worker
    AGENT_FILE="${AGENTS_DIR}/implementer.md"
    echo "${YELLOW}[INFO]${NC} Using implementer agent"
    (cd "$WORKTREE_PATH" && claude \
        --model "$MODEL" \
        --system-prompt-file "$AGENT_FILE" \
        -p "Execute the implementation plan at plans/${PLAN_BASENAME}") &
fi

CLAUDE_PID=$!

echo ""
echo "${GREEN}[LAUNCHED]${NC} Claude Code running in background (PID: ${CLAUDE_PID})"
echo "Worktree: ${WORKTREE_PATH}"
echo "Plan:     ${WORKTREE_PATH}/plans/${PLAN_BASENAME}"
echo ""
echo "Monitor with: ps -p ${CLAUDE_PID}"
echo "Kill with:    kill ${CLAUDE_PID}"

# Optionally set tmux pane title if in tmux
if [[ -n "${TMUX:-}" ]]; then
    tmux rename-window "${TICKET_KEY}" 2>/dev/null || true
fi

exit 0