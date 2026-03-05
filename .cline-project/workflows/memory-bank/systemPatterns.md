# System Patterns: ohMyZshConfig

## Architectural Overview

The repository follows a **dual responsibility model** with clear separation between storage and deployment concerns:

```
ohMyZshConfig/
├── Storage Layer (src/storage/) - Configuration files that get deployed
└── Deployment Layer (src/deployment/) - Scripts that do the deploying
```

## Current Directory Structure

```
ohMyZshConfig/
├── Makefile                    # Command interface
├── plugins.txt                 # Plugin manifest (STORAGE)
├── hooks/                      # Git hooks (DEPLOYMENT)
│   └── pre-commit
├── src/
│   ├── storage/                # What gets deployed
│   │   ├── zsh/
│   │   │   ├── .zshrc          # Main shell config
│   │   │   └── aliases.zsh     # Shell aliases
│   │   ├── git/
│   │   │   ├── .gitconfig      # Main git config
│   │   │   ├── gitconfig-gsi   # GSI profile
│   │   │   └── gitconfig-ms    # MS profile
│   │   ├── cline/              # Cline AI configs
│   │   │   ├── rules/          # Global rules
│   │   │   ├── workflows/      # Workflow instructions
│   │   │   ├── hooks/          # Event hooks
│   │   │   └── skills/         # Custom skills
│   │   └── scripts/            # User utility scripts
│   │       └── ssh-key-generator.zsh
│   └── deployment/             # How it gets deployed
│       ├── lib/
│       │   └── common.zsh      # Shared utilities
│       ├── bootstrap/
│       │   ├── macos/
│       │   │   └── 01-bootstrap.sh
│       │   ├── linux/
│       │   │   └── 01-bootstrap.sh
│       │   └── windows/
│       │       ├── 01-bootstrap.sh
│       │       └── windows-bootstrap-1.ps1
│       ├── 02-simple-deps.zsh
│       ├── 03-company-setup.zsh
│       ├── 04-deploy-zsh.zsh
│       ├── 05-deploy-git.zsh
│       ├── 06-deploy-cline.zsh
│       └── 07-finalize.zsh
```

## Key Design Patterns

### 1. Makefile as Command Interface

All operations go through the Makefile, providing a consistent interface:

| Command             | Description                          |
| ------------------- | ------------------------------------ |
| `make setup`        | Full system setup (phases 0-5)       |
| `make deploy`       | Deploy all configs (zsh, git, cline) |
| `make deploy-zsh`   | Deploy zsh only                      |
| `make deploy-git`   | Deploy git only                      |
| `make deploy-cline` | Deploy Cline only                    |
| `make finalize`     | Shell reload prompt                  |
| `make lint`         | Validate configs                     |

### 2. Phase-Based Setup

`make setup` runs in ordered phases:

1. **Phase 0** - Script permissions, git hooks configuration
2. **Phase 1** - Simple dependencies (git, curl)
3. **Phase 2** - Zsh deployment (install zsh, omz, plugins, deploy configs)
4. **Phase 3** - Git deployment (deploy git configs)
5. **Phase 4** - Cline deployment (install CLI, deploy configs)
6. **Phase 5** - Finalization (shell reload prompt)

### 3. Numbered Script System

Scripts are numbered to indicate execution order:

| Number | Phase         | Purpose                                      |
| ------ | ------------- | -------------------------------------------- |
| 01     | Bootstrap     | Platform prerequisites (nvm, pnpm, etc.)     |
| 02     | Simple Deps   | Basic tools (git, curl)                      |
| 03     | Company Setup | Dev directories, SSH keys (optional)         |
| 04     | Zsh Deploy    | Install zsh, omz, plugins, deploy configs    |
| 05     | Git Deploy    | Deploy git configs                           |
| 06     | Cline Deploy  | Install Cline CLI, deploy configs            |
| 07     | Finalize      | Shell reload prompt (runs after all deploys) |

### 4. Self-Contained Idempotent Scripts

Each deployment script:

- **Handles its full domain** - Installation + configuration
- **Is idempotent** - Can be run multiple times safely
- **Checks before installing** - Skips if already present
- **Verifies installation** - Confirms success before proceeding

Examples:

