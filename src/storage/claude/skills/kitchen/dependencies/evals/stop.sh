#!/usr/bin/env bash
# The case set's Stop step, outside the sandbox, each time a run's session stops: check-dispatch.py
# grades every subagent dispatch in the run's transcript against the kitchen's types, and the case's
# check.sh, when it has one, grades what the run left in the workspace. Both write their findings to
# .eval-results/ there, where the case's graders read them. The run never sees either check.
# levers.py finds the account by the config dir's name, and a run's is a temporary one.
evals=$(cd "$(dirname "$0")" && pwd)
out=$HOME/cwd/.eval-results
mkdir -p "$out"
transcript=$(jq -r '.transcript_path // empty' 2>/dev/null)
CLAUDE_CONFIG_DIR=$HOME/.claude python3 "$evals/check-dispatch.py" "$transcript" "$HOME/.claude/skills/kitchen/commands/roster/scripts/levers.py" > "$out/dispatch.txt" 2>&1
case_dir=$(cat "$HOME/.eval-case" 2>/dev/null) || exit 0
[ -x "$case_dir/check.sh" ] || exit 0
"$case_dir/check.sh" "$HOME/cwd" "$out" >/dev/null 2>&1
exit 0
