#!/bin/zsh
# SSH Key Generator Script
# Manages SSH keys for different hosts with organized storage and ssh-agent integration
#
# Usage:
#   kgen                        # Interactive menu
#   kgen --create <service> <suffix>  # Non-interactive key creation
#   kgen --list                 # List all keys
#   kgen --copy <host-alias>    # Copy key to clipboard
#
# Supported services: github, bitbucket, gitlab

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
    local comment=$2
    local key_type=${3:-ed25519}
    
    local key_name="id_${key_type}_${host}"
    local key_path="$KEYS_DIR/$key_name"
    
    print_color $BLUE "🔑 Generating $key_type SSH key for host: $host"
    
    # Generate the key
    ssh-keygen -t "$key_type" -C "$comment" -f "$key_path" -N ""
    
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

# Function to create Bitbucket host configuration
create_bitbucket_host() {
    local suffix key_type_choice
    
    print_color $BLUE "📦 Bitbucket Account Setup"
    echo
    print_color $BLUE "Host (SSH config alias - used in git clone URLs)"
    echo "  For multiple accounts, add a name: work, personal, etc."
    echo "  Note: You'll need to modify clone URLs"
    echo "  Example: git@bitbucket.org:user/repo.git → git@bitbucket.org-work:user/repo.git"
    echo
    read "suffix?Enter name (e.g., work, personal): "
    
    if [[ -z "$suffix" ]]; then
        print_color $RED "Name cannot be empty"
        return 1
    fi
    
    local host_alias="bitbucket.org-$suffix"
    local hostname="bitbucket.org"
    local username="git"
    
    # Ask for key type
    echo
    echo "Select key type:"
    echo "  1. ed25519 (recommended)"
    echo "  2. rsa"
    read "key_type_choice?Choice (1-2, default: 1): "
    
    local key_type="ed25519"
    case $key_type_choice in
        2) key_type="rsa" ;;
        *) key_type="ed25519" ;;
    esac
    
    # Generate key using host alias as comment
    generate_ssh_key "$host_alias" "$host_alias" "$key_type"
    
    # Convert absolute path to ~/ format for config file
    local config_key_path=$(echo "$GENERATED_KEY_PATH" | sed "s|$HOME|~|")
    
    # Add to SSH config
    add_host_to_config "$host_alias" "$hostname" "$username" "$config_key_path"
    
    print_color $GREEN "🎉 Bitbucket host '$host_alias' created successfully!"
}

# Function to create GitHub host configuration
create_github_host() {
    local suffix key_type_choice
    
    print_color $BLUE "🐙 GitHub Account Setup"
    echo
    print_color $BLUE "Host (SSH config alias - used in git clone URLs)"
    echo "  For multiple accounts, add a name: work, personal, etc."
    echo "  Note: You'll need to modify clone URLs"
    echo "  Example: git@github.com:user/repo.git → git@github.com-work:user/repo.git"
    echo
    read "suffix?Enter name (e.g., work, personal): "
    
    if [[ -z "$suffix" ]]; then
        print_color $RED "Name cannot be empty"
        return 1
    fi
    
    local host_alias="github.com-$suffix"
    local hostname="github.com"
    local username="git"
    
    # Ask for key type
    echo
    echo "Select key type:"
    echo "  1. ed25519 (recommended)"
    echo "  2. rsa"
    read "key_type_choice?Choice (1-2, default: 1): "
    
    local key_type="ed25519"
    case $key_type_choice in
        2) key_type="rsa" ;;
        *) key_type="ed25519" ;;
    esac
    
    # Generate key using host alias as comment
    generate_ssh_key "$host_alias" "$host_alias" "$key_type"
    
    # Convert absolute path to ~/ format for config file
    local config_key_path=$(echo "$GENERATED_KEY_PATH" | sed "s|$HOME|~|")
    
    # Add to SSH config
    add_host_to_config "$host_alias" "$hostname" "$username" "$config_key_path"
    
    print_color $GREEN "🎉 GitHub host '$host_alias' created successfully!"
}

