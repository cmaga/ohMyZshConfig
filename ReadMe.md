# Oh-My-Zsh Configuration Management

A comprehensive terminal configuration repository that provides cross-platform Oh-My-Zsh setup with automated plugin management, SSH key generation, and deployment tools.

## 🚀 Quick Start

Each platform has a bootstrap script that installs prerequisites (including nvm, Node.js LTS, and pnpm), then `make setup` handles everything else (Oh-My-Zsh, plugins, configuration deployment, Claude Code CLI, directory structure).

### macOS

```bash
git clone https://github.com/cmaga/ohMyZshConfig.git
cd ohMyZshConfig
./scripts/setup/macos/bootstrap.sh
make setup
```

### Linux (Ubuntu / Debian / Pop OS / Fedora / Arch)

```bash
git clone https://github.com/cmaga/ohMyZshConfig.git
cd ohMyZshConfig
./scripts/setup/linux/bootstrap.sh
make setup
```

### Windows

```powershell
# 1. Open PowerShell as Administrator and run:
.\scripts\setup\windows\windows-bootstrap-1.ps1

# 2. Restart your terminal, open Git Bash, then:
cd ohMyZshConfig
make setup
```

## 🔧 What Setup Does

### Bootstrap Scripts (per-platform)

| Platform | Script                                          | Installs                                                                                                             |
| -------- | ----------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| macOS    | `scripts/setup/macos/bootstrap.sh`              | Xcode CLI Tools (git, make; zsh is default), Homebrew, nvm, Node.js LTS, pnpm (via corepack)                         |
| Linux    | `scripts/setup/linux/bootstrap.sh`              | git, make, zsh, curl, nvm, Node.js LTS, pnpm (via corepack)                                                          |
| Windows  | `scripts/setup/windows/windows-bootstrap-1.ps1` | Chocolatey, Git, 7-Zip, Make + Zsh (MSYS2 into Git Bash), nvm-windows, Node.js LTS, pnpm, Claude Code CLI, Oh-My-Zsh |

### `make setup` (all platforms)

Runs in 4 phases:

1. **Phase 0** — Sets script permissions and configures git hooks path
2. **Phase 1** — System setup: installs remaining prerequisites, sets zsh as default shell, installs Oh-My-Zsh, creates directory structure, installs Claude Code CLI
3. **Phase 2** — Installs/updates custom plugins from `plugins.txt`
4. **Phase 3** — Deploys all configuration files (zsh, git, Cline) to the local system

## 📋 Available Commands

| Command       | Description                                                         |
| ------------- | ------------------------------------------------------------------- |
| `make setup`  | Full setup: system prerequisites → plugins → config deployment      |
| `make deploy` | Deploy zsh configs, scripts, and git configurations to local system |
| `make update` | Check and update custom plugins from plugins.txt                    |
| `make lint`   | Format files and run lint checks                                    |
| `make help`   | Show available commands                                             |

### Regular Workflow

```bash
# Update plugins when needed
make update

# Deploy configuration changes
make deploy

# Run lint checks before committing
make lint
```

## 🔌 Plugin Management

Plugins are managed automatically through the `plugins.txt` file. To add new plugins:

1. Edit `plugins.txt` and add the plugin in format: `username/repository-name`
2. Run `make update` to install/update all plugins

### Current Plugins

- `zsh-users/zsh-autosuggestions` — Fish-like autosuggestions
- `zsh-users/zsh-completions` — Additional completion definitions
- `zsh-users/zsh-syntax-highlighting` — Syntax highlighting in command line
- `MichaelAquilina/zsh-you-should-use` — Reminds you of existing aliases

## 🖥️ Cross-Platform Support

The configuration automatically detects and handles:

- **macOS** — Homebrew paths, Apple Silicon vs Intel detection
- **Linux** — Standard NVM installation paths, multiple package managers
- **Windows** — Git Bash with MSYS2 zsh/make, symlink handling, Developer Mode

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

## 🤖 Claude Code CLI

