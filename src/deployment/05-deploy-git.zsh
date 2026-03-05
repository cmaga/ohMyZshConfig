#!/bin/zsh
# Deploy Git configuration files
# Deploys .gitconfig and company-specific git configs

set -e

# Source common utilities
SCRIPT_DIR="${0:A:h}"
source "${SCRIPT_DIR}/lib/common.zsh"

# Get storage paths
STORAGE_DIR="$(get_storage_dir)"

# Source paths
GITCONFIG_SOURCE="${STORAGE_DIR}/git/.gitconfig"
GITCONFIG_GSI_SOURCE="${STORAGE_DIR}/git/gitconfig-gsi"
GITCONFIG_MS_SOURCE="${STORAGE_DIR}/git/gitconfig-ms"

# Destination paths
GITCONFIG_DEST="$HOME/.gitconfig"
CUSTOM_GIT_DIR="$OMZ_DIR/custom/git"
GITCONFIG_GSI_DEST="$CUSTOM_GIT_DIR/gitconfig-gsi"
GITCONFIG_MS_DEST="$CUSTOM_GIT_DIR/gitconfig-ms"

# Check if Oh-My-Zsh is installed
[ -d "$OMZ_DIR" ] || error "Oh-My-Zsh not found at $OMZ_DIR. Please install it first."

# Deploy Git configurations
if [ -f "$GITCONFIG_SOURCE" ] && [ -f "$GITCONFIG_GSI_SOURCE" ] && [ -f "$GITCONFIG_MS_SOURCE" ]; then
    log "Deploying Git configurations..."
    
    # Create custom git directory if it doesn't exist
    if [ ! -d "$CUSTOM_GIT_DIR" ]; then
        info "Creating custom git directory..."
        mkdir -p "$CUSTOM_GIT_DIR" || error "Failed to create custom git directory"
    fi
    
    # Deploy git config files
    cp "$GITCONFIG_SOURCE" "$GITCONFIG_DEST" || error "Failed to deploy .gitconfig"
    cp "$GITCONFIG_GSI_SOURCE" "$GITCONFIG_GSI_DEST" || error "Failed to deploy gitconfig-gsi"
    cp "$GITCONFIG_MS_SOURCE" "$GITCONFIG_MS_DEST" || error "Failed to deploy gitconfig-ms"
    
    log "Git configurations deployed successfully!"
else
    error "Git configuration files not found in $STORAGE_DIR/git/"
fi

# Show what was deployed
info "Deployed Git files:"
echo "  - .gitconfig -> $GITCONFIG_DEST"
echo "  - gitconfig-gsi -> $GITCONFIG_GSI_DEST"
echo "  - gitconfig-ms -> $GITCONFIG_MS_DEST"

log "Git deployment complete!"