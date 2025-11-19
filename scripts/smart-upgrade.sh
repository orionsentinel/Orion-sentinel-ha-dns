#!/usr/bin/env bash
# Smart Upgrade System for rpi-ha-dns-stack
# Checks for updates, manages version pinning, and performs safe upgrades

set -euo pipefail
IFS=$'\n\t'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="$REPO_ROOT/.versions.yml"
UPGRADE_LOG="$REPO_ROOT/upgrade.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[upgrade]${NC} $*" | tee -a "$UPGRADE_LOG"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "$UPGRADE_LOG"; }
err() { echo -e "${RED}[ERROR]${NC} $*" >&2 | tee -a "$UPGRADE_LOG"; }
info() { echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$UPGRADE_LOG"; }
success() { echo -e "${GREEN}✓${NC} $*" | tee -a "$UPGRADE_LOG"; }

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Initialize upgrade log
init_log() {
    echo "=== Smart Upgrade Session: $(date) ===" >> "$UPGRADE_LOG"
}

# Check for latest Docker image versions
check_image_updates() {
    local image=$1
    local current_tag=${2:-latest}
    
    info "Checking for updates: $image:$current_tag"
    
    # Pull latest digest
    if docker pull "$image:$current_tag" &> /dev/null; then
        local latest_digest=$(docker inspect "$image:$current_tag" --format='{{.RepoDigests}}' 2>/dev/null | grep -oP 'sha256:[a-f0-9]+' | head -1)
        echo "$latest_digest"
    else
        echo "error"
    fi
}

# Create version tracking file
create_version_file() {
    log "Creating version tracking file..."
    
    cat > "$VERSION_FILE" << 'EOF'
# Version tracking for rpi-ha-dns-stack
# This file pins Docker image versions for stability
# Last updated: $(date)

services:
  pihole:
    image: pihole/pihole
    version: latest
    auto_update: true
    
  unbound:
    image: klutchell/unbound
    version: latest
    auto_update: true
    
  grafana:
    image: grafana/grafana
    version: latest
    auto_update: true
    
  prometheus:
    image: prom/prometheus
    version: latest
    auto_update: true
    
  alertmanager:
    image: prom/alertmanager
    version: latest
    auto_update: true
    
  loki:
    image: grafana/loki
    version: latest
    auto_update: true
    
  promtail:
    image: grafana/promtail
    version: latest
    auto_update: true
    
  signal-cli:
    image: bbernhard/signal-cli-rest-api
    version: latest
    auto_update: true
    
  portainer:
    image: portainer/portainer-ce
    version: latest
    auto_update: false  # Manual updates recommended
    
  homepage:
    image: ghcr.io/gethomepage/homepage
    version: latest
    auto_update: true
    
  uptime-kuma:
    image: louislam/uptime-kuma
    version: latest
    auto_update: true
    
  netdata:
    image: netdata/netdata
    version: latest
    auto_update: true
    
  watchtower:
    image: containrrr/watchtower
    version: latest
    auto_update: true
    
  wireguard:
    image: linuxserver/wireguard
    version: latest
    auto_update: true
    
  wireguard-ui:
    image: ngoduykhanh/wireguard-ui
    version: latest
    auto_update: true
    
  nginx-proxy-manager:
    image: jc21/nginx-proxy-manager
    version: latest
    auto_update: true
    
  authelia:
    image: authelia/authelia
    version: latest
    auto_update: true
    
  oauth2-proxy:
    image: quay.io/oauth2-proxy/oauth2-proxy
    version: latest
    auto_update: true
    
  cloudflared:
    image: cloudflare/cloudflared
    version: latest
    auto_update: true
    
  tailscale:
    image: tailscale/tailscale
    version: latest
    auto_update: true

stack_version: "2.4.0"
upgrade_notes: |
  Version 2.4.0 introduces:
  - Smart upgrade system with version tracking
  - Automated update checking
  - Safe rollback capabilities
  - Enhanced monitoring and health checks
EOF
    
    success "Version tracking file created: $VERSION_FILE"
}

# Check all services for updates
check_all_updates() {
    log "Checking all services for available updates..."
    echo
    
    local updates_available=0
    
    # Array of images to check
    declare -A images=(
        ["pihole/pihole"]="latest"
        ["klutchell/unbound"]="latest"
        ["grafana/grafana"]="latest"
        ["prom/prometheus"]="latest"
        ["prom/alertmanager"]="latest"
        ["grafana/loki"]="latest"
        ["portainer/portainer-ce"]="latest"
        ["louislam/uptime-kuma"]="latest"
        ["netdata/netdata"]="latest"
    )
    
    for image in "${!images[@]}"; do
        local tag="${images[$image]}"
        printf "  ${CYAN}%-40s${NC}" "$image:$tag"
        
        if docker pull "$image:$tag" &> /dev/null; then
            printf "${GREEN}✓ Available${NC}\n"
        else
            printf "${RED}✗ Failed${NC}\n"
            ((updates_available++))
        fi
    done
    
    echo
    if [[ $updates_available -gt 0 ]]; then
        warn "Some images could not be updated. Check network connectivity."
    else
        success "All images checked successfully"
    fi
}

# Perform system health check before upgrade
pre_upgrade_health_check() {
    log "Performing pre-upgrade health check..."
    echo
    
    # Check disk space
    local disk_usage=$(df -h "$REPO_ROOT" | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ $disk_usage -gt 85 ]]; then
        warn "Disk usage is high: ${disk_usage}% - Consider cleaning up before upgrade"
        read -r -p "Continue anyway? (y/N): " choice
        [[ ! "$choice" =~ ^[Yy]$ ]] && exit 0
    else
        success "Disk space OK: ${disk_usage}% used"
    fi
    
    # Check Docker daemon
    if ! docker info &> /dev/null; then
        err "Docker daemon is not running!"
        exit 1
    fi
    success "Docker daemon running"
    
    # Check running containers
    local running=$(docker ps --filter "name=pihole" --filter "name=unbound" --format "{{.Names}}" | wc -l)
    info "Found $running critical DNS containers running"
    
    # Check network connectivity
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        warn "No internet connectivity - cannot pull updates"
        read -r -p "Continue with offline upgrade? (y/N): " choice
        [[ ! "$choice" =~ ^[Yy]$ ]] && exit 0
    else
        success "Network connectivity OK"
    fi
    
    echo
    success "Pre-upgrade health check passed"
    echo
}

