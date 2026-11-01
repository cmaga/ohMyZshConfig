#!/usr/bin/env bash
# Runs a plain skill's saved eval cases with claude plugin eval, which loads only plugins: the skill
# is copied into a throwaway plugin as skills/<name>/, so its nested files stay reference files.
# Usage: eval.sh <skill dir> [claude plugin eval options]
set -eu

skill=$(cd "${1:?usage: eval.sh <skill dir> [claude plugin eval options]}" && pwd)
shift
name=$(basename "$skill")
cases=
for d in evals dependencies/evals; do
  if [ -d "$skill/$d" ]; then cases=$d; break; fi
done
[ -n "$cases" ] || { echo "no evals/ or dependencies/evals/ in $skill" >&2; exit 3; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
plugin=$work/$name
mkdir -p "$plugin/.claude-plugin" "$plugin/skills"
printf '{"name": "%s"}\n' "$name" > "$plugin/.claude-plugin/plugin.json"
cp -R "$skill" "$plugin/skills/$name"
rm -rf "$plugin/skills/$name/$cases" "$plugin/skills/$name/artifacts"
cp -R "$skill/$cases" "$plugin/evals"
rm -rf "$plugin/evals/results"
# other skills and agents of this repo that the cases use, one name per line
if [ -f "$skill/$cases/skills.txt" ]; then
  while IFS= read -r s; do
    if [ -n "$s" ]; then cp -R "$skill/../$s" "$plugin/skills/$s"; fi
  done < "$skill/$cases/skills.txt"
fi
if [ -f "$skill/$cases/agents.txt" ]; then
  mkdir -p "$plugin/agents"
  while IFS= read -r a; do
    if [ -n "$a" ]; then cp "$skill/../../agents/$a.md" "$plugin/agents/"; fi
  done < "$skill/$cases/agents.txt"
fi
mkdir -p "$plugin/hooks"
cp "$(dirname "$0")/run-env.sh" "$plugin/hooks/"
hooks='"SessionStart": [{"hooks": [{"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/run-env.sh"}]}]'
if [ -x "$plugin/evals/stop.sh" ]; then
  hooks="$hooks"', "Stop": [{"hooks": [{"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/evals/stop.sh"}]}]'
fi
printf '{"hooks": {%s}}\n' "$hooks" > "$plugin/hooks/hooks.json"

# auto memory off: an eval run neither reads nor writes the user's memories. A run waits for its
# background agents, which print mode otherwise stops 10 minutes after the main loop goes idle; the
# case's timeout bounds it instead.
status=0
CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0 claude plugin eval "$plugin" --trust-plugin "$@" || status=$?
if [ -d "$plugin/evals/results" ]; then
  mkdir -p "$skill/$cases/results"
  cp -R "$plugin/evals/results/." "$skill/$cases/results/"
  # the report path printed above dies with the temporary plugin
  echo "Results copied to $skill/$cases/results/"
fi
exit $status
