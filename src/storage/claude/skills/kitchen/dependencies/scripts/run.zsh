#!/usr/bin/env zsh
# The kitchen skill's scheduler (launchd KeepAlive; see ../../automation.toml). Runs one
# pass over every project, sleeps, and repeats. launchd relaunches it if it exits.

# the scheduler (launchd, systemd, cron) ships a minimal PATH; rebuild enough to find claude, jira, bdei, gh, bb, cr, jq, and node.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin:$HOME/.toolbox/bin:$HOME/bin:$PATH"
if [[ -d "$HOME/.nvm/versions/node" ]]; then
    nvm_bin=$(/bin/ls -d "$HOME/.nvm/versions/node"/*/bin 2>/dev/null | tail -1)
    [[ -n "$nvm_bin" ]] && export PATH="$nvm_bin:$PATH"
fi

KITCHEN="${0:A:h}/kitchen.zsh"
INTERVAL="${KITCHEN_INTERVAL:-300}"

while true; do
    zsh "$KITCHEN" tick
    sleep "$INTERVAL"
done
