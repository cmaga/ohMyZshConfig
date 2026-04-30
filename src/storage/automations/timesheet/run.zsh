#!/usr/bin/env zsh
# Timesheet automation trigger. Invoked by launchd on the schedule in ./automation.toml.
# Calls harvest-update.zsh weekly directly — no Claude in the loop, since there's no judgment to make.

set -uo pipefail

SCRIPT_PATH="${(%):-%x}"
SCRIPT_DIR="${SCRIPT_PATH:A:h}"
TOML="$SCRIPT_DIR/automation.toml"

# launchd ships a minimal PATH; rebuild enough to find curl, jq, security.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin:$HOME/bin:$PATH"

toml_string() {
    grep -E "^$1[[:space:]]*=" "$TOML" 2>/dev/null \
        | sed -E "s/^$1[[:space:]]*=[[:space:]]*\"([^\"]*)\".*/\1/" \
        | head -1
}
toml_bool() {
    grep -E "^$1[[:space:]]*=" "$TOML" 2>/dev/null \
        | sed -E "s/^$1[[:space:]]*=[[:space:]]*(true|false).*/\1/" \
        | head -1
}

ENABLED=$(toml_bool enabled)
REPO_PATH=$(toml_string repo_path)

[[ "$ENABLED" != "true" ]] && exit 0
if [[ -z "$REPO_PATH" || "$REPO_PATH" == "/CHANGEME" ]]; then
    echo "timesheet: repo_path not configured in $TOML" >&2
    exit 0
fi
if [[ ! -d "$REPO_PATH" ]]; then
    echo "timesheet: repo_path '$REPO_PATH' is not a directory" >&2
    exit 1
fi

log() { print -- "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

TODAY_DAY=$(date '+%a')
case "$TODAY_DAY" in
    Sat|Sun) log "skip: weekend ($TODAY_DAY)"; exit 0 ;;
esac

log "running harvest-update.zsh weekly"
update_exit=0
"$SCRIPT_DIR/harvest-update.zsh" weekly || update_exit=$?
log "harvest-update.zsh exit $update_exit"
exit "$update_exit"
