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

    # Manual timesheet reconcile (square last week to the weekly target); the Sunday 11am
    # cron usually does this. To fill/edit a day's entry, use `/standup [YYYY-MM-DD]` in Claude.
    alias timesheet="$HOME/.local/share/cmagana-automations/timesheet/reconcile.zsh"

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

# Pull ohMyZshConfig, deploy what changed, then reload the shell to pick up new
# zsh config. 04-deploy-zsh.zsh fills in this clone's path.
glc() { DEPLOY_RELOADS_SHELL=1 make -C "__OHMYZSHCONFIG_DIR__" update && print "Reloading zsh" && exec zsh; }

# SSH Key Generation and Management
alias kgen='$ZSH/custom/scripts/ssh-key-generator.zsh'

# Claude Code - skip permission prompts. Routes through the local proxy
# (automations/claude-proxy) when this machine has one, so DeepSeek model names
# resolve; otherwise plain claude, where only Anthropic models are reachable.
# Behind a proxy Claude Code turns MCP tool search off and sends every MCP tool
# definition with every request (48k tokens here), and runs background requests
# (titles, summaries, web-page digests) on the session model instead of Haiku.
# The proxy relays Claude requests untouched, so restore both unless the caller
# set them. Keep the Haiku ID on the latest Haiku: the `haiku` alias resolves to it.
oc() {
  local -a via_proxy=() account=()
  # Under ~/dev/<company>/, sign in as that company's account (06-deploy-claude.zsh builds its config dir).
  local company=${${PWD#$HOME/dev/}%%/*}
  [[ $PWD == $HOME/dev/* && -d $HOME/.claude-$company ]] && account=(CLAUDE_CONFIG_DIR=${CLAUDE_CONFIG_DIR:-$HOME/.claude-$company})
  if curl -sf -o /dev/null --max-time 1 http://localhost:4000/health; then
    via_proxy=(
      ANTHROPIC_BASE_URL=http://localhost:4000
      ENABLE_TOOL_SEARCH=${ENABLE_TOOL_SEARCH:-true}
      ANTHROPIC_DEFAULT_HAIKU_MODEL=${ANTHROPIC_DEFAULT_HAIKU_MODEL:-claude-haiku-5-5}
    )
  else
    print -u2 "oc: claude-proxy is not up; starting without it (DeepSeek models will not resolve)"
  fi
  env $account $via_proxy claude --dangerously-skip-permissions "$@"
}

# oc on DeepSeek Flash as the session model. Needs the proxy, so it refuses to
# start without it rather than open a session whose model cannot resolve.
# Shadows /usr/bin/od (octal dump); reach that with `command od`.
od() {
  if ! curl -sf -o /dev/null --max-time 1 http://localhost:4000/health; then
    print -u2 "od: claude-proxy is not up; DeepSeek models need it"
    return 1
  fi
  # DeepSeek rejects deferred tools (422 on the tool_reference blocks), so load them upfront.
  ENABLE_TOOL_SEARCH=false oc --model 'deepseek-flash[1m]' "$@"
}

# Task Planner - launch plan execution via Claude Code CLI
TASK_PLANNER_LAUNCHER="$HOME/.cline/skills/task-planner/scripts/launch.zsh"
run-small()  { $TASK_PLANNER_LAUNCHER --small "$@"; }
run-medium() { $TASK_PLANNER_LAUNCHER --medium "$@"; }
run-large()  { $TASK_PLANNER_LAUNCHER --large "$@"; }
