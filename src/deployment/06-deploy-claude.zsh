#!/bin/zsh
# Claude Code Deployment Script
# Deploys Claude Code configuration files from git repository to system
# And installs the Claude CLI

set -e

# Source common utilities
SCRIPT_DIR="${0:A:h}"
source "${SCRIPT_DIR}/lib/common.zsh"

# Get project root and storage paths
PROJECT_ROOT="${SCRIPT_DIR:h:h}"
STORAGE_DIR="${PROJECT_ROOT}/src/storage"

# Claude Code Configuration Source
CLAUDE_CONFIG_SOURCE="${STORAGE_DIR}/claude"

# Install Claude CLI
print_status "info" "Checking for Claude CLI..."

if command_exists claude; then
    claude_version=$(claude --version 2>/dev/null || echo "unknown")
    print_status "success" "Claude CLI already installed ($claude_version)"
elif [[ "$(detect_os)" == "windows" ]]; then
    print_status "info" "Claude CLI installation not supported on Windows — skipping"
else
    print_status "warning" "Claude CLI not found"
    print_status "download" "Installing Claude CLI..."

    if npm install -g @anthropic-ai/claude-code 2>/dev/null; then
        print_status "success" "Claude CLI installed successfully"

        # Verify installation
        if command_exists claude; then
            claude_version=$(claude --version 2>/dev/null || echo "unknown")
            print_status "success" "Claude CLI verified ($claude_version)"
        else
            print_status "warning" "Claude CLI installed but not found in PATH - you may need to restart your terminal"
        fi
    else
        print_status "warning" "Failed to install Claude CLI - continuing with config deployment"
    fi
fi

echo

