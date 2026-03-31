#!/bin/bash
# Script: prerequisites.sh
# Purpose: Verify required tools are installed for JIRA workflows

# Colors using ANSI-C quoting for cross-platform compatibility
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
NC=$'\033[0m'

MISSING=()

echo "Checking JIRA workflow prerequisites..."
echo ""

# Check for jira CLI (jira-cli-go)
if command -v jira &> /dev/null; then
  VERSION=$(jira version 2>/dev/null | head -1)
  echo "${GREEN}[OK]${NC} jira CLI: $VERSION"
else
  echo "${RED}[MISSING]${NC} jira CLI (jira-cli-go)"
  MISSING+=("jira")
fi

# Check for GitHub CLI
if command -v gh &> /dev/null; then
  VERSION=$(gh --version 2>/dev/null | head -1)
  echo "${GREEN}[OK]${NC} GitHub CLI: $VERSION"
  
  # Check if authenticated
  if gh auth status &> /dev/null; then
    echo "${GREEN}[OK]${NC} GitHub CLI: authenticated"
  else
    echo "${YELLOW}[WARN]${NC} GitHub CLI: not authenticated (run 'gh auth login')"
  fi
else
  echo "${RED}[MISSING]${NC} GitHub CLI (gh)"
  MISSING+=("gh")
fi

# Check for jq
if command -v jq &> /dev/null; then
  VERSION=$(jq --version 2>/dev/null)
  echo "${GREEN}[OK]${NC} jq: $VERSION"
else
  echo "${RED}[MISSING]${NC} jq (JSON processor)"
  MISSING+=("jq")
fi

# Check for git
if command -v git &> /dev/null; then
  VERSION=$(git --version 2>/dev/null)
  echo "${GREEN}[OK]${NC} git: $VERSION"
else
  echo "${RED}[MISSING]${NC} git"
  MISSING+=("git")
fi

echo ""

# Report results
if [ ${#MISSING[@]} -eq 0 ]; then
  echo "${GREEN}All prerequisites are installed.${NC}"
  exit 0
else
  echo "${RED}Missing tools: ${MISSING[*]}${NC}"
  echo ""
  echo "Installation instructions:"
  echo ""
  
  for tool in "${MISSING[@]}"; do
    case "$tool" in
      jira)
        echo "  jira CLI (jira-cli-go):"
        echo "    macOS:   brew install jira-cli"
        echo "    Linux:   brew install jira-cli (or download from GitHub)"
        echo "    Windows: scoop install jira-cli"
        echo "    After install: jira init"
        echo ""
        ;;
      gh)
        echo "  GitHub CLI:"
        echo "    macOS:   brew install gh"
        echo "    Linux:   brew install gh (or apt install gh)"
        echo "    Windows: winget install GitHub.cli"
        echo "    After install: gh auth login"
        echo ""
        ;;
      jq)
        echo "  jq:"
        echo "    macOS:   brew install jq"
        echo "    Linux:   apt install jq"
        echo "    Windows: winget install jqlang.jq"
        echo ""
        ;;
      git)
        echo "  git:"
        echo "    macOS:   brew install git (or Xcode Command Line Tools)"
        echo "    Linux:   apt install git"
        echo "    Windows: winget install Git.Git"
        echo ""
        ;;
    esac
  done
  
  exit 1
fi