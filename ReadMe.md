# Oh-My-Zsh Configuration Management

A comprehensive terminal configuration repository that provides cross-platform Oh-My-Zsh setup with automated plugin management, SSH key generation, and deployment tools.

## 🚀 Quick Start

Each platform has a bootstrap script that installs prerequisites (including nvm, Node.js LTS, and pnpm), then `make setup` handles everything else (Oh-My-Zsh, plugins, configuration deployment, Claude Code CLI, directory structure).

### macOS

```bash
git clone https://github.com/cmaga/ohMyZshConfig.git
cd ohMyZshConfig
./src/deployment/bootstrap/macos/bootstrap.sh
make setup
```

### Linux (Ubuntu / Debian / Pop OS / Fedora / Arch)

```bash
git clone https://github.com/cmaga/ohMyZshConfig.git
cd ohMyZshConfig
./src/deployment/bootstrap/linux/bootstrap.sh
make setup
```

### Windows

```powershell
# 1. Open PowerShell as Administrator and run:
.\src\deployment\bootstrap\windows\windows-bootstrap-1.ps1

# 2. Restart your terminal, open Git Bash, then:
cd ohMyZshConfig
make setup
```

## 🔧 What Setup Does

### Bootstrap Scripts (per-platform)

| Platform | Script                                                     | Installs                                                                                                             |
| -------- | ---------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| macOS    | `src/deployment/bootstrap/macos/bootstrap.sh`              | Xcode CLI Tools (git, make; zsh is default), Homebrew, nvm, Node.js LTS, pnpm (via corepack)                         |
| Linux    | `src/deployment/bootstrap/linux/bootstrap.sh`              | git, make, zsh, curl, nvm, Node.js LTS, pnpm (via corepack)                                                          |
| Windows  | `src/deployment/bootstrap/windows/windows-bootstrap-1.ps1` | Chocolatey, Git, 7-Zip, Make + Zsh (MSYS2 into Git Bash), nvm-windows, Node.js LTS, pnpm, Claude Code CLI, Oh-My-Zsh |

### `make setup` (all platforms)

Runs in 6 phases:

1. **Phase 0** — Sets script permissions and configures git hooks path
2. **Phase 1** — Simple dependencies (git, curl)
3. **Phase 2** — Zsh deployment (installs zsh, sets default shell, installs Oh-My-Zsh, plugins, deploys configs)
4. **Phase 3** — Git deployment (deploys git configs)
5. **Phase 4** — Cline deployment (deploys Cline CLI + configs)
6. **Phase 5** — Finalization (offers to reload shell configuration)

All deployment scripts are **idempotent** — they safely skip steps that are already complete.

## 📋 Available Commands

| Command             | Description                                                    |
| ------------------- | -------------------------------------------------------------- |
| `make setup`        | Full setup: system prerequisites → plugins → config deployment |
| `make deploy`       | Deploy all configs (zsh, git, cline) to local system           |
| `make deploy-zsh`   | Deploy zsh (installs zsh/omz if needed, deploys configs)       |
| `make deploy-git`   | Deploy only git configs (.gitconfig, company profiles)         |
| `make deploy-cline` | Deploy only Cline configs (rules, workflows, skills)           |
| `make lint`         | Format files and run lint checks                               |
| `make help`         | Show available commands                                        |

### Regular Workflow

```bash
# Deploy configuration changes (includes plugin updates if needed)
make deploy

# Run lint checks before committing
make lint
```

## 🔌 Plugin Management

Plugins are managed automatically through the `plugins.txt` file. To add new plugins:

1. Edit `plugins.txt` and add the plugin in format: `username/repository-name`
2. Run `make deploy-zsh` to install/update all plugins

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

- `src/storage/cline/rules/` — Global rules applied to all projects
- `src/storage/cline/workflows/` — Reusable workflow instructions
- `src/storage/cline/hooks/` — Hook scripts for Cline events
- `src/storage/cline/skills/` — Custom skills with dependencies

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

- `src/storage/git/.gitconfig` — Main git configuration (deployed to `~/.gitconfig`)
- `src/storage/git/gitconfig-gsi` — GSI-specific settings
- `src/storage/git/gitconfig-ms` — MS-specific settings

