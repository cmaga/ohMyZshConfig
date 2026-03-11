#!/bin/zsh
# Company Setup Script
# Creates development directories. Generates SSH keys for each company/service combination using the kgen script.
# The keys are created based on if the identity file name matches the company/service combination.
#

set -e

# Source common utilities
SCRIPT_DIR="${0:A:h}"
source "${SCRIPT_DIR}/lib/common.zsh"

# ============================================================================
# CONFIGURATION - Edit these values to add/remove companies or services
# ============================================================================

# Development directory prefix
DEV_PREFIX="$HOME/dev"

# List of company acronyms
COMPANIES=("gsi" "ms")

# Services to create SSH keys for (all companies get keys for all services)
SERVICES=("github" "bitbucket")

# ============================================================================
# Script - No need to edit below this line
# ============================================================================

# Get project root and storage paths
PROJECT_ROOT="${SCRIPT_DIR:h:h}"
STORAGE_DIR="${PROJECT_ROOT}/src/storage"
KGEN_SCRIPT="${STORAGE_DIR}/scripts/ssh-key-generator.zsh"

# Check kgen exists
if [[ ! -f "$KGEN_SCRIPT" ]]; then
    print_color $RED "Error: kgen script not found: $KGEN_SCRIPT"
    exit 1
fi

print_color $BLUE "Company Setup"
print_color $BLUE "============="
echo ""

# Track what was created
DIRS_CREATED=()
KEYS_CREATED=()

# Process each company
for company in "${COMPANIES[@]}"; do
    print_color $BLUE "Setting up: $company"
    
    # Create directory
    company_dir="$DEV_PREFIX/$company"
    if [[ ! -d "$company_dir" ]]; then
        mkdir -p "$company_dir"
        DIRS_CREATED+=("$company_dir")
        print_color $GREEN "  Created directory: $company_dir"
    else
        print_color $YELLOW "  Directory exists: $company_dir"
    fi
    
    # Create SSH keys for all services
    for service in "${SERVICES[@]}"; do
        print_color $BLUE "  Creating SSH key for $service..."
        
        # Run kgen non-interactively
        if "$KGEN_SCRIPT" --create "$service" "$company" 2>/dev/null; then
            KEYS_CREATED+=("${service}-${company}")
        fi
    done
    
    echo ""
done

# Create default personal directory
personal_dir="$DEV_PREFIX/personal"
if [[ ! -d "$personal_dir" ]]; then
    mkdir -p "$personal_dir"
    DIRS_CREATED+=("$personal_dir")
    print_color $GREEN "Created personal directory: $personal_dir"
else
    print_color $YELLOW "Personal directory exists: $personal_dir"
fi

# Create default SSH keys for personal use (no suffix)
print_color $BLUE "Setting up personal SSH keys (default)..."
echo ""
for service in "${SERVICES[@]}"; do
    print_color $BLUE "  Creating default SSH key for $service..."
    
    # Run kgen with --create-default flag
    if "$KGEN_SCRIPT" --create-default "$service" 2>/dev/null; then
        KEYS_CREATED+=("${service}-default")
    fi
done
echo ""

# Summary
echo ""
print_color $BLUE "Setup Complete!"
print_color $BLUE "==============="
echo ""

if [[ ${#DIRS_CREATED[@]} -gt 0 ]]; then
    print_color $GREEN "Created directories:"
    for dir in "${DIRS_CREATED[@]}"; do
        echo "  $dir"
    done
    echo ""
fi

if [[ ${#KEYS_CREATED[@]} -gt 0 ]]; then
    print_color $GREEN "Created SSH keys:"
    for key in "${KEYS_CREATED[@]}"; do
        echo "  $key"
    done
    echo ""
fi