# Function to create GitLab host configuration
create_gitlab_host() {
    local suffix key_type_choice
    
    print_color $BLUE "🦊 GitLab Account Setup"
    echo
    print_color $BLUE "Host (SSH config alias - used in git clone URLs)"
    echo "  For multiple accounts, add a name: work, personal, etc."
    echo "  Note: You'll need to modify clone URLs"
    echo "  Example: git@gitlab.com:user/repo.git → git@gitlab.com-work:user/repo.git"
    echo
    read "suffix?Enter name (e.g., work, personal): "
    
    if [[ -z "$suffix" ]]; then
        print_color $RED "Name cannot be empty"
        return 1
    fi
    
    local host_alias="gitlab.com-$suffix"
    local hostname="gitlab.com"
    local username="git"
    
    # Ask for key type
    echo
    echo "Select key type:"
    echo "  1. ed25519 (recommended)"
    echo "  2. rsa"
    read "key_type_choice?Choice (1-2, default: 1): "
    
    local key_type="ed25519"
    case $key_type_choice in
        2) key_type="rsa" ;;
        *) key_type="ed25519" ;;
    esac
    
    # Generate key using host alias as comment
    generate_ssh_key "$host_alias" "$host_alias" "$key_type"
    
    # Convert absolute path to ~/ format for config file
    local config_key_path=$(echo "$GENERATED_KEY_PATH" | sed "s|$HOME|~|")
    
    # Add to SSH config
    add_host_to_config "$host_alias" "$hostname" "$username" "$config_key_path"
    
    print_color $GREEN "🎉 GitLab host '$host_alias' created successfully!"
}

# Function to create custom host configuration
create_custom_host() {
    local host_alias hostname username key_type_choice
    
    print_color $BLUE "⚙️  Custom Host Configuration"
    echo
    print_color $BLUE "Host (SSH config field 'Host' - your connection alias)"
    echo "  This is the shortcut name you'll use to connect"
    echo "  Example: myserver, prod-db, github.com-custom"
    echo
    read "host_alias?Enter Host: "
    
    if [[ -z "$host_alias" ]]; then
        print_color $RED "Host cannot be empty"
        return 1
    fi
    
    echo
    print_color $BLUE "HostName (SSH config field 'HostName' - actual server address)"
    echo "  The real domain or IP where SSH connects"
    echo "  Example: github.com, 192.168.1.100, myserver.example.com"
    echo
    read "hostname?Enter HostName: "
    
    if [[ -z "$hostname" ]]; then
        print_color $RED "HostName cannot be empty"
        return 1
    fi
    
    echo
    print_color $BLUE "User (SSH config field 'User' - login username)"
    echo "  Username for SSH authentication"
    echo "  For git services: 'git' (default)"
    echo "  For servers: your username"
    echo
    read "username?Enter User [git]: "
    
    # Use 'git' as default if no username provided
    if [[ -z "$username" ]]; then
        username="git"
    fi
    
    # Ask for key type
    echo
    echo "Select key type:"
    echo "  1. ed25519 (recommended)"
    echo "  2. rsa"
    read "key_type_choice?Choice (1-2, default: 1): "
    
    local key_type="ed25519"
    case $key_type_choice in
        2) key_type="rsa" ;;
        *) key_type="ed25519" ;;
    esac
    
    # Generate key using host alias as comment
    generate_ssh_key "$host_alias" "$host_alias" "$key_type"
    
    # Convert absolute path to ~/ format for config file
    local config_key_path=$(echo "$GENERATED_KEY_PATH" | sed "s|$HOME|~|")
    
    # Add to SSH config
    add_host_to_config "$host_alias" "$hostname" "$username" "$config_key_path"
    
    print_color $GREEN "🎉 Custom host '$host_alias' created successfully!"
}

# Function to create new host configuration with service selector
create_new_host() {
    local service_choice
    
    print_color $BLUE "🆕 Create New Host Configuration"
    echo
    echo "Select service type:"
    echo "  1. GitHub"
    echo "  2. Bitbucket"
    echo "  3. GitLab"
    echo "  4. Custom host"
    echo
    read "service_choice?Choice (1-4): "
    
    echo
    case $service_choice in
        1)
            create_github_host
            ;;
        2)
            create_bitbucket_host
            ;;
        3)
            create_gitlab_host
            ;;
        4)
            create_custom_host
            ;;
        *)
            print_color $RED "Invalid option"
            return 1
            ;;
    esac
}

