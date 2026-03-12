#!/bin/zsh
# Simple Dependencies Script
# Installs basic tools that don't require additional configuration
# These are prerequisites needed before other scripts can run

set -e

# Source common utilities
SCRIPT_DIR="${0:A:h}"
source "${SCRIPT_DIR}/lib/common.zsh"

# function to install git if not present
check_install_git() {
    print_status "info" "Checking for git..."
    
    if command_exists git; then
        local git_version=$(git --version | cut -d' ' -f3)
        print_status "success" "Git found (version $git_version)"
        return 0
    fi
    
    print_status "warning" "Git not found"
    install_package "git"
    
    # Verify installation
    if command_exists git; then
        local git_version=$(git --version | cut -d' ' -f3)
        print_status "success" "Git installed successfully (version $git_version)"
    else
        print_status "error" "Git installation failed"
        exit 1
    fi
}

# function to install direnv if not present
# - Windows: uses the official install script (curl -sfL https://direnv.net/install.sh | bash)
# - Linux/macOS: uses the system package manager
check_install_direnv() {
    local os=$(detect_os)
    
    print_status "info" "Checking for direnv..."
    
    if command_exists direnv; then
        local direnv_version=$(direnv version 2>/dev/null || echo "unknown")
        print_status "success" "direnv found (version $direnv_version)"
        return 0
    fi
    
    print_status "warning" "direnv not found"
    
    if [[ "$os" == "windows" ]]; then
        print_status "install" "Installing direnv via install script..."
        curl -sfL https://direnv.net/install.sh | bash
    else
        install_package "direnv"
    fi
    
    # Verify installation
    if command_exists direnv; then
        local direnv_version=$(direnv version 2>/dev/null || echo "unknown")
        print_status "success" "direnv installed successfully (version $direnv_version)"
    else
        print_status "error" "direnv installation failed"
        exit 1
    fi
}

# function to install curl if not present
check_install_curl() {
    print_status "info" "Checking for curl..."
    
    if command_exists curl; then
        local curl_version=$(curl --version | head -n1 | cut -d' ' -f2)
        print_status "success" "Curl found (version $curl_version)"
        return 0
    fi
    
    print_status "warning" "Curl not found"
    install_package "curl"
    
    # Verify installation
    if command_exists curl; then
        local curl_version=$(curl --version | head -n1 | cut -d' ' -f2)
        print_status "success" "Curl installed successfully (version $curl_version)"
    else
        print_status "error" "Curl installation failed"
        exit 1
    fi
}

# Main function
main() {
    echo
    print_status "info" "Installing simple dependencies..."
    echo
    
    check_install_git
    check_install_curl
    check_install_direnv
    
    echo
    print_status "success" "Simple dependencies installed!"
    echo
}

# Run main function if script is executed directly
if [[ "${(%):-%x}" == "${0}" ]]; then
    main "$@"
fi