Both the Linux/macOS system setup and the Windows PowerShell script install [Claude Code](https://claude.ai) CLI automatically. It is available as `claude` after setup completes.

## ⚙️ Cline Configuration Management

The repository includes centralized Cline (AI coding assistant) configuration management:

### Cline Configuration Files

- `configurations/cline/rules/` — Global rules applied to all projects
- `configurations/cline/workflows/` — Reusable workflow instructions
- `configurations/cline/hooks/` — Hook scripts for Cline events
- `configurations/cline/skills/` — Custom skills with dependencies

### Deployment Locations

| Config Type | Deployed To                    |
| ----------- | ------------------------------ |
| Rules       | `~/Documents/Cline/Rules/`     |
| Workflows   | `~/Documents/Cline/Workflows/` |
| Hooks       | `~/Documents/Cline/Hooks/`     |
| Skills      | `~/.cline/skills/`             |

### Skills and Repository Dependencies

Skills may include repository dependencies (e.g., reference documentation). These are:

- **Not tracked in git** — Listed in `.gitignore`
- **Cloned during deployment** — The `update-repo.zsh` script in each skill fetches required repos

This keeps the repository lightweight while ensuring dependencies are available after deployment.

## ⚙️ Git Configuration Management

The repository includes centralized git configuration management with support for multiple profiles:

### Git Configuration Files

- `configurations/git/.gitconfig` — Main git configuration (deployed to `~/.gitconfig`)
- `configurations/git/gitconfig-work` — Work-specific settings
- `configurations/git/gitconfig-kratos` — Kratos-specific settings

### How It Works

When you run `make deploy`, the system automatically:

1. Copies the main `.gitconfig` to your home directory (`~/.gitconfig`)
2. Places profile-specific configs in `~/.oh-my-zsh/custom/git/`
3. Sets up the git configuration structure for easy profile switching

### Using Git Profiles

The work and kratos configurations are stored as separate files that can be included in your main git config or used for specific repositories. This allows you to maintain different git identities for different projects.

## ⚙️ Machine-Specific Overrides

Create machine-specific configuration files for custom settings per machine:

- `~/.zshrc.local` — General local overrides (applies to all machines)
- `~/.zshrc.$(hostname)` — Machine-specific overrides (only applies to current machine)

Example:

```bash
# On a machine named "work-laptop", create:
# ~/.zshrc.work-laptop

# Add machine-specific aliases, exports, etc.
export WORK_ENV="true"
alias vpn="sudo openconnect work.company.com"
```

## 📁 Project Structure

```txt
ohMyZshConfig/
├── Makefile                    # Build automation commands
├── plugins.txt                 # List of Oh-My-Zsh plugins to install
├── .zshrc                      # Main Zsh configuration
├── aliases.zsh                 # Platform-specific aliases
├── configurations/
│   ├── cline/                  # Cline AI assistant configurations
│   │   ├── rules/              # Global rules for all projects
│   │   ├── workflows/          # Reusable workflow instructions
│   │   ├── hooks/              # Hook scripts for Cline events
│   │   └── skills/             # Custom skills with dependencies
│   └── git/
│       ├── .gitconfig          # Main git configuration
│       ├── gitconfig-work      # Work-specific git settings
│       └── gitconfig-kratos    # Kratos-specific git settings
├── scripts/
│   ├── system-setup.zsh        # System prerequisites & Oh-My-Zsh installation
│   ├── plugin-manager.zsh      # Plugin installation/update script
│   ├── ssh-key-generator.zsh   # SSH key management utility
│   └── setup/
│       ├── macos/
│       │   └── bootstrap.sh    # macOS prerequisite installer
│       ├── linux/
│       │   └── bootstrap.sh    # Linux prerequisite installer
│       └── windows/
│           ├── windows-bootstrap-1.ps1  # Windows full bootstrap (Admin PowerShell)
│           └── windows-bootstrap-2.sh   # Git Bash shell configuration
├── hooks/
│   └── pre-commit              # Git pre-commit hook for validation
├── update-zsh-config.zsh       # Deployment script
└── README.md                   # This file
```

## 🤝 Dev Notes

Changes made as needed unless specified here.

- Mac working
- Windows untested
- PopOs untested
- Ubuntu working

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
