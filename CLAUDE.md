# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a personal Zsh configuration repository that provides:
- Custom Oh-My-Zsh configuration files (.zshrc, aliases.zsh)
- Cross-platform compatibility (macOS, Linux, Windows)
- SSH key generation and management utility
- Automated deployment script for syncing configurations

## Common Commands

### Deploying Configuration
- `source ./update-zsh-config.zsh` - Deploy all config files to Oh-My-Zsh installation and optionally reload shell
- The deployment script handles:
  - Copying .zshrc to ~/.zshrc
  - Copying aliases.zsh to $ZSH/custom/aliases.zsh  
  - Copying scripts/ to $ZSH/custom/scripts/
  - Setting proper permissions
  - Creating backups before deployment

### SSH Key Management
- `kgen` (alias for the SSH key generator) - Interactive SSH key generation and host management
- The SSH key generator provides:
  - Generate ed25519/RSA keys for specific hosts
  - Automatic SSH config management
  - Cross-platform clipboard integration
  - SSH agent integration

### Git Operations
Available aliases in aliases.zsh:
- `gits` - git status
- `gitd` - git diff  
- `gitl` - git log
- `gita` - git add .
- `gnuke` - delete all local branches except master/main

## Architecture Overview

### File Structure
- `.zshrc` - Main Zsh configuration with cross-platform NVM setup
- `aliases.zsh` - Platform-specific aliases and shortcuts
- `scripts/ssh-key-generator.zsh` - Comprehensive SSH key management utility
- `update-zsh-config.zsh` - Deployment automation script

### Cross-Platform Design
The configuration uses OS detection (`$OSTYPE`) to handle platform differences:
- **macOS**: Homebrew paths, Apple Silicon vs Intel detection
- **Linux**: Standard NVM installation paths  
- **Windows**: Git Bash/WSL compatibility with special PATH handling

### SSH Key Management Architecture
The SSH key generator (`scripts/ssh-key-generator.zsh`) implements:
- Organized key storage in `~/.ssh/keys/` directory
- Automatic SSH config file management
- Host-specific key naming convention: `id_{keytype}_{hostname}`
- SSH agent integration with automatic key loading
- Cross-platform clipboard support for public keys

### NVM Integration
Platform-specific NVM loading with fallbacks:
- Detects Homebrew NVM installations (macOS)
- Handles Windows PATH issues with helper functions
- Provides `nvmr` alias for Windows PATH refresh after node version changes

## Development Notes

- All shell scripts use proper error handling with `set -e`
- Color-coded output for better UX across all utilities
- Backup creation before modifying system files
- Permission management for SSH keys and config files
- The codebase follows defensive programming practices with existence checks before file operations