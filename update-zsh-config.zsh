#!/bin/zsh

# Deploy zsh configuration files from git repository to system

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print with color
log() {
    echo -e "${GREEN}$1${NC}"
}

warn() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

error() {
    echo -e "${RED}ERROR: $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}$1${NC}"
}

# Cline Configuration Paths
CLINE_CONFIG_SOURCE="$(pwd)/configurations/cline"
CLINE_DOCS_DIR="$HOME/Documents/Cline"
CLINE_RULES_DEST="$CLINE_DOCS_DIR/Rules"
CLINE_WORKFLOWS_DEST="$CLINE_DOCS_DIR/Workflows"
CLINE_HOOKS_DEST="$CLINE_DOCS_DIR/Hooks"
CLINE_SKILLS_DEST="$HOME/.cline/skills"

# Paths
ZSHRC_SOURCE="$(pwd)/.zshrc"
ALIASES_SOURCE="$(pwd)/aliases.zsh"
SCRIPTS_SOURCE="$(pwd)/scripts"
GITCONFIG_SOURCE="$(pwd)/configurations/git/.gitconfig"
GITCONFIG_WORK_SOURCE="$(pwd)/configurations/git/gitconfig-work"
GITCONFIG_KRATOS_SOURCE="$(pwd)/configurations/git/gitconfig-kratos"
ZSHRC_DEST="$HOME/.zshrc"
OMZ_DIR="${ZSH:-$HOME/.oh-my-zsh}"
ALIASES_DEST="$OMZ_DIR/custom/aliases.zsh"
SCRIPTS_DEST="$OMZ_DIR/custom/scripts"
GITCONFIG_DEST="$HOME/.gitconfig"
CUSTOM_GIT_DIR="$OMZ_DIR/custom/git"
GITCONFIG_WORK_DEST="$CUSTOM_GIT_DIR/gitconfig-work"
GITCONFIG_KRATOS_DEST="$CUSTOM_GIT_DIR/gitconfig-kratos"

# Check if source files exist
[ -f "$ZSHRC_SOURCE" ] || error "Source .zshrc not found at $ZSHRC_SOURCE"
[ -f "$ALIASES_SOURCE" ] || error "Source aliases.zsh not found at $ALIASES_SOURCE"

# Check if Oh-My-Zsh is installed
[ -d "$OMZ_DIR" ] || error "Oh-My-Zsh not found at $OMZ_DIR. Please install it first."

# Create custom directory if it doesn't exist
if [ ! -d "$OMZ_DIR/custom" ]; then
    log "Creating Oh-My-Zsh custom directory..."
    mkdir -p "$OMZ_DIR/custom"
fi

# Deploy .zshrc
log "Deploying .zshrc from $ZSHRC_SOURCE to $ZSHRC_DEST"
cp "$ZSHRC_SOURCE" "$ZSHRC_DEST" || error "Failed to deploy .zshrc"

# Deploy aliases.zsh
log "Deploying aliases.zsh from $ALIASES_SOURCE to $ALIASES_DEST"
cp "$ALIASES_SOURCE" "$ALIASES_DEST" || error "Failed to deploy aliases.zsh"

