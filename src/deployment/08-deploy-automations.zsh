#!/bin/zsh
# Automation deployment script
# Discovers automation.toml files in two locations and registers a launchd
# job for each on macOS, a systemd user service (and, when scheduled, timer) on
# Linux, or a per-user Task Scheduler logon task on Windows (keepalive only).
# A Linux host with no systemd user manager (Amazon Linux 2) runs scheduled ones
# from the user's crontab instead, in a managed block, and no keepalive ones:
#   1. Skill-bundled: ~/.claude/skills/<name>/automation.toml
#      Triggered run script: ~/.claude/skills/<name>/dependencies/scripts/run.zsh
#   2. Standalone:   src/storage/automations/<name>/automation.toml
#      Triggered run script: src/storage/automations/<name>/run.zsh
#      (deployed to ~/.local/share/cmagana-automations/<name>/ at install time)
#
# An automation runs on macOS unless its toml sets `platforms`, a space-separated
# list of macos|linux|windows. Windows supports keepalive automations only;
# scheduled ones are skipped there.
#
# Names given as arguments deploy only those standalone automations (and skip
# skill-bundled ones and retirements), for a machine that takes just a few.
#
# A machine can run an automation on its own schedule: a <name>_cron line
# (dashes as underscores) in ~/.config/cmagana-automations/schedule.toml, e.g.
# timesheet_fill_cron = "0 22 * * 5", replaces the cron of its automation.toml.
# A <name>_enabled line there replaces its `enabled` the same way, so
# dashboard_tunnel_enabled = false keeps the tunnel off a machine without the box.
#
# Idempotent: existing plists/units/tasks are unloaded and rewritten on each deploy.

set -e

ONLY=("$@")
SCHEDULE_OVERRIDES="${XDG_CONFIG_HOME:-$HOME/.config}/cmagana-automations/schedule.toml"

SCRIPT_DIR="${0:A:h}"
source "${SCRIPT_DIR}/lib/common.zsh"

PROJECT_ROOT="${SCRIPT_DIR:h:h}"
STORAGE_DIR="${PROJECT_ROOT}/src/storage"
STANDALONE_SOURCE="${STORAGE_DIR}/automations"
STANDALONE_DEST="$HOME/.local/share/cmagana-automations"
OS="$(detect_os)"
LINUX_SCHEDULER=""

case "$OS" in
    macos)
        LOG_DIR="$HOME/Library/Logs/cmagana-automations"
        LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
        mkdir -p "$LOG_DIR" "$LAUNCH_AGENTS_DIR"
        ;;
    linux)
        LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/cmagana-automations"
        if command_exists systemctl && systemctl --user show-environment >/dev/null 2>&1; then
            LINUX_SCHEDULER=systemd
            SYSTEMD_USER_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
            mkdir -p "$SYSTEMD_USER_DIR"
        elif command_exists crontab; then
            LINUX_SCHEDULER=cron
            print_status "info" "No systemd user manager, so scheduled automations run from crontab"
        else
            print_status "info" "Skipping automation deployment — no systemd user manager and no crontab"
            exit 0
        fi
        mkdir -p "$LOG_DIR"
        ;;
    windows)
        LOG_DIR="$HOME/AppData/Local/cmagana-automations/logs"
        mkdir -p "$LOG_DIR"
        ;;
    *)
        print_status "info" "Skipping automation deployment — only macOS (launchd), Linux (systemd), and Windows (Task Scheduler) are supported"
        exit 0
        ;;
esac

# Read a quoted-string value: key = "value"
toml_string() {
    grep -E "^$1[[:space:]]*=" "$2" 2>/dev/null \
        | sed -E "s/^[^=]+=[[:space:]]*\"([^\"]*)\".*/\1/" \
        | head -1
}

# Read a bare bool value: key = true|false
toml_bool() {
    grep -E "^$1[[:space:]]*=" "$2" 2>/dev/null \
        | sed -E "s/^[^=]+=[[:space:]]*(true|false).*/\1/" \
        | head -1
}

