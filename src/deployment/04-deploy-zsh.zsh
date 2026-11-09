#!/bin/zsh
# Deploy Zsh Configuration
# Handles: zsh installation, default shell, Oh-My-Zsh, plugins, and config deployment
# --config-only deploys only aliases.zsh and scripts/, for a machine whose zsh,
# Oh-My-Zsh and ~/.zshrc are set up by someone else.

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
BIN_SOURCE="${STORAGE_DIR}/bin"
SCRIPTS_SOURCE="${STORAGE_DIR}/scripts"
PLUGINS_FILE="${PROJECT_ROOT}/plugins.txt"

# Destination paths. Oh-My-Zsh loads custom/*.zsh; a config-only machine
# without it gets a plain directory, which ~/.zshrc sources instead.
CONFIG_ONLY=false
[[ "$1" == "--config-only" ]] && CONFIG_ONLY=true
CUSTOM_DIR="$OMZ_DIR/custom"
if $CONFIG_ONLY && [[ ! -d "$OMZ_DIR" ]]; then
    CUSTOM_DIR="$HOME/.config/ohmyzshconfig"
fi
ZSHRC_DEST="$HOME/.zshrc"
ALIASES_DEST="$CUSTOM_DIR/aliases.zsh"
BIN_DEST="$HOME/.local/bin"
SCRIPTS_DEST="$CUSTOM_DIR/scripts"
PLUGINS_DIR="$OMZ_DIR/custom/plugins"

# ~/.zshrc as the last deploy left it. Anything added to ~/.zshrc since (an
# installer appending its PATH line) moves to ~/.zshrc.local before the deploy
# replaces ~/.zshrc, so it keeps working.
ZSHRC_SNAPSHOT="$HOME/.config/ohmyzshconfig/zshrc.deployed"
ZSHRC_LOCAL="$HOME/.zshrc.local"


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

# Print the user's configured login shell. $SHELL only reflects the current
# session, so it stays stale after chsh until the next login.
get_login_shell() {
    case "$(detect_os)" in
        macos) dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}' ;;
        linux) getent passwd "$USER" | cut -d: -f7 ;;
        *)     echo "$SHELL" ;;
    esac
}

