#!/usr/bin/env bash
# PostToolUse hook: scrub CLAUDE.md in newly-entered paperlives worktrees.
#
# Motivation: the paperlives (a.k.a. symdocs) repo's tracked CLAUDE.md
# ships team-wide instructions cmagana is in the middle of revising.
# While the team reviews the proposed changes, suppress the team
# CLAUDE.md locally so Claude sessions in fresh worktrees don't load
# the outdated content. Each new worktree is a fresh checkout, so the
# suppression must be applied per-worktree (skip-worktree is
# index-local).
#
# Mechanism: when EnterWorktree completes, this hook fires in the
# parent session whose cwd has switched to the new worktree. If that
# worktree is part of the paperlives repo, set skip-worktree on
# CLAUDE.md and truncate it to zero bytes.
#
# Scoping: identified by remote.origin.url containing "paperlives".
# Non-paperlives repos are no-ops.
#
# Hook protocol (Claude Code):
#   - Input: JSON on stdin, including .tool_name, .tool_input, .tool_response.
#   - Exit 0: success/no-op. Hook output not surfaced to model.

set -u

input="$(cat)"

tool_name="$(printf '%s' "$input" | /usr/bin/jq -r '.tool_name // empty' 2>/dev/null)"
[[ "$tool_name" != "EnterWorktree" ]] && exit 0

# Resolve the new worktree path. Try the tool response first (explicit),
# fall back to $PWD (the parent session's cwd post-EnterWorktree).
candidate="$(printf '%s' "$input" | /usr/bin/jq -r '
  .tool_response.path
  // .tool_response.worktree_path
  // .tool_response.cwd
  // empty
' 2>/dev/null)"

if [[ -z "$candidate" || ! -d "$candidate" ]]; then
  candidate="$PWD"
fi

# Confirm this is a paperlives worktree before touching anything.
remote="$(/usr/bin/git -C "$candidate" config --get remote.origin.url 2>/dev/null)"
[[ "$remote" != *paperlives* ]] && exit 0

claude_md="$candidate/CLAUDE.md"
[[ -f "$claude_md" ]] || exit 0

/usr/bin/git -C "$candidate" update-index --skip-worktree CLAUDE.md 2>/dev/null
: > "$claude_md"

exit 0
