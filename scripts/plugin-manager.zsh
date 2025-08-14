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
        print_color $BLUE "  📂 Plugin directory: $plugin_path"
        
        # Try to update from main branch first, then master
        local update_success=false
        if (cd "$plugin_path" && git pull origin main 2>&1); then
            update_success=true
        elif (cd "$plugin_path" && git pull origin master 2>&1); then
            update_success=true
        fi
        
        if [[ $update_success == true ]]; then
            print_color $GREEN "✅ Updated $plugin_name successfully"
        else
            print_color $YELLOW "⚠️  Could not update $plugin_name (might already be up to date or repository unavailable)"
        fi
    else
        # Plugin doesn't exist, clone it
        print_color $BLUE "📥 Installing $plugin_name..."
        print_color $BLUE "  🌐 Repository URL: $plugin_url"
        print_color $BLUE "  📂 Install location: $plugin_path"
        echo
        
        if git clone "$plugin_url" "$plugin_path"; then
            print_color $GREEN "✅ Successfully installed $plugin_name"
        else
            print_color $RED "❌ Failed to install $plugin_name"
            print_color $RED "  Repository: $plugin_url"
            print_color $RED "  This usually means:"
            print_color $RED "    - Repository doesn't exist"
            print_color $RED "    - Network connectivity issues"
            print_color $RED "    - Invalid repository format in plugins.txt"
            return 1
        fi
    fi
}

# Function to get plugin names from plugins.txt
get_plugin_names_from_file() {
    local plugin_names=()
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Remove leading/trailing whitespace
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # Skip if line is empty after trimming
        [[ -z "$line" ]] && continue
        
        # Extract plugin name (everything after the last slash)
        local plugin_name=$(basename "$line")
        plugin_names+=("$plugin_name")
    done < "$PLUGINS_FILE"
    
    echo "${plugin_names[@]}"
}

# Function to update .zshrc plugins array
update_zshrc_plugins() {
    local zshrc_path="$HOME/.zshrc"
    local backup_path="$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
    
    if [[ ! -f "$zshrc_path" ]]; then
        print_color $RED "❌ .zshrc not found at $zshrc_path"
        return 1
    fi
    
    # Get plugin names from plugins.txt
    local plugin_names=($(get_plugin_names_from_file))
    
    if [[ ${#plugin_names[@]} -eq 0 ]]; then
        print_color $BLUE "ℹ️  No plugins found in plugins.txt to add to .zshrc"
        return 0
    fi
    
    # Read current plugins from .zshrc
    local current_plugins=()
    local in_plugins_array=false
    local plugins_array_content=""
    
    while IFS= read -r line; do
        if [[ "$line" == *"plugins=("* ]]; then
            in_plugins_array=true
            continue
        elif [[ $in_plugins_array == true && "$line" == ")" ]]; then
            break
        elif [[ $in_plugins_array == true ]]; then
            # Extract plugin name from line (remove whitespace and comments)
            local plugin=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/#.*//')
            if [[ -n "$plugin" ]]; then
                current_plugins+=("$plugin")
            fi
        fi
    done < "$zshrc_path"
    
    # Find missing plugins
    local missing_plugins=()
    for plugin in "${plugin_names[@]}"; do
        local found=false
        for current in "${current_plugins[@]}"; do
            if [[ "$current" == "$plugin" ]]; then
                found=true
                break
            fi
        done
        if [[ $found == false ]]; then
            missing_plugins+=("$plugin")
        fi
    done
    
    if [[ ${#missing_plugins[@]} -eq 0 ]]; then
        print_color $BLUE "ℹ️  All plugins from plugins.txt are already in .zshrc"
        return 0
    fi
    
    # Create backup
    cp "$zshrc_path" "$backup_path"
    print_color $BLUE "📋 Created backup: $backup_path"
    
    # Add missing plugins to .zshrc
    local temp_file=$(mktemp)
    local in_plugins_array=false
    local added_plugins=false
    
    while IFS= read -r line; do
        if [[ "$line" == *"plugins=("* ]]; then
            echo "$line" >> "$temp_file"
            in_plugins_array=true
        elif [[ $in_plugins_array == true && "$line" == ")" ]]; then
            # Add missing plugins before closing parenthesis
            for missing_plugin in "${missing_plugins[@]}"; do
                echo "$missing_plugin" >> "$temp_file"
                added_plugins=true
            done
            echo "$line" >> "$temp_file"
            in_plugins_array=false
        else
            echo "$line" >> "$temp_file"
        fi
    done < "$zshrc_path"
    
    # Replace original file
    mv "$temp_file" "$zshrc_path"
    
    if [[ $added_plugins == true ]]; then
        print_color $GREEN "✅ Added missing plugins to .zshrc:"
        for plugin in "${missing_plugins[@]}"; do
            print_color $GREEN "  + $plugin"
        done
    fi
    
    return 0
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
    
    # Update .zshrc plugins array if any plugins were successfully processed
    if [[ $success_count -gt 0 ]]; then
        echo
        print_color $BLUE "🔧 Updating .zshrc plugins configuration..."
        if update_zshrc_plugins; then
            print_color $GREEN "✅ .zshrc plugins array updated successfully"
        else
            print_color $YELLOW "⚠️  Could not update .zshrc plugins array"
        fi
    fi
    
    # Summary
    echo
    print_color $BLUE "📊 Plugin Management Summary:"
    print_color $GREEN "  📦 Total processed: $total_count"
    if [[ $new_count -gt 0 ]]; then
        print_color $GREEN "  ⬇️  Newly installed: $new_count"
    fi
    if [[ $updated_count -gt 0 ]]; then
        print_color $GREEN "  🔄 Updated: $updated_count"
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
if [[ "${(%):-%x}" == "${0}" ]] || [[ "${0}" == *"plugin-manager.zsh" ]]; then
    main "$@"
fi
