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

# NVM Configuration
export NVM_DIR="$HOME/.nvm"

# Claude default model shell env
export ANTHROPIC_MODEL="sonnet"

# OS-specific configurations
case "$OSTYPE" in
darwin*)
    # Lazy nvm - defers sourcing nvm.sh until first node/npm/etc call. Eager
    # sourcing invokes `node --version` on every shell startup, and the first
    # cold-cache launch of any Developer-ID-signed binary on macOS can take
    # minutes while syspolicyd runs full certificate validation. Non-underscore
    # names so shims + init helper survive Claude Code's shell-snapshot filter
    # (the snapshot at ~/.claude/shell-snapshots/snapshot-zsh-*.sh, re-sourced
    # for every BashTool invocation, captures top-level function definitions
    # but filters out underscore-prefixed ones). Shims unset themselves before
    # sourcing so nvm.sh can't re-enter them while loading.
    nvm_lazy_init() {
      unset -f nvm node npm npx pnpm yarn nvm_lazy_init
      [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && source "/opt/homebrew/opt/nvm/nvm.sh"
      [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && source "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"
    }
    nvm()  { nvm_lazy_init; command nvm "$@"; }
    node() { nvm_lazy_init; command node "$@"; }
    npm()  { nvm_lazy_init; command npm "$@"; }
    npx()  { nvm_lazy_init; command npx "$@"; }
    pnpm() { nvm_lazy_init; command pnpm "$@"; }
    yarn() { nvm_lazy_init; command yarn "$@"; }

    # Add macOS specific paths
    export PATH="$HOME/.local/bin:$PATH"
    ;;

linux*)
    # Lazy nvm - see darwin* branch for rationale
    nvm_lazy_init() {
      unset -f nvm node npm npx pnpm yarn nvm_lazy_init
      [ -s "$HOME/.nvm/nvm.sh" ] && source "$HOME/.nvm/nvm.sh"
      [ -s "$HOME/.nvm/bash_completion" ] && source "$HOME/.nvm/bash_completion"
    }
    nvm()  { nvm_lazy_init; command nvm "$@"; }
    node() { nvm_lazy_init; command node "$@"; }
    npm()  { nvm_lazy_init; command npm "$@"; }
    npx()  { nvm_lazy_init; command npx "$@"; }
    pnpm() { nvm_lazy_init; command pnpm "$@"; }
    yarn() { nvm_lazy_init; command yarn "$@"; }
    ;;
    
msys*|cygwin*|mingw*)
    # Windows specific settings (Git Bash)
    
    # nvm-windows PATH integration
    # nvm-windows sets two env vars:
    #   NVM_HOME    - directory containing nvm.exe
    #   NVM_SYMLINK - junction pointing to the active Node.js version
    # Add both so that `nvm` and `node`/`npm`/`pnpm` are all available.
    if [[ -n "$NVM_HOME" ]]; then
        export PATH="$(cygpath "$NVM_HOME"):$PATH"
    fi
    if [[ -n "$NVM_SYMLINK" ]]; then
        export PATH="$(cygpath "$NVM_SYMLINK"):$PATH"
    elif [[ -n "$NVM_HOME" ]]; then
        # NVM_SYMLINK missing - try to find an installed version in NVM_HOME
        local _nvm_home_unix="$(cygpath "$NVM_HOME")"
        local _active_node="$_nvm_home_unix/$(ls "$_nvm_home_unix" 2>/dev/null | grep '^v' | tail -1)"
        [[ -d "$_active_node" ]] && export PATH="$_active_node:$PATH"
        unset _nvm_home_unix _active_node
    fi
    
    # Windows-specific PATH additions
    export PATH="$HOME/.local/bin:$PATH"
    export PATH="/c/Program Files/Amazon/AWSCLIV2:$PATH"

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
        # Agent not running - start it and load keys
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
    # Unknown OS fallback - lazy nvm, see darwin* branch for rationale
    nvm_lazy_init() {
      unset -f nvm node npm npx pnpm yarn nvm_lazy_init
      [ -s "$HOME/.nvm/nvm.sh" ] && source "$HOME/.nvm/nvm.sh"
      [ -s "$HOME/.nvm/bash_completion" ] && source "$HOME/.nvm/bash_completion"
    }
    nvm()  { nvm_lazy_init; command nvm "$@"; }
    node() { nvm_lazy_init; command node "$@"; }
    npm()  { nvm_lazy_init; command npm "$@"; }
    npx()  { nvm_lazy_init; command npx "$@"; }
    pnpm() { nvm_lazy_init; command pnpm "$@"; }
    yarn() { nvm_lazy_init; command yarn "$@"; }
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
    # Function to properly refresh PATH after nvm use (nvm-windows)
    nvm_use_refresh() {
        nvm use "$1"
        # Rehash command table and re-add NVM_SYMLINK to PATH
        hash -r
        [[ -n "$NVM_SYMLINK" ]] && export PATH="$(cygpath "$NVM_SYMLINK"):$PATH"
    }
    
    # Alias for easier use
    alias nvmr='nvm_use_refresh'
fi
