#!/bin/zsh
# Always-on local Anthropic-protocol router for Claude Code
#
# Binds 127.0.0.1 only. DEEPSEEK_API_KEY comes from ~/.zshrc.local and is added
# by hand. Without it the proxy still serves Anthropic traffic and only DeepSeek
# requests fail, with a 503 naming the missing key. Runs in the foreground; the
# com.cmagana.claude-proxy KeepAlive agent relaunches it.

# macOS only — launchd; no-op elsewhere.
[[ "$(uname)" == "Darwin" ]] || exit 0

# launchd hands the job a minimal PATH; node is installed via nvm.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:${PATH}"

# before `set -e` on purpose: the file is an interactive rc and may hold commands that return non-zero outside an interactive shell.
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

# nvm installs node outside the default PATH, so resolve the active version.
if [[ -s "$HOME/.nvm/nvm.sh" ]] && ! command -v node >/dev/null 2>&1; then
  source "$HOME/.nvm/nvm.sh" >/dev/null 2>&1
fi

set -e

if ! command -v node >/dev/null 2>&1; then
  echo "$(date -u +%FT%TZ) node not found; claude-proxy cannot start" >&2
  exit 1
fi

PORT="${CLAUDE_PROXY_PORT:-4000}"
export CLAUDE_PROXY_PORT="$PORT"
echo "$(date -u +%FT%TZ) starting claude-proxy on 127.0.0.1:${PORT}" >&2
exec node "${0:A:h}/proxy.mjs"
