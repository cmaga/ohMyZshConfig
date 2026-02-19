#!/bin/zsh
# System Setup Script for Oh-My-Zsh Configuration
# Handles fresh system setup including zsh and Oh-My-Zsh installation

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local msg_type=$1
    local message=$2
    case "$msg_type" in
        "info") echo -e "${BLUE}🔍 ${message}${NC}" ;;
        "success") echo -e "${GREEN}✅ ${message}${NC}" ;;
        "error") echo -e "${RED}❌ ${message}${NC}" ;;
        "warning") echo -e "${YELLOW}⚠️  ${message}${NC}" ;;
        "action") echo -e "${CYAN}🔄 ${message}${NC}" ;;
        "install") echo -e "${CYAN}📦 ${message}${NC}" ;;
        "download") echo -e "${CYAN}📥 ${message}${NC}" ;;
        *) echo -e "${message}" ;;
    esac
}

# Function to detect package manager
detect_package_manager() {
    if command -v brew >/dev/null 2>&1; then
        echo "brew"
    elif command -v apt-get >/dev/null 2>&1; then
        echo "apt"
    elif command -v yum >/dev/null 2>&1; then
        echo "yum"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v pacman >/dev/null 2>&1; then
        echo "pacman"
    elif command -v zypper >/dev/null 2>&1; then
        echo "zypper"
    else
        echo "unknown"
    fi
}

# Function to install package using detected package manager
install_package() {
    local package=$1
    local pm=$(detect_package_manager)
    
    case "$pm" in
        "brew")
            print_install "Installing $package via Homebrew..."
            brew install "$package"
            ;;
        "apt")
            print_install "Installing $package via apt..."
            sudo apt-get update -qq
            sudo apt-get install -y "$package"
            ;;
        "yum")
            print_install "Installing $package via yum..."
            sudo yum install -y "$package"
            ;;
        "dnf")
            print_install "Installing $package via dnf..."
            sudo dnf install -y "$package"
            ;;
        "pacman")
            print_install "Installing $package via pacman..."
            sudo pacman -S --noconfirm "$package"
            ;;
        "zypper")
            print_install "Installing $package via zypper..."
            sudo zypper install -y "$package"
            ;;
        *)
            print_status "error" "Unknown package manager. Please install $package manually."
            echo "Common installation commands:"
            echo "  macOS: brew install $package"
            echo "  Ubuntu/Debian: sudo apt-get install $package"
            echo "  RHEL/CentOS: sudo yum install $package"
            echo "  Fedora: sudo dnf install $package"
            echo "  Arch: sudo pacman -S $package"
            exit 1
            ;;
    esac
}

# Function to check and install git
check_install_git() {
    print_status "info" "Checking for git..."
    
    if command -v git >/dev/null 2>&1; then
        local git_version=$(git --version | cut -d' ' -f3)
        print_status "success" "Git found (version $git_version)"
        return 0
    fi
    
    print_status "error" "Git not found"
    install_package "git"
    
    # Verify installation
    if command -v git >/dev/null 2>&1; then
        local git_version=$(git --version | cut -d' ' -f3)
        print_status "success" "Git installed successfully (version $git_version)"
    else
        print_status "error" "Git installation failed"
        exit 1
    fi
}

# Function to check and install curl
check_install_curl() {
    print_status "info" "Checking for curl..."
    
    if command -v curl >/dev/null 2>&1; then
        local curl_version=$(curl --version | head -n1 | cut -d' ' -f2)
        print_status "success" "Curl found (version $curl_version)"
        return 0
    fi
    
    print_status "error" "Curl not found"
    install_package "curl"
    
    # Verify installation
    if command -v curl >/dev/null 2>&1; then
        local curl_version=$(curl --version | head -n1 | cut -d' ' -f2)
        print_status "success" "Curl installed successfully (version $curl_version)"
    else
        print_status "error" "Curl installation failed"
        exit 1
    fi
}

