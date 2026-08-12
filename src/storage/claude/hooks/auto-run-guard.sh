#!/usr/bin/env bash
# Stop hook + marker manager for unattended dev-workflow auto runs.
#
# Two things end an auto run early, and neither is a decision to stop:
#   1. A message with no tool call in it ends the turn. A step that closes with
#      a status paragraph hands back, however much work remains.
#   2. The `auto` flag was agreed many messages ago, and the step files say
#      "wait for the user" for gates auto converts.
# While a run is armed this hook refuses the stop and says both back.
#
# Roles (the marker path is defined once, here):
#   auto-run-guard.sh start <label>   arm; the first writer owns the marker
#   auto-run-guard.sh end <label>     disarm; only the label that armed it
#   auto-run-guard.sh                 Stop hook; reads the event JSON on stdin
#
# The marker is named after the session and lives outside the worktree, so a
# second session in the same repo still stops normally, and ExitWorktree does
# not disarm the run mid-landing. Stop never fires for subagents — they fire
# SubagentStop — so workers and chunk agents return unaffected.
#
# Hook protocol: exit 0 allows the stop; {"decision":"block","reason":...} on
# stdout refuses it. Claude Code overrides the hook after 8 consecutive blocks,
# so a marker outliving its run costs turns rather than wedging the session.

set -u

MARKER_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/auto-run"
TTL_MINUTES=480 # 8h — longer than any real run, short enough to self-clear

case "${1:-}" in
  start | end)
    action="$1"
    label="$(printf '%s' "${2:-}" | tr -cd 'A-Za-z0-9._-')"
    [ -n "$label" ] || { echo "usage: $0 $action <label>" >&2; exit 1; }

    sid="${CLAUDE_CODE_SESSION_ID:-}"
    [ -n "$sid" ] || { echo "auto-run guard unavailable: CLAUDE_CODE_SESSION_ID is unset" >&2; exit 1; }
    marker="$MARKER_DIR/$sid"

    if [ "$action" = start ]; then
      mkdir -p "$MARKER_DIR"
      if [ -f "$marker" ]; then
        echo "auto-run guard already armed for $(cat "$marker") — left alone"
      else
        printf '%s\n' "$label" > "$marker"
        echo "auto-run guard armed for $label"
      fi
    elif [ ! -f "$marker" ]; then
      echo "auto-run guard was not armed"
    elif [ "$(cat "$marker")" = "$label" ]; then
      rm -f "$marker"
      echo "auto-run guard disarmed for $label"
    else
      echo "auto-run guard belongs to $(cat "$marker") — left armed"
    fi
    exit 0
    ;;
  "") ;;
  *)
    echo "usage: $0 [start|end <label>]" >&2
    exit 1
    ;;
esac

# Hook mode. Fail open: a guard that cannot read its input must not trap a turn.
command -v jq > /dev/null 2>&1 || exit 0

input="$(cat)"
sid="$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)"
[ -n "$sid" ] || exit 0

[ -d "$MARKER_DIR" ] && find "$MARKER_DIR" -type f -mmin "+$TTL_MINUTES" -delete 2>/dev/null

marker="$MARKER_DIR/$sid"
[ -f "$marker" ] || exit 0

# A turn ending with work in flight is a pause the harness wakes, not a stop.
# A dispatch wave of workers is the normal case and must be allowed through.
inflight="$(printf '%s' "$input" | jq '((.background_tasks // []) | length) + ((.session_crons // []) | length)' 2>/dev/null)"
if [ "${inflight:-0}" -gt 0 ] 2>/dev/null; then
  exit 0
fi

label="$(cat "$marker")"

reason="$(
  cat << EOF
Auto run $label is in flight — this turn does not end here. Continue with the
next step of the workflow.

Two habits end a turn by accident:

- A message with no tool call in it ends the turn. Status prose ships in the
  same message as the next tool call, never on its own.
- A step that says to wait for the user is describing the attended run. Auto
  converted that gate: decide it, record the decision for the exit report, and
  keep going.

If the run has genuinely finished, or has halted for a reason you have already
stated, disarm it and then stop:

    $0 end $label
EOF
)"

jq -n --arg reason "$reason" '{decision: "block", reason: $reason}'
exit 0
