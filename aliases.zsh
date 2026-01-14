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

# git aliases mainly are added by the git plugin these are some extras
# thats why the alias is different for some git commands
alias gita="git add ."
alias gitm="git commit -m"
alias gnuke="git branch | grep -v \"master\\|main\" | xargs git branch -D" # deletes all local branches except master/main

# SSH Key Generation and Management
alias kgen='$ZSH/custom/scripts/ssh-key-generator.zsh'

# Kill process running on specified port
ckill() {
  if [ -z "$1" ]; then
    echo "Usage: ckill <port>"
    echo "Example: ckill 3000"
    return 1
  fi

  local port=$1
  
  case "$OSTYPE" in
    darwin*)
      # macOS specific command
      local pid=$(lsof -ti :$port)
      if [ -n "$pid" ]; then
        echo "Killing process $pid running on port $port..."
        kill -9 $pid
        if [ $? -eq 0 ]; then
          echo "Process killed successfully."
        else
          echo "Failed to kill process."
        fi
      else
        echo "No process found running on port $port."
      fi
      ;;
    linux*)
      # Linux specific command
      local pid=$(lsof -ti :$port 2>/dev/null)
      if [ -n "$pid" ]; then
        echo "Killing process $pid running on port $port..."
        kill -9 $pid
        if [ $? -eq 0 ]; then
          echo "Process killed successfully."
        else
          echo "Failed to kill process."
        fi
      else
        # Fallback to fuser if lsof doesn't find anything
        if command -v fuser >/dev/null 2>&1; then
          echo "Attempting to kill process on port $port using fuser..."
          fuser -k $port/tcp 2>/dev/null
          if [ $? -eq 0 ]; then
            echo "Process killed successfully."
          else
            echo "No process found running on port $port."
          fi
        else
          echo "No process found running on port $port."
        fi
      fi
      ;;
    msys*|cygwin*|mingw*)
      # Windows specific command
      echo "Finding process on port $port..."
      local pid=$(netstat -ano | findstr :$port | awk '{print $5}' | head -1)
      if [ -n "$pid" ]; then
        echo "Killing process $pid running on port $port..."
        taskkill //PID $pid //F
        if [ $? -eq 0 ]; then
          echo "Process killed successfully."
        else
          echo "Failed to kill process."
        fi
      else
        echo "No process found running on port $port."
      fi
      ;;
    *)
      # Fallback for other systems
      echo "ckill command not configured for this OS type: $OSTYPE"
      echo "Please manually find and kill the process running on port $port"
      ;;
  esac
}
