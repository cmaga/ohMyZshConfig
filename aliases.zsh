# This is where aliases are for oh my zsh

# OS Platform-specific commands
case "$OSTYPE" in
  darwin*)
    # macOS specific aliases
    alias getip="ipconfig getifaddr en0"
    ;;
  linux*)
    # Linux specific aliases
    alias getip="hostname -I | awk '{print \$1}'"
    ;;
  msys*|cygwin*|mingw*)
    # Windows specific aliases
    alias getip="ipconfig | grep IPv4 | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | head -1"
    ;;
  *)
    # Fallback for other systems
    alias getip="echo 'IP command not configured for this OS'"
    ;;
esac

# config shortcuts
alias zconf="vim ~/.zshrc"
alias sshconf="vim ~/.ssh/config"
alias zsource="source ~/.zshrc" # reloads zsh config

# git aliases
alias gits="git status"
alias gitd="git diff"
alias gitl="git log"
alias gita="git add ."
alias gitm="git commit -m"
alias gnuke="git branch | grep -v \"master\\|main\" | xargs git branch -D" # deletes all local branches except master/main

# SSH Key Generation and Management
alias kgen='$ZSH/custom/scripts/ssh-key-generator.zsh'