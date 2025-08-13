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
	@echo "  $(GREEN)setup$(NC)    - Initial setup to prepare system for deployments and updates"
	@echo "  $(GREEN)help$(NC)     - Show this help message"
	@echo ""
	@echo "Typical workflow:"
	@echo "  $(YELLOW)make setup$(NC)   # First time setup"
	@echo "  $(YELLOW)make deploy$(NC)  # Deploy your configs"
	@echo "  $(YELLOW)make update$(NC)  # Update plugins when needed"
	@echo "  $(YELLOW)make lint$(NC)    # Check code quality before commits"

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
			if ! echo "$$line" | grep -q '^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$$'; then \
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
	@chmod +x "$(CURRENT_DIR)/update-zsh-config.zsh"
	@echo "y" | "$(CURRENT_DIR)/update-zsh-config.zsh" || true

update: ## Check and update custom plugins from plugins.txt
	@echo "$(BLUE)🔄 Checking and updating custom plugins...$(NC)"
	@if [ ! -f "$(CURRENT_DIR)/plugins.txt" ]; then \
		echo "$(RED)❌ plugins.txt not found$(NC)"; \
		exit 1; \
	fi
	@chmod +x "$(CURRENT_DIR)/scripts/plugin-manager.zsh"
	@"$(CURRENT_DIR)/scripts/plugin-manager.zsh"

setup: ## Initial setup to prepare system for deployments and updates
	@echo "$(BLUE)🚀 Setting up Oh-My-Zsh configuration management...$(NC)"
	@echo ""
	@echo "$(BLUE)Step 1: Checking Oh-My-Zsh installation...$(NC)"
	@if [ ! -d "$(ZSH_DIR)" ]; then \
		echo "$(RED)❌ Oh-My-Zsh not found at $(ZSH_DIR)$(NC)"; \
		echo "$(BLUE)Please install Oh-My-Zsh first:$(NC)"; \
		echo "$(YELLOW)sh -c \\\"$$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\\\"$(NC)"; \
		exit 1; \
	else \
		echo "  $(GREEN)✅ Oh-My-Zsh found at $(ZSH_DIR)$(NC)"; \
	fi
	@echo ""
	@echo "$(BLUE)Step 2: Setting up plugin directory...$(NC)"
	@mkdir -p "$(PLUGINS_DIR)"
	@echo "  $(GREEN)✅ Plugin directory ready at $(PLUGINS_DIR)$(NC)"
	@echo ""
	@echo "$(BLUE)Step 3: Making scripts executable...$(NC)"
	@chmod +x scripts/*.zsh update-zsh-config.zsh hooks/pre-commit 2>/dev/null || true
	@echo "  $(GREEN)✅ Scripts are executable$(NC)"
	@echo ""
	@echo "$(BLUE)Step 4: Running initial plugin installation...$(NC)"
	@$(MAKE) update
	@echo ""
	@echo "$(BLUE)Step 5: Deploying configuration files...$(NC)"
	@$(MAKE) deploy
	@echo ""
	@echo "$(GREEN)🎉 Setup complete!$(NC)"
	@echo "$(YELLOW)💡 Run 'source ~/.zshrc' or restart your terminal to apply changes$(NC)"
	@echo ""
	@echo "$(BLUE)Next steps:$(NC)"
	@echo "  - Run '$(YELLOW)make update$(NC)' to update plugins"
	@echo "  - Run '$(YELLOW)make deploy$(NC)' to deploy config changes"
	@echo "  - Run '$(YELLOW)make lint$(NC)' before committing changes"
