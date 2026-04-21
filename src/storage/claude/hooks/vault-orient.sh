#!/usr/bin/env bash
# SessionStart hook: inject the current repo's vault _index.md as orientation.
#
# Looks up ~/dev/vault/projects.json for a repo-basename → vault-path mapping.
# If the current repo has an entry and _index.md exists, prints it to stdout;
# Claude Code adds that stdout to the session's initial context.
#
# Hook protocol (Claude Code SessionStart):
#   - Input: JSON on stdin with .cwd, .source, .hook_event_name.
#   - Stdout: added to initial context.
#   - Fires on: startup, resume, clear, compact.
#
# Must be fast and silent on any miss — never block or error a session.

set -u

input="$(cat)"

vault="$HOME/dev/vault"
projects_json="$vault/projects.json"

[[ -d "$vault" ]] || exit 0
[[ -f "$projects_json" ]] || exit 0

jq_bin="$(command -v jq || true)"
[[ -z "$jq_bin" ]] && exit 0

cwd="$(printf '%s' "$input" | "$jq_bin" -r '.cwd // empty' 2>/dev/null)"
[[ -z "$cwd" ]] && exit 0

repo="$(basename "$cwd")"
rel_path="$("$jq_bin" -r --arg k "$repo" '.[$k] // empty' "$projects_json" 2>/dev/null)"
[[ -z "$rel_path" ]] && exit 0

index_file="$vault/$rel_path/_index.md"
[[ -f "$index_file" ]] || exit 0

cat <<EOF
=== Knowledge Vault: $repo ===
Loaded from $index_file — this project's entry point in the vault at $vault.
Wikilinks below point to notes under $vault/$rel_path/. Follow them when a
proposed change could reverse a documented decision, rework documented
architecture, or violate a documented constraint.

EOF
cat "$index_file"

exit 0
