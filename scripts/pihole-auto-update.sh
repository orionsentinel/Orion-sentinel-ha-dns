#!/usr/bin/env bash
# Pi-hole Blocklist Auto-Update Script
# Automatically updates Pi-hole gravity database and blocklists on a schedule

set -euo pipefail

# Configuration
PIHOLE_CONTAINERS="${PIHOLE_CONTAINERS:-pihole_primary pihole_secondary}"
UPDATE_INTERVAL="${UPDATE_INTERVAL:-86400}"  # 24 hours default
LOG_FILE="${LOG_FILE:-/var/log/pihole-auto-update.log}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[$timestamp]${NC} $*" | tee -a "$LOG_FILE"
}

warn() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[$timestamp][WARNING]${NC} $*" | tee -a "$LOG_FILE"
}

err() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[$timestamp][ERROR]${NC} $*" | tee -a "$LOG_FILE"
}

info() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${BLUE}[$timestamp][INFO]${NC} $*" | tee -a "$LOG_FILE"
}

# Check if container is running
is_container_running() {
    local container="$1"
    docker ps --format '{{.Names}}' | grep -q "^${container}$"
}

# Update gravity for a single Pi-hole container
update_pihole_gravity() {
    local container="$1"
    
    if ! is_container_running "$container"; then
        warn "Container $container is not running, skipping"
        return 1
    fi
    
    log "Updating gravity for $container..."
    
    # Run gravity update
    if docker exec "$container" pihole updateGravity; then
        log "Gravity update completed for $container"
        
        # Get blocklist count
        local blocklist_count=$(docker exec "$container" bash -c "sqlite3 /etc/pihole/gravity.db 'SELECT COUNT(*) FROM adlist WHERE enabled=1;'" 2>/dev/null || echo "unknown")
        local domains_blocked=$(docker exec "$container" bash -c "sqlite3 /etc/pihole/gravity.db 'SELECT COUNT(*) FROM gravity;'" 2>/dev/null || echo "unknown")
        
        info "  Blocklists: $blocklist_count active"
        info "  Domains blocked: $domains_blocked"
        return 0
    else
        err "Gravity update failed for $container"
        return 1
    fi
}

# Update all configured Pi-hole containers
update_all_piholes() {
    log "Starting Pi-hole blocklist update for all containers..."
    local update_count=0
    local fail_count=0
    
    for container in $PIHOLE_CONTAINERS; do
        if update_pihole_gravity "$container"; then
            update_count=$((update_count + 1))
        else
            fail_count=$((fail_count + 1))
        fi
    done
    
    log "Update cycle complete: $update_count succeeded, $fail_count failed"
    echo "" | tee -a "$LOG_FILE"
}

# Check and update custom lists if needed
check_custom_lists() {
    log "Checking for custom list updates..."
    
    for container in $PIHOLE_CONTAINERS; do
        if ! is_container_running "$container"; then
            continue
        fi
        
        # Check if custom lists need updates (check last modified time)
        local needs_update=$(docker exec "$container" bash -c "
            if [ -f /etc/pihole/custom.list ]; then
                find /etc/pihole/custom.list -mtime +7 2>/dev/null | wc -l
            else
                echo 0
            fi
        " 2>/dev/null || echo "0")
        
        if [ "$needs_update" -gt 0 ]; then
            info "Custom lists for $container haven't been modified in 7+ days"
        fi
    done
}

# Main update loop
main() {
    log "Pi-hole Auto-Update Service started"
    log "Update interval: ${UPDATE_INTERVAL} seconds ($(($UPDATE_INTERVAL / 3600)) hours)"
    log "Monitoring containers: $PIHOLE_CONTAINERS"
    log "Log file: $LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    while true; do
        update_all_piholes
        check_custom_lists
        
        local next_update=$(date -d "@$(($(date +%s) + UPDATE_INTERVAL))" '+%Y-%m-%d %H:%M:%S')
        log "Next update scheduled for: $next_update"
        log "Sleeping for ${UPDATE_INTERVAL} seconds..."
        echo "" | tee -a "$LOG_FILE"
        
        sleep "$UPDATE_INTERVAL"
    done
}

# Run once if --once flag is provided
if [[ "${1:-}" == "--once" ]]; then
    update_all_piholes
    check_custom_lists
else
    main
fi