### How It Works

When you run `make deploy`, the system automatically:

1. Copies the main `.gitconfig` to your home directory (`~/.gitconfig`)
2. Places profile-specific configs in `~/.oh-my-zsh/custom/git/`
3. Sets up the git configuration structure for easy profile switching

### Using Git Profiles

The profile-specific configurations are stored as separate files that can be included in your main git config or used for specific repositories. This allows you to maintain different git identities for different projects.

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

Scripts are numbered to indicate execution order during a full setup.

```txt
ohMyZshConfig/
├── Makefile                    # Build automation commands
├── plugins.txt                 # List of Oh-My-Zsh plugins to install
├── hooks/
│   └── pre-commit              # Git pre-commit hook for validation
├── src/
│   ├── storage/                # Configuration files (what gets deployed)
│   │   ├── zsh/
│   │   │   ├── .zshrc          # Main Zsh configuration
│   │   │   └── aliases.zsh     # Platform-specific aliases
│   │   ├── git/
│   │   │   ├── .gitconfig      # Main git configuration
│   │   │   ├── gitconfig-gsi   # GSI-specific git settings
│   │   │   └── gitconfig-ms    # MS-specific git settings
│   │   ├── cline/              # Cline AI assistant configurations
│   │   │   ├── rules/          # Global rules for all projects
│   │   │   ├── workflows/      # Reusable workflow instructions
│   │   │   ├── hooks/          # Hook scripts for Cline events
│   │   │   └── skills/         # Custom skills with dependencies
│   │   └── scripts/            # User utility scripts (deployed to ~/.oh-my-zsh/custom/scripts/)
│   │       └── ssh-key-generator.zsh
│   └── deployment/             # Deployment scripts (how things get deployed)
│       ├── lib/
│       │   └── common.zsh      # Shared utilities (colors, logging, platform detection)
│       ├── bootstrap/          # Platform-specific bootstrap scripts (01-*)
│       │   ├── macos/
│       │   │   └── 01-bootstrap.sh
│       │   ├── linux/
│       │   │   └── 01-bootstrap.sh
│       │   └── windows/
│       │       ├── bootstrap.ps1       # PowerShell entry point (calls 01-bootstrap.sh)
│       │       └── 01-bootstrap.sh
│       ├── 02-simple-deps.zsh          # Simple dependencies (git, curl)
│       ├── 03-company-setup.zsh        # Company directories & SSH key generation
│       ├── 04-deploy-zsh.zsh           # Deploy zsh (install, omz, plugins, configs)
│       ├── 05-deploy-git.zsh           # Deploy git configs (.gitconfig, company profiles)
│       ├── 06-deploy-cline.zsh         # Deploy Cline CLI + configs (rules, workflows, skills)
│       └── 07-finalize.zsh             # Final cleanup and shell reload prompt
└── README.md                   # This file
```

### Script Numbering Convention

| Number | Phase         | Scripts                                                |
| ------ | ------------- | ------------------------------------------------------ |
| 01     | Bootstrap     | Platform-specific bootstrap (first script to run)      |
| 02     | Simple Deps   | Basic tools that don't need configuration (git, curl)  |
| 03     | Company Setup | Company directories & SSH keys (optional)              |
| 04     | Zsh Deploy    | Deploy zsh (install, omz, plugins, configs)            |
| 05     | Git Deploy    | Deploy git configs (.gitconfig, company profiles)      |
| 06     | Cline Deploy  | Deploy Cline CLI + configs (rules, workflows, skills)  |
| 07     | Finalize      | Final cleanup and shell reload prompt (runs after all) |

### Idempotent Design

All scripts are designed to be **idempotent** — they can be run multiple times safely:

- If zsh is already installed, `04-deploy-zsh.zsh` skips installation
- If Oh-My-Zsh exists, it skips that step too
- If Cline CLI is already installed, `06-deploy-cline.zsh` skips installation
- Each deploy script handles its full domain (installation + configuration)

## 🤝 Dev Notes

Changes made as needed unless specified here.

- Mac working
- Windows untested
- PopOs untested
- Ubuntu working

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
