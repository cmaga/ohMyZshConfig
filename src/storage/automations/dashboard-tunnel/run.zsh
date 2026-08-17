#!/bin/zsh
# Always-on SSM port-forward to the Capture Station dashboard.
#
# nginx binds 127.0.0.1:8788 on the mdcap-capture box and proxies to the
# dashboard on 127.0.0.1:8787. Neither has an inbound port, so both are reachable
# only through an SSM tunnel. This resolves the box by tag (never a hardcoded
# instance id) and forwards localhost:8787 to the PROXY. Runs in the foreground
# and exits when the tunnel drops; the com.cmagana.dashboard-tunnel KeepAlive
# agent relaunches it.
#
# THIS IS A FORK OF engine's deploy/dashboard-tunnel.sh, NOT A CALLER OF IT, so
# no test in that repo can reach this file and nothing there will fail if the two
# drift. REMOTE_PORT below must track the vhost's listen port in
# engine's deploy/nginx/dashboard.conf. Pointing it back at 8787 still appears to
# work today, because the dashboard process itself still answers there — it just
# silently bypasses the proxy, and stops working altogether at the frontend
# cutover, when 8787 no longer serves pages.
#
# LOCAL_PORT deliberately stays 8787 so existing browser bookmarks keep working;
# it is only the box-side port that moved.
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
# nginx, not the dashboard process. See the header.
REMOTE_PORT=8788
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
