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

# Offer to source the new configuration
read "REPLY?Would you like to apply the new configuration now? (Y/n) "
if [[ -z $REPLY || $REPLY =~ ^[Yy]$ ]]; then
    log "Sourcing ~/.zshrc..."
    source ~/.zshrc
    log "Done! Your new Zsh configuration is now active."
else
    log "Remember to run 'source ~/.zshrc' to apply the changes."
fi
