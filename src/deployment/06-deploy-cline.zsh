#!/bin/zsh
# Cline Deployment Script
# Deploys Cline configuration files from git repository to system
# And install the cline cli

set -e

# Source common utilities
SCRIPT_DIR="${0:A:h}"
source "${SCRIPT_DIR}/lib/common.zsh"

# Get project root and storage paths
PROJECT_ROOT="${SCRIPT_DIR:h:h}"
STORAGE_DIR="${PROJECT_ROOT}/src/storage"

# Cline Configuration Source
CLINE_CONFIG_SOURCE="${STORAGE_DIR}/cline"

# Install Cline CLI
print_status "info" "Checking for Cline CLI..."

if command_exists cline; then
    local cline_version=$(cline --version 2>/dev/null || echo "unknown")
    print_status "success" "Cline CLI already installed ($cline_version)"
else
    print_status "warning" "Cline CLI not found"
    print_status "download" "Installing Cline CLI via pnpm..."
    
    if pnpm install -g @cline/cli 2>/dev/null || npm install -g @cline/cli 2>/dev/null; then
        print_status "success" "Cline CLI installed successfully"
        
        # Verify installation
        if command_exists cline; then
            local cline_version=$(cline --version 2>/dev/null || echo "unknown")
            print_status "success" "Cline CLI verified ($cline_version)"
        else
            warn "Cline CLI installed but not found in PATH - you may need to restart your terminal"
        fi
    else
        warn "Failed to install Cline CLI - continuing with config deployment"
    fi
fi

echo

# Deploy Cline configurations
if [ -d "$CLINE_CONFIG_SOURCE" ]; then
    info "Deploying Cline configurations..."

    # Ensure ~/Documents/Cline base directories exist
    mkdir -p "$CLINE_RULES_DEST" || error "Failed to create Cline Rules directory"
    mkdir -p "$CLINE_WORKFLOWS_DEST" || error "Failed to create Cline Workflows directory"
    mkdir -p "$CLINE_HOOKS_DEST" || error "Failed to create Cline Hooks directory"
    mkdir -p "$CLINE_AGENTS_DEST" || error "Failed to create Cline Agents directory"
    mkdir -p "$CLINE_SKILLS_DEST" || error "Failed to create Cline Skills directory"

    # Deploy rules
    if [ -d "$CLINE_CONFIG_SOURCE/rules" ]; then
        info "Deploying Cline rules..."
        cp "$CLINE_CONFIG_SOURCE/rules"/*.md "$CLINE_RULES_DEST"/ || error "Failed to deploy Cline rules"
        log "Cline rules deployed to $CLINE_RULES_DEST"
    fi

    # Deploy workflows
    if [ -d "$CLINE_CONFIG_SOURCE/workflows" ]; then
        info "Deploying Cline workflows..."
        cp "$CLINE_CONFIG_SOURCE/workflows"/*.md "$CLINE_WORKFLOWS_DEST"/ || error "Failed to deploy Cline workflows"
        log "Cline workflows deployed to $CLINE_WORKFLOWS_DEST"
    fi

    # Deploy hooks
    if [ -d "$CLINE_CONFIG_SOURCE/hooks" ]; then
        info "Deploying Cline hooks..."
        cp -r "$CLINE_CONFIG_SOURCE/hooks"/. "$CLINE_HOOKS_DEST"/ 2>/dev/null
        log "Cline hooks deployed to $CLINE_HOOKS_DEST"
    fi

    # Deploy custom agents
    if [ -d "$CLINE_CONFIG_SOURCE/agents" ]; then
        info "Deploying Cline custom agents..."
        cp "$CLINE_CONFIG_SOURCE/agents"/*.md "$CLINE_AGENTS_DEST"/ 2>/dev/null || true
        log "Cline agents deployed to $CLINE_AGENTS_DEST"
    fi

    # Deploy skills (excluding repos directories, which are fetched on-demand)
    if [ -d "$CLINE_CONFIG_SOURCE/skills" ]; then
        info "Deploying Cline skills..."
        for skill_dir in "$CLINE_CONFIG_SOURCE/skills"/*/; do
            skill_name=$(basename "$skill_dir")
            skill_dest="$CLINE_SKILLS_DEST/$skill_name"
            mkdir -p "$skill_dest"

            # Copy skill files excluding the repos directory
            rsync -a --exclude="dependencies/repos/" "$skill_dir" "$skill_dest/" 2>/dev/null || {
                # Fallback if rsync is unavailable: copy manually
                find "$skill_dir" -not -path "*/dependencies/repos/*" -type f | while read -r src_file; do
                    rel_path="${src_file#$skill_dir}"
                    dest_file="$skill_dest/$rel_path"
                    mkdir -p "$(dirname "$dest_file")"
                    cp "$src_file" "$dest_file"
                done
            }

            # Run the update-repo script to clone/update skill repositories
            repo_script="$skill_dest/dependencies/scripts/update-repo.zsh"
            if [ -f "$repo_script" ]; then
                info "Fetching repositories for skill: $skill_name"
                chmod +x "$repo_script"
                "$repo_script" || warn "Failed to fetch repositories for skill: $skill_name"
            fi

            log "Skill '$skill_name' deployed to $skill_dest"
        done
    fi

    log "Cline configurations deployed successfully!"
else
    error "Cline configuration directory not found at $CLINE_CONFIG_SOURCE"
fi

# Show what was deployed
info "Deployed Cline files:"
echo "  - Rules -> $CLINE_RULES_DEST"
echo "  - Workflows -> $CLINE_WORKFLOWS_DEST"
echo "  - Hooks -> $CLINE_HOOKS_DEST"
echo "  - Agents -> $CLINE_AGENTS_DEST"
echo "  - Skills -> $CLINE_SKILLS_DEST"

log "Cline deployment complete!"