#!/bin/bash
# windows-bootstrap-2.sh
# Called by windows-bootstrap-1.ps1 — runs in Git Bash context

# --- Configure .bashrc for UTF-8 + Zsh ---
if ! grep -q "exec zsh" ~/.bashrc 2>/dev/null; then
    echo '/c/Windows/System32/chcp.com 65001 > /dev/null 2>&1' >> ~/.bashrc
    echo '' >> ~/.bashrc
    echo 'if [ -t 1 ]; then' >> ~/.bashrc
    echo '  exec zsh' >> ~/.bashrc
    echo 'fi' >> ~/.bashrc
    echo "✅ Configured .bashrc to launch Zsh"
else
    echo "⚠️  .bashrc already configured for Zsh"
fi

# --- Install Oh-My-Zsh ---
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing Oh-My-Zsh..."
    zsh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    echo "✅ Oh-My-Zsh installed"
else
    echo "⚠️  Oh-My-Zsh already installed"
fi