#!/bin/zsh

# Deploy Cline configuration files from git repository to system

# Color codes for output (ANSI-C quoting for cross-shell compatibility)
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
RED=$'\033[0;31m'
BLUE=$'\033[0;34m'
NC=$'\033[0m' # No Color

# Print with color
log() {
    echo "${GREEN}$1${NC}"
}

warn() {
    echo "${YELLOW}WARNING: $1${NC}"
}

error() {
    echo "${RED}ERROR: $1${NC}"
    exit 1
}

info() {
    echo "${BLUE}$1${NC}"
}

# Cline Configuration Paths
CLINE_CONFIG_SOURCE="$(pwd)/configurations/cline"
CLINE_DOCS_DIR="$HOME/Documents/Cline"
CLINE_RULES_DEST="$CLINE_DOCS_DIR/Rules"
CLINE_WORKFLOWS_DEST="$CLINE_DOCS_DIR/Workflows"
CLINE_HOOKS_DEST="$CLINE_DOCS_DIR/Hooks"
CLINE_SKILLS_DEST="$HOME/.cline/skills"

# Deploy Cline configurations
if [ -d "$CLINE_CONFIG_SOURCE" ]; then
    info "Deploying Cline configurations..."

    # Ensure ~/Documents/Cline base directories exist
    mkdir -p "$CLINE_RULES_DEST" || error "Failed to create Cline Rules directory"
    mkdir -p "$CLINE_WORKFLOWS_DEST" || error "Failed to create Cline Workflows directory"
    mkdir -p "$CLINE_HOOKS_DEST" || error "Failed to create Cline Hooks directory"
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
echo "  - Skills -> $CLINE_SKILLS_DEST"

log "Cline deployment complete!"