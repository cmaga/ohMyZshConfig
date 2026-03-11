#!/usr/bin/env zsh
# Script: dispatch-tickets.zsh
# Purpose: Dispatch Cline CLI instances to execute implementation plans
# Usage: dispatch-tickets.zsh <ticket_key> [ticket_key...]

set -euo pipefail

# Colors using ANSI-C quoting for cross-platform compatibility
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
BLUE=$'\033[0;34m'
NC=$'\033[0m'

# Hardcoded configuration
WORKTREE_DIR="./wt"
PLAN_DIR=".cline-project/skills/automater/plans"

# Validate arguments
if [[ $# -lt 1 ]]; then
    echo "${RED}Usage: $0 <ticket_key> [ticket_key...]${NC}"
    exit 1
fi

TICKET_KEYS=("$@")

# Check if cline CLI is available
if ! command -v cline &> /dev/null; then
    echo "${RED}Cline CLI not found. Please install it first.${NC}"
    exit 1
fi

# Track PIDs and results
declare -A PIDS
declare -A RESULTS

echo "${BLUE}=== Dispatching Cline CLI Instances ===${NC}"
echo ""

# Dispatch CLI instances
for TICKET_KEY in "${TICKET_KEYS[@]}"; do
    WORKTREE_PATH="${WORKTREE_DIR}/${TICKET_KEY}"
    PLAN_PATH="${PLAN_DIR}/${TICKET_KEY}-plan.md"
    
    # Validate worktree exists
    if [[ ! -d "$WORKTREE_PATH" ]]; then
        echo "${RED}[ERROR]${NC} Worktree not found for ${TICKET_KEY}: ${WORKTREE_PATH}"
        RESULTS[$TICKET_KEY]="no_worktree"
        continue
    fi
    
    # Validate plan exists in worktree
    if [[ ! -f "${WORKTREE_PATH}/${PLAN_PATH}" ]]; then
        echo "${RED}[ERROR]${NC} Plan not found for ${TICKET_KEY}: ${WORKTREE_PATH}/${PLAN_PATH}"
        RESULTS[$TICKET_KEY]="no_plan"
        continue
    fi
    
    echo "${BLUE}[DISPATCH]${NC} ${TICKET_KEY} -> ${WORKTREE_PATH}"
    
    # Dispatch Cline CLI in background
    # Using -y for yolo mode (auto-approve)
    # Single-line prompt avoids shell escaping issues with multi-line strings
    cline -y --cwd "$WORKTREE_PATH" "Execute the implementation plan at ${PLAN_PATH}" &
    PIDS[$TICKET_KEY]=$!
    RESULTS[$TICKET_KEY]="running"
done

# Check if any instances were dispatched
DISPATCHED_COUNT=${#PIDS[@]}
if [[ $DISPATCHED_COUNT -eq 0 ]]; then
    echo ""
    echo "${RED}No CLI instances were dispatched${NC}"
    exit 1
fi

echo ""
echo "${BLUE}Dispatched ${DISPATCHED_COUNT} CLI instance(s). Waiting for completion...${NC}"
echo ""

# Wait for all instances and collect results
FAILED=0
for TICKET_KEY in "${(@k)PIDS}"; do
    PID="${PIDS[$TICKET_KEY]}"
    
    if wait "$PID"; then
        RESULTS[$TICKET_KEY]="success"
        echo "${GREEN}[DONE]${NC} ${TICKET_KEY} completed successfully"
    else
        EXIT_CODE=$?
        RESULTS[$TICKET_KEY]="failed:${EXIT_CODE}"
        echo "${RED}[FAILED]${NC} ${TICKET_KEY} exited with code ${EXIT_CODE}"
        FAILED=$((FAILED + 1))
    fi
done

# Final summary
echo ""
echo "${BLUE}=== Dispatch Summary ===${NC}"
for TICKET_KEY in "${TICKET_KEYS[@]}"; do
    STATUS="${RESULTS[$TICKET_KEY]:-unknown}"
    case "$STATUS" in
        success)
            echo "${GREEN}[OK]${NC} ${TICKET_KEY}: completed"
            ;;
        running)
            echo "${YELLOW}[RUNNING]${NC} ${TICKET_KEY}: still running"
            ;;
        no_worktree)
            echo "${RED}[SKIP]${NC} ${TICKET_KEY}: worktree not found"
            ;;
        no_plan)
            echo "${RED}[SKIP]${NC} ${TICKET_KEY}: plan not found"
            ;;
        failed:*)
            EXIT_CODE="${STATUS#failed:}"
            echo "${RED}[FAILED]${NC} ${TICKET_KEY}: exit code ${EXIT_CODE}"
            ;;
        *)
            echo "${RED}[UNKNOWN]${NC} ${TICKET_KEY}: ${STATUS}"
            ;;
    esac
done

if [[ $FAILED -gt 0 ]]; then
    echo ""
    echo "${RED}${FAILED} instance(s) failed${NC}"
    exit 1
fi

echo ""
echo "${GREEN}All instances completed successfully${NC}"
exit 0