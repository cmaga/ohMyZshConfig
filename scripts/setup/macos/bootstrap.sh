#!/bin/bash
# macOS Bootstrap Script
# Ensures Xcode Command Line Tools are installed (provides git, make, and other essentials)
# Installs Homebrew, nvm, Node.js LTS, and pnpm
# zsh is already the default shell on macOS

set -e

GREEN=$'\033[0;32m'
BLUE=$'\033[0;34m'
YELLOW=$'\033[1;33m'
RED=$'\033[0;31m'
NC=$'\033[0m'

echo "${BLUE}🍎 macOS Bootstrap${NC}"
echo

# Check for Xcode Command Line Tools
if xcode-select -p &>/dev/null; then
    echo "${GREEN}✅ Xcode Command Line Tools already installed${NC}"
else
    echo "${YELLOW}📦 Installing Xcode Command Line Tools (provides git, make, etc.)...${NC}"
    xcode-select --install

    # Wait for installation to complete
    echo "${BLUE}Waiting for installation to complete...${NC}"
    echo "${BLUE}Please follow the dialog that appeared and press Enter here when done.${NC}"
    read -r
fi

# Verify essentials
echo
echo "${BLUE}Verifying tools...${NC}"

for tool in git make zsh; do
    if command -v "$tool" &>/dev/null; then
        echo "${GREEN}✅ $tool found${NC}"
    else
        echo "${YELLOW}⚠️  $tool not found — you may need to restart your terminal${NC}"
    fi
done

# --- Install Homebrew ---
echo
if command -v brew &>/dev/null; then
    echo "${GREEN}✅ Homebrew already installed${NC}"
else
    echo "${YELLOW}📦 Installing Homebrew...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for current session
    if [ -f "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -f "/usr/local/bin/brew" ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi

    if command -v brew &>/dev/null; then
        echo "${GREEN}✅ Homebrew installed${NC}"
    else
        echo "${RED}❌ Homebrew installation failed${NC}"
        exit 1
    fi
fi

# --- Install nvm via Homebrew ---
echo
export NVM_DIR="$HOME/.nvm"

if [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] || [ -s "/usr/local/opt/nvm/nvm.sh" ]; then
    echo "${GREEN}✅ nvm already installed via Homebrew${NC}"
else
    echo "${YELLOW}📦 Installing nvm via Homebrew...${NC}"
    brew install nvm
fi

# Create nvm directory if needed
[ ! -d "$NVM_DIR" ] && mkdir -p "$NVM_DIR"

# Source nvm for current session
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && source "/opt/homebrew/opt/nvm/nvm.sh"
[ -s "/usr/local/opt/nvm/nvm.sh" ] && source "/usr/local/opt/nvm/nvm.sh"

if command -v nvm &>/dev/null; then
    echo "${GREEN}✅ nvm available ($(nvm --version))${NC}"

    # --- Install Node.js LTS ---
    echo "${YELLOW}📦 Installing Node.js LTS via nvm...${NC}"
    nvm install --lts
    nvm use --lts

    if command -v node &>/dev/null; then
        echo "${GREEN}✅ Node.js $(node --version) installed${NC}"
    else
        echo "${RED}❌ Node.js not found after nvm install${NC}"
        exit 1
    fi

    # --- Enable corepack for pnpm ---
    echo "${YELLOW}📦 Enabling corepack (provides pnpm)...${NC}"
    corepack enable
    echo "${GREEN}✅ corepack enabled${NC}"
else
    echo "${RED}❌ nvm not available after install — you may need to restart your shell${NC}"
    exit 1
fi

echo
echo "${GREEN}🎉 macOS bootstrap complete!${NC}"
echo "${BLUE}Next step: run 'make setup' to complete the full configuration.${NC}"