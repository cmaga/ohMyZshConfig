#!/bin/zsh

# deploy-zsh-config.zsh - Deploy zsh configuration files from git repository to system

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

# Paths
ZSHRC_SOURCE="$(pwd)/.zshrc"
ALIASES_SOURCE="$(pwd)/aliases.zsh"
ZSHRC_DEST="$HOME/.zshrc"
OMZ_DIR="${ZSH:-$HOME/.oh-my-zsh}"
ALIASES_DEST="$OMZ_DIR/custom/aliases.zsh"

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

log "Deployment complete!"

# Offer to source the new configuration
read "REPLY?Would you like to apply the new configuration now? (y/n) "
if [[ $REPLY =~ ^[Yy]$ ]]; then
  log "Sourcing ~/.zshrc..."
  source ~/.zshrc
  log "Done! Your new Zsh configuration is now active."
else
  log "Remember to run 'source ~/.zshrc' to apply the changes."
fi