# Function to add key to existing host
add_key_to_existing_host() {
    local host=$1
    local key_type_choice
    
    print_color $BLUE "🔑 Adding new key to existing host: $host"
    
    # Get host details
    local host_details=$(get_host_details "$host")
    if [[ -z "$host_details" ]]; then
        print_color $RED "Could not find details for host: $host"
        return 1
    fi
    
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
    
    # Generate key using host alias as comment
    generate_ssh_key "$host" "$host" "$key_type"
    
    # Convert absolute path to ~/ format for config file
    local config_key_path=$(echo "$GENERATED_KEY_PATH" | sed "s|$HOME|~|")
    
    # Update SSH config with new key path
    print_color $BLUE "📝 Updating SSH config with new key..."
    
    # Create backup
    cp "$CONFIG_FILE" "$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Update IdentityFile line for this host using the ~/ path
    sed -i.tmp "/^Host $host$/,/^Host / s|IdentityFile.*|IdentityFile $config_key_path|" "$CONFIG_FILE"
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

# Function to delete all keys
delete_all_keys() {
    print_color $BLUE "🗑️  Delete All SSH Keys"
    echo
    
    # Check if there are any keys to delete
    local has_keys=false
    if [[ -d "$KEYS_DIR" ]] && [[ -n "$(ls -A "$KEYS_DIR" 2>/dev/null)" ]]; then
        has_keys=true
    fi
    
    if [[ "$has_keys" == false ]]; then
        print_color $YELLOW "📁 No SSH keys found to delete"
        return 0
    fi
    
    # Show what will be deleted
    print_color $YELLOW "⚠️  WARNING: This will delete the following keys:"
    echo
    for key_file in "$KEYS_DIR"/*; do
        if [[ -f "$key_file" ]] && [[ "$key_file" != *.pub ]]; then
            local key_name=$(basename "$key_file")
            echo "  🔐 $key_name"
            if [[ -f "$key_file.pub" ]]; then
                echo "  🔓 $key_name.pub"
            fi
        fi
    done
    echo
    
    # Confirmation prompt
    local confirm
    print_color $RED "⚠️  This action cannot be undone!"
    read "confirm?Are you sure you want to delete ALL keys? (yes/no): "
    
    if [[ "$confirm" != "yes" ]]; then
        print_color $BLUE "Operation cancelled"
        return 0
    fi
    
    # Step 1: Remove all keys from SSH agent
    print_color $BLUE "🔧 Removing all keys from SSH agent..."
    if ssh-add -D >/dev/null 2>&1; then
        print_color $GREEN "✓ All keys removed from SSH agent"
    else
        local exit_code=$?
        if [[ $exit_code -eq 2 ]]; then
            print_color $YELLOW "⚠ SSH agent not running (no keys to remove from agent)"
        else
            print_color $YELLOW "⚠ Could not remove keys from SSH agent"
        fi
    fi
    
    # Step 2: Delete all key files
    print_color $BLUE "🗑️  Deleting all key files..."
    local deleted_count=0
    for key_file in "$KEYS_DIR"/*; do
        if [[ -f "$key_file" ]]; then
            rm -f "$key_file"
            ((deleted_count++))
        fi
    done
    
    if [[ $deleted_count -gt 0 ]]; then
        print_color $GREEN "✓ Deleted $deleted_count file(s) from $KEYS_DIR"
    else
        print_color $YELLOW "No files were deleted"
    fi
    
    print_color $GREEN "🎉 All keys have been removed!"
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

# Function to copy existing key to clipboard (interactive)
copy_key_to_clipboard() {
    local keys=()
    local key_names=()
    
    # Build array of available keys
    if [[ -d "$KEYS_DIR" ]]; then
        for key_file in "$KEYS_DIR"/*; do
            if [[ -f "$key_file" ]] && [[ "$key_file" != *.pub ]]; then
                keys+=("$key_file")
                local key_name=$(basename "$key_file" | sed 's/id_[^_]*_//')
                key_names+=("$key_name")
            fi
        done
    fi
    
    if [[ ${#keys[@]} -eq 0 ]]; then
        print_color $YELLOW "No SSH keys found in $KEYS_DIR"
        print_color $BLUE "Generate keys first using option 2"
        return 1
    fi
    
    print_color $BLUE "Select a key to copy to clipboard:"
    echo
    for i in "${!key_names[@]}"; do
        echo "  $((i+1)). ${key_names[i]}"
    done
    echo
    
    local selection
    read "selection?Choose key (1-${#keys[@]}): "
    
    if [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -le ${#keys[@]} ]]; then
        local selected_key="${keys[$((selection-1))]}"
        local selected_name="${key_names[$((selection-1))]}"
        local pub_key_content=$(cat "$selected_key.pub")
        copy_to_clipboard "$pub_key_content"
        echo
        print_color $GREEN "Copied $selected_name public key to clipboard"
    else
        print_color $RED "Invalid selection"
        return 1
    fi
}

# Function to create key non-interactively
create_key_noninteractive() {
    local service=$1
    local suffix=$2
    
    if [[ -z "$service" ]] || [[ -z "$suffix" ]]; then
        echo "Usage: kgen --create <service> <suffix>"
        echo "  Services: github, bitbucket, gitlab"
        echo "  Example: kgen --create github gsi"
        exit 1
    fi
    
    local hostname
    local host_alias
    
    case $service in
        github)
            hostname="github.com"
            host_alias="github.com-$suffix"
            ;;
        bitbucket)
            hostname="bitbucket.org"
            host_alias="bitbucket.org-$suffix"
            ;;
        gitlab)
            hostname="gitlab.com"
            host_alias="gitlab.com-$suffix"
            ;;
        *)
            echo "Unknown service: $service"
            echo "Supported services: github, bitbucket, gitlab"
            exit 1
            ;;
    esac
    
    # Check if key already exists
    local key_path="$KEYS_DIR/id_ed25519_$host_alias"
    if [[ -f "$key_path" ]]; then
        print_color $YELLOW "Key already exists: $host_alias"
        return 0
    fi
    
    print_color $BLUE "Creating SSH key for $host_alias..."
    
    # Generate key (using ed25519 by default)
    generate_ssh_key "$host_alias" "$host_alias" "ed25519"
    
    # Convert absolute path to ~/ format for config file
    local config_key_path=$(echo "$GENERATED_KEY_PATH" | sed "s|$HOME|~|")
    
    # Add to SSH config
    add_host_to_config "$host_alias" "$hostname" "git" "$config_key_path"
    
    print_color $GREEN "Created SSH key: $host_alias"
}

# Function to copy key by name (non-interactive)
copy_key_by_name() {
    local host_alias=$1
    
    if [[ -z "$host_alias" ]]; then
        echo "Usage: kgen --copy <host-alias>"
        exit 1
    fi
    
    # Find the key file
    local key_file=$(ls "$KEYS_DIR"/id_*_"$host_alias" 2>/dev/null | head -1)
    
    if [[ -f "$key_file" ]] && [[ -f "$key_file.pub" ]]; then
        local pub_key_content=$(cat "$key_file.pub")
        copy_to_clipboard "$pub_key_content"
        print_color $GREEN "Copied $host_alias public key to clipboard"
    else
        print_color $RED "Key not found: $host_alias"
        echo "Available keys:"
        for kf in "$KEYS_DIR"/*; do
            if [[ -f "$kf" ]] && [[ "$kf" != *.pub ]]; then
                local key_name=$(basename "$kf" | sed 's/id_[^_]*_//')
                echo "  $key_name"
            fi
        done
        exit 1
    fi
}

# Function to list keys non-interactively
list_keys_noninteractive() {
    if [[ ! -d "$KEYS_DIR" ]] || [[ -z "$(ls -A "$KEYS_DIR" 2>/dev/null)" ]]; then
        echo "No SSH keys found"
        exit 0
    fi
    
    for key_file in "$KEYS_DIR"/*; do
        if [[ -f "$key_file" ]] && [[ "$key_file" != *.pub ]]; then
            local key_name=$(basename "$key_file" | sed 's/id_[^_]*_//')
            echo "$key_name"
        fi
    done
}

# Parse command line arguments
parse_args() {
    case "$1" in
        --create)
            create_key_noninteractive "$2" "$3"
            exit 0
            ;;
        --list)
            list_keys_noninteractive
            exit 0
            ;;
        --copy)
            copy_key_by_name "$2"
            exit 0
            ;;
        --help|-h)
            echo "SSH Key Generator (kgen)"
            echo ""
            echo "Usage:"
            echo "  kgen                        # Interactive menu"
            echo "  kgen --create <service> <suffix>  # Create key for service"
            echo "  kgen --list                 # List all keys"
            echo "  kgen --copy <host-alias>    # Copy key to clipboard"
            echo ""
            echo "Services: github, bitbucket, gitlab"
            echo ""
            echo "Examples:"
            echo "  kgen --create github gsi    # Creates github.com-gsi key"
            echo "  kgen --copy github.com-gsi  # Copies public key to clipboard"
            exit 0
            ;;
        "")
            # No arguments, run interactive menu
            return 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
}

# Parse arguments first
parse_args "$@"

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
    echo "  5. Delete all keys"
    echo "  6. Copy key to clipboard"
    echo "  0. Exit"
    echo
    
    read "choice?Choose an option (0-6): "
    
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
            delete_all_keys
            echo
            read "?Press Enter to return to main menu..."
            main_menu
            ;;
        6)
            copy_key_to_clipboard
            echo
            read "?Press Enter to return to main menu..."
            main_menu
            ;;
        0)
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
