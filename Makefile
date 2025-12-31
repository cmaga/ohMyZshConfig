# Oh-My-Zsh Configuration Management
# This Makefile provides convenient commands for managing your Zsh configuration

.PHONY: help setup update deploy lint
.DEFAULT_GOAL := help

# Color codes for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

# Configuration
ZSH_DIR := $(HOME)/.oh-my-zsh
PLUGINS_DIR := $(ZSH_DIR)/custom/plugins
CURRENT_DIR := $(shell pwd)

help: ## Show this help message
	@echo "$(BLUE)Oh-My-Zsh Configuration Management$(NC)"
	@echo ""
	@echo "Available commands:"
	@echo "  $(GREEN)lint$(NC)     - Format files and run lint checks"
	@echo "  $(GREEN)deploy$(NC)   - Deploy changes/config from this project to the local system"
	@echo "  $(GREEN)update$(NC)   - Check and update custom plugins from plugins.txt"
	@echo "  $(GREEN)setup$(NC)    - Complete system setup (fresh system to fully configured)"
	@echo "  $(GREEN)help$(NC)     - Show this help message"
	@echo ""
	@echo "Typical workflow:"
	@echo "  $(YELLOW)make setup$(NC)   # Full setup on fresh system (installs zsh, oh-my-zsh, plugins, configs)"
	@echo "  $(YELLOW)make deploy$(NC)  # Deploy config changes to existing setup"
	@echo "  $(YELLOW)make update$(NC)  # Update plugins when needed"
	@echo "  $(YELLOW)make lint$(NC)    # Validate configuration before commits"
	@echo ""
	@echo "$(BLUE)Fresh System Setup:$(NC)"
	@echo "  The $(YELLOW)setup$(NC) command handles everything needed on a fresh system:"
	@echo "  • Installs prerequisites (git, curl, zsh)"
	@echo "  • Sets zsh as default shell"
	@echo "  • Installs Oh-My-Zsh framework"
	@echo "  • Installs custom plugins"
	@echo "  • Deploys all configuration files"

lint: ## Format files and run lint checks
	@echo "$(BLUE)� Running lint checks...$(NC)"
	@echo ""
	@echo "$(BLUE)Checking zsh syntax...$(NC)"
	@for file in .zshrc aliases.zsh scripts/*.zsh update-zsh-config.zsh; do \
		if [ -f "$$file" ]; then \
			echo "  Checking $$file..."; \
			if zsh -n "$$file"; then \
				echo "  $(GREEN)✅ $$file - OK$(NC)"; \
			else \
				echo "  $(RED)❌ $$file - SYNTAX ERROR$(NC)"; \
				exit 1; \
			fi; \
		fi; \
	done
	@echo ""
	@echo "$(BLUE)Checking file permissions...$(NC)"
	@for file in scripts/*.zsh update-zsh-config.zsh hooks/pre-commit; do \
		if [ -f "$$file" ] && [ ! -x "$$file" ]; then \
			echo "  $(YELLOW)⚠️  Making $$file executable$(NC)"; \
			chmod +x "$$file"; \
		fi; \
	done
	@echo ""
	@echo "$(BLUE)Validating plugins.txt format...$(NC)"
	@if [ -f "plugins.txt" ]; then \
		while IFS= read -r line || [ -n "$$line" ]; do \
			[ -z "$$line" ] && continue; \
			echo "$$line" | grep -q '^#' && continue; \
			line=$$(echo "$$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$$//'); \
			[ -z "$$line" ] && continue; \
			if ! echo "$$line" | grep -q '^[a-zA-Z0-9_-][a-zA-Z0-9_.-]*/[a-zA-Z0-9_-][a-zA-Z0-9_.-]*$$'; then \
				echo "  $(RED)❌ Invalid plugin format: $$line$(NC)"; \
				echo "  $(YELLOW)Expected format: username/repository-name$(NC)"; \
				exit 1; \
			fi; \
		done < plugins.txt; \
		echo "  $(GREEN)✅ plugins.txt format is valid$(NC)"; \
	fi
	@echo ""
	@echo "$(GREEN)🎉 All lint checks passed!$(NC)"

deploy: ## Deploy changes/config from this project to the local system
	@echo "$(BLUE)📋 Deploying configuration files to local system...$(NC)"
	@if [ ! -f "$(CURRENT_DIR)/update-zsh-config.zsh" ]; then \
		echo "$(RED)❌ update-zsh-config.zsh not found$(NC)"; \
		exit 1; \
	fi
	@"$(CURRENT_DIR)/update-zsh-config.zsh"

update: ## Check and update custom plugins from plugins.txt
	@echo "$(BLUE)🔄 Checking and updating custom plugins...$(NC)"
	@if [ ! -f "$(CURRENT_DIR)/plugins.txt" ]; then \
		echo "$(RED)❌ plugins.txt not found$(NC)"; \
		exit 1; \
	fi
	@"$(CURRENT_DIR)/scripts/plugin-manager.zsh"

setup: ## Initial setup to prepare system for deployments and updates
	@echo "$(BLUE)🚀 Full System Setup for Oh-My-Zsh Configuration$(NC)"
	@echo ""
	@echo "$(BLUE)Preparing fresh system for Oh-My-Zsh configuration management...$(NC)"
	@echo ""
	@echo "$(BLUE)Phase 0: Setting script permissions...$(NC)"
	@for file in scripts/*.zsh update-zsh-config.zsh hooks/pre-commit; do \
		if [ -f "$$file" ]; then \
			echo "  Setting executable permissions for $$file"; \
			chmod +x "$$file"; \
		fi; \
	done
	@echo ""
	@echo "$(BLUE)Phase 1: System Prerequisites & Environment Setup$(NC)"
	@if "$(CURRENT_DIR)/scripts/system-setup.zsh"; then \
		echo ""; \
		echo "$(BLUE)Phase 2: Plugin Management$(NC)"; \
		echo "$(BLUE)Installing and updating custom plugins...$(NC)"; \
		$(MAKE) update; \
		echo ""; \
		echo "$(BLUE)Phase 3: Configuration Deployment$(NC)"; \
		echo "$(BLUE)Deploying configuration files to system...$(NC)"; \
		$(MAKE) deploy; \
		echo ""; \
		echo "$(GREEN)🎉 Complete System Setup Finished!$(NC)"; \
		echo ""; \
		echo "$(BLUE)💡 Maintenance Commands:$(NC)"; \
		echo "  - $(YELLOW)make update$(NC) - Update plugins"; \
		echo "  - $(YELLOW)make deploy$(NC) - Deploy config changes"; \
		echo "  - $(YELLOW)make lint$(NC) - Validate configuration before commits"; \
	fi
