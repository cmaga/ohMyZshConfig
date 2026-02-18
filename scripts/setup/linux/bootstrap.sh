#!/bin/bash
# Linux Bootstrap Script
# Installs make, git, and zsh so that 'make setup' can handle the rest

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
    echo "Please install the following manually: git, make, zsh"
    exit 1
fi

echo "${BLUE}Detected package manager: ${PM}${NC}"
echo

install_packages() {
    case "$PM" in
        apt)
            sudo apt-get update -qq
            sudo apt-get install -y git make zsh
            ;;
        dnf)
            sudo dnf install -y git make zsh
            ;;
        yum)
            sudo yum install -y git make zsh
            ;;
        pacman)
            sudo pacman -S --noconfirm --needed git make zsh
            ;;
        zypper)
            sudo zypper install -y git make zsh
            ;;
    esac
}

# Check which packages are missing
MISSING=()
for tool in git make zsh; do
    if ! command -v "$tool" &>/dev/null; then
        MISSING+=("$tool")
    fi
done

if [ ${#MISSING[@]} -eq 0 ]; then
    echo "${GREEN}✅ All prerequisites already installed (git, make, zsh)${NC}"
else
    echo "${YELLOW}📦 Installing missing packages: ${MISSING[*]}${NC}"
    install_packages
fi

# Verify
echo
echo "${BLUE}Verifying tools...${NC}"

for tool in git make zsh; do
    if command -v "$tool" &>/dev/null; then
        echo "${GREEN}✅ $tool found${NC}"
    else
        echo "${RED}❌ $tool not found — installation may have failed${NC}"
        exit 1
    fi
done

echo
echo "${GREEN}🎉 Linux bootstrap complete!${NC}"
echo "${BLUE}Next step: run 'make setup' to complete the full configuration.${NC}"