# Deploy Claude Code configurations
if [ -d "$CLAUDE_CONFIG_SOURCE" ]; then
    print_status "info" "Deploying Claude Code configurations..."

    # Ensure ~/.claude base directories exist
    mkdir -p "$CLAUDE_DIR" || error "Failed to create Claude directory"
    mkdir -p "$CLAUDE_DIR/rules" || error "Failed to create Claude rules directory"
    mkdir -p "$CLAUDE_SKILLS_DEST" || error "Failed to create Claude Skills directory"
    mkdir -p "$CLAUDE_AGENTS_DEST" || error "Failed to create Claude Agents directory"

    # Deploy CLAUDE.md (global rules)
    if [ -f "$CLAUDE_CONFIG_SOURCE/CLAUDE.md" ]; then
        print_status "info" "Deploying global CLAUDE.md..."
        cp "$CLAUDE_CONFIG_SOURCE/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md" || error "Failed to deploy CLAUDE.md"
        print_status "success" "CLAUDE.md deployed to $CLAUDE_DIR/CLAUDE.md"
    fi

    # Deploy rules (modular rule files)
    if [ -d "$CLAUDE_CONFIG_SOURCE/rules" ]; then
        rule_count=$(find "$CLAUDE_CONFIG_SOURCE/rules" -name "*.md" 2>/dev/null | wc -l)
        if [ "$rule_count" -gt 0 ]; then
            print_status "info" "Deploying Claude rules..."
            cp "$CLAUDE_CONFIG_SOURCE/rules"/*.md "$CLAUDE_DIR/rules/" 2>/dev/null || true
            print_status "success" "Claude rules deployed to $CLAUDE_DIR/rules/ ($rule_count files)"
        fi
    fi

    # Deploy skills (excluding repos and artifacts directories)
    if [ -d "$CLAUDE_CONFIG_SOURCE/skills" ]; then
        print_status "info" "Deploying Claude skills..."
        for skill_dir in "$CLAUDE_CONFIG_SOURCE/skills"/*/; do
            skill_name=$(basename "$skill_dir")
            skill_dest="$CLAUDE_SKILLS_DEST/$skill_name"
            mkdir -p "$skill_dest"

            # Copy skill files excluding repos and artifacts directories
            if ! rsync -a --exclude="dependencies/repos/" --exclude="artifacts/" "$skill_dir" "$skill_dest/" 2>&1; then
                # Fallback if rsync is unavailable or failed: copy manually
                print_status "warning" "rsync failed for skill '$skill_name', falling back to manual copy"
                find "$skill_dir" -not -path "*/dependencies/repos/*" -not -path "*/artifacts/*" -type f | while read -r src_file; do
                    rel_path="${src_file#$skill_dir}"
                    dest_file="$skill_dest/$rel_path"
                    mkdir -p "$(dirname "$dest_file")"
                    cp "$src_file" "$dest_file"
                done
            fi

            # Run any update-repo script to clone/update skill repositories
            repo_script="$skill_dest/dependencies/scripts/update-repo.zsh"
            if [ -f "$repo_script" ]; then
                print_status "info" "Fetching repositories for skill: $skill_name"
                chmod +x "$repo_script"
                "$repo_script" || print_status "warning" "Failed to fetch repositories for skill: $skill_name"
            fi

            print_status "success" "Skill '$skill_name' deployed to $skill_dest"
        done
    fi

    # Deploy agents (if any exist beyond .gitkeep)
    if [ -d "$CLAUDE_CONFIG_SOURCE/agents" ]; then
        agent_count=$(find "$CLAUDE_CONFIG_SOURCE/agents" -name "*.md" 2>/dev/null | wc -l)
        if [ "$agent_count" -gt 0 ]; then
            print_status "info" "Deploying Claude agents..."
            cp "$CLAUDE_CONFIG_SOURCE/agents"/*.md "$CLAUDE_AGENTS_DEST"/ 2>/dev/null || true
            print_status "success" "Claude agents deployed to $CLAUDE_AGENTS_DEST ($agent_count files)"
        fi
    fi

    # Deploy executable hook scripts to ~/.claude/hooks/
    HOOKS_SCRIPTS_SOURCE="$CLAUDE_CONFIG_SOURCE/hooks"
    HOOKS_SCRIPTS_DEST="$CLAUDE_DIR/hooks"
    if [ -d "$HOOKS_SCRIPTS_SOURCE" ]; then
        script_count=$(find "$HOOKS_SCRIPTS_SOURCE" -name "*.sh" -type f 2>/dev/null | wc -l | tr -d ' ')
        if [ "$script_count" -gt 0 ]; then
            print_status "info" "Deploying Claude hook scripts..."
            mkdir -p "$HOOKS_SCRIPTS_DEST" || error "Failed to create Claude hooks directory"
            for src in "$HOOKS_SCRIPTS_SOURCE"/*.sh; do
                [ -f "$src" ] || continue
                dest="$HOOKS_SCRIPTS_DEST/$(basename "$src")"
                cp "$src" "$dest" || error "Failed to copy $(basename "$src")"
                chmod +x "$dest" || error "Failed to chmod +x $(basename "$src")"
            done
            print_status "success" "Hook scripts deployed to $HOOKS_SCRIPTS_DEST ($script_count files)"
        fi
    fi

    # Deploy hooks (merge into ~/.claude/settings.json)
    HOOKS_SOURCE="$CLAUDE_CONFIG_SOURCE/hooks.json"
    SETTINGS_DEST="$CLAUDE_DIR/settings.json"

    if [ -f "$HOOKS_SOURCE" ]; then
        hooks_count=$(jq '.hooks | length' "$HOOKS_SOURCE" 2>/dev/null)
        if [ "$hooks_count" -gt 0 ] 2>/dev/null; then
            print_status "info" "Deploying Claude hooks..."

            if ! command_exists jq; then
                error "jq is required to deploy hooks — install it with: brew install jq"
            fi

            if [ ! -f "$SETTINGS_DEST" ]; then
                echo '{}' > "$SETTINGS_DEST"
            fi

            # Substitute $HOME in hook command paths at deploy time so the
            # deployed settings.json has absolute paths and does not depend
            # on Claude Code shell-expanding variables at hook invocation.
            hooks_resolved=$(mktemp)
            sed "s|\\\$HOME|$HOME|g" "$HOOKS_SOURCE" > "$hooks_resolved"

            # Concat-plus-dedupe merge: per-event arrays are concatenated and
            # deduplicated by exact JSON stringification. Repo entries always
            # present; manual additions survive re-deploy.
            jq -s '
              .[0] as $existing
              | .[1].hooks as $incoming
              | $existing
              | .hooks = (
                  reduce ($incoming | keys_unsorted[]) as $event (($existing.hooks // {});
                    .[$event] = ((.[$event] // []) + $incoming[$event] | unique_by(. | tostring))
                  )
                )
            ' "$SETTINGS_DEST" "$hooks_resolved" > "${SETTINGS_DEST}.tmp" \
                && mv "${SETTINGS_DEST}.tmp" "$SETTINGS_DEST" \
                || { rm -f "$hooks_resolved"; error "Failed to merge hooks into settings.json"; }
            rm -f "$hooks_resolved"

            print_status "success" "Hooks deployed to $SETTINGS_DEST"
        else
            print_status "info" "hooks.json has no hooks — skipping hooks deployment"
        fi
    fi

    # Merge BashTool timeout env vars into ~/.claude/settings.json.
    # Idempotent: same keys overwritten with same values on re-deploy.
    if command_exists jq; then
        if [ ! -f "$SETTINGS_DEST" ]; then
            echo '{}' > "$SETTINGS_DEST"
        fi
        print_status "info" "Setting BashTool timeout env vars..."
        jq '.env = ((.env // {}) + {"BASH_DEFAULT_TIMEOUT_MS":"600000","BASH_MAX_TIMEOUT_MS":"3600000"})' \
            "$SETTINGS_DEST" > "${SETTINGS_DEST}.tmp" \
            && mv "${SETTINGS_DEST}.tmp" "$SETTINGS_DEST" \
            || error "Failed to merge BashTool timeout env vars into settings.json"
        print_status "success" "BashTool timeouts set (default=10m, max=60m)"
    else
        print_status "warning" "jq not found — skipping BashTool timeout env merge"
    fi

    # Clean up legacy runaway-shell-watchdog LaunchAgent + hook script.
    # Removed 2026-04-15 after the Round 2 investigation reattributed the
    # mid-session `syspolicyd` saturation to Cline Kanban's hook fan-out
    # rather than LLM-generated busy loops. See docs/terminal-hangs.md.
    if [[ "$(detect_os)" == "macos" ]]; then
        legacy_plist_label="com.cmagana.runaway-shell-watchdog"
        legacy_plist_path="$HOME/Library/LaunchAgents/${legacy_plist_label}.plist"
        if launchctl list 2>/dev/null | grep -q "$legacy_plist_label"; then
            print_status "info" "Unloading legacy $legacy_plist_label LaunchAgent..."
            launchctl unload "$legacy_plist_path" 2>/dev/null || true
        fi
        if [ -f "$legacy_plist_path" ]; then
            rm -f "$legacy_plist_path" \
              && print_status "success" "Removed $legacy_plist_path"
        fi
    fi
    if [ -f "$HOOKS_SCRIPTS_DEST/runaway-shell-watchdog.sh" ]; then
        rm -f "$HOOKS_SCRIPTS_DEST/runaway-shell-watchdog.sh" \
          && print_status "success" "Removed legacy $HOOKS_SCRIPTS_DEST/runaway-shell-watchdog.sh"
    fi

    print_status "success" "Claude Code configurations deployed successfully!"
else
    error "Claude Code configuration directory not found at $CLAUDE_CONFIG_SOURCE"
fi

# Show what was deployed
print_status "info" "Deployed Claude Code files:"
echo "  - CLAUDE.md -> $CLAUDE_DIR/CLAUDE.md"
echo "  - Rules -> $CLAUDE_DIR/rules/"
echo "  - Skills -> $CLAUDE_SKILLS_DEST"
echo "  - Agents -> $CLAUDE_AGENTS_DEST"
echo "  - Hook scripts -> $CLAUDE_DIR/hooks/"
echo "  - Hooks -> $SETTINGS_DEST (merged)"
echo "  - BashTool timeouts -> $SETTINGS_DEST (env)"

print_status "success" "Claude Code deployment complete!"
