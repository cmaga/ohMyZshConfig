#!/bin/zsh
# Final Deployment Cleanup
# Runs after all deployments are complete and offers to reload shell configuration

set -e

# Source common utilities
SCRIPT_DIR="${0:A:h}"
source "${SCRIPT_DIR}/lib/common.zsh"

echo
print_status "success" "All deployments complete!"
echo

# Offer to source the new configuration
read "REPLY?Would you like to apply the new configuration now? (Y/n) "
if [[ -z $REPLY || $REPLY =~ ^[Yy]$ ]]; then
    log "Sourcing ~/.zshrc..."
    source ~/.zshrc
    log "Done! Your new Zsh configuration is now active."
else
    log "Remember to run 'source ~/.zshrc' to apply the changes."
fi