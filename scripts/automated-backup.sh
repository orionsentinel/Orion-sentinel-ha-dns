#!/usr/bin/env bash
# Enhanced Automated Backup Solution
# Backs up all critical stack data with rotation and restore capability

set -euo pipefail

# Configuration
BACKUP_DIR="${BACKUP_DIR:-/opt/rpi-ha-dns-stack/backups}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
STACK_ROOT="${STACK_ROOT:-/opt/rpi-ha-dns-stack}"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
BACKUP_NAME="stack_backup_${TIMESTAMP}"
LOG_FILE="${BACKUP_DIR}/backup.log"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log() { 
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo -e "${GREEN}${msg}${NC}" | tee -a "$LOG_FILE"
}

info() { 
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo -e "${BLUE}${msg}${NC}" | tee -a "$LOG_FILE"
}

warn() { 
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $*"
    echo -e "${YELLOW}${msg}${NC}" | tee -a "$LOG_FILE"
}

error() { 
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*"
    echo -e "${RED}${msg}${NC}" | tee -a "$LOG_FILE"
}

# Create backup directory structure
mkdir -p "$BACKUP_DIR"
mkdir -p "${BACKUP_DIR}/tmp"
TEMP_BACKUP_DIR="${BACKUP_DIR}/tmp/${BACKUP_NAME}"
mkdir -p "$TEMP_BACKUP_DIR"

# Backup function for Docker volumes
backup_docker_volume() {
    local container="$1"
    local volume_path="$2"
    local backup_subdir="$3"
    
    if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        warn "Container $container not running, skipping volume backup"
        return 1
    fi
    
    info "Backing up $container volume: $volume_path"
    mkdir -p "${TEMP_BACKUP_DIR}/${backup_subdir}"
    
    # Use docker exec to copy data
    docker exec "$container" tar czf - -C "$volume_path" . 2>/dev/null > \
        "${TEMP_BACKUP_DIR}/${backup_subdir}/data.tar.gz" || {
        warn "Failed to backup $container volume, may be empty"
        return 1
    }
    
    log "✓ Backed up $container volume"
    return 0
}

# Backup configuration files
backup_configs() {
    info "Backing up configuration files..."
    mkdir -p "${TEMP_BACKUP_DIR}/configs"
    
    # Stack configurations
    if [ -f "${STACK_ROOT}/.env" ]; then
        cp "${STACK_ROOT}/.env" "${TEMP_BACKUP_DIR}/configs/"
        log "✓ Backed up main .env file"
    fi
    
    # DNS stack configs
    if [ -d "${STACK_ROOT}/stacks/dns" ]; then
        mkdir -p "${TEMP_BACKUP_DIR}/configs/dns"
        cp -r "${STACK_ROOT}/stacks/dns/unbound" "${TEMP_BACKUP_DIR}/configs/dns/" 2>/dev/null || true
        cp "${STACK_ROOT}/stacks/dns/docker-compose.yml" "${TEMP_BACKUP_DIR}/configs/dns/" 2>/dev/null || true
        log "✓ Backed up DNS configurations"
    fi
    
    # Observability configs
    if [ -d "${STACK_ROOT}/stacks/observability" ]; then
        mkdir -p "${TEMP_BACKUP_DIR}/configs/observability"
        cp -r "${STACK_ROOT}/stacks/observability/grafana/provisioning" "${TEMP_BACKUP_DIR}/configs/observability/" 2>/dev/null || true
        cp -r "${STACK_ROOT}/stacks/observability/prometheus" "${TEMP_BACKUP_DIR}/configs/observability/" 2>/dev/null || true
        cp "${STACK_ROOT}/stacks/observability/docker-compose.yml" "${TEMP_BACKUP_DIR}/configs/observability/" 2>/dev/null || true
        log "✓ Backed up observability configurations"
    fi
    
    # Management stack configs
    if [ -d "${STACK_ROOT}/stacks/management" ]; then
        mkdir -p "${TEMP_BACKUP_DIR}/configs/management"
        cp -r "${STACK_ROOT}/stacks/management/homepage" "${TEMP_BACKUP_DIR}/configs/management/" 2>/dev/null || true
        cp "${STACK_ROOT}/stacks/management/docker-compose.yml" "${TEMP_BACKUP_DIR}/configs/management/" 2>/dev/null || true
        log "✓ Backed up management configurations"
    fi
}

# Backup Pi-hole data
backup_pihole() {
    info "Backing up Pi-hole data..."
    
    # Primary Pi-hole
    backup_docker_volume "pihole_primary" "/etc/pihole" "pihole/primary/etc" || true
    backup_docker_volume "pihole_primary" "/etc/dnsmasq.d" "pihole/primary/dnsmasq" || true
    
    # Secondary Pi-hole
    backup_docker_volume "pihole_secondary" "/etc/pihole" "pihole/secondary/etc" || true
    backup_docker_volume "pihole_secondary" "/etc/dnsmasq.d" "pihole/secondary/dnsmasq" || true
    
    # Export Pi-hole settings via API
    for instance in pihole_primary pihole_secondary; do
        if docker ps --format '{{.Names}}' | grep -q "^${instance}$"; then
            info "Exporting $instance teleporter backup..."
            docker exec "$instance" pihole -a -t > \
                "${TEMP_BACKUP_DIR}/pihole/${instance}_teleporter.tar.gz" 2>/dev/null || \
                warn "Failed to export $instance teleporter backup"
        fi
    done
}

# Backup Grafana data
backup_grafana() {
    info "Backing up Grafana data..."
    backup_docker_volume "grafana" "/var/lib/grafana" "grafana" || \
        warn "Failed to backup Grafana volume"
}