# Translate a 5-field cron expression's day-of-week into launchd Weekday integers (0=Sun…6=Sat).
# Outputs a space-separated list. Supports "*", a single digit, "M-N" range, or "M,N,..." list.
cron_dow_to_weekdays() {
    local dow="$1"
    if [[ "$dow" == "*" ]]; then
        echo "0 1 2 3 4 5 6"
    elif [[ "$dow" =~ ^([0-9])-([0-9])$ ]]; then
        local start_day="${match[1]}"
        local end_day="${match[2]}"
        local i
        local out=""
        for ((i=start_day; i<=end_day; i++)); do
            out+="$i "
        done
        echo "${out% }"
    elif [[ "$dow" =~ ^[0-9](,[0-9])*$ ]]; then
        echo "${dow//,/ }"
    else
        return 1
    fi
}

# A cron expression's minute, hour and day-of-week as a systemd OnCalendar
# value, e.g. "0 11 * * 0" as "Sun *-*-* 11:00:00".
cron_to_oncalendar() {
    local cron="$1"
    local minute=$(echo "$cron" | awk '{print $1}')
    local hour=$(echo "$cron" | awk '{print $2}')
    local dow=$(echo "$cron" | awk '{print $5}')
    local weekdays out="" d
    local -a names=(Sun Mon Tue Wed Thu Fri Sat)
    weekdays=$(cron_dow_to_weekdays "$dow") || return 1
    [[ "$minute" == <-> && "$hour" == <-> ]] || return 1
    if [[ "$dow" != "*" ]]; then
        for d in ${=weekdays}; do out+="${names[$((d + 1))]},"; done
        out="${out%,} "
    fi
    printf '%s*-*-* %02d:%02d:00\n' "$out" "$hour" "$minute"
}

# Render and start a systemd user timer and its oneshot service: the Linux
# counterpart of register_plist. Persistent, so a run missed while the machine
# was off happens at the next boot. AUTOMATION_TZ (e.g. America/New_York) pins
# the schedule to that zone instead of the system's, which on a cloud host is
# often UTC; it needs systemd 235 or later.
# Args: name run_script cron_expr
register_timer_unit() {
    local name="$1"
    local run_script="$2"
    local cron="$3"
    local unit="cmagana-$name"

    local calendar
    if ! calendar=$(cron_to_oncalendar "$cron"); then
        print_status "warning" "Automation '$name': unsupported cron '$cron' — skipping"
        return 0
    fi
    if [[ -n "${AUTOMATION_TZ:-}" ]]; then
        local systemd_version=$(systemctl --version 2>/dev/null | awk 'NR == 1 {print $2}')
        if [[ "$systemd_version" == <-> ]] && (( systemd_version >= 235 )); then
            calendar+=" $AUTOMATION_TZ"
        else
            print_status "warning" "Automation '$name': systemd ${systemd_version:-unknown} has no time zones in timers, so it runs at $cron system time ($(date +%Z))"
        fi
    fi

    cat > "$SYSTEMD_USER_DIR/$unit.service" <<EOF
[Unit]
Description=cmagana automation: $name

[Service]
Type=oneshot
ExecStart=$(command -v zsh) $run_script
StandardOutput=append:$LOG_DIR/$name.log
StandardError=append:$LOG_DIR/$name.log
EOF
    cat > "$SYSTEMD_USER_DIR/$unit.timer" <<EOF
[Unit]
Description=cmagana automation schedule: $name

[Timer]
OnCalendar=$calendar
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # A host that once ran it from crontab (before it had a user manager)
    command_exists crontab && write_cron_block "$name"

    systemctl --user daemon-reload
    if systemctl --user enable --now "$unit.timer" >/dev/null 2>&1; then
        print_status "success" "Registered systemd timer '$unit.timer' (cron: $cron)"
    else
        print_status "warning" "systemctl --user failed to start $unit.timer"
    fi
}

