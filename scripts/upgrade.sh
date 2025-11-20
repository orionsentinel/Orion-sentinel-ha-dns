#!/bin/bash
# Simple Upgrade Script for Orion Sentinel DNS HA
# Performs backup, git pull, and Docker updates
#
# This script provides a straightforward upgrade process:
# 1. Backs up current configuration
# 2. Pulls latest changes from git
# 3. Updates Docker images
# 4. Restarts the DNS stack
#
# Usage: bash scripts/upgrade.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DNS_STACK_DIR="$REPO_ROOT/stacks/dns"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[upgrade]${NC} $*"; }
warn() { echo -e "${YELLOW}[upgrade][WARNING]${NC} $*"; }
error() { echo -e "${RED}[upgrade][ERROR]${NC} $*" >&2; }
info() { echo -e "${BLUE}[upgrade][INFO]${NC} $*"; }

# Error handler
trap 'error "Upgrade failed at line $LINENO. Check errors above."' ERR

echo ""
echo "================================================================"
log "Orion Sentinel DNS HA - Upgrade Script"
echo "================================================================"
echo ""

# Step 1: Create backup before upgrade
log "Step 1/4: Creating configuration backup..."
echo ""
if [ -f "$SCRIPT_DIR/backup-config.sh" ]; then
    bash "$SCRIPT_DIR/backup-config.sh"
    echo ""
    log "✅ Backup completed successfully"
else
    error "Backup script not found at $SCRIPT_DIR/backup-config.sh"
    exit 1
fi

echo ""
# Step 2: Pull latest changes from git
log "Step 2/4: Pulling latest changes from git..."
echo ""
cd "$REPO_ROOT"

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    error "Not a git repository. Cannot pull updates."
    exit 1
fi

# Check for uncommitted changes
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    warn "You have uncommitted changes in the repository"
    warn "These changes will be preserved, but may cause conflicts"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Upgrade cancelled"
        exit 0
    fi
fi

# Pull latest changes
log "Pulling from remote repository..."
if git pull; then
    log "✅ Git pull completed successfully"
else
    error "Git pull failed. Resolve conflicts and try again."
    exit 1
fi

echo ""
# Step 3: Pull latest Docker images
log "Step 3/4: Pulling latest Docker images..."
echo ""

# Change to DNS stack directory
cd "$DNS_STACK_DIR"

if [ ! -f "docker-compose.yml" ]; then
    error "docker-compose.yml not found in $DNS_STACK_DIR"
    exit 1
fi

log "Pulling latest images for DNS stack..."
if docker compose pull; then
    log "✅ Docker images updated successfully"
else
    error "Failed to pull Docker images"
    exit 1
fi

echo ""
# Step 4: Restart DNS stack with new images
log "Step 4/4: Restarting DNS stack with updated images..."
echo ""

log "Bringing stack down..."
docker compose down

log "Starting stack with new images..."
if docker compose up -d; then
    log "✅ DNS stack restarted successfully"
else
    error "Failed to start DNS stack"
    error "To rollback, restore from the backup created earlier"
    exit 1
fi

# Wait a moment for containers to start
sleep 5

# Check container health
echo ""
log "Checking container health..."
if docker compose ps; then
    echo ""
    log "✅ Container status displayed above"
else
    warn "Could not check container status"
fi

echo ""
echo "================================================================"
log "Upgrade completed successfully! 🎉"
echo "================================================================"
echo ""
log "Summary:"
log "  ✅ Configuration backed up"
log "  ✅ Git repository updated"
log "  ✅ Docker images updated"
log "  ✅ DNS stack restarted"
echo ""
log "Next steps:"
log "  1. Verify services are running: docker ps"
log "  2. Test DNS resolution: dig @192.168.8.255 google.com"
log "  3. Check Pi-hole admin panel: http://192.168.8.251/admin"
log "  4. Monitor logs: docker compose logs -f"
echo ""
log "If you encounter issues, restore from backup:"
log "  bash scripts/restore-config.sh backups/dns-ha-backup-*.tar.gz"
echo ""
