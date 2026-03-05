# Product Context: ohMyZshConfig

## Why This Exists

As a developer working across multiple machines and contexts (personal, work), maintaining consistent tooling becomes critical. This repository solves the "new machine problem" - the hours spent configuring a fresh system to match your preferred workflow.

## Problems Solved

### 1. Configuration Drift

Without centralized management, each machine develops its own quirks. An alias added on the work laptop never makes it to the home desktop. This repository ensures all machines stay in sync via git.

### 2. Machine Recovery

When a machine dies or gets replaced, starting from scratch is painful. With this system, recovery is: clone repo → run bootstrap → run setup → done.

### 3. Identity Management

Working with multiple git identities (personal GitHub, work accounts) is error-prone. Directory-based git configuration automatically applies the correct identity based on where the project lives (`~/dev/personal/`, `~/dev/work/`, `~/dev/kratos/`).

### 4. AI Assistant Portability

Cline skills and configurations need to work consistently across all projects. The skills in this repository are intentionally generalized - they don't assume any particular company or codebase.

## User Experience Goals

### For Fresh Machine Setup

```bash
git clone https://github.com/cmaga/ohMyZshConfig.git
cd ohMyZshConfig
./src/deployment/bootstrap/macos/01-bootstrap.sh  # or linux/windows
make setup
```

Result: Fully configured machine with zsh, Oh-My-Zsh, plugins, git profiles, Cline skills, and Claude CLI.

### For Configuration Updates

```bash
cd ~/dev/personal/ohMyZshConfig
git pull
make deploy
```

Result: Latest configurations applied to current machine.

### For Git Identity

```bash
cd ~/dev/work/some-project
git commit -m "fix bug"  # Automatically uses work identity
cd ~/dev/personal/side-project
git commit -m "add feature"  # Automatically uses personal identity
```

Result: Zero thought required about which identity to use.

## Key Differentiators

1. **Dual Responsibility Model** - Clear separation between what's stored vs how it's deployed
2. **Directory-Based Git Profiles** - One of the most useful features; identity is determined by project location
3. **Portable AI Tooling** - Cline skills that travel with the dotfiles
4. **Platform Abstraction** - Same config works on macOS, Linux, and Windows (to varying degrees)

## Platform Priority

| Platform | Priority    | Status                  |
| -------- | ----------- | ----------------------- |
| macOS    | Primary     | Working                 |
| Pop OS   | Secondary   | Untested (Ubuntu works) |
| Ubuntu   | Secondary   | Working                 |
| Windows  | Maintenance | Untested                |
