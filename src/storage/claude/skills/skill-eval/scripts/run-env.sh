#!/usr/bin/env bash
# SessionStart hook of each eval run, outside the run's sandbox. The sandbox cannot stat Homebrew's
# git through its symlink, so a bare git falls through to /usr/bin/git, whose xcrun shim fails there;
# stand-ins pin git, and the helpers it runs to reach a local remote, to the ones this shell finds.
# The case set's bin/ goes first on PATH beside them, and its session-start.sh runs here, where it can
# start whatever bin/ talks to.
set -eu
bin=$HOME/.eval-bin
evals=$CLAUDE_PLUGIN_ROOT/evals
mkdir -p "$bin"
for tool in git git-upload-pack git-receive-pack; do
  printf '#!/bin/sh\nexec %s "$@"\n' "$(command -v $tool)" > "$bin/$tool"
  chmod +x "$bin/$tool"
done
if [ -d "$evals/bin" ]; then cp -R "$evals/bin/." "$bin/"; fi
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then echo "export PATH=\"$bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"; fi
if [ -x "$evals/session-start.sh" ]; then "$evals/session-start.sh"; fi
