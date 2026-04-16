#!/bin/zsh
# Deploy Zsh Configuration
# Handles: zsh installation, default shell, Oh-My-Zsh, plugins, and config deployment

set -e

# Source common utilities
SCRIPT_DIR="${0:A:h}"
source "${SCRIPT_DIR}/lib/common.zsh"

# Get project root and storage paths
PROJECT_ROOT="${SCRIPT_DIR:h:h}"
STORAGE_DIR="${PROJECT_ROOT}/src/storage"

# Source paths
ZSHRC_SOURCE="${STORAGE_DIR}/zsh/.zshrc"
ALIASES_SOURCE="${STORAGE_DIR}/zsh/aliases.zsh"
JIRA_WRAPPER_SOURCE="${STORAGE_DIR}/zsh/jira-wrapper.zsh"
SCRIPTS_SOURCE="${STORAGE_DIR}/scripts"
PLUGINS_FILE="${PROJECT_ROOT}/plugins.txt"

# Destination paths
ZSHRC_DEST="$HOME/.zshrc"
ALIASES_DEST="$OMZ_DIR/custom/aliases.zsh"
JIRA_WRAPPER_DEST="$OMZ_DIR/custom/jira-wrapper.zsh"
SCRIPTS_DEST="$OMZ_DIR/custom/scripts"
PLUGINS_DIR="$OMZ_DIR/custom/plugins"


# Function to check and install zsh if its not present
check_install_zsh() {
    print_status "info" "Checking for zsh..."
    
    if command_exists zsh; then
        local zsh_version=$(zsh --version | cut -d' ' -f2)
        print_status "success" "Zsh found (version $zsh_version)"
        return 0
    fi
    
    print_status "warning" "Zsh not found"
    install_package "zsh"
    
    # Verify installation
    if command_exists zsh; then
        local zsh_version=$(zsh --version | cut -d' ' -f2)
        print_status "success" "Zsh installed successfully (version $zsh_version)"
    else
        print_status "error" "Zsh installation failed"
        exit 1
    fi
}

# Function to set zsh as the default shell
set_default_shell() {
    print_status "info" "Checking default shell..."
    
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
    
    local current_shell=$(basename "$SHELL")
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
        echo "You may need to run: chsh -s $zsh_path"
        echo "Or check with your system administrator"
    fi
}

# Function to check and install Oh-My-Zsh if not present
check_install_oh_my_zsh() {
    print_status "info" "Checking for Oh-My-Zsh..."
    
    if [[ -d "$OMZ_DIR" ]]; then
        print_status "success" "Oh-My-Zsh found at $OMZ_DIR"
        return 0
    fi
    
    print_status "warning" "Oh-My-Zsh not found"
    print_status "download" "Installing Oh-My-Zsh..."
    
    # Download and install Oh-My-Zsh
    if sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; then
        print_status "success" "Oh-My-Zsh installed successfully"
    else
        print_status "error" "Oh-My-Zsh installation failed"
        exit 1
    fi
    
    # Verify installation
    if [[ -d "$OMZ_DIR" ]]; then
        print_status "success" "Oh-My-Zsh verified at $OMZ_DIR"
    else
        print_status "error" "Oh-My-Zsh installation verification failed"
        exit 1
    fi
}


# Function to set up necessary directories for personal Oh-My-Zsh customizations
setup_omz_directories() {
    print_status "info" "Setting up Oh-My-Zsh directories..."
    
    # Create custom directory if it doesn't exist
    if [[ ! -d "$OMZ_DIR/custom" ]]; then
        print_status "action" "Creating custom directory..."
        mkdir -p "$OMZ_DIR/custom"
        print_status "success" "Custom directory created"
    fi
    
    # Create plugins directory
    if [[ ! -d "$PLUGINS_DIR" ]]; then
        print_status "action" "Creating plugins directory..."
        mkdir -p "$PLUGINS_DIR"
        print_status "success" "Plugins directory created"
    fi
    
    # Create scripts directory
    if [[ ! -d "$SCRIPTS_DEST" ]]; then
        print_status "action" "Creating scripts directory..."
        mkdir -p "$SCRIPTS_DEST"
        print_status "success" "Scripts directory created"
    fi
    
    print_status "success" "Oh-My-Zsh directories ready"
}

