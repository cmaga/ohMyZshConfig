#!/bin/zsh
# Script to clone or update the Cline repository for documentation reference
# This ensures we always have the latest customization documentation

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPO_DIR="$BASE_DIR/dependencies/repos/cline"

echo "=== Cline Repository Update Script ==="
echo "Base directory: $BASE_DIR"

if [ -d "$REPO_DIR" ]; then
    echo "Found existing Cline repository. Updating..."
    cd "$REPO_DIR"
    
    # Store current commit before update
    BEFORE_COMMIT=$(git log -1 --format='%h')
    
    # Pull latest changes
    git pull
    
    # Get new commit
    AFTER_COMMIT=$(git log -1 --format='%h')
    
    if [ "$BEFORE_COMMIT" = "$AFTER_COMMIT" ]; then
        echo "✓ Already up to date at commit: $AFTER_COMMIT"
    else
        echo "✓ Updated from $BEFORE_COMMIT to $AFTER_COMMIT"
        echo "Latest commit: $(git log -1 --format='%h - %s (%an, %ar)')"
    fi
else
    echo "Cline repository not found. Cloning..."
    mkdir -p "$BASE_DIR/dependencies/repos"
    cd "$BASE_DIR/dependencies/repos"
    
    git clone https://github.com/cline/cline.git
    
    if [ $? -eq 0 ]; then
        echo "✓ Repository cloned successfully"
        cd cline
        echo "Current commit: $(git log -1 --format='%h - %s (%an, %ar)')"
    else
        echo "✗ Failed to clone repository"
        exit 1
    fi
fi

echo ""
echo "Documentation available at: $REPO_DIR/docs/customization/"
echo "=== Update complete ==="