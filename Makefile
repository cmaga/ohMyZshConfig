# Oh-My-Zsh Configuration Management
# This Makefile provides convenient commands for managing your Zsh configuration

.PHONY: help setup deploy deploy-zsh deploy-git deploy-claude deploy-automations finalize lint
.DEFAULT_GOAL := help

# Use bash for recipe execution (ensures consistent behavior on all platforms)
SHELL := $(shell which bash)

# Color codes for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

# Configuration
ZSH_DIR := $(HOME)/.oh-my-zsh
PLUGINS_DIR := $(ZSH_DIR)/custom/plugins
CURRENT_DIR := $(shell pwd)
DEPLOYMENT_DIR := $(CURRENT_DIR)/src/deployment
STORAGE_DIR := $(CURRENT_DIR)/src/storage

help: ## Show this help message
	@printf "$(BLUE)Oh-My-Zsh Configuration Management$(NC)\n"
	@printf "\n"
	@printf "Available commands:\n"
	@printf "  $(GREEN)lint$(NC)          - Format files and run lint checks\n"
	@printf "  $(GREEN)deploy$(NC)        - Deploy all configs (zsh, git, claude)\n"
	@printf "  $(GREEN)deploy-zsh$(NC)    - Deploy only zsh configs (.zshrc, aliases, scripts)\n"
	@printf "  $(GREEN)deploy-git$(NC)    - Deploy only git configs (.gitconfig, company profiles)\n"
	@printf "  $(GREEN)deploy-claude$(NC) - Deploy only Claude Code configs (CLAUDE.md, rules, skills, agents)\n"
	@printf "  $(GREEN)setup$(NC)         - Complete system setup (fresh system to fully configured)\n"
	@printf "  $(GREEN)help$(NC)          - Show this help message\n"
	@printf "\n"
	@printf "Typical workflow:\n"
	@printf "  $(YELLOW)make setup$(NC)   # Full setup on fresh system (installs zsh, oh-my-zsh, plugins, configs)\n"
	@printf "  $(YELLOW)make deploy$(NC)  # Deploy all config changes to existing setup\n"
	@printf "  $(YELLOW)make lint$(NC)    # Validate configuration before commits\n"
	@printf "\n"
	@printf "$(BLUE)Fresh System Setup:$(NC)\n"
	@printf "  The $(YELLOW)setup$(NC) command handles everything needed on a fresh system:\n"
	@printf "  • Installs prerequisites (git, curl, zsh)\n"
	@printf "  • Sets zsh as default shell\n"
	@printf "  • Installs Oh-My-Zsh framework\n"
	@printf "  • Installs custom plugins\n"
	@printf "  • Deploys all configuration files\n"

lint: ## Format files and run lint checks
	@printf "$(BLUE)Running lint checks...$(NC)\n"
	@printf "\n"
	@printf "$(BLUE)Checking zsh syntax...$(NC)\n"
	@for file in $(STORAGE_DIR)/zsh/.zshrc $(STORAGE_DIR)/zsh/*.zsh $(STORAGE_DIR)/scripts/*.zsh $(DEPLOYMENT_DIR)/*.zsh $(DEPLOYMENT_DIR)/lib/*.zsh; do \
		if [ -f "$$file" ]; then \
			printf "  Checking $$file...\n"; \
			if zsh -n "$$file"; then \
				printf "  $(GREEN)OK: $$file$(NC)\n"; \
			else \
				printf "  $(RED)SYNTAX ERROR: $$file$(NC)\n"; \
				exit 1; \
			fi; \
		fi; \
	done
	@printf "\n"
	@printf "$(BLUE)Checking file permissions...$(NC)\n"
	@for file in $(DEPLOYMENT_DIR)/*.zsh $(STORAGE_DIR)/scripts/*.zsh hooks/pre-commit; do \
		if [ -f "$$file" ] && [ ! -x "$$file" ]; then \
			printf "  $(YELLOW)Making $$file executable$(NC)\n"; \
			chmod +x "$$file"; \
		fi; \
	done
	@printf "\n"
	@printf "$(BLUE)Validating plugins.txt format...$(NC)\n"
	@if [ -f "plugins.txt" ]; then \
		while IFS= read -r line || [ -n "$$line" ]; do \
			[ -z "$$line" ] && continue; \
			echo "$$line" | grep -q '^#' && continue; \
			line=$$(echo "$$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$$//'); \
			[ -z "$$line" ] && continue; \
			if ! echo "$$line" | grep -q '^[a-zA-Z0-9_-][a-zA-Z0-9_.-]*/[a-zA-Z0-9_-][a-zA-Z0-9_.-]*$$'; then \
				printf "  $(RED)Invalid plugin format: $$line$(NC)\n"; \
				printf "  $(YELLOW)Expected format: username/repository-name$(NC)\n"; \
				exit 1; \
			fi; \
		done < plugins.txt; \
		printf "  $(GREEN)plugins.txt format is valid$(NC)\n"; \
	fi
	@printf "\n"
	@printf "$(GREEN)All lint checks passed!$(NC)\n"

