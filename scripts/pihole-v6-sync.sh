#!/usr/bin/env bash
# Pi-hole v6 Configuration Sync Script
# Compatible with Pi-hole v6's new database structure
# Syncs configuration between Pi-hole instances without Gravity Sync

set -eu

# Configuration
PIHOLE_PRIMARY="${PIHOLE_PRIMARY:-pihole_primary}"
PIHOLE_SECONDARY="${PIHOLE_SECONDARY:-pihole_secondary}"
SYNC_INTERVAL="${SYNC_INTERVAL:-300}"  # 5 minutes default

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*"; }
warn() { echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')][WARN]${NC} $*"; }
err() { echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')][ERROR]${NC} $*"; }

# Check if container is running and healthy
is_container_healthy() {
    local container="$1"
    if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        return 1
    fi
    
    # Check if Pi-hole is responding
    if ! docker exec "$container" pihole status &>/dev/null; then
        return 1
    fi
    
    return 0
}

# Sync Pi-hole v6 database
sync_gravity_db() {
    log "Syncing gravity.db (main blocklist database)..."
    
    # Create backup first
    docker exec "$PIHOLE_SECONDARY" cp /etc/pihole/gravity.db /etc/pihole/gravity.db.bak 2>/dev/null || true
    
    # Copy database
    docker exec "$PIHOLE_PRIMARY" cat /etc/pihole/gravity.db | \
        docker exec -i "$PIHOLE_SECONDARY" sh -c 'cat > /etc/pihole/gravity.db'
    
    # Set proper permissions
    docker exec "$PIHOLE_SECONDARY" chown pihole:pihole /etc/pihole/gravity.db
    docker exec "$PIHOLE_SECONDARY" chmod 644 /etc/pihole/gravity.db
    
    log "✓ Gravity database synced"
}

# Sync custom DNS records (Pi-hole v6 local DNS)
sync_custom_dns() {
    if ! docker exec "$PIHOLE_PRIMARY" test -f /etc/pihole/custom.list 2>/dev/null; then
        return 0
    fi
    
    log "Syncing custom DNS records..."
    docker exec "$PIHOLE_PRIMARY" cat /etc/pihole/custom.list | \
        docker exec -i "$PIHOLE_SECONDARY" sh -c 'cat > /etc/pihole/custom.list'
    
    docker exec "$PIHOLE_SECONDARY" chown pihole:pihole /etc/pihole/custom.list 2>/dev/null || true
    log "✓ Custom DNS records synced"
}

# Sync CNAME records (Pi-hole v6)
sync_cname_records() {
    if ! docker exec "$PIHOLE_PRIMARY" test -f /etc/dnsmasq.d/05-pihole-custom-cname.conf 2>/dev/null; then
        return 0
    fi
    
    log "Syncing CNAME records..."
    docker exec "$PIHOLE_PRIMARY" cat /etc/dnsmasq.d/05-pihole-custom-cname.conf | \
        docker exec -i "$PIHOLE_SECONDARY" sh -c 'cat > /etc/dnsmasq.d/05-pihole-custom-cname.conf'
    
    log "✓ CNAME records synced"
}

# Sync teleporter backup (full configuration)
sync_teleporter_backup() {
    log "Creating teleporter backup from primary..."
    
    # Generate teleporter backup on primary
    docker exec "$PIHOLE_PRIMARY" pihole -a -t > /tmp/pihole-teleporter.tar.gz 2>/dev/null || {
        warn "Teleporter backup failed, skipping"
        return 1
    }
    
    log "Restoring teleporter backup to secondary..."
    docker cp /tmp/pihole-teleporter.tar.gz "$PIHOLE_SECONDARY":/tmp/
    docker exec "$PIHOLE_SECONDARY" pihole -a -r /tmp/pihole-teleporter.tar.gz 2>/dev/null || {
        warn "Teleporter restore failed"
        return 1
    }
    
    rm -f /tmp/pihole-teleporter.tar.gz
    log "✓ Teleporter backup synced"
}

# Sync FTL configuration
sync_ftl_config() {
    if ! docker exec "$PIHOLE_PRIMARY" test -f /etc/pihole/pihole-FTL.conf 2>/dev/null; then
        return 0
    fi
    
    log "Syncing FTL configuration..."
    docker exec "$PIHOLE_PRIMARY" cat /etc/pihole/pihole-FTL.conf | \
        docker exec -i "$PIHOLE_SECONDARY" sh -c 'cat > /etc/pihole/pihole-FTL.conf'
    
    docker exec "$PIHOLE_SECONDARY" chown pihole:pihole /etc/pihole/pihole-FTL.conf 2>/dev/null || true
    log "✓ FTL configuration synced"
}

# Reload secondary Pi-hole DNS
reload_secondary() {
    log "Reloading secondary Pi-hole..."
    
    # Restart DNS to apply changes
    if docker exec "$PIHOLE_SECONDARY" pihole restartdns reload-lists; then
        log "✓ Secondary Pi-hole reloaded successfully"
    else
        warn "Failed to reload secondary Pi-hole"
        return 1
    fi
}

# Get sync statistics
get_sync_stats() {
    local primary_domains=$(docker exec "$PIHOLE_PRIMARY" bash -c \
        "sqlite3 /etc/pihole/gravity.db 'SELECT COUNT(*) FROM gravity;'" 2>/dev/null || echo "0")
    
    local secondary_domains=$(docker exec "$PIHOLE_SECONDARY" bash -c \
        "sqlite3 /etc/pihole/gravity.db 'SELECT COUNT(*) FROM gravity;'" 2>/dev/null || echo "0")
    
    local primary_lists=$(docker exec "$PIHOLE_PRIMARY" bash -c \
        "sqlite3 /etc/pihole/gravity.db 'SELECT COUNT(*) FROM adlist WHERE enabled=1;'" 2>/dev/null || echo "0")
    
    log "Sync Statistics:"
    log "  Primary domains blocked: $primary_domains"
    log "  Secondary domains blocked: $secondary_domains"
    log "  Active blocklists: $primary_lists"
}

# Main sync function
sync_pihole_config() {
    log "========================================="
    log "Starting Pi-hole v6 configuration sync"
    log "========================================="
    
    # Check container health
    if ! is_container_healthy "$PIHOLE_PRIMARY"; then
        err "Primary Pi-hole ($PIHOLE_PRIMARY) is not healthy"
        return 1
    fi
    
    if ! is_container_healthy "$PIHOLE_SECONDARY"; then
        err "Secondary Pi-hole ($PIHOLE_SECONDARY) is not healthy"
        return 1
    fi
    
    # Perform sync operations
    local sync_success=true
    
    sync_gravity_db || sync_success=false
    sync_custom_dns || sync_success=false
    sync_cname_records || sync_success=false
    sync_ftl_config || sync_success=false
    
    # Reload secondary
    if $sync_success; then
        reload_secondary
    else
        warn "Some sync operations failed"
    fi
    
    # Show statistics
    get_sync_stats
    
    log "========================================="
    log "Sync completed!"
    log "========================================="
    echo ""
}

# Main loop
main() {
    log "Pi-hole v6 Sync Service started"
    log "Sync interval: ${SYNC_INTERVAL} seconds"
    log "Primary: $PIHOLE_PRIMARY"
    log "Secondary: $PIHOLE_SECONDARY"
    echo ""
    
    while true; do
        if is_container_healthy "$PIHOLE_PRIMARY" && is_container_healthy "$PIHOLE_SECONDARY"; then
            sync_pihole_config || log "ERROR: Sync failed"
        else
            warn "One or both Pi-hole containers not healthy, skipping sync"
        fi
        
        local next_sync=$(date -d "+${SYNC_INTERVAL} seconds" '+%Y-%m-%d %H:%M:%S')
        log "Next sync at: $next_sync"
        log "Sleeping for ${SYNC_INTERVAL} seconds..."
        echo ""
        
        sleep "$SYNC_INTERVAL"
    done
}

# Run once if --once flag is provided
if [[ "${1:-}" == "--once" ]]; then
    sync_pihole_config
else
    main
fi
