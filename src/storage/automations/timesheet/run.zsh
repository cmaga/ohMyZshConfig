#!/usr/bin/env zsh
# Sunday timesheet reconciler (launchd; schedule in ./automation.toml).
# 1) Fill any unposted day of the just-ended week via the standup skill (headless, no review).
# 2) Square the week's hours to weekly_target.

set -uo pipefail

SCRIPT_PATH="${(%):-%x}"
SCRIPT_DIR="${SCRIPT_PATH:A:h}"
TOML="$SCRIPT_DIR/automation.toml"

# launchd ships a minimal PATH; rebuild enough to find curl, jq, security, and claude.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin:$HOME/bin:$PATH"
if [[ -d "$HOME/.nvm/versions/node" ]]; then
    nvm_bin=$(/bin/ls -d "$HOME/.nvm/versions/node"/*/bin 2>/dev/null | tail -1)
    [[ -n "$nvm_bin" ]] && export PATH="$nvm_bin:$PATH"
fi

source "${SCRIPT_DIR}/harvest-lib.zsh"
ENABLED=$(_toml_bool enabled "$TOML")
REPO_PATH=$(_toml_string repo_path "$TOML")

[[ "$ENABLED" != "true" ]] && exit 0
if [[ -z "$REPO_PATH" || "$REPO_PATH" == "/CHANGEME" || ! -d "$REPO_PATH" ]]; then
    echo "timesheet: repo_path invalid in $TOML" >&2
    exit 1
fi

log() { print -- "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# 1) Fill unposted days of the week (normally Friday + Saturday) via the standup skill,
#    headless and un-reviewed — the user eyeballs them at the Monday-morning glance.
log "filling unposted days via standup skill"
cd "$REPO_PATH"
claude -p "/standup auto" --dangerously-skip-permissions 2>&1 | sed 's/^/  standup: /'

# 2) Square the week to the weekly target.
log "reconciling week"
"$SCRIPT_DIR/reconcile.zsh"
rc=$?
log "done (reconcile exit $rc)"
exit "$rc"
