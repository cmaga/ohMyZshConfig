# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set theme - this must be before sourcing oh-my-zsh.sh
ZSH_THEME="half-life"

# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
plugins=(
  git
  zsh-completions
  zsh-autosuggestions
  zsh-syntax-highlighting
)

# Path to plugin
fpath+=${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src

# Update settings
zstyle ':omz:update' mode auto

# Initialization
source $ZSH/oh-my-zsh.sh

# User configuration
alias aconf="vim $HOME/.oh-my-zsh/custom/aliases.zsh"

# Load zsh-completions
autoload -U compinit && compinit

# OS-specific configurations
case "$OSTYPE" in
  darwin*)
    # macOS specific settings
    [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && source "/opt/homebrew/opt/nvm/nvm.sh" # Apple Silicon
    [ -s "/usr/local/opt/nvm/nvm.sh" ] && source "/usr/local/opt/nvm/nvm.sh" # Intel Mac
    
    # Add macOS specific paths
    export PATH="/opt/homebrew/bin:$PATH"
    ;;
    
  linux*)
    # Linux specific settings
    [ -s "$HOME/.nvm/nvm.sh" ] && source "$HOME/.nvm/nvm.sh"
    # Add Linux specific paths if needed
    ;;
    
  msys*|cygwin*|mingw*)
    # Windows specific settings
    [ -s "$HOME/.nvm/nvm.sh" ] && source "$HOME/.nvm/nvm.sh"
    # Add Windows specific paths if needed
    ;;
    
  *)
    # Unknown OS, try common locations
    [ -s "$HOME/.nvm/nvm.sh" ] && source "$HOME/.nvm/nvm.sh"
    ;;
esac

# Source custom aliases if file exists
[ -f "$HOME/.oh-my-zsh/custom/aliases.zsh" ] && source "$HOME/.oh-my-zsh/custom/aliases.zsh"

# Load additional local configuration if it exists
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"