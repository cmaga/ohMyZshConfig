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

# A child process cannot change the calling shell, so sourcing ~/.zshrc here
# applies nothing (and aborts under set -e when Oh-My-Zsh helpers return nonzero).
log "Run 'exec zsh' to apply the new configuration."
