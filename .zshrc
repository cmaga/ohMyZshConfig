# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
plugins=(
  git
  zsh-completions
  zsh-autosuggestions
  zsh-syntax-highlighting
)

# path to plugin
fpath+=${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src

# Update settings
zstyle ':omz:update' mode auto

# initialization
source $ZSH/oh-my-zsh.sh

# User configuration
alias aconf="vim /Users/cmagana/.oh-my-zsh/custom/aliases.zsh"
autoload -U compinit && compinit # load zsh-completions
source /opt/homebrew/opt/nvm/nvm.sh # use nvm

# Set theme (must be at the end)
eval "$(starship init zsh)"