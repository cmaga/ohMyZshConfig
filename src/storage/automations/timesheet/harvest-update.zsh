#!/usr/bin/env zsh
# Push 8h time entries to Harvest for this week's weekdays based on the standup file.
# Idempotent: skips days that already have an entry for the configured project/task.
# Never submits — created entries remain unsubmitted.
#
# Usage: harvest-update.zsh (daily|weekly)

set -uo pipefail

SCRIPT_PATH="${(%):-%x}"
SCRIPT_DIR="${SCRIPT_PATH:A:h}"
source "${SCRIPT_DIR}/harvest-lib.zsh"

MODE="${1:-weekly}"
case "$MODE" in
    daily|weekly) ;;
    *) echo "usage: $0 (daily|weekly)" >&2; exit 2 ;;
esac

TOML=$(resolve_toml)
REPO_PATH=$(_toml_string repo_path "$TOML")
PROJECT_NAME=$(_toml_string project_name "$TOML")
TASK_NAME=$(_toml_string task_name "$TOML")
DEFAULT_HOURS=$(_toml_int default_hours "$TOML")
DEFAULT_HOURS=${DEFAULT_HOURS:-8}

if [[ -z "$REPO_PATH" || -z "$PROJECT_NAME" || -z "$TASK_NAME" ]]; then
    echo "timesheet: automation.toml missing repo_path / project_name / task_name" >&2
    exit 1
fi

TODAY_DOW=$(date '+%w')
if [[ "$TODAY_DOW" == "0" || "$TODAY_DOW" == "6" ]]; then
    echo "Timesheet writes cover weekdays only."
    exit 0
fi

require_credentials || exit 1
resolve_project_task "$PROJECT_NAME" "$TASK_NAME" || exit 1

SUNDAY=$(sunday_mmdd)
STANDUP_FILE="$REPO_PATH/.claude-artifacts/workflows/standup/${SUNDAY}-week.md"

case "$MODE" in
    daily)  OFFSETS=("$TODAY_DOW") ;;
    weekly) OFFSETS=(1 2 3 4 5) ;;
esac

WEEK_START=$(weekday_iso 1)
WEEK_END=$(weekday_iso 5)
existing_body=$(harvest_api GET "/time_entries?from=${WEEK_START}&to=${WEEK_END}") || {
    echo "timesheet: failed to fetch existing entries" >&2
    exit 1
}
typeset -A EXISTING
while IFS= read -r d; do
    [[ -n "$d" ]] && EXISTING[$d]=1
done < <(print -r -- "$existing_body" | jq -r --argjson p "$PROJECT_ID" --argjson t "$TASK_ID" \
    '.time_entries[] | select(.project.id == $p and .task.id == $t) | .spent_date')

created=0
skipped=0
errors=0
for offset in "${OFFSETS[@]}"; do
    iso=$(weekday_iso "$offset")
    short=$(weekday_short "$offset")
    mmdd=$(weekday_mmdd "$offset")

    if [[ -n "${EXISTING[$iso]:-}" ]]; then
        print -- "skip   $short $iso (entry exists)"
        ((skipped++))
        continue
    fi

    notes=$(standup_paragraph "$STANDUP_FILE" "$short" "$mmdd")

    payload=$(jq -n \
        --argjson p "$PROJECT_ID" --argjson t "$TASK_ID" \
        --arg d "$iso" --argjson h "$DEFAULT_HOURS" --arg n "$notes" \
        '{project_id: $p, task_id: $t, spent_date: $d, hours: $h, notes: $n}')

    if harvest_api POST "/time_entries" "$payload" >/dev/null; then
        print -- "create $short $iso ${DEFAULT_HOURS}h"
        ((created++))
    else
        print -- "ERROR  $short $iso (POST failed)"
        ((errors++))
    fi
done

print -- "done: ${created} created, ${skipped} skipped, ${errors} errors"
[[ $errors -eq 0 ]]