# Rewrite the user's crontab: its own lines, then the managed block with every
# cmagana entry except $1's, plus $2 when given. CRON_TZ in the block pins the
# entries to AUTOMATION_TZ; the block goes last so the user's lines keep the
# system zone. Nothing is written when $1 has no entry and none is added.
# Args: name [entry]
write_cron_block() {
    local name="$1" entry="${2:-}"
    local tag=" # cmagana-$name"
    local current=$(crontab -l 2>/dev/null || true)
    [[ -z "$entry" && $'\n'"$current"$'\n' != *"$tag"$'\n'* ]] && return 0
    local outside=$(print -r -- "$current" | awk '/^# BEGIN cmagana-automations/{b=1;next} /^# END cmagana-automations/{b=0;next} !b')
    local kept=$(print -r -- "$current" | awk -v tag="$tag" '/^# BEGIN cmagana-automations/{b=1;next} /^# END cmagana-automations/{b=0;next} b && !/^CRON_TZ=/ && substr($0, length($0) - length(tag) + 1) != tag')
    local -a entries=(${(f)kept})
    [[ -n "$entry" ]] && entries+=("$entry")
    {
        [[ -n "$outside" ]] && print -r -- "$outside"
        if (( ${#entries} )); then
            print -r -- "# BEGIN cmagana-automations (written by 08-deploy-automations.zsh)"
            [[ -n "${AUTOMATION_TZ:-}" ]] && print -r -- "CRON_TZ=$AUTOMATION_TZ"
            print -rl -- "${entries[@]}"
            print -r -- "# END cmagana-automations"
        fi
    } | crontab -
}

# The crontab counterpart of register_timer_unit, for a host without a systemd
# user manager. cron runs it whether or not the user is logged in.
# Args: name run_script cron_expr
register_cron_entry() {
    local name="$1" run_script="$2" cron="$3"
    if write_cron_block "$name" "$cron $(command -v zsh) $run_script >> $LOG_DIR/$name.log 2>&1 # cmagana-$name"; then
        print_status "success" "Registered crontab entry 'cmagana-$name' (cron: $cron${AUTOMATION_TZ:+ $AUTOMATION_TZ})"
    else
        print_status "warning" "crontab failed to register $name"
    fi
}

# Linux teardown on whichever scheduler this host uses.
unregister_linux() {
    local name="$1"
    if [[ "$LINUX_SCHEDULER" == "cron" ]]; then
        crontab -l 2>/dev/null | grep -q " # cmagana-$name\$" || return 0
        write_cron_block "$name" && print_status "info" "Automation '$name' disabled — removed its crontab entry"
    else
        unregister_unit "$name"
    fi
}

# Render and load a launchd plist.
# Args: name run_script cron_expr
register_plist() {
    local name="$1"
    local run_script="$2"
    local cron="$3"

    local label="com.cmagana.$name"
    local plist="$LAUNCH_AGENTS_DIR/$label.plist"

    local minute=$(echo "$cron" | awk '{print $1}')
    local hour=$(echo "$cron" | awk '{print $2}')
    local dow=$(echo "$cron" | awk '{print $5}')

    local weekdays
    if ! weekdays=$(cron_dow_to_weekdays "$dow"); then
        print_status "warning" "Automation '$name': unsupported cron weekday '$dow' — skipping"
        return 0
    fi

    local entries=""
    local day=""
    for day in ${=weekdays}; do
        entries+="        <dict><key>Hour</key><integer>$hour</integer><key>Minute</key><integer>$minute</integer><key>Weekday</key><integer>$day</integer></dict>
"
    done

    cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$label</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/zsh</string>
        <string>$run_script</string>
    </array>
    <key>StartCalendarInterval</key>
    <array>
$entries    </array>
    <key>StandardOutPath</key>
    <string>$LOG_DIR/$name.log</string>
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/$name.log</string>
</dict>
</plist>
EOF

    launchctl unload "$plist" 2>/dev/null || true
    if launchctl load "$plist" 2>/dev/null; then
        print_status "success" "Registered launchd job '$label' (cron: $cron)"
    else
        print_status "warning" "launchctl load failed for $plist"
    fi
}

# Render and load a KeepAlive launchd agent — a long-running daemon (e.g. an
# SSM tunnel), not a scheduled job. Relaunched whenever it exits (drop, reboot,
# transient error), throttled so an unreachable target can't tight-loop.
# Args: name run_script
register_keepalive_plist() {
    local name="$1"
    local run_script="$2"

    local label="com.cmagana.$name"
    local plist="$LAUNCH_AGENTS_DIR/$label.plist"

    cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$label</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/zsh</string>
        <string>$run_script</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ThrottleInterval</key>
    <integer>15</integer>
    <key>StandardOutPath</key>
    <string>$LOG_DIR/$name.log</string>
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/$name.log</string>
</dict>
</plist>
EOF

    launchctl unload "$plist" 2>/dev/null || true
    if launchctl load "$plist" 2>/dev/null; then
        print_status "success" "Registered KeepAlive agent '$label'"
    else
        print_status "warning" "launchctl load failed for $plist"
    fi
}

# Render and start a systemd user service — the Linux counterpart of
# register_keepalive_plist. Restarted whenever it exits, throttled the same way.
# Args: name run_script
register_keepalive_unit() {
    local name="$1"
    local run_script="$2"

    local unit="cmagana-$name.service"

    cat > "$SYSTEMD_USER_DIR/$unit" <<EOF
[Unit]
Description=cmagana automation: $name
StartLimitIntervalSec=0

[Service]
ExecStart=$(command -v zsh) $run_script
Restart=always
RestartSec=15
StandardOutput=append:$LOG_DIR/$name.log
StandardError=append:$LOG_DIR/$name.log

[Install]
WantedBy=default.target
EOF

    systemctl --user daemon-reload
    if systemctl --user enable "$unit" >/dev/null 2>&1 && systemctl --user restart "$unit"; then
        print_status "success" "Registered systemd user service '$unit'"
    else
        print_status "warning" "systemctl --user failed to start $unit"
    fi
}

# Linux counterpart of unregister_plist: the service, and its timer if scheduled.
unregister_unit() {
    local name="$1"
    local unit kind removed=""
    for kind in timer service; do
        unit="cmagana-$name.$kind"
        [ -f "$SYSTEMD_USER_DIR/$unit" ] || continue
        systemctl --user disable --now "$unit" >/dev/null 2>&1 || true
        rm -f "$SYSTEMD_USER_DIR/$unit"
        removed+=" $unit"
    done
    if [[ -n "$removed" ]]; then
        systemctl --user daemon-reload
        print_status "info" "Automation '$name' disabled — removed$removed"
    fi
}

# Disabled automation: tear down any existing plist for this name.
unregister_plist() {
    local name="$1"
    local plist="$LAUNCH_AGENTS_DIR/com.cmagana.$name.plist"
    if [ -f "$plist" ]; then
        launchctl unload "$plist" 2>/dev/null || true
        rm -f "$plist"
        print_status "info" "Automation '$name' disabled — removed $plist"
    fi
}

# PowerShell that stops the $env:TASK_NAME task and everything it started.
# Stop-ScheduledTask ends only conhost, leaving zsh and node orphaned on the
# port, so it also kills every process whose command line points into the
# automation's deployed directory.
STOP_WINDOWS_TASK_PS='
    Stop-ScheduledTask -TaskPath "\cmagana\" -TaskName $env:TASK_NAME -ErrorAction SilentlyContinue
    $pattern = "cmagana-automations[\/]+" + [regex]::Escape($env:TASK_NAME) + "[\/]"
    Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match $pattern } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
'

# Windows counterpart of register_keepalive_plist: a logon task under \cmagana\
# that runs keepalive.zsh, which relaunches run.zsh whenever it exits.
# conhost --headless keeps a console window from showing. A redeploy stops the
# running instance first, so it restarts on the fresh copy.
# Values reach PowerShell through the environment to avoid nested quoting.
# Args: name run_script
register_windows_task() {
    local name="$1"
    local run_script="$2"

    local zsh_exe=$(cygpath -w /usr/bin/zsh.exe)
    local args="--headless \"$zsh_exe\" -l \"$STANDALONE_DEST/keepalive.zsh\" \"$run_script\" \"$LOG_DIR/$name.log\""

    if TASK_NAME="$name" TASK_ARGS="$args" powershell.exe -NoProfile -NonInteractive -Command "$STOP_WINDOWS_TASK_PS"'
        $ErrorActionPreference = "Stop"
        $action = New-ScheduledTaskAction -Execute "conhost.exe" -Argument $env:TASK_ARGS
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
        $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew
        Register-ScheduledTask -TaskPath "\cmagana\" -TaskName $env:TASK_NAME -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
        Start-ScheduledTask -TaskPath "\cmagana\" -TaskName $env:TASK_NAME
    '; then
        print_status "success" "Registered Windows logon task '$name' (log: $LOG_DIR/$name.log)"
    else
        print_status "warning" "Task Scheduler registration failed for '$name'"
    fi
}

# Windows counterpart of unregister_plist: stop and remove the task.
unregister_windows_task() {
    local name="$1"
    local removed=$(TASK_NAME="$name" powershell.exe -NoProfile -NonInteractive -Command '
        if (Get-ScheduledTask -TaskPath "\cmagana\" -TaskName $env:TASK_NAME -ErrorAction SilentlyContinue) {
            '"$STOP_WINDOWS_TASK_PS"'
            Unregister-ScheduledTask -TaskPath "\cmagana\" -TaskName $env:TASK_NAME -Confirm:$false
            "removed"
        }
    ')
    if [[ "$removed" == removed* ]]; then
        print_status "info" "Automation '$name' disabled — removed its Windows logon task"
    fi
}

# Process one automation.toml.
# Args: name run_script toml
process_automation() {
    local name="$1"
    local run_script="$2"
    local toml="$3"

    local enabled=$(toml_bool enabled "$toml")
    local own_enabled=$(toml_bool "${name//-/_}_enabled" "$SCHEDULE_OVERRIDES")
    [[ -n "$own_enabled" ]] && enabled="$own_enabled"
    local keepalive=$(toml_bool keepalive "$toml")
    local cron=$(toml_string cron "$toml")
    local own_cron=$(toml_string "${name//-/_}_cron" "$SCHEDULE_OVERRIDES")
    [[ -n "$own_cron" ]] && cron="$own_cron"
    local repo_path=$(toml_string repo_path "$toml")
    local platforms=$(toml_string platforms "$toml")

    if [[ " ${platforms:-macos} " != *" $OS "* ]]; then
        case "$OS" in
            linux) unregister_linux "$name" ;;
            windows) unregister_windows_task "$name" ;;
        esac
        return 0
    fi

    # Windows runs KeepAlive daemons only.
    if [[ "$OS" == "windows" ]]; then
        if [[ "$enabled" != "true" || "$keepalive" != "true" ]]; then
            unregister_windows_task "$name"
        elif [ ! -f "$run_script" ]; then
            print_status "warning" "Automation '$name' has automation.toml but no run.zsh at $run_script — skipping"
        else
            register_windows_task "$name" "$run_script"
        fi
        return 0
    fi

    if [[ "$enabled" != "true" ]]; then
        if [[ "$OS" == "linux" ]]; then unregister_linux "$name"; else unregister_plist "$name"; fi
        return 0
    fi

    if [ ! -f "$run_script" ]; then
        print_status "warning" "Automation '$name' has automation.toml but no run.zsh at $run_script — skipping"
        return 0
    fi
    chmod +x "$run_script" 2>/dev/null || true

    # KeepAlive daemon — no cron; relaunched whenever it exits.
    if [[ "$keepalive" == "true" ]]; then
        if [[ "$LINUX_SCHEDULER" == "cron" ]]; then
            print_status "warning" "Automation '$name' is a keepalive daemon, which needs a systemd user manager — skipping"
        elif [[ "$OS" == "linux" ]]; then
            register_keepalive_unit "$name" "$run_script"
        else
            register_keepalive_plist "$name" "$run_script"
        fi
        return 0
    fi

    if [[ -z "$cron" || "$repo_path" == "/CHANGEME" ]]; then
        print_status "warning" "Automation '$name' has incomplete automation.toml — skipping"
        return 0
    fi

    if [[ "$LINUX_SCHEDULER" == "cron" ]]; then
        register_cron_entry "$name" "$run_script" "$cron"
    elif [[ "$OS" == "linux" ]]; then
        register_timer_unit "$name" "$run_script" "$cron"
    else
        register_plist "$name" "$run_script" "$cron"
    fi
}

print_status "info" "Deploying automations..."

# Retired automations: unload and remove anything previously registered that is not in source.
# Runs before registration so a successor that takes over a retired agent's port can bind it.
for name in cost-tracker litellm-proxy; do
    [[ "$OS" == "macos" && ${#ONLY} -eq 0 ]] || break
    label="com.cmagana.$name"
    plist="$LAUNCH_AGENTS_DIR/$label.plist"
    if launchctl list 2>/dev/null | grep -q "$label"; then
        print_status "info" "Unloading retired $label..."
        launchctl unload "$plist" 2>/dev/null || true
    fi
    if [ -f "$plist" ]; then
        rm -f "$plist" && print_status "success" "Removed $plist"
    fi
    if [ -d "$STANDALONE_DEST/$name" ]; then
        rm -rf "$STANDALONE_DEST/$name" && print_status "success" "Removed $STANDALONE_DEST/$name"
    fi
done

# 1. Skill-bundled automations under ~/.claude/skills/<name>/ (macOS only)
if [[ "$OS" == "macos" && ${#ONLY} -eq 0 && -d "$CLAUDE_SKILLS_DEST" ]]; then
    for skill_dir in "$CLAUDE_SKILLS_DEST"/*/; do
        skill_dir="${skill_dir%/}"
        toml="$skill_dir/automation.toml"
        [ -f "$toml" ] || continue
        name=$(basename "$skill_dir")
        run_script="$skill_dir/dependencies/scripts/run.zsh"
        process_automation "$name" "$run_script" "$toml"
    done
fi

# 2. Standalone automations under src/storage/automations/<name>/.
# Each gets copied to ~/.local/share/cmagana-automations/<name>/ for a stable runtime path
# independent of the source repo location.
if [ -d "$STANDALONE_SOURCE" ]; then
    mkdir -p "$STANDALONE_DEST"
    [[ "$OS" == "windows" ]] && cp "$STANDALONE_SOURCE/keepalive.zsh" "$STANDALONE_DEST/keepalive.zsh"
    for src_dir in "$STANDALONE_SOURCE"/*/; do
        [ -d "$src_dir" ] || continue
        name=$(basename "${src_dir%/}")
        (( ${#ONLY} == 0 || ${ONLY[(Ie)$name]} )) || continue
        dest_dir="$STANDALONE_DEST/$name"
        toml="$src_dir/automation.toml"
        [ -f "$toml" ] || continue
        mkdir -p "$dest_dir"
        rsync -a --delete "$src_dir" "$dest_dir/" 2>/dev/null \
            || cp -R "$src_dir"/* "$dest_dir/"
        run_script="$dest_dir/run.zsh"
        process_automation "$name" "$run_script" "$dest_dir/automation.toml"
    done
fi

# A user's systemd timers stop at logout unless lingering is on.
if [[ "${LINUX_SCHEDULER:-}" == "systemd" ]] && [[ "$(loginctl show-user "$USER" -p Linger --value 2>/dev/null)" != "yes" ]]; then
    print_status "warning" "Timers run only while $USER is logged in. To run them anyway: sudo loginctl enable-linger $USER"
fi

print_status "success" "Automation deployment complete!"
