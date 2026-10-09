#!/bin/zsh
# Automation deployment script
# Discovers automation.toml files in two locations and registers a launchd
# job for each on macOS, or a systemd user service on Linux (keepalive only):
#   1. Skill-bundled: ~/.claude/skills/<name>/automation.toml
#      Triggered run script: ~/.claude/skills/<name>/dependencies/scripts/run.zsh
#   2. Standalone:   src/storage/automations/<name>/automation.toml
#      Triggered run script: src/storage/automations/<name>/run.zsh
#      (deployed to ~/.local/share/cmagana-automations/<name>/ at install time)
#
# An automation runs on macOS unless its toml sets `platforms`, a space-separated
# list of macos|linux. Linux supports keepalive automations only; scheduled ones
# are skipped there.
#
# Idempotent: existing plists/units are unloaded and rewritten on each deploy.
# No-op on Windows.

set -e

SCRIPT_DIR="${0:A:h}"
source "${SCRIPT_DIR}/lib/common.zsh"

PROJECT_ROOT="${SCRIPT_DIR:h:h}"
STORAGE_DIR="${PROJECT_ROOT}/src/storage"
STANDALONE_SOURCE="${STORAGE_DIR}/automations"
STANDALONE_DEST="$HOME/.local/share/cmagana-automations"
OS="$(detect_os)"

case "$OS" in
    macos)
        LOG_DIR="$HOME/Library/Logs/cmagana-automations"
        LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
        mkdir -p "$LOG_DIR" "$LAUNCH_AGENTS_DIR"
        ;;
    linux)
        if ! command_exists systemctl || ! systemctl --user show-environment >/dev/null 2>&1; then
            print_status "info" "Skipping automation deployment — no systemd user manager"
            exit 0
        fi
        LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/cmagana-automations"
        SYSTEMD_USER_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
        mkdir -p "$LOG_DIR" "$SYSTEMD_USER_DIR"
        ;;
    *)
        print_status "info" "Skipping automation deployment — only macOS (launchd) and Linux (systemd) are supported"
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

# Linux counterpart of unregister_plist.
unregister_unit() {
    local name="$1"
    local unit="cmagana-$name.service"
    if [ -f "$SYSTEMD_USER_DIR/$unit" ]; then
        systemctl --user disable --now "$unit" >/dev/null 2>&1 || true
        rm -f "$SYSTEMD_USER_DIR/$unit"
        systemctl --user daemon-reload
        print_status "info" "Automation '$name' disabled — removed $unit"
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

# Process one automation.toml.
# Args: name run_script toml
process_automation() {
    local name="$1"
    local run_script="$2"
    local toml="$3"

    local enabled=$(toml_bool enabled "$toml")
    local keepalive=$(toml_bool keepalive "$toml")
    local cron=$(toml_string cron "$toml")
    local repo_path=$(toml_string repo_path "$toml")
    local platforms=$(toml_string platforms "$toml")

    if [[ " ${platforms:-macos} " != *" $OS "* ]]; then
        [[ "$OS" == "linux" ]] && unregister_unit "$name"
        return 0
    fi

    if [[ "$enabled" != "true" ]]; then
        if [[ "$OS" == "linux" ]]; then unregister_unit "$name"; else unregister_plist "$name"; fi
        return 0
    fi

    if [ ! -f "$run_script" ]; then
        print_status "warning" "Automation '$name' has automation.toml but no run.zsh at $run_script — skipping"
        return 0
    fi
    chmod +x "$run_script" 2>/dev/null || true

    # KeepAlive daemon — no cron; relaunched whenever it exits.
    if [[ "$keepalive" == "true" ]]; then
        if [[ "$OS" == "linux" ]]; then
            register_keepalive_unit "$name" "$run_script"
        else
            register_keepalive_plist "$name" "$run_script"
        fi
        return 0
    fi

    if [[ "$OS" == "linux" ]]; then
        print_status "info" "Automation '$name': scheduled jobs are macOS-only — skipping"
        return 0
    fi

    if [[ -z "$cron" || -z "$repo_path" || "$repo_path" == "/CHANGEME" ]]; then
        print_status "warning" "Automation '$name' has incomplete automation.toml — skipping"
        return 0
    fi

    register_plist "$name" "$run_script" "$cron"
}

print_status "info" "Deploying automations..."

# Retired automations: unload and remove anything previously registered that is not in source.
# Runs before registration so a successor that takes over a retired agent's port can bind it.
for name in cost-tracker litellm-proxy; do
    [[ "$OS" == "macos" ]] || break
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

# 1. Skill-bundled automations under ~/.claude/skills/<name>/
if [ -d "$CLAUDE_SKILLS_DEST" ]; then
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
    for src_dir in "$STANDALONE_SOURCE"/*/; do
        [ -d "$src_dir" ] || continue
        name=$(basename "${src_dir%/}")
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

print_status "success" "Automation deployment complete!"