# Install or update a single custom plugin
manage_plugin() {
    local plugin_spec=$1
    local plugin_name=$(basename "$plugin_spec")
    local plugin_path="$PLUGINS_DIR/$plugin_name"
    local plugin_url="https://github.com/$plugin_spec.git"
    
    if [[ -d "$plugin_path" ]]; then
        # Plugin exists, update it
        info "Updating $plugin_name..."
        
        local update_success=false
        if (cd "$plugin_path" && git pull origin main 2>&1); then
            update_success=true
        elif (cd "$plugin_path" && git pull origin master 2>&1); then
            update_success=true
        fi
        
        if [[ $update_success == true ]]; then
            log "Updated $plugin_name successfully"
        else
            warn "Could not update $plugin_name (might already be up to date)"
        fi
    else
        # Plugin doesn't exist, clone it
        info "Installing $plugin_name..."
        
        if git clone "$plugin_url" "$plugin_path"; then
            # Fix broken symlinks on Windows
            if [[ "$(detect_os)" == "windows" ]]; then
                local expected_plugin_file="$plugin_path/$plugin_name.plugin.zsh"
                if [[ ! -f "$expected_plugin_file" ]]; then
                    for candidate in "$plugin_path"/*.plugin.zsh; do
                        if [[ -f "$candidate" && $(wc -c < "$candidate") -lt 200 ]]; then
                            local target=$(cat "$candidate" | tr -d '[:space:]')
                            if [[ -f "$plugin_path/$target" ]]; then
                                cp "$plugin_path/$target" "$expected_plugin_file"
                                warn "Fixed broken symlink for $plugin_name"
                                break
                            fi
                        fi
                    done
                fi
            fi
            log "Successfully installed $plugin_name"
        else
            print_status "error" "Failed to install $plugin_name"
            return 1
        fi
    fi
}

# install all plugins from plugins.txt
install_plugins() {
    print_status "info" "Installing/updating custom plugins..."
    
    if [[ ! -f "$PLUGINS_FILE" ]]; then
        warn "plugins.txt not found at $PLUGINS_FILE - skipping plugin installation"
        return 0
    fi
    
    local success_count=0
    local fail_count=0
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Remove leading/trailing whitespace
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [[ -z "$line" ]] && continue
        
        if manage_plugin "$line"; then
            success_count=$((success_count + 1))
        else
            fail_count=$((fail_count + 1))
        fi
    done < "$PLUGINS_FILE"
    
    if [[ $fail_count -gt 0 ]]; then
        warn "Some plugins failed to install ($fail_count failures)"
    else
        log "All plugins installed/updated successfully ($success_count total)"
    fi
}

deploy_configs() {
    print_status "info" "Deploying zsh configurations..."
    
    # Check if source files exist
    [ -f "$ZSHRC_SOURCE" ] || error "Source .zshrc not found at $ZSHRC_SOURCE"
    [ -f "$ALIASES_SOURCE" ] || error "Source aliases.zsh not found at $ALIASES_SOURCE"
    [ -f "$JIRA_WRAPPER_SOURCE" ] || error "Source jira-wrapper.zsh not found at $JIRA_WRAPPER_SOURCE"

    # Deploy .zshrc
    log "Deploying .zshrc from $ZSHRC_SOURCE to $ZSHRC_DEST"
    cp "$ZSHRC_SOURCE" "$ZSHRC_DEST" || error "Failed to deploy .zshrc"

    # Deploy aliases.zsh
    log "Deploying aliases.zsh from $ALIASES_SOURCE to $ALIASES_DEST"
    cp "$ALIASES_SOURCE" "$ALIASES_DEST" || error "Failed to deploy aliases.zsh"

    # Deploy jira-wrapper.zsh (omz auto-sources $OMZ_DIR/custom/*.zsh)
    log "Deploying jira-wrapper.zsh from $JIRA_WRAPPER_SOURCE to $JIRA_WRAPPER_DEST"
    cp "$JIRA_WRAPPER_SOURCE" "$JIRA_WRAPPER_DEST" || error "Failed to deploy jira-wrapper.zsh"

    # Deploy utility scripts directory
    if [ -d "$SCRIPTS_SOURCE" ]; then
        log "Deploying scripts directory from $SCRIPTS_SOURCE to $SCRIPTS_DEST"
        cp -r "$SCRIPTS_SOURCE"/* "$SCRIPTS_DEST"/ || error "Failed to deploy scripts"
        find "$SCRIPTS_DEST" -type f -name "*.zsh" -exec chmod +x {} \;
        find "$SCRIPTS_DEST" -type f -name "*.sh" -exec chmod +x {} \;
        log "Scripts deployed successfully!"
    else
        warn "Scripts directory not found at $SCRIPTS_SOURCE - skipping"
    fi
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    echo
    print_status "info" "Zsh Deployment"
    echo
    
    # Step 1: Ensure zsh is installed
    check_install_zsh
    echo
    
    # Step 2: Set zsh as default shell
    set_default_shell
    echo
    
    # Step 3: Install Oh-My-Zsh
    check_install_oh_my_zsh
    echo
    
    # Step 4: Set up custom directories
    setup_omz_directories
    echo
    
    # Step 5: Install/update plugins
    install_plugins
    echo
    
    # Step 6: Deploy configurations
    deploy_configs
    echo
    
    print_status "success" "Zsh deployment complete!"
    echo
    
    # Show what was deployed
    info "Deployed files:"
    echo "  - .zshrc -> $ZSHRC_DEST"
    echo "  - aliases.zsh -> $ALIASES_DEST"
    echo "  - jira-wrapper.zsh -> $JIRA_WRAPPER_DEST"
    if [ -d "$SCRIPTS_SOURCE" ]; then
        info "Deployed scripts:"
        for script in "$SCRIPTS_SOURCE"/*; do
            if [ -f "$script" ]; then
                echo "    - $(basename "$script")"
            fi
        done
    fi
    echo
}

# Run main function if script is executed directly
if [[ "${(%):-%x}" == "${0}" ]]; then
    main "$@"
fi