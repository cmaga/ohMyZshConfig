# This is where aliases are for oh my zsh

# OS Platform-specific commands
case "$OSTYPE" in
  darwin*)
    # macOS specific aliases
    alias getip="ipconfig getifaddr en0"
    alias astudio='open -a "Android Studio"'
    ckill() { [ -z "$1" ] && echo "Usage: ckill <port>" || { lsof -ti :$1 | xargs kill -9 2>/dev/null || echo "No process on port $1"; }; }
    
    # Symage
    alias unrealed='DEVELOPER_DIR="/Applications/Xcode-16.2.0.app/Contents/Developer" open "/Users/Shared/Epic Games/UE_5.5/Engine/Binaries/Mac/UnrealEditor.app"'
    alias symage='DEVELOPER_DIR="/Applications/Xcode-16.2.0.app/Contents/Developer" open "/Users/Shared/Epic Games/UE_5.5/Engine/Binaries/Mac/UnrealEditor.app" --args "/Users/cmagana/dev/work/symage/unreal/Symage/Symage.uproject"'

    ;;
  linux*)
    # Linux specific aliases
    alias getip="hostname -I | awk '{print \$1}'"
    ckill() { [ -z "$1" ] && echo "Usage: ckill <port>" || { fuser -k $1/tcp 2>/dev/null || echo "No process on port $1"; }; }

    ;;
  msys*|cygwin*|mingw*)
    # Windows specific aliases
    alias getip="ipconfig | grep IPv4 | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | head -1"
    ckill() { [ -z "$1" ] && echo "Usage: ckill <port>" || { netstat -ano | findstr :$1 | awk '{print $5}' | head -1 | xargs -I {} taskkill //PID {} //F 2>/dev/null || echo "No process on port $1"; }; }

    ;;
  *)
    # Fallback for other systems
    alias getip="echo 'IP command not configured for this OS'"
    ckill() { echo "ckill not configured for this OS"; }
    ;;
esac

# config shortcuts
alias zconf="vim ~/.zshrc"
alias sshconf="vim ~/.ssh/config"
alias zsource="source ~/.zshrc" # reloads zsh config

# git aliases mainly are added by the git plugin these are some extras
# thats why the alias is different for some git commands
alias gita="git add ."
alias gitm="git commit -m"
alias gnuke="git branch | grep -v \"master\\|main\" | xargs git branch -D" # deletes all local branches except master/main
alias gskip='git update-index --skip-worktree'
alias gunskip='git update-index --no-skip-worktree'
alias gskipped='git ls-files -v | grep "^S"'

# SSH Key Generation and Management
alias kgen='$ZSH/custom/scripts/ssh-key-generator.zsh'