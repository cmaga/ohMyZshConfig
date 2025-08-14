# Oh-My-Zsh Configuration Management

A comprehensive terminal configuration repository that provides cross-platform Oh-My-Zsh setup with automated plugin management, SSH key generation, and deployment tools.

## 🚀 Quick Start

### First Time Setup

```bash
# Clone the repository
git clone https://github.com/cmaga/ohMyZshConfig.git
cd ohMyZshConfig

# Run complete setup (installs plugins and deploys configs)
make setup
```

### Regular Updates

```bash
# Update plugins when needed
make update

# Deploy configuration changes
make deploy

# Run lint checks before committing
make lint
```

## 📋 Available Commands

| Command       | Description                                                 |
| ------------- | ----------------------------------------------------------- |
| `make setup`  | Initial setup to prepare system for deployments and updates |
| `make deploy` | Deploy changes/config from this project to the local system |
| `make update` | Check and update custom plugins from plugins.txt            |
| `make lint`   | Format files and run lint checks                            |
| `make help`   | Show available commands                                     |

## 🔧 Prerequisites

1. **Install Zsh and set as default shell**

   ```bash
   # macOS (using Homebrew)
   brew install zsh
   chsh -s $(which zsh)

   # Ubuntu/Debian
   sudo apt install zsh
   chsh -s $(which zsh)

   # If you can't change default shell:
   echo "exec zsh" >> ~/.bashrc
   ```

2. **Install Oh-My-Zsh**
   ```bash
   sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
   ```

## 🔌 Plugin Management

Plugins are managed automatically through the `plugins.txt` file. To add new plugins:

1. Edit `plugins.txt` and add the plugin in format: `username/repository-name`
2. Run `make update` to install/update all plugins

### Current Plugins

- `zsh-users/zsh-autosuggestions` - Fish-like autosuggestions
- `zsh-users/zsh-completions` - Additional completion definitions
- `zsh-users/zsh-syntax-highlighting` - Syntax highlighting in command line

## 🖥️ Cross-Platform Support

The configuration automatically detects and handles:

- **macOS**: Homebrew paths, Apple Silicon vs Intel detection
- **Linux**: Standard NVM installation paths
- **Windows**: Git Bash/WSL compatibility with special PATH handling

## 🔑 SSH Key Management

Use the built-in SSH key generator:

```bash
kgen  # Interactive SSH key generation and management
```

Features:

- Generate ed25519/RSA keys for specific hosts
- Automatic SSH config management
- Cross-platform clipboard integration
- SSH agent integration

## ⚙️ Machine-Specific Overrides

Create machine-specific configuration files for custom settings per machine:

- `~/.zshrc.local` - General local overrides (applies to all machines)
- `~/.zshrc.$(hostname)` - Machine-specific overrides (only applies to current machine)

Example:

```bash
# On a machine named "work-laptop", create:
# ~/.zshrc.work-laptop

# Add machine-specific aliases, exports, etc.
export WORK_ENV="true"
alias vpn="sudo openconnect work.company.com"
```

## 🧪 Testing & Validation

Run syntax validation and basic checks:

```bash
make lint
```

This will:

- Check syntax of all `.zsh` files using `zsh -n`
- Verify file permissions are correct
- Validate plugins.txt format

## 🪝 Git Hooks (Optional)

Install the pre-commit hook to automatically validate shell syntax:

```bash
# Copy the hook and make it executable
cp hooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

The hook will run syntax validation on staged `.zsh` files before each commit.

## 📁 Project Structure

```
ohMyZshConfig/
├── Makefile                    # Build automation commands
├── plugins.txt                 # List of Oh-My-Zsh plugins to install
├── .zshrc                      # Main Zsh configuration
├── aliases.zsh                 # Platform-specific aliases
├── scripts/
│   ├── ssh-key-generator.zsh   # SSH key management utility
│   └── plugin-manager.zsh      # Plugin installation/update script
├── hooks/
│   └── pre-commit              # Git pre-commit hook for validation
├── update-zsh-config.zsh       # Legacy deployment script (still supported)
└── README.md                   # This file
```

## 🤝 Dev notes

Most things are added/changed as needed which is very rare.

- setup has never been tested

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