- `04-deploy-zsh.zsh` checks if zsh exists before installing
- `06-deploy-cline.zsh` checks if Cline CLI exists before installing
- `07-finalize.zsh` can be run standalone if user wants to reload

### 5. Shared Library Pattern

`src/deployment/lib/common.zsh` provides:

- `print_status()` - Colored status messages
- `command_exists()` - Check if command is available
- `detect_os()` - Platform detection
- `install_package()` - Cross-platform package installation
- `get_storage_dir()` - Path resolution
- Standard environment variables (colors, paths)

### 6. Platform Detection

Cross-platform support uses `$OSTYPE` detection:

```zsh
case "$OSTYPE" in
  darwin*)   # macOS
  linux*)    # Linux
  msys*|cygwin*|mingw*)  # Windows
esac
```

### 7. Directory-Based Git Identity

Git config uses `includeIf` to apply profiles based on directory:

```gitconfig
[includeIf "gitdir:~/dev/gsi/"]
    path = ~/.oh-my-zsh/custom/git/gitconfig-gsi

[includeIf "gitdir:~/dev/ms/"]
    path = ~/.oh-my-zsh/custom/git/gitconfig-ms
```

### 8. Cline Skills Architecture

Each skill follows a consistent structure:

```
skill-name/
├── SKILL.md              # Entry point with metadata
├── modes/                # Different operational modes
├── dependencies/
│   ├── docs/             # Reference documentation
│   ├── templates/        # Templates used by skill
│   ├── scripts/          # Helper scripts (e.g., update-repo.zsh)
│   └── repos/            # Git repos (cloned on deploy, gitignored)
```

Skills are deployed to `~/.cline/skills/` and repos are cloned on-demand via `update-repo.zsh`.

### 9. Deployment Targets

| Source                         | Destination                                 |
| ------------------------------ | ------------------------------------------- |
| `src/storage/zsh/.zshrc`       | `~/.zshrc`                                  |
| `src/storage/zsh/aliases.zsh`  | `~/.oh-my-zsh/custom/aliases.zsh`           |
| `src/storage/scripts/*.zsh`    | `~/.oh-my-zsh/custom/scripts/`              |
| `src/storage/git/`             | `~/.gitconfig` + `~/.oh-my-zsh/custom/git/` |
| `src/storage/cline/rules/`     | `~/Documents/Cline/Rules/`                  |
| `src/storage/cline/workflows/` | `~/Documents/Cline/Workflows/`              |
| `src/storage/cline/hooks/`     | `~/Documents/Cline/Hooks/`                  |
| `src/storage/cline/skills/`    | `~/.cline/skills/`                          |

## Shell Script Conventions

From `.clinerules/01-learnings.md`:

1. **Use ANSI-C quoting** for escape sequences: `RED=$'\\033[0;31m'`
2. **Avoid `echo -e`** - behavior varies across shells
3. **Use `--no-pager`** for git commands that produce output
4. **Single-line strings** for CLI arguments (multi-line gets mangled)
5. **No emojis** in code or documentation

## Execution Flow

### Fresh Machine Setup

```
1. User runs: ./src/deployment/bootstrap/<platform>/01-bootstrap.sh
   → Installs: Homebrew/apt, nvm, Node.js, pnpm, gh CLI, bb CLI

2. User runs: make setup
   → Phase 0: Set permissions, configure git hooks
   → Phase 1: Install git, curl (via 02-simple-deps.zsh)
   → Phase 2: Deploy zsh (via 04-deploy-zsh.zsh)
      - Install zsh if needed
      - Set as default shell
      - Install Oh-My-Zsh
      - Install plugins from plugins.txt
      - Deploy .zshrc, aliases.zsh, scripts/
   → Phase 3: Deploy git (via 05-deploy-git.zsh)
      - Deploy .gitconfig and profiles
   → Phase 4: Deploy Cline (via 06-deploy-cline.zsh)
      - Install Cline CLI if needed
      - Deploy rules, workflows, hooks, skills
   → Phase 5: Finalize (via 07-finalize.zsh)
      - Offer to source ~/.zshrc
```

### Configuration Update

```
1. User runs: git pull
2. User runs: make deploy
   → Runs: make deploy-zsh
   → Runs: make deploy-git
   → Runs: make deploy-cline
   → Runs: make finalize
```
