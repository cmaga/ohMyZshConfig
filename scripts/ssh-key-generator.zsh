#!/bin/zsh
# SSH Key Generator Script
# Manages SSH keys for different hosts with organized storage and ssh-agent integration

set -e

# Configuration
SSH_DIR="$HOME/.ssh"
KEYS_DIR="$SSH_DIR/keys"
CONFIG_FILE="$SSH_DIR/config"

# Global variable to store generated key path
GENERATED_KEY_PATH=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Ensure required directories exist
mkdir -p "$KEYS_DIR"

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to copy to clipboard (cross-platform)
copy_to_clipboard() {
    local content=$1
    if command -v pbcopy >/dev/null 2>&1; then
        # macOS
        echo "$content" | pbcopy
        print_color $GREEN "✓ Public key copied to clipboard (macOS)"
    elif command -v xclip >/dev/null 2>&1; then
        # Linux with xclip
        echo "$content" | xclip -selection clipboard
        print_color $GREEN "✓ Public key copied to clipboard (Linux)"
    elif command -v clip.exe >/dev/null 2>&1; then
        # Windows (Git Bash)
        echo "$content" | clip.exe
        print_color $GREEN "✓ Public key copied to clipboard (Windows)"
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "mingw"* ]]; then
        # Windows fallback
        echo "$content" > /dev/clipboard
        print_color $GREEN "✓ Public key copied to clipboard (Windows)"
    else
        print_color $YELLOW "⚠ Could not copy to clipboard. Public key content:"
        echo "$content"
    fi
}

# Function to parse SSH config and extract hosts
get_ssh_hosts() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        return
    fi
    
    grep "^Host " "$CONFIG_FILE" | awk '{print $2}' | grep -v "\*" | sort | uniq
}

# Function to get host details from SSH config
get_host_details() {
    local host=$1
    if [[ ! -f "$CONFIG_FILE" ]]; then
        return 1
    fi
    
    awk -v host="$host" '
    /^Host / { current_host = $2; next }
    current_host == host && /^[[:space:]]*(HostName|User|IdentityFile)/ {
        gsub(/^[[:space:]]+/, "")
        print $0
    }
    ' "$CONFIG_FILE"
}

# Function to generate SSH key (fixed version using global variable)
generate_ssh_key() {
    local host=$1
    local email=$2
    local key_type=${3:-ed25519}
    
    local key_name="id_${key_type}_${host}"
    local key_path="$KEYS_DIR/$key_name"
    
    print_color $BLUE "🔑 Generating $key_type SSH key for host: $host"
    
    # Generate the key
    ssh-keygen -t "$key_type" -C "$email" -f "$key_path" -N ""
    
    # Set proper permissions
    chmod 600 "$key_path"
    chmod 644 "$key_path.pub"
    
    print_color $GREEN "✓ SSH key generated: $key_path"
    
    # Add to ssh-agent
    if ssh-add "$key_path" 2>/dev/null; then
        print_color $GREEN "✓ Key added to ssh-agent"
    else
        print_color $YELLOW "⚠ Could not add key to ssh-agent (agent might not be running)"
    fi
    
    # Copy public key to clipboard
    local pub_key_content=$(cat "$key_path.pub")
    copy_to_clipboard "$pub_key_content"
    
    # Set global variable instead of using echo/return
    GENERATED_KEY_PATH="$key_path"
}

# Function to add host to SSH config
add_host_to_config() {
    local host=$1
    local hostname=$2
    local user=$3
    local key_path=$4
    
    print_color $BLUE "📝 Adding host configuration to SSH config..."
    
    # Create backup of config
    if [[ -f "$CONFIG_FILE" ]]; then
        cp "$CONFIG_FILE" "$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Add host configuration
    cat >> "$CONFIG_FILE" << EOF

Host $host
  HostName $hostname
  User $user
  IdentityFile $key_path
  IdentitiesOnly yes
  AddKeysToAgent yes
EOF
    
    # Set proper permissions
    chmod 600 "$CONFIG_FILE"
    
    print_color $GREEN "✓ Host configuration added to SSH config"
}

