#!/usr/bin/env zsh
# Shared helpers for the timesheet automation.
# Sourced by harvest-post.zsh, reconcile.zsh, and run.zsh.

HARVEST_BASE="https://api.harvestapp.com/v2"
HARVEST_UA="cmagana-timesheet/1.0 (hichris12009@gmail.com)"

# --- TOML parsing (regex-grade, matches standup's run.zsh) ---
_toml_string() {
    local key="$1" file="$2"
    grep -E "^${key}[[:space:]]*=" "$file" 2>/dev/null \
        | sed -E "s/^${key}[[:space:]]*=[[:space:]]*\"([^\"]*)\".*/\1/" \
        | head -1
}

_toml_bool() {
    local key="$1" file="$2"
    grep -E "^${key}[[:space:]]*=" "$file" 2>/dev/null \
        | sed -E "s/^${key}[[:space:]]*=[[:space:]]*(true|false).*/\1/" \
        | head -1
}

_toml_int() {
    local key="$1" file="$2"
    grep -E "^${key}[[:space:]]*=" "$file" 2>/dev/null \
        | sed -E "s/^${key}[[:space:]]*=[[:space:]]*([0-9]+).*/\1/" \
        | head -1
}

# Resolve the automation's automation.toml — sibling of this lib.
resolve_toml() {
    local lib_path="${(%):-%x}"
    local lib_dir="${lib_path:A:h}"
    print -- "${lib_dir}/automation.toml"
}

# --- Credentials (chmod-600 env file) ---
HARVEST_ENV_FILE="${HARVEST_ENV_FILE:-$HOME/.config/harvest/env}"

require_credentials() {
    if [[ ! -f "$HARVEST_ENV_FILE" ]]; then
        cat >&2 <<EOF
timesheet: Harvest credentials not found at $HARVEST_ENV_FILE.
Create the file with:
  mkdir -p "${HARVEST_ENV_FILE:h}" && chmod 700 "${HARVEST_ENV_FILE:h}"
  printf 'HARVEST_TOKEN=%s\nHARVEST_ACCOUNT_ID=%s\n' "<token>" "<account-id>" > "$HARVEST_ENV_FILE"
  chmod 600 "$HARVEST_ENV_FILE"
Create a PAT at https://id.getharvest.com/developers
EOF
        return 1
    fi
    local perms
    perms=$(stat -f '%A' "$HARVEST_ENV_FILE" 2>/dev/null)
    if [[ -n "$perms" && "$perms" != "600" ]]; then
        echo "timesheet: $HARVEST_ENV_FILE has perms $perms; expected 600. Run: chmod 600 $HARVEST_ENV_FILE" >&2
        return 1
    fi
    HARVEST_TOKEN=$(grep -E '^HARVEST_TOKEN=' "$HARVEST_ENV_FILE" | head -1 | sed -E 's/^HARVEST_TOKEN=//')
    HARVEST_ACCOUNT_ID=$(grep -E '^HARVEST_ACCOUNT_ID=' "$HARVEST_ENV_FILE" | head -1 | sed -E 's/^HARVEST_ACCOUNT_ID=//')
    if [[ -z "$HARVEST_TOKEN" || -z "$HARVEST_ACCOUNT_ID" ]]; then
        echo "timesheet: $HARVEST_ENV_FILE missing HARVEST_TOKEN or HARVEST_ACCOUNT_ID" >&2
        return 1
    fi
}

# --- HTTP ---
# Args: METHOD PATH [JSON_DATA]
# Prints body on stdout. Returns non-zero on HTTP >= 400.
harvest_api() {
    local method="$1" endpoint="$2" data="${3:-}"
    local url="${HARVEST_BASE}${endpoint}"
    local tmp_body http_code
    tmp_body=$(mktemp)
    if [[ -n "$data" ]]; then
        http_code=$(curl -sS -o "$tmp_body" -w '%{http_code}' \
            -X "$method" \
            -H "Authorization: Bearer $HARVEST_TOKEN" \
            -H "Harvest-Account-Id: $HARVEST_ACCOUNT_ID" \
            -H "User-Agent: $HARVEST_UA" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "$url")
    else
        http_code=$(curl -sS -o "$tmp_body" -w '%{http_code}' \
            -X "$method" \
            -H "Authorization: Bearer $HARVEST_TOKEN" \
            -H "Harvest-Account-Id: $HARVEST_ACCOUNT_ID" \
            -H "User-Agent: $HARVEST_UA" \
            "$url")
    fi
    cat "$tmp_body"
    rm -f "$tmp_body"
    [[ "$http_code" -lt 400 ]]
}

# Sets PROJECT_ID and TASK_ID by matching names from automation.toml.
resolve_project_task() {
    local project_name="$1" task_name="$2" body
    body=$(harvest_api GET "/users/me/project_assignments") || {
        echo "timesheet: failed to fetch project assignments" >&2
        return 1
    }
    PROJECT_ID=$(print -r -- "$body" | jq -r --arg p "$project_name" \
        '[.project_assignments[] | select(.project.name == $p)][0].project.id // empty')
    TASK_ID=$(print -r -- "$body" | jq -r --arg p "$project_name" --arg t "$task_name" \
        '[.project_assignments[] | select(.project.name == $p) | .task_assignments[] | select(.task.name == $t)][0].task.id // empty')
    if [[ -z "$PROJECT_ID" ]]; then
        echo "timesheet: no project assignment matching '$project_name'" >&2
        return 1
    fi
    if [[ -z "$TASK_ID" ]]; then
        echo "timesheet: project '$project_name' has no task '$task_name'" >&2
        return 1
    fi
}

# --- Hours / date utilities ---

# Ceil a decimal-hours value up to the nearest 0.25. "8.1" -> "8.25", "8" -> "8.00".
round_up_quarter() {
    awk -v h="$1" 'BEGIN { q = h * 4; iq = int(q); if (q > iq + 1e-9) iq++; printf "%.2f", iq / 4 }'
}

# The just-ended Sun-Sat week as "START END" (YYYY-MM-DD), for the Sunday cron:
# start = 7 days ago (last Sunday), end = yesterday (Saturday).
prev_week_range() {
    print -- "$(date -v-7d '+%Y-%m-%d') $(date -v-1d '+%Y-%m-%d')"
}

# Find the time-entry id for a date under the resolved project/task (empty if none).
# Requires PROJECT_ID / TASK_ID set via resolve_project_task.
entry_id_for_date() {
    local d="$1" body
    body=$(harvest_api GET "/time_entries?from=${d}&to=${d}") || return 1
    print -r -- "$body" | jq -r --argjson p "$PROJECT_ID" --argjson t "$TASK_ID" \
        'first(.time_entries[] | select(.project.id == $p and .task.id == $t) | .id) // empty'
}
