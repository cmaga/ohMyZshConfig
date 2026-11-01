#!/usr/bin/env bash
# The case set's Stop step, outside the sandbox, each time a run's session stops: the case's check.sh,
# when it has one, grades what the run left in the workspace and writes its findings to
# .eval-results/ there, where the case's graders read them. The run never sees the check.
case_dir=$(cat "$HOME/.eval-case" 2>/dev/null) || exit 0
[ -x "$case_dir/check.sh" ] || exit 0
mkdir -p "$HOME/cwd/.eval-results"
"$case_dir/check.sh" "$HOME/cwd" "$HOME/cwd/.eval-results" >/dev/null 2>&1
exit 0
