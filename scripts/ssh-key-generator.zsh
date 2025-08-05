#!/usr/bin/env zsh

# SSH Key Generator Script
# Manages SSH keys for different hosts with organized storage and ssh-agent integration

# Exit if any command fails
set -e

# Configuration
SSH_DIR="$HOME/.ssh"
KEYS_DIR="$SSH_DIR/keys"
CONFIG_FILE="$SSH_DIR/config"
SCRIPT_DIR="$SSH_DIR/scripts"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Ensure required directories exist
mkdir -p "$KEYS_DIR" "$SCRIPT_DIR"

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

# Function to generate SSH key
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
    
    echo "$key_path"
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

# Function to create new host
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
    
    # Generate key
    local key_path=$(generate_ssh_key "$host_alias" "$email" "$key_type")
    
    # Add to SSH config
    add_host_to_config "$host_alias" "$hostname" "$username" "$key_path"
    
    print_color $GREEN "🎉 New host '$host_alias' created successfully!"
}

# Function to add key to existing host
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
    
    # Generate key
    local key_path=$(generate_ssh_key "$host" "$email" "$key_type")
    
    # Update SSH config with new key path
    print_color $BLUE "📝 Updating SSH config with new key..."
    
    # Create backup
    cp "$CONFIG_FILE" "$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Update IdentityFile line for this host
    sed -i.tmp "/^Host $host$/,/^Host / s|IdentityFile.*|IdentityFile $key_path|" "$CONFIG_FILE"
    rm -f "$CONFIG_FILE.tmp"
    
    print_color $GREEN "🎉 Key added to host '$host' successfully!"
}

# Function to list managed keys
list_keys() {
    print_color $BLUE "🗂️  Managed SSH Keys:"
    
    if [[ ! -d "$KEYS_DIR" ]] || [[ -z "$(ls -A "$KEYS_DIR" 2>/dev/null)" ]]; then
        print_color $YELLOW "No managed keys found"
        return
    fi
    
    for key_file in "$KEYS_DIR"/*; do
        if [[ -f "$key_file" ]] && [[ "$key_file" != *.pub ]]; then
            local key_name=$(basename "$key_file")
            local host_name=$(echo "$key_name" | sed 's/id_[^_]*_//')
            
            echo "  📁 Host: $host_name"
            echo "     🔐 Private: $key_file"
            echo "     🔓 Public:  $key_file.pub"
            
            # Check if key is in ssh-agent
            local fingerprint=$(ssh-keygen -lf "$key_file" 2>/dev/null | awk '{print $2}')
            if ssh-add -l 2>/dev/null | grep -q "$fingerprint"; then
                print_color $GREEN "     ✓ Loaded in ssh-agent"
            else
                print_color $YELLOW "     ⚠ Not loaded in ssh-agent"
            fi
            echo
        fi
    done
}

# Main menu
main_menu() {
    local choice
    
    print_color $BLUE "🔐 SSH Key Generator"
    echo
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
                fi
            else
                local create_new
                print_color $YELLOW "No existing hosts found. Would you like to create a new one? (y/n)"
                read "create_new?> "
                if [[ "$create_new" =~ ^[Yy] ]]; then
                    create_new_host
                fi
            fi
            ;;
        2)
            create_new_host
            ;;
        3)
            list_keys
            ;;
        4)
            print_color $BLUE "🔍 SSH Agent Status:"
            if ssh-add -l 2>/dev/null; then
                print_color $GREEN "✓ SSH agent is running with loaded keys"
            else
                print_color $YELLOW "⚠ SSH agent is not running or has no keys loaded"
                print_color $BLUE "To start ssh-agent: eval \$(ssh-agent -s)"
            fi
            ;;
        5)
            print_color $GREEN "👋 Goodbye!"
            exit 0
            ;;
        *)
            print_color $RED "Invalid option. Please try again."
            main_menu
            ;;
    esac
}

# Check if ssh-agent is running
if ! ssh-add -l >/dev/null 2>&1; then
    print_color $YELLOW "⚠ SSH agent is not running. Starting ssh-agent..."
    eval "$(ssh-agent -s)"
fi

# Run main menu
main_menu