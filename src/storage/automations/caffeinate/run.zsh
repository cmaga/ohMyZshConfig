#!/bin/zsh
# Hold caffeinate's sleep assertions for as long as this runs: -i idle sleep,
# -m disk idle sleep, -s system sleep (AC power only). Runs in the foreground;
# the com.cmagana.caffeinate KeepAlive agent relaunches it if it exits.
#
# macOS only; no-op elsewhere.
[[ "$(uname)" == "Darwin" ]] || exit 0

echo "$(date -u +%FT%TZ) holding sleep assertions" >&2
exec /usr/bin/caffeinate -ims
