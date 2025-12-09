#!/usr/bin/env bash
# Automated Pi-hole Backup Script
# Creates timestamped backups and maintains rotation

set -eu

# Configuration
BACKUP_DIR="${BACKUP_DIR:-/backup}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
PIHOLE_CONTAINERS="${PIHOLE_CONTAINERS:-pihole_primary pihole_secondary}"
BACKUP_INTERVAL="${BACKUP_INTERVAL:-86400}"  # 24 hours

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*"; }
info() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*"; }
warn() { echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*"; }

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup single Pi-hole container
backup_pihole() {
    local container="$1"
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_name="${container}_${timestamp}"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        warn "Container $container not running, skipping"
        return 1
    fi
    
    log "Backing up $container..."
    
    # Create backup directory
    mkdir -p "$backup_path"
    
    # Backup gravity database
    docker exec "$container" cat /etc/pihole/gravity.db > "$backup_path/gravity.db"
    
    # Backup configuration files
    docker exec "$container" cat /etc/pihole/pihole-FTL.conf > "$backup_path/pihole-FTL.conf" 2>/dev/null || true
    docker exec "$container" cat /etc/pihole/custom.list > "$backup_path/custom.list" 2>/dev/null || true
    docker exec "$container" cat /etc/dnsmasq.d/05-pihole-custom-cname.conf > "$backup_path/05-pihole-custom-cname.conf" 2>/dev/null || true
    
    # Create teleporter backup (full backup)
    docker exec "$container" pihole -a -t > "$backup_path/teleporter.tar.gz" 2>/dev/null || true
    
    # Backup statistics
    docker exec "$container" bash -c "
        sqlite3 /etc/pihole/gravity.db 'SELECT * FROM info;' > /tmp/info.txt 2>/dev/null || true
        cat /tmp/info.txt
    " > "$backup_path/info.txt" 2>/dev/null || true
    
    # Create backup metadata
    cat > "$backup_path/backup-info.txt" << EOF
Backup Date: $(date '+%Y-%m-%d %H:%M:%S')
Container: $container
Hostname: $(hostname)
Pi-hole Version: $(docker exec "$container" pihole -v | head -1)

Database Statistics:
EOF
    
    # Add database stats
    docker exec "$container" bash -c "
        echo \"  Domains blocked: \$(sqlite3 /etc/pihole/gravity.db 'SELECT COUNT(*) FROM gravity;')\"
        echo \"  Active blocklists: \$(sqlite3 /etc/pihole/gravity.db 'SELECT COUNT(*) FROM adlist WHERE enabled=1;')\"
        echo \"  Whitelisted: \$(sqlite3 /etc/pihole/gravity.db 'SELECT COUNT(*) FROM domainlist WHERE type=0;')\"
        echo \"  Blacklisted: \$(sqlite3 /etc/pihole/gravity.db 'SELECT COUNT(*) FROM domainlist WHERE type=1;')\"
    " >> "$backup_path/backup-info.txt" 2>/dev/null || true
    
    # Compress backup
    tar -czf "${backup_path}.tar.gz" -C "$BACKUP_DIR" "$backup_name"
    rm -rf "$backup_path"
    
    log "✓ Backup created: ${backup_name}.tar.gz ($(du -h "${backup_path}.tar.gz" | cut -f1))"
}

# Clean old backups
cleanup_old_backups() {
    log "Cleaning up backups older than $RETENTION_DAYS days..."
    
    local deleted=0
    while IFS= read -r -d '' backup; do
        rm -f "$backup"
        deleted=$((deleted + 1))
    done < <(find "$BACKUP_DIR" -name "*.tar.gz" -type f -mtime +$RETENTION_DAYS -print0)
    
    if [ $deleted -gt 0 ]; then
        log "✓ Deleted $deleted old backup(s)"
    else
        info "No old backups to clean"
    fi
}

# Get backup statistics
show_backup_stats() {
    local total_backups=$(find "$BACKUP_DIR" -name "*.tar.gz" -type f | wc -l)
    local total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
    local oldest=$(find "$BACKUP_DIR" -name "*.tar.gz" -type f -printf '%T+ %p\n' 2>/dev/null | sort | head -1 | cut -d' ' -f1)
    local newest=$(find "$BACKUP_DIR" -name "*.tar.gz" -type f -printf '%T+ %p\n' 2>/dev/null | sort | tail -1 | cut -d' ' -f1)
    
    info "Backup Statistics:"
    info "  Total backups: $total_backups"
    info "  Total size: $total_size"
    info "  Oldest backup: ${oldest:-none}"
    info "  Newest backup: ${newest:-none}"
}

# Backup all containers
backup_all() {
    log "========================================="
    log "Starting automated backup"
    log "========================================="
    
    local success=0
    local failed=0
    
    for container in $PIHOLE_CONTAINERS; do
        if backup_pihole "$container"; then
            success=$((success + 1))
        else
            failed=$((failed + 1))
        fi
    done
    
    cleanup_old_backups
    show_backup_stats
    
    log "========================================="
    log "Backup completed: $success succeeded, $failed failed"
    log "========================================="
    echo ""
}

# Main loop
main() {
    log "Pi-hole Automated Backup Service started"
    log "Backup directory: $BACKUP_DIR"
    log "Backup interval: $BACKUP_INTERVAL seconds ($(($BACKUP_INTERVAL / 3600)) hours)"
    log "Retention: $RETENTION_DAYS days"
    log "Containers: $PIHOLE_CONTAINERS"
    echo ""
    
    while true; do
        backup_all
        
        local next_backup=$(date -d "+${BACKUP_INTERVAL} seconds" '+%Y-%m-%d %H:%M:%S')
        log "Next backup scheduled for: $next_backup"
        log "Sleeping for ${BACKUP_INTERVAL} seconds..."
        echo ""
        
        sleep "$BACKUP_INTERVAL"
    done
}

# Run once if --once flag is provided
if [[ "${1:-}" == "--once" ]]; then
    backup_all
else
    main
fi