deploy: deploy-zsh deploy-git deploy-claude deploy-automations finalize ## Deploy all configs (zsh, git, claude, automations)

deploy-zsh: ## Deploy zsh configs (.zshrc, aliases.zsh, custom scripts)
	@printf "$(BLUE)Deploying zsh configuration files...$(NC)\n"
	@if [ ! -f "$(DEPLOYMENT_DIR)/04-deploy-zsh.zsh" ]; then \
		printf "$(RED)src/deployment/04-deploy-zsh.zsh not found$(NC)\n"; \
		exit 1; \
	fi
	@"$(DEPLOYMENT_DIR)/04-deploy-zsh.zsh"

deploy-git: ## Deploy git configs (.gitconfig, company profiles)
	@printf "$(BLUE)Deploying git configuration files...$(NC)\n"
	@if [ ! -f "$(DEPLOYMENT_DIR)/05-deploy-git.zsh" ]; then \
		printf "$(RED)src/deployment/05-deploy-git.zsh not found$(NC)\n"; \
		exit 1; \
	fi
	@"$(DEPLOYMENT_DIR)/05-deploy-git.zsh"

deploy-claude: ## Deploy Claude Code configs (CLAUDE.md, rules, skills, agents)
	@printf "$(BLUE)Deploying Claude Code configuration files...$(NC)\n"
	@if [ ! -f "$(DEPLOYMENT_DIR)/06-deploy-claude.zsh" ]; then \
		printf "$(RED)src/deployment/06-deploy-claude.zsh not found$(NC)\n"; \
		exit 1; \
	fi
	@"$(DEPLOYMENT_DIR)/06-deploy-claude.zsh"

deploy-automations: ## Register launchd jobs for skill-bundled and standalone automations (macOS)
	@printf "$(BLUE)Deploying automations...$(NC)\n"
	@if [ ! -f "$(DEPLOYMENT_DIR)/08-deploy-automations.zsh" ]; then \
		printf "$(RED)src/deployment/08-deploy-automations.zsh not found$(NC)\n"; \
		exit 1; \
	fi
	@"$(DEPLOYMENT_DIR)/08-deploy-automations.zsh"

finalize: ## Final cleanup and shell reload prompt
	@"$(DEPLOYMENT_DIR)/07-finalize.zsh"

setup: ## Initial setup to prepare system for deployments and updates
	@printf "$(BLUE)Full System Setup for Oh-My-Zsh Configuration$(NC)\n"
	@printf "\n"
	@printf "$(BLUE)Preparing fresh system for Oh-My-Zsh configuration management...$(NC)\n"
	@printf "\n"
	@printf "$(BLUE)Phase 0: Setting script permissions...$(NC)\n"
	@for file in $(DEPLOYMENT_DIR)/*.zsh $(STORAGE_DIR)/scripts/*.zsh hooks/pre-commit; do \
		if [ -f "$$file" ]; then \
			printf "  Setting executable permissions for $$file\n"; \
			chmod +x "$$file"; \
		fi; \
	done
	@printf "  Configuring git hooks path...\n"
	@git config core.hooksPath hooks
	@printf "  $(GREEN)Git hooks configured to use hooks/ directory$(NC)\n"
	@printf "\n"
	@printf "$(BLUE)Phase 1: Simple Dependencies$(NC)\n"
	@"$(DEPLOYMENT_DIR)/02-simple-deps.zsh"
	@printf "\n"
	@printf "$(BLUE)Phase 2: Company Setup (directories + SSH keys)$(NC)\n"
	@"$(DEPLOYMENT_DIR)/03-company-setup.zsh"
	@printf "\n"
	@printf "$(BLUE)Phase 3: Zsh Deployment (installs zsh, omz, plugins, deploys configs)$(NC)\n"
	@$(MAKE) deploy-zsh
	@printf "\n"
	@printf "$(BLUE)Phase 4: Git Deployment$(NC)\n"
	@$(MAKE) deploy-git
	@printf "\n"
	@printf "$(BLUE)Phase 5: Claude Code Deployment$(NC)\n"
	@$(MAKE) deploy-claude
	@printf "\n"
	@printf "$(BLUE)Phase 6: Automation Deployment$(NC)\n"
	@$(MAKE) deploy-automations
	@printf "\n"
	@printf "$(BLUE)Phase 7: Finalization$(NC)\n"
	@$(MAKE) finalize
	@printf "\n"
	@printf "$(GREEN)Complete System Setup Finished!$(NC)\n"
	@printf "\n"
	@printf "$(BLUE)Maintenance Commands:$(NC)\n"
	@printf "  - $(YELLOW)make deploy$(NC) - Deploy all config changes\n"
	@printf "  - $(YELLOW)make deploy-zsh$(NC) - Deploy zsh (includes plugins if needed)\n"
	@printf "  - $(YELLOW)make deploy-git$(NC) - Deploy git configs\n"
	@printf "  - $(YELLOW)make deploy-claude$(NC) - Deploy Claude Code configs\n"
	@printf "  - $(YELLOW)make deploy-automations$(NC) - Register launchd jobs for automations\n"
	@printf "  - $(YELLOW)make lint$(NC) - Validate configuration before commits\n"