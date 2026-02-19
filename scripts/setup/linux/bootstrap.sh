#!/bin/bash
# Linux Bootstrap Script
# Installs make, git, zsh, nvm, Node.js LTS, and pnpm so that 'make setup' can handle the rest

set -e

GREEN=$'\033[0;32m'
BLUE=$'\033[0;34m'
YELLOW=$'\033[1;33m'
RED=$'\033[0;31m'
NC=$'\033[0m'

echo "${BLUE}🐧 Linux Bootstrap${NC}"
echo

# Detect package manager
detect_package_manager() {
    if command -v apt-get &>/dev/null; then
        echo "apt"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v yum &>/dev/null; then
        echo "yum"
    elif command -v pacman &>/dev/null; then
        echo "pacman"
    elif command -v zypper &>/dev/null; then
        echo "zypper"
    else
        echo "unknown"
    fi
}

PM=$(detect_package_manager)

if [ "$PM" = "unknown" ]; then
    echo "${RED}❌ Could not detect package manager.${NC}"
    echo "Please install the following manually: git, make, zsh, curl"
    exit 1
fi

echo "${BLUE}Detected package manager: ${PM}${NC}"
echo

install_packages() {
    case "$PM" in
        apt)
            sudo apt-get update -qq
            sudo apt-get install -y git make zsh curl
            ;;
        dnf)
            sudo dnf install -y git make zsh curl
            ;;
        yum)
            sudo yum install -y git make zsh curl
            ;;
        pacman)
            sudo pacman -S --noconfirm --needed git make zsh curl
            ;;
        zypper)
            sudo zypper install -y git make zsh curl
            ;;
    esac
}

# Check which packages are missing
MISSING=()
for tool in git make zsh curl; do
    if ! command -v "$tool" &>/dev/null; then
        MISSING+=("$tool")
    fi
done

if [ ${#MISSING[@]} -eq 0 ]; then
    echo "${GREEN}✅ All prerequisites already installed (git, make, zsh, curl)${NC}"
else
    echo "${YELLOW}📦 Installing missing packages: ${MISSING[*]}${NC}"
    install_packages
fi

# Verify system packages
echo
echo "${BLUE}Verifying tools...${NC}"

for tool in git make zsh curl; do
    if command -v "$tool" &>/dev/null; then
        echo "${GREEN}✅ $tool found${NC}"
    else
        echo "${RED}❌ $tool not found — installation may have failed${NC}"
        exit 1
    fi
done

# --- Install nvm ---
echo
export NVM_DIR="$HOME/.nvm"

if [ -s "$NVM_DIR/nvm.sh" ]; then
    echo "${GREEN}✅ nvm already installed${NC}"
else
    echo "${YELLOW}📦 Installing nvm...${NC}"
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
fi

# Source nvm for current session
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"

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
echo "${GREEN}🎉 Linux bootstrap complete!${NC}"
echo "${BLUE}Next step: run 'make setup' to complete the full configuration.${NC}"