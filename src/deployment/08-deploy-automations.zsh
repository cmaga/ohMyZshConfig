#!/bin/zsh
# Automation deployment script
# Discovers automation.toml files in two locations and registers a launchd
# job for each on macOS:
#   1. Skill-bundled: ~/.claude/skills/<name>/automation.toml
#      Triggered run script: ~/.claude/skills/<name>/dependencies/scripts/run.zsh
#   2. Standalone:   src/storage/automations/<name>/automation.toml
#      Triggered run script: src/storage/automations/<name>/run.zsh
#      (deployed to ~/.local/share/cmagana-automations/<name>/ at install time)
#
# Idempotent: existing plists are unloaded and rewritten on each deploy.
# No-op on Linux/Windows.

set -e

SCRIPT_DIR="${0:A:h}"
source "${SCRIPT_DIR}/lib/common.zsh"

PROJECT_ROOT="${SCRIPT_DIR:h:h}"
STORAGE_DIR="${PROJECT_ROOT}/src/storage"
STANDALONE_SOURCE="${STORAGE_DIR}/automations"
STANDALONE_DEST="$HOME/.local/share/cmagana-automations"
LOG_DIR="$HOME/Library/Logs/cmagana-automations"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"

if [[ "$(detect_os)" != "macos" ]]; then
    print_status "info" "Skipping automation deployment — only macOS launchd is supported"
    exit 0
fi

mkdir -p "$LOG_DIR" "$LAUNCH_AGENTS_DIR"

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
    local cron=$(toml_string cron "$toml")
    local repo_path=$(toml_string repo_path "$toml")

    if [[ "$enabled" != "true" ]]; then
        unregister_plist "$name"
        return 0
    fi

    if [[ -z "$cron" || -z "$repo_path" || "$repo_path" == "/CHANGEME" ]]; then
        print_status "warning" "Automation '$name' has incomplete automation.toml — skipping"
        return 0
    fi

    if [ ! -f "$run_script" ]; then
        print_status "warning" "Automation '$name' has automation.toml but no run.zsh at $run_script — skipping"
        return 0
    fi
    chmod +x "$run_script" 2>/dev/null || true

    register_plist "$name" "$run_script" "$cron"
}

print_status "info" "Deploying automations..."

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