# Function to show existing hosts
show_existing_hosts() {
    local hosts=($(get_ssh_hosts))
    
    if [[ ${#hosts[@]} -eq 0 ]]; then
        print_color $YELLOW "No hosts found in SSH config"
        return 1
    fi
    
    print_color $BLUE "📋 Existing SSH hosts:"
    for i in "${!hosts[@]}"; do
        echo "  $((i+1)). ${hosts[i]}"
    done
    
    return 0
}

# Function to select existing host
select_existing_host() {
    local hosts=($(get_ssh_hosts))
    local selection
    
    if [[ ${#hosts[@]} -eq 0 ]]; then
        return 1
    fi
    
    while true; do
        read "selection?Select host number (1-${#hosts[@]}): "
        if [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -le ${#hosts[@]} ]]; then
            echo "${hosts[$((selection-1))]}"
            return 0
        else
            print_color $RED "Invalid selection. Please enter a number between 1 and ${#hosts[@]}"
        fi
    done
}

# Updated create_new_host function
create_new_host() {
    local host_alias hostname username email key_type_choice
    
    print_color $BLUE "🆕 Creating new host configuration"
    
    read "host_alias?Enter host alias (e.g., 'github-work', 'server1'): "
    read "hostname?Enter hostname/IP (e.g., 'github.com', '192.168.1.100'): "
    read "username?Enter username: "
    read "email?Enter your email for the key: "
    
    # Ask for key type
    echo "Select key type:"
    echo "  1. ed25519 (recommended)"
    echo "  2. rsa"
    read "key_type_choice?Choice (1-2, default: 1): "
    
    local key_type="ed25519"
    case $key_type_choice in
        2) key_type="rsa" ;;
        *) key_type="ed25519" ;;
    esac
    
    # Generate key (uses global variable)
    generate_ssh_key "$host_alias" "$email" "$key_type"
    
    # Add to SSH config using the global variable
    add_host_to_config "$host_alias" "$hostname" "$username" "$GENERATED_KEY_PATH"
    
    print_color $GREEN "🎉 New host '$host_alias' created successfully!"
}

# Updated add_key_to_existing_host function
add_key_to_existing_host() {
    local host=$1
    local email key_type_choice
    
    print_color $BLUE "🔑 Adding new key to existing host: $host"
    
    # Get host details
    local host_details=$(get_host_details "$host")
    if [[ -z "$host_details" ]]; then
        print_color $RED "Could not find details for host: $host"
        return 1
    fi
    
    read "email?Enter your email for the key: "
    
    # Ask for key type
    echo "Select key type:"
    echo "  1. ed25519 (recommended)"
    echo "  2. rsa"
    read "key_type_choice?Choice (1-2, default: 1): "
    
    local key_type="ed25519"
    case $key_type_choice in
        2) key_type="rsa" ;;
        *) key_type="ed25519" ;;
    esac
    
    # Generate key (uses global variable)
    generate_ssh_key "$host" "$email" "$key_type"
    
    # Update SSH config with new key path
    print_color $BLUE "📝 Updating SSH config with new key..."
    
    # Create backup
    cp "$CONFIG_FILE" "$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Update IdentityFile line for this host using the global variable
    sed -i.tmp "/^Host $host$/,/^Host / s|IdentityFile.*|IdentityFile $GENERATED_KEY_PATH|" "$CONFIG_FILE"
    rm -f "$CONFIG_FILE.tmp"
    
    print_color $GREEN "🎉 Key added to host '$host' successfully!"
}

# Function to list managed keys
list_keys() {
    print_color $BLUE "🗂️  Managed SSH Keys:"
    
    # Check if keys directory exists and has files
    if [[ ! -d "$KEYS_DIR" ]]; then
        print_color $YELLOW "📁 Keys directory doesn't exist yet"
        print_color $BLUE "💡 Generate your first key by selecting option 1 or 2"
        return 0
    fi
    
    # Check if directory is empty using a simple and reliable method
    if [[ -z "$(ls -A "$KEYS_DIR" 2>/dev/null)" ]]; then
        print_color $YELLOW "📁 No SSH keys found in $KEYS_DIR"
        print_color $BLUE "💡 Generate your first key by selecting option 1 or 2"
        return 0
    fi
    
    # Check if ssh-agent is accessible
    local agent_status=""
    if ! ssh-add -l >/dev/null 2>&1; then
        local exit_code=$?
        if [[ $exit_code -eq 2 ]]; then
            agent_status="agent_not_running"
        elif [[ $exit_code -eq 1 ]]; then
            agent_status="agent_no_keys"
        fi
    else
        agent_status="agent_with_keys"
    fi
    
    # List the keys
    local found_keys=false
    for key_file in "$KEYS_DIR"/*; do
        if [[ -f "$key_file" ]] && [[ "$key_file" != *.pub ]]; then
            found_keys=true
            local key_name=$(basename "$key_file")
            local host_name=$(echo "$key_name" | sed 's/id_[^_]*_//')
            
            echo "  📁 Host: $host_name"
            echo "     🔐 Private: $key_file"
            echo "     🔓 Public:  $key_file.pub"
            
            # Check if key is in ssh-agent (only if agent is accessible)
            if [[ "$agent_status" == "agent_not_running" ]]; then
                print_color $RED "     ✗ SSH agent not running"
            elif [[ "$agent_status" == "agent_no_keys" ]]; then
                print_color $YELLOW "     ⚠ Not loaded in ssh-agent"
            else
                local fingerprint=$(ssh-keygen -lf "$key_file" 2>/dev/null | awk '{print $2}')
                if ssh-add -l 2>/dev/null | grep -q "$fingerprint"; then
                    print_color $GREEN "     ✓ Loaded in ssh-agent"
                else
                    print_color $YELLOW "     ⚠ Not loaded in ssh-agent"
                fi
            fi
            echo
        fi
    done
    
    # If no valid key files were found (shouldn't happen if directory check passed)
    if [[ "$found_keys" == false ]]; then
        print_color $YELLOW "📁 No valid SSH key files found"
        print_color $BLUE "💡 Generate your first key by selecting option 1 or 2"
    fi
    
    # Show agent status summary
    case "$agent_status" in
        "agent_not_running")
            print_color $YELLOW "🔧 SSH Agent Status: Not running"
            print_color $BLUE "   To start: eval \$(ssh-agent -s)"
            ;;
        "agent_no_keys")
            print_color $YELLOW "🔧 SSH Agent Status: Running but no keys loaded"
            print_color $BLUE "   Keys will be added automatically when generated"
            ;;
        "agent_with_keys")
            print_color $GREEN "🔧 SSH Agent Status: Running with keys loaded"
            ;;
    esac
}

# Function to check SSH agent status
check_ssh_agent_status() {
    print_color $BLUE "🔍 SSH Agent Status:"
    
    # Check if ssh-agent is running
    if ! ssh-add -l >/dev/null 2>&1; then
        local exit_code=$?
        if [[ $exit_code -eq 2 ]]; then
            # Exit code 2 means ssh-agent is not running
            print_color $RED "✗ SSH agent is not running"
            print_color $BLUE "To start ssh-agent: eval \$(ssh-agent -s)"
        elif [[ $exit_code -eq 1 ]]; then
            # Exit code 1 means ssh-agent is running but has no keys
            print_color $YELLOW "⚠ SSH agent is running but has no keys loaded"
            print_color $BLUE "Keys will be added automatically when generated"
        fi
    else
        # Exit code 0 means ssh-agent is running with keys
        print_color $GREEN "✓ SSH agent is running with loaded keys"
        echo "Loaded keys:"
        ssh-add -l | sed 's/^/  /'
    fi
}

# Main menu with better user guidance
main_menu() {
    local choice
    
    print_color $BLUE "🔐 SSH Key Generator"
    echo
    
    # Show quick status
    local has_hosts=false
    local has_keys=false
    
    if [[ -f "$CONFIG_FILE" ]] && [[ -n "$(get_ssh_hosts)" ]]; then
        has_hosts=true
    fi
    
    if [[ -d "$KEYS_DIR" ]] && [[ -n "$(ls -A "$KEYS_DIR" 2>/dev/null)" ]]; then
        has_keys=true
    fi
    
    # Provide contextual guidance
    if [[ "$has_hosts" == false ]] && [[ "$has_keys" == false ]]; then
        print_color $YELLOW "👋 Welcome! No SSH hosts or keys found."
        print_color $BLUE "💡 Start by creating a new host configuration (option 2)"
        echo
    elif [[ "$has_hosts" == true ]] && [[ "$has_keys" == false ]]; then
        print_color $BLUE "📋 Found existing SSH hosts but no managed keys."
        print_color $BLUE "💡 Add keys to existing hosts (option 1) or create new ones (option 2)"
        echo
    fi

        echo "What would you like to do?"
    echo "  1. Add key to existing host"
    echo "  2. Create new host configuration"
    echo "  3. List managed keys"
    echo "  4. Show SSH agent status"
    echo "  5. Exit"
    echo
    
    read "choice?Choose an option (1-5): "
    
    case $choice in
        1)
            if show_existing_hosts; then
                echo
                local selected_host=$(select_existing_host)
                if [[ -n "$selected_host" ]]; then
                    add_key_to_existing_host "$selected_host"
                    echo
                    print_color $GREEN "✨ Key generation complete!"
                    read "?Press Enter to return to main menu..."
                    main_menu
                fi
            else
                local create_new
                print_color $YELLOW "No existing hosts found in SSH config."
                print_color $BLUE "💡 Would you like to create a new host configuration instead?"
                read "create_new?(y/n): "
                if [[ "$create_new" =~ ^[Yy] ]]; then
                    create_new_host
                    echo
                    print_color $GREEN "✨ Host creation complete!"
                    read "?Press Enter to return to main menu..."
                fi
                main_menu
            fi
            ;;
        2)
            create_new_host
            echo
            print_color $GREEN "✨ Host creation complete!"
            read "?Press Enter to return to main menu..."
            main_menu
            ;;
        3)
            list_keys
            echo
            read "?Press Enter to return to main menu..."
            main_menu
            ;;
        4)
            check_ssh_agent_status
            echo
            read "?Press Enter to return to main menu..."
            main_menu
            ;;
        5)
            print_color $GREEN "👋 Goodbye!"
            exit 0
            ;;
        *)
            print_color $RED "Invalid option. Please try again."
            echo
            main_menu
            ;;
    esac
}

# Start the script
main_menu
    