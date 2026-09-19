#!/bin/zsh
# Always-on local LiteLLM proxy for Claude Code
#
# Binds 127.0.0.1 only. LITELLM_MASTER_KEY and DEEPSEEK_API_KEY come from
# ~/.zshrc.local; 06-deploy-claude.zsh generates the master key, the DeepSeek key
# is added by hand. Without a DeepSeek key the proxy still serves the Claude
# models and only `deepseek` requests fail. Runs in the foreground; the
# com.cmagana.litellm-proxy KeepAlive agent relaunches it.


# macOS only — launchd; no-op elsewhere.
[[ "$(uname)" == "Darwin" ]] || exit 0

# launchd hands the job a minimal PATH; litellm is a pipx app in ~/.local/bin.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:${PATH}"

# before `set -e` on purpose: the file is an interactive rc and may hold commands that return non-zero outside an interactive shell.
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
set -e

if [[ -z "$LITELLM_MASTER_KEY" ]]; then
  echo "$(date -u +%FT%TZ) LITELLM_MASTER_KEY missing from ~/.zshrc.local; run make deploy-claude" >&2
  exit 1
fi
export DEEPSEEK_API_KEY="${DEEPSEEK_API_KEY:-unset}"

PORT="${LITELLM_PORT:-4000}"
echo "$(date -u +%FT%TZ) starting litellm on 127.0.0.1:${PORT}" >&2
exec litellm --config "${0:A:h}/config.yaml" --host 127.0.0.1 --port "$PORT"
