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

# --- Per-machine config (never in a repo) ---
# ~/.config/harvest/timesheet.toml holds what differs per machine and must not be
# published: the Harvest projects (client and contract names), their caps, the
# repos to read, and this machine's role. Without it, the automation runs in its
# original single-project form from automation.toml (project_name, repo_path).
#
#   projects        = "amazon va"      managed projects, by key
#   <key>_project   = "..."            Harvest project: name, code, or "[code] name"
#   <key>_task      = "..."            Harvest task under that project
#   <key>_cap       = 8                weekly hour cap; the one project without a
#                                      cap takes the rest of the week's target
#   fill_project    = "amz"            project this machine's standup posts to
#   repo_roots      = "~/workplace"    folders scanned for git repos (and repos)
#   exclude_repos   = "dotfiles"       repo folder names that are not client work
#   standup_dir     = "~/dev/x/.standup"  where the weekly standup files go
#   extra_activity  = "..."            extra instruction for gathering a day's work
#   reconcile       = true             this machine runs the Sunday reconcile
#   reconcile_after_fill = true        reconcile right after the Friday fill, for a
#                                      machine that is off at weekends; give it only
#                                      its own projects, all capped, so it sets those
#                                      and leaves the rest of the week to another
TIMESHEET_CONFIG="${TIMESHEET_CONFIG:-$HOME/.config/harvest/timesheet.toml}"

has_timesheet_config() { [[ -f "$TIMESHEET_CONFIG" ]]; }

# ts_string/ts_int/ts_bool KEY: the per-machine config, else automation.toml.
ts_string() {
    local v=""
    has_timesheet_config && v=$(_toml_string "$1" "$TIMESHEET_CONFIG")
    [[ -n "$v" ]] || v=$(_toml_string "$1" "$(resolve_toml)")
    print -r -- "${v/#\~/$HOME}"
}
ts_int() {
    local v=""
    has_timesheet_config && v=$(_toml_int "$1" "$TIMESHEET_CONFIG")
    [[ -n "$v" ]] || v=$(_toml_int "$1" "$(resolve_toml)")
    print -r -- "$v"
}
ts_bool() {
    local v=""
    has_timesheet_config && v=$(_toml_bool "$1" "$TIMESHEET_CONFIG")
    [[ -n "$v" ]] || v=$(_toml_bool "$1" "$(resolve_toml)")
    print -r -- "$v"
}

# Managed project keys. The original single-project form is one key, "default",
# whose project/task come from project_name/task_name.
project_keys() {
    local keys=$(ts_string projects)
    print -r -- "${keys:-default}"
}
project_name_for() { [[ "$1" == default ]] && ts_string project_name || ts_string "${1}_project"; }
task_name_for()    { [[ "$1" == default ]] && ts_string task_name    || ts_string "${1}_task"; }

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
    perms=$(stat -c '%a' "$HARVEST_ENV_FILE" 2>/dev/null || stat -f '%A' "$HARVEST_ENV_FILE" 2>/dev/null)
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

# Sets PROJECT_ID and TASK_ID from a project and task name. The project may be
# given as Harvest stores its name, as its code, or as "[code] name", which is
# how Harvest's UI shows it.
resolve_project_task() {
    local project_name="$1" task_name="$2" body
    body=$(harvest_api GET "/users/me/project_assignments?per_page=2000") || {
        echo "timesheet: failed to fetch project assignments" >&2
        return 1
    }
    local match='.project.name == $p or .project.code == $p or ("[" + (.project.code // "") + "] " + .project.name) == $p'
    PROJECT_ID=$(print -r -- "$body" | jq -r --arg p "$project_name" \
        "[.project_assignments[] | select($match)][0].project.id // empty")
    TASK_ID=$(print -r -- "$body" | jq -r --arg p "$project_name" --arg t "$task_name" \
        "[.project_assignments[] | select($match) | .task_assignments[] | select(.task.name == \$t)][0].task.id // empty")
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

# A date N days from today (negative for the past), YYYY-MM-DD. GNU date
# (Linux) and BSD date (macOS) spell this differently.
days_from_today() {
    local n="$1"
    [[ "$n" == [-+]* ]] || n="+$n"
    date -d "$n days" '+%Y-%m-%d' 2>/dev/null || date -v"${n}d" '+%Y-%m-%d'
}

# The Sun-Sat week to reconcile as "START END" (YYYY-MM-DD): the one holding the
# day before yesterday. That is this week on a Friday (the VA laptop's fill-and-
# reconcile), the just-ended one on Sunday, and still the just-ended one on a
# Monday, when a timer that missed Sunday (the machine was off) catches up.
prev_week_range() {
    local w=$(( ($(date +%w) + 5) % 7 ))   # weekday of the day before yesterday
    print -- "$(days_from_today $(( -2 - w ))) $(days_from_today $(( 4 - w )))"
}

# Find the time-entry id for a date under the resolved project/task (empty if none).
# Requires PROJECT_ID / TASK_ID set via resolve_project_task.
entry_id_for_date() {
    local d="$1" body
    body=$(harvest_api GET "/time_entries?from=${d}&to=${d}") || return 1
    print -r -- "$body" | jq -r --argjson p "$PROJECT_ID" --argjson t "$TASK_ID" \
        'first(.time_entries[] | select(.project.id == $p and .task.id == $t) | .id) // empty'
}
