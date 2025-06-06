# This is where aliases are for oh my zsh
alias ip="ipconfig getifaddr en0"

# config shortcuts
alias zconf="vim ~/.zshrc"
alias zsource="source ~/.zshrc" # reloads zsh config
alias sshconf="vim ~/.ssh/config"

# git aliases
alias gits="git status"
alias gitd="git diff"
alias gitl="git log"
alias gita="git add ."
alias gitc="cz commit"
alias gnuke="git branch | grep -v "master" | xargs git branch -D" # deletes all local branches except master