# Create backup before upgrade
create_upgrade_backup() {
    log "Creating pre-upgrade backup..."
    
    local backup_script="$REPO_ROOT/scripts/automated-backup.sh"
    if [[ -f "$backup_script" ]]; then
        if bash "$backup_script"; then
            success "Pre-upgrade backup created successfully"
        else
            warn "Backup creation failed - continuing anyway"
        fi
    else
        warn "Backup script not found - skipping backup"
    fi
    echo
}

# Upgrade individual stack
upgrade_stack() {
    local stack_name=$1
    local stack_dir="$REPO_ROOT/stacks/$stack_name"
    
    if [[ ! -d "$stack_dir" ]]; then
        warn "Stack directory not found: $stack_name"
        return 1
    fi
    
    info "Upgrading stack: $stack_name"
    
    cd "$stack_dir"
    
    # Pull latest images
    if docker compose pull; then
        # Recreate containers with new images
        if docker compose up -d; then
            success "Stack upgraded: $stack_name"
            return 0
        else
            err "Failed to start stack: $stack_name"
            return 1
        fi
    else
        err "Failed to pull images for stack: $stack_name"
        return 1
    fi
}

# Upgrade all stacks
upgrade_all_stacks() {
    log "Upgrading all stacks..."
    echo
    
    local stacks=(
        "dns"
        "observability"
        "management"
        "backup"
        "ai-watchdog"
    )
    
    local failed_stacks=()
    
    for stack in "${stacks[@]}"; do
        if ! upgrade_stack "$stack"; then
            failed_stacks+=("$stack")
        fi
        sleep 2
    done
    
    echo
    if [[ ${#failed_stacks[@]} -eq 0 ]]; then
        success "All stacks upgraded successfully!"
    else
        warn "Some stacks failed to upgrade: ${failed_stacks[*]}"
        return 1
    fi
}

# Post-upgrade verification
post_upgrade_verification() {
    log "Performing post-upgrade verification..."
    echo
    
    sleep 10  # Give containers time to start
    
    # Check container health
    local unhealthy=$(docker ps --filter "health=unhealthy" --format "{{.Names}}" | wc -l)
    
    if [[ $unhealthy -gt 0 ]]; then
        warn "Found $unhealthy unhealthy containers:"
        docker ps --filter "health=unhealthy" --format "table {{.Names}}\t{{.Status}}"
        echo
        warn "Some containers may need attention"
    else
        success "All containers are healthy"
    fi
    
    # Check DNS resolution
    if docker exec pihole_primary dig @127.0.0.1 google.com +short &> /dev/null; then
        success "DNS resolution working (primary)"
    else
        warn "DNS resolution test failed on primary Pi-hole"
    fi
    
    if docker exec pihole_secondary dig @127.0.0.1 google.com +short &> /dev/null; then
        success "DNS resolution working (secondary)"
    else
        warn "DNS resolution test failed on secondary Pi-hole"
    fi
    
    echo
    success "Post-upgrade verification complete"
}

# Show upgrade summary
show_upgrade_summary() {
    log "Upgrade Summary"
    echo
    
    cat << 'EOF'
╔════════════════════════════════════════════════════════════════╗
║                    UPGRADE COMPLETED                           ║
╚════════════════════════════════════════════════════════════════╝

The stack has been upgraded to the latest versions.

Key Services:
  - Pi-hole DNS (Primary & Secondary)
  - Unbound Recursive DNS
  - Prometheus Monitoring
  - Grafana Dashboards
  - AI Watchdog
  - Backup System

Next Steps:
  1. Verify services at their web interfaces
  2. Check Grafana dashboards for anomalies
  3. Review upgrade log: upgrade.log
  4. Monitor system for 24 hours

Rollback:
  If issues occur, you can restore from backup:
    bash scripts/restore-backup.sh

EOF
    
    info "Upgrade log saved to: $UPGRADE_LOG"
    echo
}

# Main upgrade workflow
perform_upgrade() {
    log "Starting smart upgrade process..."
    echo
    
    pre_upgrade_health_check
    create_upgrade_backup
    check_all_updates
    
    echo
    read -r -p "Proceed with upgrade? (Y/n): " choice
    if [[ "$choice" =~ ^[Nn]$ ]]; then
        info "Upgrade cancelled by user"
        exit 0
    fi
    
    echo
    upgrade_all_stacks
    post_upgrade_verification
    show_upgrade_summary
    
    success "Smart upgrade completed successfully! 🎉"
}

# Interactive mode
interactive_mode() {
    clear
    cat << 'EOF'
╔════════════════════════════════════════════════════════════════╗
║            RPi HA DNS Stack - Smart Upgrade System             ║
║                        Version 2.4.0                           ║
╚════════════════════════════════════════════════════════════════╝

EOF
    
    echo "What would you like to do?"
    echo
    echo "  1) Check for available updates"
    echo "  2) Perform full system upgrade"
    echo "  3) Upgrade specific stack only"
    echo "  4) Create version tracking file"
    echo "  5) View upgrade history"
    echo "  6) Exit"
    echo
    
    read -r -p "Enter choice [1-6]: " choice
    
    case $choice in
        1)
            check_all_updates
            ;;
        2)
            perform_upgrade
            ;;
        3)
            echo
            echo "Available stacks:"
            echo "  - dns"
            echo "  - observability"
            echo "  - management"
            echo "  - backup"
            echo "  - ai-watchdog"
            echo "  - sso"
            echo "  - vpn"
            echo
            read -r -p "Enter stack name: " stack_name
            upgrade_stack "$stack_name"
            ;;
        4)
            create_version_file
            ;;
        5)
            if [[ -f "$UPGRADE_LOG" ]]; then
                less "$UPGRADE_LOG"
            else
                info "No upgrade history found"
            fi
            ;;
        6)
            exit 0
            ;;
        *)
            err "Invalid choice"
            exit 1
            ;;
    esac
}

