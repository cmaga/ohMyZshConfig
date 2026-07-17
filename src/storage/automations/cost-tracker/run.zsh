#!/bin/zsh
# Local VictoriaMetrics sink for Claude Code telemetry.
#
# Claude Code sessions push OTLP metrics (claude_code.cost.usage,
# claude_code.token.usage) to http://127.0.0.1:8428/opentelemetry — the env
# vars are merged into ~/.claude/settings.json by 06-deploy-claude.zsh. Runs
# in the foreground; the com.cmagana.cost-tracker KeepAlive agent relaunches
# it if it exits.
#
# macOS only — launchd/brew tooling; no-op elsewhere.
[[ "$(uname)" == "Darwin" ]] || exit 0
set -e

# launchd hands the job a minimal PATH; brew lives in /usr/local on Intel and
# /opt/homebrew on Apple Silicon.
export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH}"

if ! command -v victoria-metrics >/dev/null 2>&1; then
  echo "$(date -u +%FT%TZ) victoria-metrics not found, installing via brew" >&2
  brew install victoriametrics
fi

DATA_DIR="$HOME/.claude/cost-tracker/data"
mkdir -p "$DATA_DIR"

echo "$(date -u +%FT%TZ) starting victoria-metrics on 127.0.0.1:8428" >&2
exec victoria-metrics \
  -storageDataPath="$DATA_DIR" \
  -retentionPeriod=13 \
  -httpListenAddr=127.0.0.1:8428 \
  -opentelemetry.usePrometheusNaming
