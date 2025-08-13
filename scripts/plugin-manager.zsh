#!/bin/zsh
# Oh-My-Zsh Plugin Manager
# Automatically installs and updates plugins listed in plugins.txt

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PLUGINS_FILE="$(dirname "$(dirname "$(realpath "$0")")")/plugins.txt"
OMZ_DIR="${ZSH:-$HOME/.oh-my-zsh}"
PLUGINS_DIR="$OMZ_DIR/custom/plugins"

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to check if Oh-My-Zsh is installed
check_omz_installation() {
    if [[ ! -d "$OMZ_DIR" ]]; then
        print_color $RED "❌ Oh-My-Zsh not found at $OMZ_DIR"
        print_color $BLUE "Please install Oh-My-Zsh first:"
        print_color $BLUE "sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
        exit 1
    fi
    
    # Ensure custom plugins directory exists
    mkdir -p "$PLUGINS_DIR"
}

# Function to check if plugins.txt exists
check_plugins_file() {
    if [[ ! -f "$PLUGINS_FILE" ]]; then
        print_color $RED "❌ plugins.txt not found at $PLUGINS_FILE"
        print_color $BLUE "Please create a plugins.txt file with one plugin per line:"
        print_color $BLUE "Example format: zsh-users/zsh-autosuggestions"
        exit 1
    fi
}

# Function to install or update a plugin
manage_plugin() {
    local plugin_spec=$1
    local plugin_name=$(basename "$plugin_spec")
    local plugin_path="$PLUGINS_DIR/$plugin_name"
    local plugin_url="https://github.com/$plugin_spec.git"
    
    if [[ -d "$plugin_path" ]]; then
        # Plugin exists, update it
        print_color $BLUE "🔄 Updating $plugin_name..."
        if (cd "$plugin_path" && git pull origin main 2>/dev/null) || (cd "$plugin_path" && git pull origin master 2>/dev/null); then
            print_color $GREEN "✅ Updated $plugin_name"
        else
            print_color $YELLOW "⚠️  Could not update $plugin_name (might already be up to date)"
        fi
    else
        # Plugin doesn't exist, clone it
        print_color $BLUE "📥 Installing $plugin_name..."
        if git clone "$plugin_url" "$plugin_path" 2>/dev/null; then
            print_color $GREEN "✅ Installed $plugin_name"
        else
            print_color $RED "❌ Failed to install $plugin_name from $plugin_url"
            return 1
        fi
    fi
}

# Function to process all plugins
process_plugins() {
    local success_count=0
    local fail_count=0
    local total_count=0
    local new_count=0
    local updated_count=0
    
    print_color $BLUE "🔌 Processing custom plugins from plugins.txt..."
    echo
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Remove leading/trailing whitespace
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # Skip if line is empty after trimming
        [[ -z "$line" ]] && continue
        
        total_count=$((total_count + 1))
        local plugin_name=$(basename "$line")
        local plugin_path="$PLUGINS_DIR/$plugin_name"
        
        if [[ -d "$plugin_path" ]]; then
            # Existing plugin - update it
            if manage_plugin "$line"; then
                success_count=$((success_count + 1))
                updated_count=$((updated_count + 1))
            else
                fail_count=$((fail_count + 1))
            fi
        else
            # New plugin - install it
            if manage_plugin "$line"; then
                success_count=$((success_count + 1))
                new_count=$((new_count + 1))
            else
                fail_count=$((fail_count + 1))
            fi
        fi
        echo
    done < "$PLUGINS_FILE"
    
    # Summary
    print_color $BLUE "📊 Plugin Management Summary:"
    print_color $GREEN "  📦 Total processed: $total_count"
    if [[ $new_count -gt 0 ]]; then
        print_color $GREEN "  ⬇️  Newly installed: $new_count"
    fi
    if [[ $updated_count -gt 0 ]]; then
        print_color $GREEN "  � Updated: $updated_count"
    fi
    if [[ $fail_count -gt 0 ]]; then
        print_color $RED "  ❌ Failed: $fail_count"
    fi
    
    if [[ $success_count -gt 0 ]]; then
        echo
        print_color $YELLOW "💡 Plugin changes will take effect after restarting your shell or running 'source ~/.zshrc'"
    fi
    
    return $fail_count
}

# Main function
main() {
    print_color $BLUE "🔌 Oh-My-Zsh Custom Plugin Manager"
    echo
    
    # Perform checks
    check_omz_installation
    check_plugins_file
    
    # Process plugins
    if process_plugins; then
        print_color $GREEN "🎉 Plugin management complete!"
        return 0
    else
        print_color $RED "❌ Some plugins failed to install/update"
        return 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
