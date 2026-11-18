#!/usr/bin/env bash
# The case set's SessionStart step, outside the sandbox: name the kitchen's account for the run, whose
# config dir is a temporary one levers.py cannot match, then start the stand-in Jira over the issues the
# scaffold wrote. It stops on its own once the run's home is gone.
set -eu
levers=$CLAUDE_PLUGIN_ROOT/skills/kitchen/commands/roster/scripts/levers.py
if [ -n "${CLAUDE_ENV_FILE:-}" ] && acct=$(CLAUDE_CONFIG_DIR=$HOME/.claude python3 "$levers" | jq -r .account); then
  echo "export KITCHEN_ACCOUNT=$acct" >> "$CLAUDE_ENV_FILE"
fi
state=$HOME/.jira-mock
[ -f "$state/issues.json" ] || exit 0
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$state/spool"
nohup python3 "$here/jira/server.py" "$state" "$here/jira/config.yml" </dev/null >"$state/server.log" 2>&1 &
