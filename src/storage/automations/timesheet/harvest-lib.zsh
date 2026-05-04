#!/usr/bin/env zsh
# Shared helpers for the timesheet automation.
# Sourced by harvest-update.zsh, harvest-show.zsh, and run.zsh.

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

# --- Date helpers (BSD date on macOS) ---
# WEEK_OFFSET_DAYS shifts the resolved week (e.g. -7 = previous week) for backfills.
: ${WEEK_OFFSET_DAYS:=+0}
sunday_mmdd()    { date -v-Sun -v"${WEEK_OFFSET_DAYS}d" '+%m-%d'; }
weekday_iso()    { date -v-Sun -v"${WEEK_OFFSET_DAYS}d" -v+${1}d '+%Y-%m-%d'; }
weekday_mmdd()   { date -v-Sun -v"${WEEK_OFFSET_DAYS}d" -v+${1}d '+%m-%d'; }
weekday_short()  { date -v-Sun -v"${WEEK_OFFSET_DAYS}d" -v+${1}d '+%a'; }

# --- Standup paragraph extraction ---
# Args: standup_file day_short day_mmdd. Prints the paragraph (may be empty).
standup_paragraph() {
    local file="$1" day_short="$2" day_mmdd="$3"
    [[ -f "$file" ]] || return 0
    awk -v hdr="## $day_short $day_mmdd" '
        $0 == hdr { in_block = 1; next }
        in_block && /^## / { exit }
        in_block { lines[++n] = $0 }
        END {
            while (n > 0 && lines[n] ~ /^[[:space:]]*$/) n--
            start = 1
            while (start <= n && lines[start] ~ /^[[:space:]]*$/) start++
            for (i = start; i <= n; i++) print lines[i]
        }
    ' "$file"
}