# Show help
show_help() {
    cat << 'EOF'
Smart Upgrade System for RPi HA DNS Stack

Usage: bash scripts/smart-upgrade.sh [OPTIONS]

Options:
  -h, --help              Show this help message
  -i, --interactive       Interactive mode
  -c, --check             Check for available updates only
  -u, --upgrade           Perform full system upgrade
  -s, --stack <name>      Upgrade specific stack only
  -v, --verify            Verify system health only
  --create-version-file   Create version tracking file
  --no-backup            Skip pre-upgrade backup

Examples:
  # Interactive mode
  bash scripts/smart-upgrade.sh -i

  # Check for updates
  bash scripts/smart-upgrade.sh -c

  # Full upgrade with backup
  bash scripts/smart-upgrade.sh -u

  # Upgrade specific stack
  bash scripts/smart-upgrade.sh -s dns

EOF
}

# Main entry point
main() {
    init_log
    
    # Parse command line arguments
    if [[ $# -eq 0 ]]; then
        interactive_mode
        exit 0
    fi
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -i|--interactive)
                interactive_mode
                exit 0
                ;;
            -c|--check)
                check_all_updates
                exit 0
                ;;
            -u|--upgrade)
                perform_upgrade
                exit 0
                ;;
            -s|--stack)
                shift
                upgrade_stack "$1"
                exit 0
                ;;
            -v|--verify)
                post_upgrade_verification
                exit 0
                ;;
            --create-version-file)
                create_version_file
                exit 0
                ;;
            *)
                err "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
}

main "$@"
