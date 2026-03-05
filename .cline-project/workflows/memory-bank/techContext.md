# Tech Context: ohMyZshConfig

## Core Technologies

### Shell Environment

| Technology      | Purpose                              |
| --------------- | ------------------------------------ |
| Zsh             | Primary shell                        |
| Oh-My-Zsh       | Zsh framework for plugins and themes |
| Half-life theme | Zsh prompt theme                     |

### Node.js Ecosystem

| Technology  | Purpose                        |
| ----------- | ------------------------------ |
| nvm         | Node version management        |
| Node.js LTS | JavaScript runtime             |
| pnpm        | Package manager (via corepack) |

### AI Tooling

| Technology      | Purpose                                 |
| --------------- | --------------------------------------- |
| Cline           | AI coding assistant (VS Code extension) |
| Claude Code CLI | Anthropic's Claude in terminal          |

### Version Control

| Technology | Purpose                                        |
| ---------- | ---------------------------------------------- |
| Git        | Version control                                |
| GitHub     | Remote repository                              |
| gh CLI     | GitHub operations (used by git-provider skill) |

## Oh-My-Zsh Plugins

Managed via `plugins.txt`:

| Plugin                               | Purpose                           |
| ------------------------------------ | --------------------------------- |
| `zsh-users/zsh-autosuggestions`      | Fish-like command autosuggestions |
| `zsh-users/zsh-completions`          | Additional completion definitions |
| `zsh-users/zsh-syntax-highlighting`  | Command syntax highlighting       |
| `MichaelAquilina/zsh-you-should-use` | Reminds about existing aliases    |

Built-in plugins enabled in `.zshrc`:

- `git` - Git aliases and functions
- `direnv` - Directory-specific environment variables

## Platform Support Matrix

### macOS (Primary)

- **Bootstrap**: `src/deployment/bootstrap/macos/01-bootstrap.sh`
- **Prerequisites**: Xcode CLI Tools, Homebrew
- **nvm location**: `/opt/homebrew/opt/nvm/` (Apple Silicon) or `/usr/local/opt/nvm/` (Intel)
- **Status**: Working

### Linux (Secondary)

- **Bootstrap**: `src/deployment/bootstrap/linux/01-bootstrap.sh`
- **Distributions**: Ubuntu, Debian, Pop OS, Fedora, Arch
- **Package managers**: apt, dnf, yum, pacman, zypper
- **nvm location**: `$HOME/.nvm/`
- **Status**: Ubuntu working, Pop OS untested

### Windows (Maintenance)

- **Bootstrap**: `src/deployment/bootstrap/windows/windows-bootstrap-1.ps1`
- **Environment**: Git Bash with MSYS2 zsh/make
- **Special handling**: SSH agent auto-start, nvm-windows, PATH management
- **Status**: Untested

## Directory Structure on Target Machines

After deployment, the following directories exist:

```
~/
├── .zshrc                          # Shell config
├── .gitconfig                      # Git config
├── .oh-my-zsh/
│   └── custom/
│       ├── aliases.zsh             # Custom aliases
│       ├── scripts/                # Utility scripts
│       │   ├── ssh-key-generator.zsh
│       │   └── company-setup.zsh
│       ├── git/                    # Git profiles
│       │   ├── gitconfig-work
│       │   └── gitconfig-kratos
│       └── plugins/                # Custom plugins
│           ├── zsh-autosuggestions/
│           ├── zsh-completions/
│           ├── zsh-syntax-highlighting/
│           └── zsh-you-should-use/
├── .cline/
│   └── skills/                     # Cline skills
│       ├── automater/
│       ├── cline-configuration/
│       ├── git-provider/
│       └── jira/
├── Documents/
│   └── Cline/
│       ├── Rules/                  # Global Cline rules
│       ├── Workflows/              # Workflow instructions
│       └── Hooks/                  # Cline hooks
└── dev/
    ├── personal/                   # Personal projects (personal git identity)
    ├── work/                       # Work projects (work git identity)
    └── kratos/                     # Kratos projects (kratos git identity)
```

## Development Dependencies

### Required for Bootstrap

- `curl` - Downloading scripts/installers
- `git` - Cloning repositories
- `make` - Running Makefile commands

### Installed by Bootstrap

- `zsh` - Shell (macOS default, installed on Linux)
- `nvm` - Node version manager
- `node` - Node.js LTS
- `pnpm` - Package manager

### Installed by Setup

- Oh-My-Zsh framework
- Custom plugins from `plugins.txt`
- Claude Code CLI

## Key Configuration Files

### .zshrc

- Sets `ZSH_THEME="half-life"`
- Enables plugins: git, direnv, zsh-completions, zsh-autosuggestions, zsh-syntax-highlighting, zsh-you-should-use
- Cross-platform NVM configuration
- Sources `aliases.zsh`, `.zshrc.local`, `.zshrc.$(hostname)`
- Windows-specific SSH agent management

### .gitconfig

- Directory-based identity via `includeIf`
- Common git settings and aliases
- Profile configs in `~/.oh-my-zsh/custom/git/`

## Constraints and Considerations

1. **No sudo in scripts without warning** - Bootstrap scripts need sudo, but it should be clear
2. **Cross-shell compatibility** - Scripts must work in both bash and zsh
3. **ANSI-C quoting required** - Use `$'\033[0;31m'` not `\033[0;31m`
4. **No emojis in code** - Per project coding standards
5. **Do not auto-run deploy** - Users must manually run `make deploy` for system stability
