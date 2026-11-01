#!/usr/bin/env bash
# The case set's SessionStart step, outside the sandbox: start the stand-in Jira over the issues the
# scaffold wrote. It stops on its own once the run's home is gone.
set -eu
state=$HOME/.jira-mock
[ -f "$state/issues.json" ] || exit 0
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$state/spool"
nohup python3 "$here/jira/server.py" "$state" "$here/jira/config.yml" </dev/null >"$state/server.log" 2>&1 &