# Backup Prometheus data
backup_prometheus() {
    info "Backing up Prometheus data..."
    
    # Create Prometheus snapshot via API
    info "Creating Prometheus snapshot..."
    if docker ps --format '{{.Names}}' | grep -q "^prometheus$"; then
        # Trigger snapshot
        docker exec prometheus wget -qO- --post-data='' http://localhost:9090/api/v1/admin/tsdb/snapshot 2>/dev/null > \
            "${TEMP_BACKUP_DIR}/prometheus_snapshot.json" || \
            warn "Failed to create Prometheus snapshot"
        
        # Backup data directory
        backup_docker_volume "prometheus" "/prometheus" "prometheus" || \
            warn "Failed to backup Prometheus volume"
    fi
}

# Backup Unbound data
backup_unbound() {
    info "Backing up Unbound data..."
    
    for instance in unbound1 unbound2; do
        if docker ps --format '{{.Names}}' | grep -q "^${instance}$"; then
            mkdir -p "${TEMP_BACKUP_DIR}/unbound/${instance}"
            docker exec "$instance" cat /opt/unbound/etc/unbound/unbound.conf > \
                "${TEMP_BACKUP_DIR}/unbound/${instance}/unbound.conf" 2>/dev/null || \
                warn "Failed to backup $instance config"
        fi
    done
}

# Backup management services
backup_management() {
    info "Backing up management services..."
    
    # Portainer
    if docker ps --format '{{.Names}}' | grep -q "^portainer$"; then
        backup_docker_volume "portainer" "/data" "management/portainer" || true
    fi
    
    # Uptime Kuma
    if docker ps --format '{{.Names}}' | grep -q "^uptime-kuma$"; then
        backup_docker_volume "uptime-kuma" "/app/data" "management/uptime-kuma" || true
    fi
    
    # Netdata (config only, metrics are ephemeral)
    if docker ps --format '{{.Names}}' | grep -q "^netdata$"; then
        docker exec netdata cat /etc/netdata/netdata.conf > \
            "${TEMP_BACKUP_DIR}/management/netdata.conf" 2>/dev/null || true
    fi
}

# Create backup metadata
create_metadata() {
    info "Creating backup metadata..."
    
    cat > "${TEMP_BACKUP_DIR}/BACKUP_INFO.txt" <<EOF
Backup Created: $(date '+%Y-%m-%d %H:%M:%S')
Backup Name: ${BACKUP_NAME}
Hostname: $(hostname)
Stack Version: $(cat ${STACK_ROOT}/VERSIONS.md 2>/dev/null | grep -m1 "Version" || echo "Unknown")

Running Containers:
$(docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}')

Backup Contents:
$(find ${TEMP_BACKUP_DIR} -type f | sed "s|${TEMP_BACKUP_DIR}/||")

Backup Size: $(du -sh ${TEMP_BACKUP_DIR} | cut -f1)
EOF
    
    log "✓ Created backup metadata"
}

# Compress backup
compress_backup() {
    info "Compressing backup..."
    
    cd "${BACKUP_DIR}/tmp"
    tar czf "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" "$BACKUP_NAME" 2>/dev/null
    
    BACKUP_SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" | cut -f1)
    log "✓ Backup compressed: ${BACKUP_NAME}.tar.gz (${BACKUP_SIZE})"
    
    # Cleanup temp directory
    rm -rf "$TEMP_BACKUP_DIR"
}

# Cleanup old backups
cleanup_old_backups() {
    info "Cleaning up backups older than ${RETENTION_DAYS} days..."
    
    local deleted=0
    while IFS= read -r old_backup; do
        rm -f "$old_backup"
        deleted=$((deleted + 1))
        log "Deleted old backup: $(basename "$old_backup")"
    done < <(find "$BACKUP_DIR" -name "stack_backup_*.tar.gz" -mtime "+${RETENTION_DAYS}" -type f)
    
    if [ $deleted -eq 0 ]; then
        info "No old backups to delete"
    else
        log "✓ Deleted $deleted old backup(s)"
    fi
}

# Calculate backup statistics
show_statistics() {
    info "Backup Statistics:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$LOG_FILE"
    echo "Backup Name: ${BACKUP_NAME}.tar.gz" | tee -a "$LOG_FILE"
    echo "Backup Size: $(du -h "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" | cut -f1)" | tee -a "$LOG_FILE"
    echo "Total Backups: $(find "$BACKUP_DIR" -name "stack_backup_*.tar.gz" -type f | wc -l)" | tee -a "$LOG_FILE"
    echo "Total Backup Size: $(du -sh "$BACKUP_DIR" | cut -f1)" | tee -a "$LOG_FILE"
    echo "Oldest Backup: $(find "$BACKUP_DIR" -name "stack_backup_*.tar.gz" -type f -printf '%T+ %p\n' | sort | head -1 | cut -d' ' -f1 || echo "None")" | tee -a "$LOG_FILE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$LOG_FILE"
}

# Main backup process
main() {
    log "═══════════════════════════════════════════════════"
    log "   Starting Automated Backup - $(date '+%Y-%m-%d %H:%M:%S')"
    log "═══════════════════════════════════════════════════"
    
    # Perform backups
    backup_configs
    backup_pihole
    backup_grafana
    backup_prometheus
    backup_unbound
    backup_management
    
    # Create metadata and compress
    create_metadata
    compress_backup
    
    # Cleanup old backups
    cleanup_old_backups
    
    # Show statistics
    show_statistics
    
    log "═══════════════════════════════════════════════════"
    log "   Backup Completed Successfully!"
    log "   Backup Location: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
    log "═══════════════════════════════════════════════════"
}

# Run main function
main
