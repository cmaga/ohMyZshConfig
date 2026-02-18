#!/bin/bash
# macOS Bootstrap Script
# Ensures Xcode Command Line Tools are installed (provides git, make, and other essentials)
# zsh is already the default shell on macOS

set -e

GREEN=$'\033[0;32m'
BLUE=$'\033[0;34m'
YELLOW=$'\033[1;33m'
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

echo
echo "${GREEN}🎉 macOS bootstrap complete!${NC}"
echo "${BLUE}Next step: run 'make setup' to complete the full configuration.${NC}"