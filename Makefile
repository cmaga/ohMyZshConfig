# Oh-My-Zsh Configuration Management
# This Makefile provides convenient commands for managing your Zsh configuration

.PHONY: help setup update deploy deploy-cline lint
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

help: ## Show this help message
	@printf "$(BLUE)Oh-My-Zsh Configuration Management$(NC)\n"
	@printf "\n"
	@printf "Available commands:\n"
	@printf "  $(GREEN)lint$(NC)          - Format files and run lint checks\n"
	@printf "  $(GREEN)deploy$(NC)        - Deploy zsh, git, and Cline configs to local system\n"
	@printf "  $(GREEN)deploy-cline$(NC)  - Deploy only Cline configs (rules, workflows, skills)\n"
	@printf "  $(GREEN)update$(NC)        - Check and update custom plugins from plugins.txt\n"
	@printf "  $(GREEN)setup$(NC)         - Complete system setup (fresh system to fully configured)\n"
	@printf "  $(GREEN)help$(NC)          - Show this help message\n"
	@printf "\n"
	@printf "Typical workflow:\n"
	@printf "  $(YELLOW)make setup$(NC)   # Full setup on fresh system (installs zsh, oh-my-zsh, plugins, configs)\n"
	@printf "  $(YELLOW)make deploy$(NC)  # Deploy config changes to existing setup\n"
	@printf "  $(YELLOW)make update$(NC)  # Update plugins when needed\n"
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
	@printf "$(BLUE)🔍 Running lint checks...$(NC)\n"
	@printf "\n"
	@printf "$(BLUE)Checking zsh syntax...$(NC)\n"
	@for file in .zshrc aliases.zsh scripts/*.zsh update-zsh-config.zsh; do \
		if [ -f "$$file" ]; then \
			printf "  Checking $$file...\n"; \
			if zsh -n "$$file"; then \
				printf "  $(GREEN)✅ $$file - OK$(NC)\n"; \
			else \
				printf "  $(RED)❌ $$file - SYNTAX ERROR$(NC)\n"; \
				exit 1; \
			fi; \
		fi; \
	done
	@printf "\n"
	@printf "$(BLUE)Checking file permissions...$(NC)\n"
	@for file in scripts/*.zsh update-zsh-config.zsh hooks/pre-commit; do \
		if [ -f "$$file" ] && [ ! -x "$$file" ]; then \
			printf "  $(YELLOW)⚠️  Making $$file executable$(NC)\n"; \
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
				printf "  $(RED)❌ Invalid plugin format: $$line$(NC)\n"; \
				printf "  $(YELLOW)Expected format: username/repository-name$(NC)\n"; \
				exit 1; \
			fi; \
		done < plugins.txt; \
		printf "  $(GREEN)✅ plugins.txt format is valid$(NC)\n"; \
	fi
	@printf "\n"
	@printf "$(GREEN)🎉 All lint checks passed!$(NC)\n"

deploy: ## Deploy changes/config from this project to the local system
	@printf "$(BLUE)📋 Deploying configuration files to local system...$(NC)\n"
	@if [ ! -f "$(CURRENT_DIR)/update-zsh-config.zsh" ]; then \
		printf "$(RED)❌ update-zsh-config.zsh not found$(NC)\n"; \
		exit 1; \
	fi
	@"$(CURRENT_DIR)/update-zsh-config.zsh"

deploy-cline: ## Deploy only Cline configurations (rules, workflows, hooks, skills)
	@printf "$(BLUE)📋 Deploying Cline configuration files...$(NC)\n"
	@if [ ! -f "$(CURRENT_DIR)/scripts/deploy-cline.zsh" ]; then \
		printf "$(RED)❌ scripts/deploy-cline.zsh not found$(NC)\n"; \
		exit 1; \
	fi
	@"$(CURRENT_DIR)/scripts/deploy-cline.zsh"

update: ## Check and update custom plugins from plugins.txt
	@printf "$(BLUE)🔄 Checking and updating custom plugins...$(NC)\n"
	@if [ ! -f "$(CURRENT_DIR)/plugins.txt" ]; then \
		printf "$(RED)❌ plugins.txt not found$(NC)\n"; \
		exit 1; \
	fi
	@"$(CURRENT_DIR)/scripts/plugin-manager.zsh"

setup: ## Initial setup to prepare system for deployments and updates
	@printf "$(BLUE)🚀 Full System Setup for Oh-My-Zsh Configuration$(NC)\n"
	@printf "\n"
	@printf "$(BLUE)Preparing fresh system for Oh-My-Zsh configuration management...$(NC)\n"
	@printf "\n"
	@printf "$(BLUE)Phase 0: Setting script permissions...$(NC)\n"
	@for file in scripts/*.zsh update-zsh-config.zsh hooks/pre-commit; do \
		if [ -f "$$file" ]; then \
			printf "  Setting executable permissions for $$file\n"; \
			chmod +x "$$file"; \
		fi; \
	done
	@printf "  Configuring git hooks path...\n"
	@git config core.hooksPath hooks
	@printf "  $(GREEN)✅ Git hooks configured to use hooks/ directory$(NC)\n"
	@printf "\n"
	@printf "$(BLUE)Phase 1: System Prerequisites & Environment Setup$(NC)\n"
	@if "$(CURRENT_DIR)/scripts/system-setup.zsh"; then \
		printf "\n"; \
		printf "$(BLUE)Phase 2: Plugin Management$(NC)\n"; \
		printf "$(BLUE)Installing and updating custom plugins...$(NC)\n"; \
		$(MAKE) update; \
		printf "\n"; \
		printf "$(BLUE)Phase 3: Configuration Deployment$(NC)\n"; \
		printf "$(BLUE)Deploying configuration files to system...$(NC)\n"; \
		$(MAKE) deploy; \
		printf "\n"; \
		printf "$(GREEN)🎉 Complete System Setup Finished!$(NC)\n"; \
		printf "\n"; \
		printf "$(BLUE)💡 Maintenance Commands:$(NC)\n"; \
		printf "  - $(YELLOW)make update$(NC) - Update plugins\n"; \
		printf "  - $(YELLOW)make deploy$(NC) - Deploy config changes\n"; \
		printf "  - $(YELLOW)make lint$(NC) - Validate configuration before commits\n"; \
	fi