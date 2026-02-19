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
zsh-you-should-use
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

# NVM Configuration - MUST be set before OS-specific configurations
export NVM_DIR="$HOME/.nvm"

# OS-specific configurations
case "$OSTYPE" in
darwin*)
    # macOS specific settings
    [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && source "/opt/homebrew/opt/nvm/nvm.sh" # Apple Silicon
    [ -s "/usr/local/opt/nvm/nvm.sh" ] && source "/usr/local/opt/nvm/nvm.sh" # Intel Mac
    [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && source "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"
    [ -s "/usr/local/opt/nvm/etc/bash_completion.d/nvm" ] && source "/usr/local/opt/nvm/etc/bash_completion.d/nvm"
    
    # Add macOS specific paths
    export PATH="/opt/homebrew/bin:$PATH"
    ;;
    
linux*)
    # Linux specific settings
    [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"
    ;;
    
msys*|cygwin*|mingw*)
    # Windows specific settings (Git Bash)
    [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"
    
    # Windows-specific PATH additions
    export PATH="$HOME/.local/bin:$PATH"
    
    # Windows-specific PATH management for nvm
    # Ensure nvm's node comes first in PATH
    if [ -n "$NVM_BIN" ]; then
        export PATH="$NVM_BIN:$PATH"
    fi

    # SSH agent auto-start for Windows (Git Bash/Zsh)
    # macOS and Linux handle ssh-agent via system keychain / desktop environment,
    # but Windows needs explicit agent management.
    _ssh_agent_env="$HOME/.ssh/agent.env"

    _ssh_agent_load_env() {
        [[ -f "$_ssh_agent_env" ]] && source "$_ssh_agent_env" >| /dev/null
    }

    _ssh_agent_start() {
        (umask 077; ssh-agent >| "$_ssh_agent_env")
        source "$_ssh_agent_env" >| /dev/null
    }

    _ssh_agent_load_keys() {
        local keys_dir="$HOME/.ssh/keys"
        [[ -d "$keys_dir" ]] || return
        for _key in "$keys_dir"/id_*(N); do
            [[ "$_key" != *.pub ]] && ssh-add "$_key" 2>/dev/null
        done
    }

    _ssh_agent_load_env
    _ssh_agent_state=$(ssh-add -l >| /dev/null 2>&1; echo $?)

    if [[ ! "$SSH_AUTH_SOCK" ]] || [[ $_ssh_agent_state -eq 2 ]]; then
        # Agent not running — start it and load keys
        _ssh_agent_start
        _ssh_agent_load_keys
    elif [[ $_ssh_agent_state -eq 1 ]]; then
        # Agent running but no keys loaded
        _ssh_agent_load_keys
    fi

    unset _ssh_agent_env _ssh_agent_state _key
    unfunction _ssh_agent_load_env _ssh_agent_start _ssh_agent_load_keys 2>/dev/null
    ;;
    
*)
    # Unknown OS, try common locations
    [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"
    ;;
esac

# Source custom aliases if file exists
[ -f "$HOME/.oh-my-zsh/custom/aliases.zsh" ] && source "$HOME/.oh-my-zsh/custom/aliases.zsh"

# Load additional local configuration if it exists
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"

# Load machine-specific configuration if it exists
[ -f "$HOME/.zshrc.$(hostname)" ] && source "$HOME/.zshrc.$(hostname)"

# Additional nvm helper function for Windows
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "mingw"* ]]; then
    # Function to properly refresh PATH after nvm use
    nvm_use_refresh() {
        nvm use "$1"
        # Force refresh of PATH to ensure nvm's node is found first
        hash -r
        export PATH="$NVM_BIN:$PATH"
    }
    
    # Alias for easier use
    alias nvmr='nvm_use_refresh'
fi
