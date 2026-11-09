#!/usr/bin/env zsh
# Friday timesheet fill (schedule in ./automation.toml): the standup skill, headless,
# posts this machine's fill_project notes for every unposted day through today.

set -uo pipefail

SCRIPT_PATH="${(%):-%x}"
SCRIPT_DIR="${SCRIPT_PATH:A:h}"
TOML="$SCRIPT_DIR/automation.toml"

export PATH="/opt/homebrew/bin:/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.toolbox/bin:$HOME/.local/bin:$HOME/bin:$PATH"
if [[ -d "$HOME/.nvm/versions/node" ]]; then
    nvm_bin=$(/bin/ls -d "$HOME/.nvm/versions/node"/*/bin 2>/dev/null | tail -1)
    [[ -n "$nvm_bin" ]] && export PATH="$nvm_bin:$PATH"
fi

source "${SCRIPT_DIR:h}/timesheet/harvest-lib.zsh"
[[ "$(_toml_bool enabled "$TOML")" == "true" ]] || exit 0
has_timesheet_config || exit 0
FILL=$(ts_string fill_project)
[[ -n "$FILL" ]] || exit 0

log() { print -- "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
log "filling $FILL through today via standup skill"
cd "$HOME"
claude -p "/standup auto --through-today" --dangerously-skip-permissions 2>&1 | sed 's/^/  standup: /'
log "done"
