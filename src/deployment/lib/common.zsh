#!/bin/zsh
# Common utilities for deployment scripts
# Provides colors, logging, platform detection, and path resolution

# =============================================================================
# COLOR DEFINITIONS (ANSI-C quoting for cross-shell compatibility)
# =============================================================================
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
CYAN=$'\033[0;36m'
NC=$'\033[0m' # No Color

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

# Print green success message
log() {
    echo "${GREEN}$1${NC}"
}

# Print yellow warning message
warn() {
    echo "${YELLOW}WARNING: $1${NC}"
}

# Print red error message and exit
error() {
    echo "${RED}ERROR: $1${NC}"
    exit 1
}

# Print blue info message
info() {
    echo "${BLUE}$1${NC}"
}

# Print cyan action message
action() {
    echo "${CYAN}$1${NC}"
}

# Print colored output with message type (for verbose logging)
print_status() {
    local msg_type=$1
    local message=$2
    case "$msg_type" in
        "info") echo "${BLUE}[INFO] ${message}${NC}" ;;
        "success") echo "${GREEN}[OK] ${message}${NC}" ;;
        "error") echo "${RED}[ERROR] ${message}${NC}" ;;
        "warning") echo "${YELLOW}[WARN] ${message}${NC}" ;;
        "action") echo "${CYAN}[ACTION] ${message}${NC}" ;;
        "install") echo "${CYAN}[INSTALL] ${message}${NC}" ;;
        "download") echo "${CYAN}[DOWNLOAD] ${message}${NC}" ;;
        *) echo "${message}" ;;
    esac
}

# =============================================================================
# PLATFORM DETECTION
# =============================================================================

# Detect operating system
# Returns: "macos", "linux", "windows", or "unknown"
detect_os() {
    case "$OSTYPE" in
        darwin*) echo "macos" ;;
        linux*) echo "linux" ;;
        msys*|cygwin*|mingw*) echo "windows" ;;
        *) echo "unknown" ;;
    esac
}

# Detect package manager
# Returns: "brew", "apt", "dnf", "yum", "pacman", "zypper", or "unknown"
detect_package_manager() {
    if command -v brew >/dev/null 2>&1; then
        echo "brew"
    elif command -v apt-get >/dev/null 2>&1; then
        echo "apt"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v yum >/dev/null 2>&1; then
        echo "yum"
    elif command -v pacman >/dev/null 2>&1; then
        echo "pacman"
    elif command -v zypper >/dev/null 2>&1; then
        echo "zypper"
    else
        echo "unknown"
    fi
}

# =============================================================================
# PATH RESOLUTION
# =============================================================================

# Get directory containing the current script
# Usage: SCRIPT_DIR=$(get_script_dir)
get_script_dir() {
    echo "${0:A:h}"
}

# Get project root directory (navigates up from lib/ to project root)
# Assumes this file is at src/deployment/lib/common.zsh
# Usage: PROJECT_ROOT=$(get_project_root)
get_project_root() {
    local lib_dir="${0:A:h}"
    # Navigate up: lib -> deployment -> src -> project_root
    echo "${lib_dir:h:h:h}"
}

# Get storage directory path
# Usage: STORAGE_DIR=$(get_storage_dir)
get_storage_dir() {
    echo "$(get_project_root)/src/storage"
}

# Get deployment directory path
# Usage: DEPLOYMENT_DIR=$(get_deployment_dir)
get_deployment_dir() {
    echo "$(get_project_root)/src/deployment"
}

# =============================================================================
# COMMON PATHS
# =============================================================================

# Oh-My-Zsh directory
OMZ_DIR="${ZSH:-$HOME/.oh-my-zsh}"

# Cline directories
CLINE_DOCS_DIR="$HOME/Documents/Cline"
CLINE_RULES_DEST="$CLINE_DOCS_DIR/Rules"
CLINE_WORKFLOWS_DEST="$CLINE_DOCS_DIR/Workflows"
CLINE_HOOKS_DEST="$CLINE_DOCS_DIR/Hooks"
CLINE_SKILLS_DEST="$HOME/.cline/skills"

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install a package using the detected package manager
install_package() {
    local package=$1
    local pm=$(detect_package_manager)
    
    case "$pm" in
        "brew")
            print_status "install" "Installing $package via Homebrew..."
            brew install "$package"
            ;;
        "apt")
            print_status "install" "Installing $package via apt..."
            sudo apt-get update -qq
            sudo apt-get install -y "$package"
            ;;
        "yum")
            print_status "install" "Installing $package via yum..."
            sudo yum install -y "$package"
            ;;
        "dnf")
            print_status "install" "Installing $package via dnf..."
            sudo dnf install -y "$package"
            ;;
        "pacman")
            print_status "install" "Installing $package via pacman..."
            sudo pacman -S --noconfirm "$package"
            ;;
        "zypper")
            print_status "install" "Installing $package via zypper..."
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
            return 1
            ;;
    esac
}