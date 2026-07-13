#!/bin/zsh
# Always-on SSM port-forward to the Capture Station dashboard.
#
# The dashboard binds 127.0.0.1:8787 on the mdcap-capture box with no inbound
# port, so it is only reachable through an SSM tunnel. This resolves the box by
# tag (never a hardcoded instance id) and forwards localhost:8787 to it. Runs in
# the foreground and exits when the tunnel drops; the com.cmagana.dashboard-tunnel
# KeepAlive agent relaunches it.
#
# macOS only — launchd/SSM tooling; no-op elsewhere.
[[ "$(uname)" == "Darwin" ]] || exit 0
set -e

export AWS_PROFILE="${AWS_PROFILE:-moneystop}"
export AWS_REGION="${AWS_REGION:-us-east-2}"
# launchd hands the job a minimal PATH; aws + session-manager-plugin live in the
# Homebrew prefix on Apple Silicon.
export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH}"

LOCAL_PORT="${DASHBOARD_LOCAL_PORT:-8787}"
REMOTE_PORT=8787
TAG_NAME="mdcap-capture"

id="$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=${TAG_NAME}" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].InstanceId' --output text)"

if [[ -z "$id" || "$id" == "None" ]]; then
  echo "$(date -u +%FT%TZ) no running instance tagged Name=${TAG_NAME}" >&2
  exit 1
fi

echo "$(date -u +%FT%TZ) forwarding localhost:${LOCAL_PORT} -> ${id}:${REMOTE_PORT}" >&2
exec aws ssm start-session \
  --target "$id" \
  --document-name AWS-StartPortForwardingSession \
  --parameters "{\"portNumber\":[\"${REMOTE_PORT}\"],\"localPortNumber\":[\"${LOCAL_PORT}\"]}"
