#!/bin/zsh
# Deploy selected Cline skills to Claude Code's global skills directory
# Runs after Cline deployment (06) to share skills with the Claude CLI

set -e

# Source common utilities
SCRIPT_DIR="${0:A:h}"
source "${SCRIPT_DIR}/lib/common.zsh"

# Get project root and storage paths
PROJECT_ROOT="${SCRIPT_DIR:h:h}"
SKILLS_SOURCE="${PROJECT_ROOT}/src/storage/cline/skills"

# Claude Code global skills directory
CLAUDE_SKILLS_DEST="$HOME/.claude/skills"

# =============================================================================
# SKILLS TO DEPLOY — edit this list to control which skills are shared with Claude
# from the cline skills directory
# =============================================================================
CLAUDE_SKILLS=(
    git-provider
    jira
)

# Deploy a single skill to Claude's global skills directory
deploy_skill() {
    local skill_name="$1"
    local skill_src="$SKILLS_SOURCE/$skill_name"
    local skill_dest="$CLAUDE_SKILLS_DEST/$skill_name"

    if [ ! -d "$skill_src" ]; then
        warn "Skill '$skill_name' not found in $SKILLS_SOURCE — skipping"
        return 0
    fi

    mkdir -p "$skill_dest"

    # Pass 1: Deploy everything except dependencies/repos/ and evals/
    rsync -a --delete \
        --exclude="dependencies/repos/" \
        --exclude="evals/" \
        "$skill_src/" "$skill_dest/" 2>/dev/null || {
        # Fallback if rsync is unavailable
        find "$skill_src" \
            -not -path "*/dependencies/repos/*" \
            -not -path "*/evals/*" \
            -type f | while read -r src_file; do
            rel_path="${src_file#$skill_src/}"
            dest_file="$skill_dest/$rel_path"
            mkdir -p "$(dirname "$dest_file")"
            cp "$src_file" "$dest_file"
        done
    }

    # Pass 2: Seed evals/ with --ignore-existing (never overwrite appended feedback)
    if [ -d "$skill_src/evals" ]; then
        rsync -a --ignore-existing \
            "$skill_src/evals/" "$skill_dest/evals/" 2>/dev/null || {
            # Fallback: only copy if destination file does not exist
            find "$skill_src/evals" -type f | while read -r src_file; do
                rel_path="${src_file#$skill_src/}"
                dest_file="$skill_dest/$rel_path"
                if [ ! -f "$dest_file" ]; then
                    mkdir -p "$(dirname "$dest_file")"
                    cp "$src_file" "$dest_file"
                fi
            done
        }
    fi

    log "  Skill '$skill_name' -> $skill_dest"
}

# --- Main ---

info "Deploying skills to Claude Code ($CLAUDE_SKILLS_DEST)..."

mkdir -p "$CLAUDE_SKILLS_DEST"

for skill in "${CLAUDE_SKILLS[@]}"; do
    deploy_skill "$skill"
done

echo
log "Claude skills deployment complete!"