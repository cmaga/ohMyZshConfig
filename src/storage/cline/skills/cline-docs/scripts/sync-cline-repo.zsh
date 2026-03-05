#!/bin/zsh
# Sync Cline Repository
# Clones or pulls the cline/cline repository to ~/.cline/repos/cline

set -e

# Capture skill directory before any cd commands
SKILL_DIR="${0:a:h:h}"  # Parent of scripts/ = skill root
VERSION_FILE="$SKILL_DIR/.clinerules/cline-version.json"

REPO_URL="https://github.com/cline/cline.git"
REPO_DIR="$HOME/.cline/repos/cline"
BRANCH="main"

# Create repos directory if needed
mkdir -p "$HOME/.cline/repos"

if [[ -d "$REPO_DIR" ]]; then
    echo "Updating existing Cline repository..."
    cd "$REPO_DIR"
    git fetch origin
    git checkout $BRANCH
    git pull origin $BRANCH
else
    echo "Cloning Cline repository..."
    git clone --branch $BRANCH "$REPO_URL" "$REPO_DIR"
    cd "$REPO_DIR"
fi

# Output current HEAD SHA
CURRENT_SHA=$(git rev-parse HEAD)
echo ""
echo "Current HEAD: $CURRENT_SHA"

# Compare with stored version
if [[ -f "$VERSION_FILE" ]]; then
    STORED_SHA=$(jq -r '.cline_version' "$VERSION_FILE")
    echo "Stored version: $STORED_SHA"
    echo ""
    
    if [[ "$CURRENT_SHA" == "$STORED_SHA" ]]; then
        echo "No updates needed - versions match."
        exit 0
    else
        echo "Updates available!"
        echo ""
        echo "Changed files since last sync:"
        if [[ "$STORED_SHA" != "initial" ]]; then
            git diff --name-only "$STORED_SHA" HEAD -- docs/ .clinerules/ 2>/dev/null || echo "(Unable to diff - stored SHA may be invalid)"
        else
            echo "(Initial sync - no previous version to compare)"
        fi
    fi
else
    echo "No version file found at $VERSION_FILE"
fi