# Deploy scripts directory
if [ -d "$SCRIPTS_SOURCE" ]; then
    log "Deploying scripts directory from $SCRIPTS_SOURCE to $SCRIPTS_DEST"
    
    # Create scripts directory if it doesn't exist
    if [ ! -d "$SCRIPTS_DEST" ]; then
        info "Creating custom scripts directory..."
        mkdir -p "$SCRIPTS_DEST"
    fi
    
    # Copy all files from scripts directory, overwriting existing ones
    info "Copying script files..."
    cp -r "$SCRIPTS_SOURCE"/* "$SCRIPTS_DEST"/ || error "Failed to deploy scripts"
    
    # Make all script files executable
    info "Making script files executable..."
    find "$SCRIPTS_DEST" -type f -name "*.zsh" -exec chmod +x {} \;
    find "$SCRIPTS_DEST" -type f -name "*.sh" -exec chmod +x {} \;
    
    log "Scripts deployed successfully!"
else
    warn "Scripts directory not found at $SCRIPTS_SOURCE - skipping scripts deployment"
fi

# Deploy Git configurations
if [ -f "$GITCONFIG_SOURCE" ] && [ -f "$GITCONFIG_WORK_SOURCE" ] && [ -f "$GITCONFIG_KRATOS_SOURCE" ]; then
    log "Deploying Git configurations..."
    
    # Create custom git directory if it doesn't exist
    if [ ! -d "$CUSTOM_GIT_DIR" ]; then
        info "Creating custom git directory..."
        mkdir -p "$CUSTOM_GIT_DIR" || error "Failed to create custom git directory"
    fi
    
    # Deploy git config files
    cp "$GITCONFIG_SOURCE" "$GITCONFIG_DEST" || error "Failed to deploy .gitconfig"
    cp "$GITCONFIG_WORK_SOURCE" "$GITCONFIG_WORK_DEST" || error "Failed to deploy gitconfig-work"
    cp "$GITCONFIG_KRATOS_SOURCE" "$GITCONFIG_KRATOS_DEST" || error "Failed to deploy gitconfig-kratos"
    
    log "Git configurations deployed successfully!"
else
    warn "Git configuration files not found - skipping Git config deployment"
fi

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
            rsync -a --exclude="dependencies/repos/" "$skill_dir" "$skill_dest/" || {
                # Fallback if rsync is unavailable: copy manually
                find "$skill_dir" -not -path "*/dependencies/repos/*" -type f | while read -r src_file; do
                    rel_path="${src_file#$skill_dir}"
                    dest_file="$skill_dest/$rel_path"
                    mkdir -p "$(dirname "$dest_file")"
                    cp "$src_file" "$dest_file"
                done
            }

            # Run the update-repo script to clone/update skill repositories
            repo_script="$skill_dir/dependencies/scripts/update-repo.zsh"
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
    warn "Cline configuration directory not found at $CLINE_CONFIG_SOURCE - skipping Cline deployment"
fi

log "Deployment complete!"

# Show what was deployed
info "Deployed files:"
echo "  ✓ .zshrc → $ZSHRC_DEST"
echo "  ✓ aliases.zsh → $ALIASES_DEST"
if [ -f "$GITCONFIG_SOURCE" ] && [ -f "$GITCONFIG_WORK_SOURCE" ] && [ -f "$GITCONFIG_KRATOS_SOURCE" ]; then
    echo "  ✓ Git configurations:"
    echo "    - .gitconfig → $GITCONFIG_DEST"
    echo "    - gitconfig-work → $GITCONFIG_WORK_DEST"
    echo "    - gitconfig-kratos → $GITCONFIG_KRATOS_DEST"
fi
if [ -d "$SCRIPTS_SOURCE" ]; then
    # List deployed scripts
    info "Deployed scripts:"
    for script in "$SCRIPTS_SOURCE"/*; do
        if [ -f "$script" ]; then
            echo "    - $(basename "$script")"
        fi
    done
fi
if [ -d "$CLINE_CONFIG_SOURCE" ]; then
    echo "  ✓ Cline configurations:"
    echo "    - Rules → $CLINE_RULES_DEST"
    echo "    - Workflows → $CLINE_WORKFLOWS_DEST"
    echo "    - Hooks → $CLINE_HOOKS_DEST"
    echo "    - Skills → $CLINE_SKILLS_DEST"
fi

# Offer to source the new configuration
read "REPLY?Would you like to apply the new configuration now? (Y/n) "
if [[ -z $REPLY || $REPLY =~ ^[Yy]$ ]]; then
    log "Sourcing ~/.zshrc..."
    source ~/.zshrc
    log "Done! Your new Zsh configuration is now active."
else
    log "Remember to run 'source ~/.zshrc' to apply the changes."
fi
