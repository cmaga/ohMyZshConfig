#!/bin/zsh
# Windows stand-in for launchd's KeepAlive + ThrottleInterval.
#
# Task Scheduler starts this once at logon; it relaunches the automation's
# run.zsh whenever it exits, 15s apart so an unreachable target can't
# tight-loop. Both streams go to the log, as StandardOutPath does on macOS.
# Args: run_script log_file

run_script="$1"
log_file="$2"

mkdir -p "${log_file:h}"
exec >>"$log_file" 2>&1

while true; do
  /bin/zsh "$run_script"
  rc=$?
  echo "$(date -u +%FT%TZ) ${run_script:h:t} exited with $rc; relaunching in 15s"
  sleep 15
done
