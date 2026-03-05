# Project Brief: ohMyZshConfig

## Overview

ohMyZshConfig is a personal configuration management system with a dual responsibility model:

1. **Storage** - Central repository for configuration files, scripts, and AI tooling
2. **Deployment** - Automated setup and deployment to new or existing machines

## Core Purpose

Provide a portable, version-controlled development environment that can be deployed to any machine, ensuring consistent tooling and configuration across all workstations. If a machine is lost or wiped, the user can restore their complete environment from this repository.

## Primary Goals

1. **Configuration Portability** - Store all shell configurations, git profiles, aliases, and scripts in one place
2. **Automated Setup** - Bootstrap fresh machines with minimal manual intervention
3. **Cross-Platform Support** - Work consistently across macOS, Linux (Pop OS/Ubuntu), and Windows
4. **AI Tooling** - Provide generalized Cline skills that work across any project or company
5. **Git Profile Management** - Directory-based git configuration for automatic identity switching

## Non-Goals

- This is not a framework for others to adopt
- Not intended for team collaboration on the configs themselves
- Windows support is maintenance-only, not a priority

## Success Criteria

- Fresh machine can be fully configured with `bootstrap.sh` + `make setup`
- Configuration changes propagate to all machines via git pull + `make deploy`
- Cline skills work identically across different project contexts
- Git commits automatically use correct identity based on project directory
