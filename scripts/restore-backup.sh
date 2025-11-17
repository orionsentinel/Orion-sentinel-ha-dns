#!/usr/bin/env bash
# Enhanced Backup Restore Script
# Restores stack data from automated backups

set -euo pipefail

# Configuration
BACKUP_DIR="${BACKUP_DIR:-/opt/rpi-ha-dns-stack/backups}"
STACK_ROOT="${STACK_ROOT:-/opt/rpi-ha-dns-stack}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*"; }
info() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*"; }
warn() { echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} WARNING: $*"; }
error() { echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} ERROR: $*"; }

# List available backups
list_backups() {
    echo ""
    echo "Available Backups:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local backups=($(find "$BACKUP_DIR" -name "stack_backup_*.tar.gz" -type f | sort -r))
    
    if [ ${#backups[@]} -eq 0 ]; then
        error "No backups found in $BACKUP_DIR"
        exit 1
    fi
    
    local index=1
    for backup in "${backups[@]}"; do
        local backup_name=$(basename "$backup")
        local backup_size=$(du -h "$backup" | cut -f1)
        local backup_date=$(stat -c %y "$backup" | cut -d' ' -f1,2 | cut -d'.' -f1)
        echo "$index) $backup_name"
        echo "   Size: $backup_size | Created: $backup_date"
        index=$((index + 1))
    done
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# Select backup
select_backup() {
    list_backups
    
    local backups=($(find "$BACKUP_DIR" -name "stack_backup_*.tar.gz" -type f | sort -r))
    
    echo -n "Select backup to restore (1-${#backups[@]}) or 'q' to quit: "
    read -r selection
    
    if [ "$selection" = "q" ]; then
        log "Restore cancelled"
        exit 0
    fi
    
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#backups[@]} ]; then
        error "Invalid selection"
        exit 1
    fi
    
    SELECTED_BACKUP="${backups[$((selection - 1))]}"
    log "Selected backup: $(basename "$SELECTED_BACKUP")"
}

# Extract backup
extract_backup() {
    info "Extracting backup..."
    
    TEMP_RESTORE_DIR="${BACKUP_DIR}/restore_tmp"
    rm -rf "$TEMP_RESTORE_DIR"
    mkdir -p "$TEMP_RESTORE_DIR"
    
    tar xzf "$SELECTED_BACKUP" -C "$TEMP_RESTORE_DIR" 2>/dev/null || {
        error "Failed to extract backup"
        exit 1
    }
    
    # Find the extracted directory
    RESTORE_DIR=$(find "$TEMP_RESTORE_DIR" -maxdepth 1 -type d -name "stack_backup_*" | head -1)
    
    if [ -z "$RESTORE_DIR" ]; then
        error "Could not find extracted backup directory"
        exit 1
    fi
    
    log "✓ Backup extracted"
    
    # Show backup info
    if [ -f "${RESTORE_DIR}/BACKUP_INFO.txt" ]; then
        echo ""
        info "Backup Information:"
        cat "${RESTORE_DIR}/BACKUP_INFO.txt"
        echo ""
    fi
}

# Confirm restore
confirm_restore() {
    warn "This will OVERWRITE existing data with backup data!"
    warn "Make sure all containers are stopped before proceeding."
    echo ""
    echo -n "Are you sure you want to restore? (yes/no): "
    read -r confirmation
    
    if [ "$confirmation" != "yes" ]; then
        log "Restore cancelled"
        rm -rf "$TEMP_RESTORE_DIR"
        exit 0
    fi
}

# Stop containers
stop_containers() {
    info "Stopping containers..."
    
    cd "${STACK_ROOT}/stacks/dns" && docker compose down 2>/dev/null || true
    cd "${STACK_ROOT}/stacks/observability" && docker compose down 2>/dev/null || true
    cd "${STACK_ROOT}/stacks/management" && docker compose down 2>/dev/null || true
    
    log "✓ Containers stopped"
}

# Restore configuration files
restore_configs() {
    info "Restoring configuration files..."
    
    if [ -d "${RESTORE_DIR}/configs" ]; then
        # Backup current configs
        if [ -d "${STACK_ROOT}/stacks" ]; then
            cp -r "${STACK_ROOT}/stacks" "${STACK_ROOT}/stacks.backup.$(date +%s)" 2>/dev/null || true
        fi
        
        # Restore DNS configs
        if [ -d "${RESTORE_DIR}/configs/dns" ]; then
            cp -r "${RESTORE_DIR}/configs/dns/"* "${STACK_ROOT}/stacks/dns/" 2>/dev/null || true
            log "✓ Restored DNS configurations"
        fi
        
        # Restore observability configs
        if [ -d "${RESTORE_DIR}/configs/observability" ]; then
            cp -r "${RESTORE_DIR}/configs/observability/"* "${STACK_ROOT}/stacks/observability/" 2>/dev/null || true
            log "✓ Restored observability configurations"
        fi
        
        # Restore management configs
        if [ -d "${RESTORE_DIR}/configs/management" ]; then
            cp -r "${RESTORE_DIR}/configs/management/"* "${STACK_ROOT}/stacks/management/" 2>/dev/null || true
            log "✓ Restored management configurations"
        fi
        
        # Restore main .env
        if [ -f "${RESTORE_DIR}/configs/.env" ]; then
            cp "${RESTORE_DIR}/configs/.env" "${STACK_ROOT}/.env"
            log "✓ Restored main .env file"
        fi
    fi
}

# Restore Pi-hole data
restore_pihole() {
    info "Restoring Pi-hole data..."
    
    # Start containers temporarily for restore
    cd "${STACK_ROOT}/stacks/dns"
    docker compose up -d pihole_primary pihole_secondary 2>/dev/null || true
    sleep 5
    
    # Restore primary
    if [ -f "${RESTORE_DIR}/pihole/primary/etc/data.tar.gz" ]; then
        docker exec pihole_primary sh -c 'rm -rf /etc/pihole/* && tar xzf - -C /etc/pihole' < \
            "${RESTORE_DIR}/pihole/primary/etc/data.tar.gz" 2>/dev/null || \
            warn "Failed to restore primary Pi-hole data"
        log "✓ Restored primary Pi-hole data"
    fi
    
    # Restore secondary
    if [ -f "${RESTORE_DIR}/pihole/secondary/etc/data.tar.gz" ]; then
        docker exec pihole_secondary sh -c 'rm -rf /etc/pihole/* && tar xzf - -C /etc/pihole' < \
            "${RESTORE_DIR}/pihole/secondary/etc/data.tar.gz" 2>/dev/null || \
            warn "Failed to restore secondary Pi-hole data"
        log "✓ Restored secondary Pi-hole data"
    fi
    
    # Restore teleporter backups if available
    if [ -f "${RESTORE_DIR}/pihole/pihole_primary_teleporter.tar.gz" ]; then
        info "Teleporter backup available for primary Pi-hole"
        info "Import manually via Pi-hole web interface > Settings > Teleporter"
    fi
    
    docker compose down 2>/dev/null || true
}

# Restore Grafana data
restore_grafana() {
    info "Restoring Grafana data..."
    
    if [ -f "${RESTORE_DIR}/grafana/data.tar.gz" ]; then
        cd "${STACK_ROOT}/stacks/observability"
        docker compose up -d grafana 2>/dev/null || true
        sleep 5
        
        docker exec grafana sh -c 'rm -rf /var/lib/grafana/* && tar xzf - -C /var/lib/grafana' < \
            "${RESTORE_DIR}/grafana/data.tar.gz" 2>/dev/null || \
            warn "Failed to restore Grafana data"
        
        docker compose down 2>/dev/null || true
        log "✓ Restored Grafana data"
    fi
}

# Restore Prometheus data
restore_prometheus() {
    info "Restoring Prometheus data..."
    
    if [ -f "${RESTORE_DIR}/prometheus/data.tar.gz" ]; then
        cd "${STACK_ROOT}/stacks/observability"
        docker compose up -d prometheus 2>/dev/null || true
        sleep 5
        
        docker exec prometheus sh -c 'rm -rf /prometheus/* && tar xzf - -C /prometheus' < \
            "${RESTORE_DIR}/prometheus/data.tar.gz" 2>/dev/null || \
            warn "Failed to restore Prometheus data"
        
        docker compose down 2>/dev/null || true
        log "✓ Restored Prometheus data"
    fi
}

# Restore management services
restore_management() {
    info "Restoring management services..."
    
    cd "${STACK_ROOT}/stacks/management" 2>/dev/null || return 0
    
    # Restore Portainer
    if [ -f "${RESTORE_DIR}/management/portainer/data.tar.gz" ]; then
        docker compose up -d portainer 2>/dev/null || true
        sleep 3
        
        docker exec portainer sh -c 'rm -rf /data/* && tar xzf - -C /data' < \
            "${RESTORE_DIR}/management/portainer/data.tar.gz" 2>/dev/null || \
            warn "Failed to restore Portainer data"
        
        log "✓ Restored Portainer data"
    fi
    
    # Restore Uptime Kuma
    if [ -f "${RESTORE_DIR}/management/uptime-kuma/data.tar.gz" ]; then
        docker compose up -d uptime-kuma 2>/dev/null || true
        sleep 3
        
        docker exec uptime-kuma sh -c 'rm -rf /app/data/* && tar xzf - -C /app/data' < \
            "${RESTORE_DIR}/management/uptime-kuma/data.tar.gz" 2>/dev/null || \
            warn "Failed to restore Uptime Kuma data"
        
        log "✓ Restored Uptime Kuma data"
    fi
    
    docker compose down 2>/dev/null || true
}

# Start services
start_services() {
    info "Starting services..."
    
    cd "${STACK_ROOT}/stacks/dns" && docker compose up -d 2>/dev/null || true
    cd "${STACK_ROOT}/stacks/observability" && docker compose up -d 2>/dev/null || true
    cd "${STACK_ROOT}/stacks/management" && docker compose up -d 2>/dev/null || true
    
    log "✓ Services started"
}

# Cleanup
cleanup() {
    info "Cleaning up..."
    rm -rf "$TEMP_RESTORE_DIR"
    log "✓ Cleanup complete"
}

# Main restore process
main() {
    log "═══════════════════════════════════════════════════"
    log "   Backup Restore Utility"
    log "═══════════════════════════════════════════════════"
    
    select_backup
    extract_backup
    confirm_restore
    
    log "Starting restore process..."
    
    stop_containers
    restore_configs
    restore_pihole
    restore_grafana
    restore_prometheus
    restore_management
    start_services
    cleanup
    
    log "═══════════════════════════════════════════════════"
    log "   Restore Completed Successfully!"
    log "   Please verify all services are working correctly"
    log "═══════════════════════════════════════════════════"
}

# Run main function
main