# Function to check and install zsh
check_install_zsh() {
    print_status "info" "Checking for zsh..."
    
    if command -v zsh >/dev/null 2>&1; then
        local zsh_version=$(zsh --version | cut -d' ' -f2)
        print_status "success" "Zsh found (version $zsh_version)"
        return 0
    fi
    
    print_status "error" "Zsh not found"
    install_package "zsh"
    
    # Verify installation
    if command -v zsh >/dev/null 2>&1; then
        local zsh_version=$(zsh --version | cut -d' ' -f2)
        print_status "success" "Zsh installed successfully (version $zsh_version)"
    else
        print_status "error" "Zsh installation failed"
        exit 1
    fi
}

# Function to set zsh as default shell
set_default_shell() {
    print_status "info" "Checking default shell..."
    
    local current_shell=$(basename "$SHELL")
    local zsh_path=$(which zsh)
    
    if [[ "$SHELL" == "$zsh_path" ]]; then
        print_status "success" "Zsh is already the default shell"
        return 0
    fi
    
    # Check for exec zsh workaround in .bashrc (for restricted environments)
    if [[ -f "$HOME/.bashrc" ]] && grep -q "exec zsh" "$HOME/.bashrc" 2>/dev/null; then
        print_status "success" "Found 'exec zsh' workaround in .bashrc - shell setup complete"
        print_status "info" "Skipping chsh (using bashrc workaround for restricted environments)"
        return 0
    fi
    
    print_status "warning" "Current shell is $current_shell"
    print_status "action" "Setting zsh as default shell..."
    
    # Check if zsh is in /etc/shells
    if ! grep -q "$zsh_path" /etc/shells 2>/dev/null; then
        print_status "action" "Adding zsh to /etc/shells..."
        echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
    fi
    
    # Change default shell
    if chsh -s "$zsh_path" 2>/dev/null; then
        print_status "success" "Default shell changed to zsh"
        print_status "warning" "You'll need to restart your terminal for this to take effect"
    else
        print_status "error" "Failed to change default shell"
        echo "💡 You may need to run: chsh -s $zsh_path"
        echo "💡 Or check with your system administrator"
    fi
}

# Function to install Oh-My-Zsh
install_oh_my_zsh() {
    local omz_dir="${ZSH:-$HOME/.oh-my-zsh}"
    
    print_status "info" "Checking for Oh-My-Zsh..."
    
    if [[ -d "$omz_dir" ]]; then
        print_status "success" "Oh-My-Zsh found at $omz_dir"
        return 0
    fi
    
    print_status "error" "Oh-My-Zsh not found"
    print_status "download" "Installing Oh-My-Zsh..."
    
    # Download and install Oh-My-Zsh
    if sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; then
        print_status "success" "Oh-My-Zsh installed successfully"
    else
        print_status "error" "Oh-My-Zsh installation failed"
        exit 1
    fi
    
    # Verify installation
    if [[ -d "$omz_dir" ]]; then
        print_status "success" "Oh-My-Zsh verified at $omz_dir"
        
        # Create custom directory if it doesn't exist
        if [[ ! -d "$omz_dir/custom" ]]; then
            print_status "action" "Creating custom directory..."
            mkdir -p "$omz_dir/custom"
            print_status "success" "Custom directory created"
        else
            print_status "success" "Custom directory exists"
        fi
    else
        print_status "error" "Oh-My-Zsh installation verification failed"
        exit 1
    fi
}

# Function to create necessary directories
create_directories() {
    local omz_dir="${ZSH:-$HOME/.oh-my-zsh}"
    
    print_status "info" "Setting up directory structure..."
    
    # Create plugins directory
    local plugins_dir="$omz_dir/custom/plugins"
    if [[ ! -d "$plugins_dir" ]]; then
        print_status "action" "Creating plugins directory..."
        mkdir -p "$plugins_dir"
        print_status "success" "Plugins directory created at $plugins_dir"
    else
        print_status "success" "Plugins directory exists"
    fi
    
    # Create scripts directory  
    local scripts_dir="$omz_dir/custom/scripts"
    if [[ ! -d "$scripts_dir" ]]; then
        print_status "action" "Creating scripts directory..."
        mkdir -p "$scripts_dir"
        print_status "success" "Scripts directory created at $scripts_dir"
    else
        print_status "success" "Scripts directory exists"
    fi
    
    # Create git profile directories
    local work_dir="$HOME/dev/work"
    if [[ ! -d "$work_dir" ]]; then
        print_status "action" "Creating work directory for git profile..."
        mkdir -p "$work_dir"
        print_status "success" "Work directory created at $work_dir"
    else
        print_status "success" "Work directory exists"
    fi
    
    local personal_dir="$HOME/dev/personal"
    if [[ ! -d "$personal_dir" ]]; then
        print_status "action" "Creating personal directory..."
        mkdir -p "$personal_dir"
        print_status "success" "Personal directory created at $personal_dir"
    else
        print_status "success" "Personal directory exists"
    fi
    
    local kratos_dir="$HOME/dev/kratos"
    if [[ ! -d "$kratos_dir" ]]; then
        print_status "action" "Creating kratos directory for git profile..."
        mkdir -p "$kratos_dir"
        print_status "success" "Kratos directory created at $kratos_dir"
    else
        print_status "success" "Kratos directory exists"
    fi
}

