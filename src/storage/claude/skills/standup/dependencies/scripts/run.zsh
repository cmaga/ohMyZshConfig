#!/usr/bin/env zsh
# Standup automation trigger. Invoked by launchd on the schedule in ../../automation.toml.
# Calls `claude -p "/standup write daily"` headless inside repo_path and lets the skill write the file.

set -uo pipefail

SCRIPT_PATH="${(%):-%x}"
SCRIPT_DIR="${SCRIPT_PATH:A:h}"
SKILL_DIR="${SCRIPT_DIR:h:h}"
TOML="$SKILL_DIR/automation.toml"

# launchd ships a minimal PATH; rebuild enough to find claude (installed via npm).
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin:$HOME/bin:$PATH"
if [[ -d "$HOME/.nvm/versions/node" ]]; then
    nvm_bin=$(/bin/ls -d "$HOME/.nvm/versions/node"/*/bin 2>/dev/null | tail -1)
    [[ -n "$nvm_bin" ]] && export PATH="$nvm_bin:$PATH"
fi

# --- parse automation.toml (regex-grade) ---
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
    echo "standup: repo_path not configured in $TOML" >&2
    exit 0
fi
if [[ ! -d "$REPO_PATH" ]]; then
    echo "standup: repo_path '$REPO_PATH' is not a directory" >&2
    exit 1
fi

# Log to stdout/stderr — launchd redirects to ~/Library/Logs/cmagana-automations/<name>.log
log() { print -- "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# --- compute paths and headers ---
ARTIFACT_DIR="$REPO_PATH/.claude-artifacts/workflows/standup"
mkdir -p "$ARTIFACT_DIR"

TODAY_DAY=$(date '+%a')
case "$TODAY_DAY" in
    Sat|Sun) log "skip: weekend ($TODAY_DAY)"; exit 0 ;;
esac

SUNDAY_MMDD=$(date -v-Sun '+%m-%d')
WEEK_FILE="$ARTIFACT_DIR/${SUNDAY_MMDD}-week.md"
TODAY_MMDD=$(date '+%m-%d')
TODAY_HEADER="## $TODAY_DAY $TODAY_MMDD"

# --- skip if today's entry already written ---
if [[ -f "$WEEK_FILE" ]] && grep -q "^$TODAY_HEADER\b" "$WEEK_FILE"; then
    log "skip: today's block already in $WEEK_FILE"
    exit 0
fi

# --- invoke claude ---
log "invoking claude in $REPO_PATH"
cd "$REPO_PATH"
claude_output=$(claude -p "/standup write daily" --dangerously-skip-permissions 2>&1)
claude_exit=$?
print -- "$claude_output"

# --- verify or stub ---
if [[ $claude_exit -ne 0 ]] || ! grep -q "^$TODAY_HEADER\b" "$WEEK_FILE" 2>/dev/null; then
    log "claude failed (exit $claude_exit) or block missing; writing stub"
    [[ -f "$WEEK_FILE" ]] || : > "$WEEK_FILE"
    {
        print --
        print -- "$TODAY_HEADER"
        print -- "[automation error: see ~/Library/Logs/cmagana-automations/standup.log]"
    } >> "$WEEK_FILE"
else
    log "success"
fi

# --- prune week files older than 14 days ---
find "$ARTIFACT_DIR" -maxdepth 1 -name '*-week.md' -type f -mtime +14 -delete 2>/dev/null || true
exit 0
