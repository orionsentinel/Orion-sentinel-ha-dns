# Makefile for Orion Sentinel HA DNS
# Production-ready High Availability DNS with Pi-hole + Unbound
#
# Usage:
#   make up-core          - Start core DNS services (pihole + unbound + keepalived)
#   make up-all           - Start all services including exporters
#   make down             - Stop all services
#   make logs             - Show logs from all services
#   make health-check     - Run comprehensive health check
#   make restart          - Restart all services
#   make clean            - Remove all containers and volumes (DESTRUCTIVE)

.PHONY: help up-core up-exporters up-all down restart logs logs-follow health-check test backup clean validate-env

# Default target
.DEFAULT_GOAL := help

# Load environment variables from .env if it exists
ifneq (,$(wildcard .env))
    include .env
    export
endif

# Colors for output
BOLD := \033[1m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

help: ## Show this help message
	@echo "$(BOLD)Orion Sentinel HA DNS - Makefile Commands$(NC)"
	@echo ""
	@echo "$(GREEN)Core Operations:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Environment:$(NC)"
	@if [ -f .env ]; then \
		echo "  ✓ .env file found"; \
	else \
		echo "  ✗ .env file NOT found - copy .env.example to .env first"; \
	fi

validate-env: ## Validate environment configuration
	@echo "$(BOLD)Validating environment configuration...$(NC)"
	@if [ ! -f .env ]; then \
		echo "$(RED)Error: .env file not found. Copy .env.example to .env first.$(NC)"; \
		exit 1; \
	fi
	@bash scripts/validate-env.sh

up-core: validate-env ## Start core DNS services (pihole + unbound + keepalived)
	@echo "$(BOLD)Starting core DNS services...$(NC)"
	docker compose --profile dns-core up -d
	@echo "$(GREEN)✓ Core services started$(NC)"
	@echo ""
	@echo "Access Pi-hole admin at: http://$(HOST_IP)/admin"
	@echo "DNS server available at: $(VIP_ADDRESS)"

up-exporters: validate-env ## Start monitoring exporters
	@echo "$(BOLD)Starting monitoring exporters...$(NC)"
	docker compose --profile exporters up -d
	@echo "$(GREEN)✓ Exporters started$(NC)"

up-all: validate-env ## Start all services (core + exporters)
	@echo "$(BOLD)Starting all services...$(NC)"
	docker compose --profile dns-core --profile exporters up -d
	@echo "$(GREEN)✓ All services started$(NC)"
	@echo ""
	@echo "Access Pi-hole admin at: http://$(HOST_IP)/admin"
	@echo "DNS server available at: $(VIP_ADDRESS)"

down: ## Stop all services
	@echo "$(BOLD)Stopping all services...$(NC)"
	docker compose --profile dns-core --profile exporters down
	@echo "$(GREEN)✓ All services stopped$(NC)"

restart: down up-core ## Restart all services

logs: ## Show logs from all running services
	docker compose logs --tail=100

logs-follow: ## Follow logs from all running services
	docker compose logs -f

health-check: ## Run comprehensive health check
	@echo "$(BOLD)Running health checks...$(NC)"
	@if [ -f scripts/dns-health.sh ]; then \
		bash scripts/dns-health.sh; \
	else \
		bash scripts/health-check.sh; \
	fi

test: health-check ## Run health check (alias)

health: health-check ## Run health check (standardized alias)

ps: ## Show running containers
	@docker compose ps

stats: ## Show container resource usage
	@docker stats --no-stream

backup: ## Create backup of configuration
	@echo "$(BOLD)Creating backup...$(NC)"
	@bash scripts/backup-config.sh
	@echo "$(GREEN)✓ Backup complete$(NC)"

restore: ## Restore from latest backup
	@echo "$(BOLD)Restoring from backup...$(NC)"
	@bash scripts/restore-config.sh
	@echo "$(GREEN)✓ Restore complete$(NC)"

clean: ## Remove all containers and volumes (DESTRUCTIVE - asks for confirmation)
	@echo "$(RED)$(BOLD)WARNING: This will remove all containers, volumes, and data!$(NC)"
	@read -p "Are you sure? Type 'yes' to continue: " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		docker compose --profile dns-core --profile exporters down -v; \
		echo "$(GREEN)✓ Cleaned up$(NC)"; \
	else \
		echo "Cancelled."; \
	fi

pull: ## Pull latest container images
	@echo "$(BOLD)Pulling latest images...$(NC)"
	docker compose pull
	@echo "$(GREEN)✓ Images updated$(NC)"

update: pull restart ## Update and restart services

# Development targets
dev-logs: ## Show detailed logs with timestamps
	docker compose logs -f --timestamps

dev-shell-pihole: ## Open shell in pihole container
	docker compose exec pihole_primary bash

dev-shell-unbound: ## Open shell in unbound container
	docker compose exec unbound_primary sh

# Information targets
info: ## Show deployment information
	@echo "$(BOLD)Deployment Information:$(NC)"
	@echo "  Mode: $${DEPLOYMENT_MODE:-single-pi-ha}"
	@echo "  Host IP: $(HOST_IP)"
	@echo "  VIP Address: $(VIP_ADDRESS)"
	@echo "  Network Interface: $(NETWORK_INTERFACE)"
	@echo "  Keepalived Priority: $(KEEPALIVED_PRIORITY)"

version: ## Show versions of components
	@echo "$(BOLD)Component Versions:$(NC)"
	@echo -n "  Docker: "
	@docker version --format '{{.Server.Version}}'
	@echo -n "  Docker Compose: "
	@docker compose version --short
	@echo -n "  Pi-hole: "
	@docker compose exec pihole_primary pihole -v 2>/dev/null | head -n1 || echo "not running"