# Function to check and install Claude
check_install_claude() {
    print_status "info" "Checking for Claude..."
    
    if command -v claude >/dev/null 2>&1; then
        print_status "success" "Claude found"
        return 0
    fi
    
    print_status "warning" "Claude not found"
    print_status "download" "Installing Claude..."
    
    if curl -fsSL https://claude.ai/install.sh | bash; then
        print_status "success" "Claude installed successfully"
    else
        print_status "error" "Claude installation failed"
        return 1
    fi
}

# Function to check system readiness
check_system_readiness() {
    print_status "info" "Performing final system checks..."
    
    # Check if we can run zsh
    if ! zsh -c "echo 'Zsh test passed'" >/dev/null 2>&1; then
        print_status "error" "Zsh is not working properly"
        exit 1
    fi
    print_status "success" "Zsh is functional"
    
    # Check Oh-My-Zsh structure
    local omz_dir="${ZSH:-$HOME/.oh-my-zsh}"
    if [[ ! -f "$omz_dir/oh-my-zsh.sh" ]]; then
        print_status "error" "Oh-My-Zsh core files missing"
        exit 1
    fi
    print_status "success" "Oh-My-Zsh core files present"
    
    # Check custom directories
    if [[ ! -d "$omz_dir/custom" ]]; then
        print_status "error" "Oh-My-Zsh custom directory missing"
        exit 1
    fi
    print_status "success" "Oh-My-Zsh custom directory ready"
}

# Main function
main() {
    echo
    print_status "info" "Starting system setup for Oh-My-Zsh configuration..."
    echo
    
    # Early exit check - if aliases.zsh exists, setup was already run
    local omz_dir="${ZSH:-$HOME/.oh-my-zsh}"
    if [[ -f "$omz_dir/custom/aliases.zsh" ]]; then
        print_status "success" "System already configured (aliases.zsh found)"
        print_status "info" "Setup was previously completed - no changes needed"
        print_status "info" "To force a re-setup, remove $omz_dir/custom/aliases.zsh and run setup again"
        echo
        return 1
    fi
    
    # Step 1: Check and install prerequisites
    print_status "info" "Step 1: Installing prerequisites..."
    check_install_git
    check_install_curl
    echo
    
    # Step 2: Setup zsh
    print_status "info" "Step 2: Setting up Zsh..."
    check_install_zsh
    set_default_shell
    echo
    
    # Step 3: Install Oh-My-Zsh
    print_status "info" "Step 3: Installing Oh-My-Zsh..."
    install_oh_my_zsh
    echo
    
    # Step 4: Create directory structure
    print_status "info" "Step 4: Setting up directories..."
    create_directories
    echo
    
    # Step 5: Install Claude (skip on Windows - handled by windows-bootstrap-1.ps1)
    if [[ "$OSTYPE" != msys* && "$OSTYPE" != cygwin* && "$OSTYPE" != mingw* ]]; then
        print_status "info" "Step 5: Installing Claude..."
        check_install_claude
        echo
    else
        print_status "info" "Step 5: Skipping Claude install (handled by Windows setup script)"
        echo
    fi
    
    # Step 6: Final verification
    print_status "info" "Step 6: System verification..."
    check_system_readiness
    echo
    
    print_status "success" "System setup completed successfully!"
    echo
    print_status "info" "System is now ready for Oh-My-Zsh configuration deployment"
    echo
}

# Run main function if script is executed directly
if [[ "${(%):-%x}" == "${0}" ]]; then
    main "$@"
fi