# Move what was added to ~/.zshrc since the last deploy into ~/.zshrc.local.
# Runs before Oh-My-Zsh's installer, which also moves ~/.zshrc aside. Added
# lines are split into blocks at blank lines, as installers write them; a block
# is kept whole unless every line of it is already in ~/.zshrc.local (an
# installer re-adding its line after every deploy).
keep_zshrc_additions() {
    [[ -f "$ZSHRC_DEST" ]] || return 0
    local baseline
    if [[ -f "$ZSHRC_SNAPSHOT" ]]; then
        baseline="$ZSHRC_SNAPSHOT"
    elif grep -q 'oh-my-zsh.sh' "$ZSHRC_DEST"; then
        # Deployed before snapshots existed: nothing to tell apart from ours
        return 0
    else
        # Not ours (stock, or written by a company's installers): keep all of it
        baseline=/dev/null
    fi

    # deploy-zsh-config's sourcing line is dropped: aliases.zsh loads from
    # Oh-My-Zsh's custom/ once this deploy is done.
    local added
    added=$(diff "$baseline" "$ZSHRC_DEST" | awk -v localrc="$ZSHRC_LOCAL" '
        function flush() { if (fresh) out = out block "\n"; block = ""; fresh = 0 }
        BEGIN { while ((getline line < localrc) > 0) have[line] = 1 }
        /^[0-9]/ { flush(); next }
        /^> / {
            l = substr($0, 3)
            if (l ~ /\(deploy-zsh-config\)|\/ohmyzshconfig\/aliases\.zsh/) next
            if (l ~ /^[[:space:]]*$/) { flush(); next }
            block = block l "\n"
            if (!(l in have)) fresh = 1
        }
        END { flush(); printf "%s", out }') || true
    [[ -n "$added" ]] || return 0

    printf '\n# Added to ~/.zshrc after a deploy, moved here by deploy-zsh on %s\n%s\n' \
        "$(date +%Y-%m-%d)" "$added" >> "$ZSHRC_LOCAL" || error "Failed to update $ZSHRC_LOCAL"
    print_status "success" "Kept what was added to ~/.zshrc in $ZSHRC_LOCAL"
}

# Function to set zsh as the default shell
set_default_shell() {
    print_status "info" "Checking default shell..."

    # Git Bash has no chsh; the Windows bootstrap makes .bashrc exec zsh instead
    if [[ "$(detect_os)" == "windows" ]]; then
        if grep -q "exec zsh" "$HOME/.bashrc" 2>/dev/null; then
            print_status "success" "Found 'exec zsh' in .bashrc - shell setup complete"
        else
            print_status "warning" "Git Bash will not launch zsh - run src/deployment/bootstrap/windows/01-bootstrap.sh"
        fi
        return 0
    fi

    local zsh_path=$(command -v zsh)
    local login_shell=$(get_login_shell)

    # Compare by name: /bin/zsh and /usr/bin/zsh are the same shell on merged-/usr distros
    if [[ "${login_shell:t}" == "zsh" ]]; then
        print_status "success" "Zsh is already the default shell ($login_shell)"
        return 0
    fi

    print_status "warning" "Current login shell is ${login_shell:-unknown}"
    print_status "action" "Setting zsh as default shell..."

    if ! grep -qx "$zsh_path" /etc/shells 2>/dev/null; then
        print_status "action" "Adding $zsh_path to /etc/shells..."
        echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
    fi

    # chsh prompts for the account password on stderr, so stderr must stay visible
    print_status "info" "chsh will ask for your login password"
    if chsh -s "$zsh_path"; then
        print_status "success" "Default shell changed to zsh"
        print_status "warning" "Log out and back in for this to take effect"
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
    
    # Download and install Oh-My-Zsh. ZSH pins it to $OMZ_DIR, where the
    # installer would otherwise pick $ZDOTDIR/ohmyzsh when ZDOTDIR is set;
    # KEEP_ZSHRC stops it replacing ~/.zshrc, which deploy_configs writes.
    # Its output is shown only on failure: the git fetch inside it prints
    # "branch -> origin/branch" lines, and deploy output must be inert.
    local omz_out
    if omz_out=$(ZSH="$OMZ_DIR" KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended 2>&1); then
        print_status "success" "Oh-My-Zsh installed successfully"
    else
        print -r -- "$omz_out" | tail -n 15
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

# Git for Windows checks a symlink out as a small file holding the target path
# unless symlinks are enabled, and Oh-My-Zsh would run that path as a command
# (zsh-you-should-use ships its .plugin.zsh as a symlink). Copy each target over
# its stand-in. Real symlinks (macOS, Linux, Windows Developer Mode) are left alone.
replace_symlink_standins() {
    local plugin_path=$1 link file target
    for link in ${(f)"$(git -C "$plugin_path" ls-files -s | awk '$1 == "120000" {print $4}')"}; do
        file="$plugin_path/$link"
        [[ -f "$file" && ! -L "$file" ]] || continue
        target="${file:h}/$(<"$file")"
        if [[ -f "$target" ]]; then
            cp "$target" "$file"
        fi
    done
}

# Install or update a single custom plugin. Plugins are third-party and never
# edited here, so an update resets onto the remote's default branch: a pull
# refuses over the stand-in copies above, or over any stray local change.
# autocrlf=false because Git for Windows defaults it to true, and a plugin
# checked out with CRLF line endings breaks under zsh.
manage_plugin() {
    local plugin_spec=$1
    local plugin_name=$(basename "$plugin_spec")
    local plugin_path="$PLUGINS_DIR/$plugin_name"
    local plugin_url="https://github.com/$plugin_spec.git"

    if [[ -d "$plugin_path" ]]; then
        info "Updating $plugin_name..."
        git -C "$plugin_path" config core.autocrlf false \
            && git -C "$plugin_path" fetch --quiet origin HEAD \
            && git -C "$plugin_path" reset --quiet --hard FETCH_HEAD \
            || { warn "Could not update $plugin_name"; return 1; }
    else
        info "Installing $plugin_name..."
        git clone --quiet --config core.autocrlf=false "$plugin_url" "$plugin_path" \
            || { print_status "error" "Failed to install $plugin_name"; return 1; }
    fi

    replace_symlink_standins "$plugin_path" || return 1
    log "$plugin_name is up to date"
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
    [ -d "$BIN_SOURCE" ] || error "Source bin directory not found at $BIN_SOURCE"

    # Deploy .zshrc
    log "Deploying .zshrc from $ZSHRC_SOURCE to $ZSHRC_DEST"
    cp "$ZSHRC_SOURCE" "$ZSHRC_DEST" || error "Failed to deploy .zshrc"
    mkdir -p "${ZSHRC_SNAPSHOT:h}" && cp "$ZSHRC_DEST" "$ZSHRC_SNAPSHOT" \
        || error "Failed to record $ZSHRC_SNAPSHOT"

    # Deploy bin/ shims. ~/.local/bin leads PATH, so these are reached from
    # every shell -- which a zsh function is not. `jira` (used by the ticket-provider skill) was a zsh function,
    # and anything that was not zsh silently got the raw binary and its
    # default config, pointing at a different company's Jira.
    log "Deploying bin shims from $BIN_SOURCE to $BIN_DEST"
    mkdir -p "$BIN_DEST" || error "Failed to create $BIN_DEST"
    for shim in "$BIN_SOURCE"/*; do
        [ -f "$shim" ] || continue
        install -m 755 "$shim" "$BIN_DEST/$(basename "$shim")" \
            || error "Failed to deploy $(basename "$shim")"
    done

    deploy_aliases_and_scripts
}

# aliases.zsh and scripts/, the part of the zsh config every machine takes
deploy_aliases_and_scripts() {
    [ -f "$ALIASES_SOURCE" ] || error "Source aliases.zsh not found at $ALIASES_SOURCE"
    mkdir -p "$SCRIPTS_DEST" || error "Failed to create $SCRIPTS_DEST"

    # Deploy aliases.zsh, pointing glc at this clone and kgen at the deployed scripts
    log "Deploying aliases.zsh from $ALIASES_SOURCE to $ALIASES_DEST"
    sed -e "s|__OHMYZSHCONFIG_DIR__|$PROJECT_ROOT|g" -e "s|__SCRIPTS_DIR__|$SCRIPTS_DEST|g" \
        "$ALIASES_SOURCE" > "$ALIASES_DEST" || error "Failed to deploy aliases.zsh"

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

# Without Oh-My-Zsh nothing loads aliases.zsh, so ~/.zshrc gets one line that
# sources it, appended once. The rest of ~/.zshrc is never touched.
source_from_zshrc() {
    if grep -qF "$ALIASES_DEST" "$ZSHRC_DEST" 2>/dev/null; then
        log "$ZSHRC_DEST already sources $ALIASES_DEST"
        return 0
    fi
    printf '\n# ohMyZshConfig aliases (deploy-zsh-config)\n[[ -f "%s" ]] && source "%s"\n' \
        "$ALIASES_DEST" "$ALIASES_DEST" >> "$ZSHRC_DEST" || error "Failed to add a line to $ZSHRC_DEST"
    log "Added a line to $ZSHRC_DEST sourcing $ALIASES_DEST"
}

deploy_config_only() {
    local login_shell=$(get_login_shell)
    [[ "${login_shell:t}" == "zsh" ]] || warn "Login shell is ${login_shell:-unknown}, not zsh. aliases.zsh and glc need zsh"

    deploy_aliases_and_scripts
    [[ -d "$OMZ_DIR" ]] || source_from_zshrc
    echo

    print_status "success" "Zsh config deployed (config only)"
    info "Deployed files:"
    echo "  - aliases.zsh: $ALIASES_DEST"
    echo "  - scripts: $SCRIPTS_DEST"
    echo
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    echo
    print_status "info" "Zsh Deployment"
    echo

    if $CONFIG_ONLY; then
        deploy_config_only
        return
    fi
    
    # Step 1: Ensure zsh is installed
    check_install_zsh
    echo
    
    # Step 2: Set zsh as default shell
    set_default_shell
    echo
    
    # Step 3: Keep what was added to ~/.zshrc, then install Oh-My-Zsh
    keep_zshrc_additions
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
    
    # Show what was deployed. "name: path", never "name -> path": pasted into a
    # shell, the '>' truncates the path.
    info "Deployed files:"
    echo "  - .zshrc: $ZSHRC_DEST"
    echo "  - aliases.zsh: $ALIASES_DEST"
    echo "  - bin shims: $BIN_DEST"
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