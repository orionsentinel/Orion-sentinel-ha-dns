#!/usr/bin/env bash
# Pi-hole Configuration Sync Script for v6
# Syncs configuration from primary to secondary Pi-hole instance

set -euo pipefail

PIHOLE_PRIMARY="pihole_primary"
PIHOLE_SECONDARY="pihole_secondary"
SYNC_INTERVAL="${SYNC_INTERVAL:-300}"  # 5 minutes default

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

sync_pihole_config() {
    log "Starting Pi-hole configuration sync..."
    
    # Sync gravity database
    log "Syncing gravity database..."
    docker exec "$PIHOLE_PRIMARY" cat /etc/pihole/gravity.db > /tmp/gravity.db.tmp
    docker cp /tmp/gravity.db.tmp "$PIHOLE_SECONDARY":/etc/pihole/gravity.db
    rm -f /tmp/gravity.db.tmp
    
    # Sync custom DNS records
    if docker exec "$PIHOLE_PRIMARY" test -f /etc/pihole/custom.list; then
        log "Syncing custom DNS records..."
        docker exec "$PIHOLE_PRIMARY" cat /etc/pihole/custom.list > /tmp/custom.list.tmp
        docker cp /tmp/custom.list.tmp "$PIHOLE_SECONDARY":/etc/pihole/custom.list
        rm -f /tmp/custom.list.tmp
    fi
    
    # Sync adlists
    if docker exec "$PIHOLE_PRIMARY" test -f /etc/pihole/adlists.list; then
        log "Syncing adlists..."
        docker exec "$PIHOLE_PRIMARY" cat /etc/pihole/adlists.list > /tmp/adlists.list.tmp
        docker cp /tmp/adlists.list.tmp "$PIHOLE_SECONDARY":/etc/pihole/adlists.list
        rm -f /tmp/adlists.list.tmp
    fi
    
    # Sync whitelist/blacklist
    for list in whitelist.txt blacklist.txt regex.list; do
        if docker exec "$PIHOLE_PRIMARY" test -f "/etc/pihole/$list"; then
            log "Syncing $list..."
            docker exec "$PIHOLE_PRIMARY" cat "/etc/pihole/$list" > "/tmp/$list.tmp"
            docker cp "/tmp/$list.tmp" "$PIHOLE_SECONDARY:/etc/pihole/$list"
            rm -f "/tmp/$list.tmp"
        fi
    done
    
    # Reload secondary Pi-hole
    log "Reloading secondary Pi-hole DNS..."
    docker exec "$PIHOLE_SECONDARY" pihole restartdns reload-lists
    
    log "Sync completed successfully!"
}

# Main sync loop
main() {
    log "Pi-hole Config Sync started (interval: ${SYNC_INTERVAL}s)"
    
    while true; do
        if docker ps --format '{{.Names}}' | grep -q "$PIHOLE_PRIMARY" && \
           docker ps --format '{{.Names}}' | grep -q "$PIHOLE_SECONDARY"; then
            sync_pihole_config || log "ERROR: Sync failed"
        else
            log "WARNING: One or both Pi-hole containers not running, skipping sync"
        fi
        
        log "Next sync in ${SYNC_INTERVAL} seconds..."
        sleep "$SYNC_INTERVAL"
    done
}

# Run once if --once flag is provided
if [[ "${1:-}" == "--once" ]]; then
    sync_pihole_config
else
    main
fi
