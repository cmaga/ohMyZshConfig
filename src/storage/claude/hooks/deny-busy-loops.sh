#!/usr/bin/env bash
# PreToolUse hook: deny model-generated busy-wait bash loops.
#
# Motivation: `until grep ...; do true; done` style loops saturate macOS
# syspolicyd (see docs/terminal-hangs.md in this repo). Once syspolicyd
# enters its self-sustaining feedback loop, the only recovery is reboot.
# Prevention is the only real fix.
#
# Hook protocol (Claude Code):
#   - Input: JSON on stdin, including .tool_name and .tool_input.command
#   - Exit 0: allow. Exit 2: block, stderr is fed back to Claude as a message.
#
# This script must be FAST. It runs on every single BashTool call. Use pure
# bash pattern matching, no forks beyond jq, no network.

set -u

input="$(cat)"

# Fast path: only Bash tool invocations are relevant.
tool_name="$(printf '%s' "$input" | /usr/bin/jq -r '.tool_name // empty' 2>/dev/null)"
[[ "$tool_name" != "Bash" ]] && exit 0

command="$(printf '%s' "$input" | /usr/bin/jq -r '.tool_input.command // empty' 2>/dev/null)"
[[ -z "$command" ]] && exit 0

# Pattern library. Each regex matches a known-bad no-yield loop body. Extend
# this list when new shapes are observed. Keep each pattern narrow to avoid
# false positives on legitimate loops.

reasons=""

# (1) The canonical busy-loop body: `do true; done` or `do :; done`.
#     Matches "do true ; done", "do : ; done", "do true;done", etc.
if [[ "$command" =~ [[:space:]\;]do[[:space:]]+(true|:)[[:space:]]*\;?[[:space:]]*done([[:space:]]|\;|$) ]]; then
  reasons+="busy-loop body 'do true; done' or 'do :; done' (no yield); "
fi

# (2) C-style infinite for-loop: `for ((;;))`.
if [[ "$command" =~ for[[:space:]]*\(\([[:space:]]*\;[[:space:]]*\;[[:space:]]*\)\) ]]; then
  reasons+="infinite C-style 'for ((;;))' loop; "
fi

# (3) `while true` / `until false` with no sleep anywhere in the command.
if [[ "$command" =~ (while[[:space:]]+true|until[[:space:]]+false)[[:space:]]*\;[[:space:]]*do ]] \
  && ! [[ "$command" =~ sleep[[:space:]]+[0-9] ]]; then
  reasons+="infinite 'while true' / 'until false' loop without any sleep; "
fi

if [[ -n "$reasons" ]]; then
  cat >&2 <<EOF
Bash command blocked by deny-busy-loops hook.

Reasons: $reasons

This pattern saturates macOS syspolicyd under parallel Claude Code sessions
(notably Cline Kanban). Once syspolicyd enters its feedback loop the only
recovery is a machine reboot.

Replace the loop with one of:
  1. Use Claude Code's BashOutput / TaskOutput(block=true) API to wait for
     background-task output (preferred).
  2. If you MUST poll in bash, include a sleep in the loop body:
       until grep -q 'marker' file; do sleep 1; done

See docs/terminal-hangs.md in the ohMyZshConfig repo for context.
EOF
  exit 2
fi

exit 0
