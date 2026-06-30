#!/usr/bin/env zsh
# Post or update a single day's Harvest entry. Used by the standup skill (interactive
# `done` and the headless fill the reconciler triggers). Never submits.
#
# Usage: harvest-post.zsh <YYYY-MM-DD> [--note "text"] [--hours H] [--force]
#
#   no entry for the day      -> create with hours (default base) + note
#   entry exists, --force     -> overwrite the note (interactive `done`); hours untouched
#   entry exists, no --force  -> fill mode: set the note only if it is currently empty,
#                                otherwise leave it alone (preserves reviewed/manual days)
#
# Hours on an existing entry are never changed here — the weekly reconciler owns hours.

set -uo pipefail

SCRIPT_PATH="${(%):-%x}"
SCRIPT_DIR="${SCRIPT_PATH:A:h}"
source "${SCRIPT_DIR}/harvest-lib.zsh"

DATE="" NOTE="" HOURS="" FORCE=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --note)  NOTE="$2"; shift 2 ;;
        --hours) HOURS="$2"; shift 2 ;;
        --force) FORCE=1; shift ;;
        *)       DATE="$1"; shift ;;
    esac
done

if [[ ! "$DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "harvest-post: invalid or missing date '$DATE' (expected YYYY-MM-DD)" >&2
    exit 2
fi

TOML=$(resolve_toml)
PROJECT_NAME=$(_toml_string project_name "$TOML")
TASK_NAME=$(_toml_string task_name "$TOML")
BASE_HOURS=$(_toml_int default_hours "$TOML"); BASE_HOURS=${BASE_HOURS:-7}
[[ -n "$HOURS" ]] || HOURS="$BASE_HOURS"

require_credentials || exit 1
resolve_project_task "$PROJECT_NAME" "$TASK_NAME" || exit 1

id=$(entry_id_for_date "$DATE") || { echo "harvest-post: lookup failed for $DATE" >&2; exit 1; }

if [[ -z "$id" ]]; then
    payload=$(jq -n --argjson p "$PROJECT_ID" --argjson t "$TASK_ID" \
        --arg d "$DATE" --argjson h "$HOURS" --arg n "$NOTE" \
        '{project_id:$p, task_id:$t, spent_date:$d, hours:$h, notes:$n}')
    if harvest_api POST "/time_entries" "$payload" >/dev/null; then
        echo "create $DATE ${HOURS}h"
    else
        echo "ERROR  $DATE (create failed)" >&2; exit 1
    fi
    exit 0
fi

# Entry exists. One GET; a locked (submitted/approved) entry is never touched, even with --force.
entry=$(harvest_api GET "/time_entries/${id}")
if [[ "$(print -r -- "$entry" | jq -r '.is_locked')" == "true" ]]; then
    echo "skip   $DATE (locked)"
    exit 0
fi
existing_note=$(print -r -- "$entry" | jq -r '.notes // ""')
if [[ "$FORCE" -ne 1 && -n "$existing_note" ]]; then
    echo "skip   $DATE (note present)"
    exit 0
fi
if [[ -z "$NOTE" ]]; then
    echo "skip   $DATE (no note to write)"
    exit 0
fi

payload=$(jq -n --arg n "$NOTE" '{notes:$n}')
if harvest_api PATCH "/time_entries/${id}" "$payload" >/dev/null; then
    echo "note   $DATE (updated)"
else
    echo "ERROR  $DATE (note update failed)" >&2; exit 1
fi
