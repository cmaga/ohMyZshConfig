#!/usr/bin/env zsh
# Sunday timesheet reconciler (launchd or a systemd timer; schedule in ./automation.toml).
# Runs only with a per-machine config (~/.config/harvest/timesheet.toml, see
# harvest-lib.zsh) that sets `reconcile = true`. The week's days are filled
# earlier by timesheet-fill, since an unattended Sunday may have no credentials
# for Claude; a machine off at weekends reconciles right after that fill instead.

set -uo pipefail

SCRIPT_PATH="${(%):-%x}"
SCRIPT_DIR="${SCRIPT_PATH:A:h}"
TOML="$SCRIPT_DIR/automation.toml"

# launchd and systemd ship a minimal PATH; rebuild enough to find curl and jq.
export PATH="/opt/homebrew/bin:/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.toolbox/bin:$HOME/.local/bin:$HOME/bin:$PATH"

source "${SCRIPT_DIR}/harvest-lib.zsh"
[[ "$(_toml_bool enabled "$TOML")" == "true" ]] || exit 0
has_timesheet_config || exit 0
[[ "$(ts_bool reconcile)" == "true" ]] || exit 0

log() { print -- "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
log "reconciling week"
"$SCRIPT_DIR/reconcile.zsh"
rc=$?
log "done (reconcile exit $rc)"
exit "$rc"
