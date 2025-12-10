# =============================================================================
# Orion Sentinel HA DNS - Makefile
# =============================================================================
# Production-ready High Availability DNS with Pi-hole + Unbound
#
# Quick Start:
#   make single        - Deploy single node (no HA)
#   make primary       - Deploy as PRIMARY node in HA pair
#   make secondary     - Deploy as SECONDARY node in HA pair
#   make down          - Stop all services
#   make logs          - Show logs
#   make test          - Test DNS resolution
# =============================================================================

.PHONY: help single primary secondary primary-full secondary-full down restart logs test status clean
.PHONY: sync backup backup-list health install-systemd-primary install-systemd-backup _check-install-script

.DEFAULT_GOAL := help

# Colors
GREEN  := \033[0;32m
YELLOW := \033[1;33m
RED    := \033[0;31m
NC     := \033[0m

help: ## Show this help
	@echo "$(GREEN)Orion Sentinel HA DNS$(NC)"
	@echo ""
	@echo "$(YELLOW)Deployment:$(NC)"
	@echo "  make single          Deploy single node (no HA)"
	@echo "  make primary         Deploy as PRIMARY node (with keepalived)"
	@echo "  make secondary       Deploy as SECONDARY node (with keepalived)"
	@echo "  make primary-full    Deploy PRIMARY + monitoring exporters"
	@echo "  make secondary-full  Deploy SECONDARY + monitoring exporters"
	@echo ""
	@echo "$(YELLOW)Operations:$(NC)"
	@echo "  make down            Stop all services"
	@echo "  make restart         Restart all services"
	@echo "  make logs            Show container logs"
	@echo "  make status          Show container status"
	@echo "  make test            Test DNS resolution"
	@echo "  make health          Run health check"
	@echo "  make clean           Remove containers and volumes (DESTRUCTIVE)"
	@echo ""
	@echo "$(YELLOW)Sync & Backup:$(NC)"
	@echo "  make sync            Sync Pi-hole config to secondary (run on primary)"
	@echo "  make backup          Create backup of Pi-hole configuration"
	@echo "  make backup-list     List available backups"
	@echo ""
	@echo "$(YELLOW)Installation:$(NC)"
	@echo "  make install-systemd-primary   Install systemd services (primary node)"
	@echo "  make install-systemd-backup    Install systemd services (backup node)"
	@echo ""
	@echo "$(YELLOW)Configuration:$(NC)"
	@echo "  1. Copy .env.example to .env (or use .env.primary.example/.env.secondary.example)"
	@echo "  2. Edit .env with your passwords and network settings"
	@echo "  3. Run the appropriate make target"

# =============================================================================
# Deployment Targets
# =============================================================================

single: _check-env ## Deploy single node (Pi-hole+Unbound, no HA)
	@echo "$(GREEN)Deploying single node...$(NC)"
	docker compose --profile single-node up -d
	@echo ""
	@echo "$(GREEN)✓ Deployed!$(NC)"
	@echo "  Pi-hole admin: http://localhost/admin"
	@echo "  DNS server:    127.0.0.1:53"

primary: _check-env ## Deploy as PRIMARY (MASTER) node with keepalived
	@echo "$(GREEN)Deploying PRIMARY node...$(NC)"
	docker compose --profile two-node-ha-primary up -d --build
	@echo ""
	@echo "$(GREEN)✓ PRIMARY node deployed!$(NC)"
	@$(MAKE) _show-vip

secondary: _check-env ## Deploy as SECONDARY (BACKUP) node with keepalived
	@echo "$(GREEN)Deploying SECONDARY node...$(NC)"
	docker compose --profile two-node-ha-backup up -d --build
	@echo ""
	@echo "$(GREEN)✓ SECONDARY node deployed!$(NC)"
	@$(MAKE) _show-vip

primary-full: _check-env ## Deploy PRIMARY + monitoring exporters
	@echo "$(GREEN)Deploying PRIMARY node with exporters...$(NC)"
	docker compose --profile two-node-ha-primary --profile exporters up -d --build
	@echo ""
	@echo "$(GREEN)✓ PRIMARY node deployed with monitoring!$(NC)"
	@$(MAKE) _show-vip
	@echo "  Node metrics:  http://localhost:9100/metrics"
	@echo "  Pi-hole metrics: http://localhost:9617/metrics"

secondary-full: _check-env ## Deploy SECONDARY + monitoring exporters
	@echo "$(GREEN)Deploying SECONDARY node with exporters...$(NC)"
	docker compose --profile two-node-ha-backup --profile exporters up -d --build
	@echo ""
	@echo "$(GREEN)✓ SECONDARY node deployed with monitoring!$(NC)"
	@$(MAKE) _show-vip
	@echo "  Node metrics:  http://localhost:9100/metrics"
	@echo "  Pi-hole metrics: http://localhost:9617/metrics"

# =============================================================================
# Operation Targets
# =============================================================================

down: ## Stop all services
	@echo "$(YELLOW)Stopping services...$(NC)"
	docker compose --profile single-node --profile two-node-ha-primary --profile two-node-ha-backup --profile exporters down
	@echo "$(GREEN)✓ Stopped$(NC)"

restart: down primary ## Restart services (assumes primary, change as needed)

logs: ## Show container logs
	docker compose logs -f --tail=100

status: ## Show container status
	@echo "$(GREEN)Container Status:$(NC)"
	@docker compose ps
	@echo ""
	@echo "$(GREEN)VIP Status:$(NC)"
	@ip addr show | grep -E "192\.168\.8\.250|$(VIP_ADDRESS)" || echo "  VIP not assigned to this node"

test: ## Test DNS resolution via VIP
	@echo "$(GREEN)Testing DNS resolution...$(NC)"
	@echo ""
	@echo "Testing localhost (127.0.0.1):"
	@dig @127.0.0.1 google.com +short +time=2 || echo "$(RED)FAILED$(NC)"
	@echo ""
	@if [ -n "$(VIP_ADDRESS)" ]; then \
		echo "Testing VIP ($(VIP_ADDRESS)):"; \
		dig @$(VIP_ADDRESS) google.com +short +time=2 || echo "$(RED)FAILED$(NC)"; \
	fi
	@echo ""
	@echo "$(GREEN)✓ DNS test complete$(NC)"

clean: ## Remove containers and volumes (DESTRUCTIVE)
	@echo "$(RED)WARNING: This will delete all data!$(NC)"
	@read -p "Type 'yes' to confirm: " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		docker compose --profile single-node --profile two-node-ha-primary --profile two-node-ha-backup --profile exporters down -v; \
		echo "$(GREEN)✓ Cleaned$(NC)"; \
	else \
		echo "Cancelled."; \
	fi

# =============================================================================
# Sync & Backup Targets
# =============================================================================

sync: ## Sync Pi-hole config from primary to secondary
	@echo "$(GREEN)Syncing Pi-hole configuration to secondary...$(NC)"
	@./ops/pihole-sync.sh

backup: ## Create backup of Pi-hole configuration
	@echo "$(GREEN)Creating backup...$(NC)"
	@./ops/orion-dns-backup.sh

backup-list: ## List available backups
	@./ops/orion-dns-backup.sh --list

health: ## Run health check
	@./ops/orion-dns-health.sh --verbose

# =============================================================================
# Systemd Installation Targets
# =============================================================================

install-systemd-primary: _check-install-script ## Install systemd services for primary node
	@echo "$(GREEN)Installing systemd services for primary node...$(NC)"
	@sudo ./ops/install-systemd.sh primary

install-systemd-backup: _check-install-script ## Install systemd services for backup node
	@echo "$(GREEN)Installing systemd services for backup node...$(NC)"
	@sudo ./ops/install-systemd.sh backup

_check-install-script:
	@if [ ! -f ./ops/install-systemd.sh ]; then \
		echo "$(RED)Error: ./ops/install-systemd.sh not found.$(NC)"; \
		exit 1; \
	fi

# =============================================================================
# Internal Targets
# =============================================================================

_check-env:
	@if [ ! -f .env ]; then \
		echo "$(RED)Error: .env file not found$(NC)"; \
		echo "Copy .env.example to .env and configure it first"; \
		exit 1; \
	fi

_show-vip:
	@if [ -n "$(VIP_ADDRESS)" ]; then \
		echo "  VIP address:   $(VIP_ADDRESS)"; \
		echo "  Pi-hole admin: http://$(VIP_ADDRESS)/admin"; \
		echo "  DNS server:    $(VIP_ADDRESS):53"; \
	fi

# Load .env if it exists
ifneq (,$(wildcard .env))
    include .env
    export
endif
