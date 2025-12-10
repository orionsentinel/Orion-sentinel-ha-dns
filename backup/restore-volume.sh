#!/bin/bash
# restore-volume.sh - Restore Docker volumes from backup
#
# This script restores volumes from a backup created by backup-volumes.sh
#
# Usage:
#   sudo ./backup/restore-volume.sh <backup-file> [service-name]
#
# Examples:
#   # Restore all volumes from backup
#   sudo ./backup/restore-volume.sh /srv/backups/orion/2024-12-09/orion-dns-volumes-20241209_123456.tar.gz
#
#   # Restore only Pi-hole volumes
#   sudo ./backup/restore-volume.sh /srv/backups/orion/latest-volumes-backup.tar.gz pihole_primary
#
#   # Restore only Unbound volumes
#   sudo ./backup/restore-volume.sh /srv/backups/orion/latest-volumes-backup.tar.gz unbound_primary

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[restore]${NC} $*"; }
warn() { echo -e "${YELLOW}[restore][WARNING]${NC} $*"; }
error() { echo -e "${RED}[restore][ERROR]${NC} $*" >&2; }
info() { echo -e "${BLUE}[restore][INFO]${NC} $*"; }

# Usage information
usage() {
    cat <<EOF
Usage: $0 <backup-file> [service-name]

Restore volumes from a backup archive.

Arguments:
  backup-file    Path to the backup tar.gz file
  service-name   (Optional) Specific service to restore (e.g., pihole_primary, unbound_primary)
                 If not specified, all services will be restored

Examples:
  # Restore all volumes
  sudo $0 /srv/backups/orion/latest-volumes-backup.tar.gz

  # Restore only Pi-hole
  sudo $0 /srv/backups/orion/latest-volumes-backup.tar.gz pihole_primary

  # Restore only Unbound
  sudo $0 /srv/backups/orion/latest-volumes-backup.tar.gz unbound_primary

Services available for restore:
  - pihole_primary   (Pi-hole configuration and data)
  - unbound_primary  (Unbound DNS resolver configuration)
  - keepalived       (Keepalived HA configuration)

EOF
    exit 1
}

# Check arguments
if [ $# -lt 1 ]; then
    error "Missing required argument: backup-file"
    usage
fi

BACKUP_FILE="$1"
TARGET_SERVICE="${2:-all}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root (use sudo)"
    exit 1
fi

# Verify backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    error "Backup file not found: $BACKUP_FILE"
    exit 1
fi

log "Starting restore process..."
log "Backup file: $BACKUP_FILE"
log "Target service: $TARGET_SERVICE"

# Create temporary working directory
TEMP_DIR=$(mktemp -d -t orion-restore-XXXXXX)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Extract backup archive
log "Extracting backup archive..."
tar xzf "$BACKUP_FILE" -C "$TEMP_DIR"

# Show backup metadata if available
if [ -f "$TEMP_DIR/backup-metadata.txt" ]; then
    echo ""
    info "Backup Information:"
    cat "$TEMP_DIR/backup-metadata.txt" | sed 's/^/  /'
    echo ""
fi

# Function to restore a volume
restore_volume() {
    local service=$1
    local volume_archive=$2
    
    log "Restoring volume for service: $service"
    
    # Find the volume name
    local volume_name
    volume_name=$(docker volume ls -q | grep -E "${service}" | head -n1)
    
    if [ -z "$volume_name" ]; then
        warn "Volume for $service not found, creating new volume..."
        # Create volume if it doesn't exist
        volume_name="${service}_data"
        docker volume create "$volume_name"
    fi
    
    log "  Volume: $volume_name"
    log "  Archive: $volume_archive"
    
    # Stop the service if it's running
    if docker compose ps -q "$service" > /dev/null 2>&1; then
        warn "  Stopping service $service..."
        docker compose stop "$service"
    fi
    
    # Restore the volume using a temporary container
    log "  Restoring data..."
    docker run --rm \
        -v "$volume_name:/volume" \
        -v "$(dirname "$volume_archive"):/backup:ro" \
        alpine:latest \
        sh -c "cd /volume && tar xzf /backup/$(basename "$volume_archive")"
    
    if [ $? -eq 0 ]; then
        log "  ✓ Successfully restored $service volume"
        return 0
    else
        error "  ✗ Failed to restore $service volume"
        return 1
    fi
}

# Restore configuration files
if [ "$TARGET_SERVICE" = "all" ] || [ "$TARGET_SERVICE" = "config" ]; then
    log "Restoring configuration files..."
    
    if [ -f "$TEMP_DIR/config/.env" ]; then
        warn "Found .env in backup. Do you want to restore it? (y/N)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            cp "$TEMP_DIR/config/.env" "$REPO_ROOT/.env"
            log "  ✓ Restored .env file"
        else
            log "  Skipped .env file restoration"
        fi
    fi
    
    if [ -f "$TEMP_DIR/config/compose.yml" ]; then
        info "  Found compose.yml in backup (not restoring, use git for this)"
    fi
fi

# Find all service directories in the backup
AVAILABLE_SERVICES=()
for service_dir in "$TEMP_DIR"/*/; do
    service_name=$(basename "$service_dir")
    if [ "$service_name" != "config" ]; then
        AVAILABLE_SERVICES+=("$service_name")
    fi
done

log "Available services in backup: ${AVAILABLE_SERVICES[*]}"

# Restore volumes
restore_count=0
failed_count=0

if [ "$TARGET_SERVICE" = "all" ]; then
    # Restore all services
    for service in "${AVAILABLE_SERVICES[@]}"; do
        for volume_archive in "$TEMP_DIR/$service"/*.tar.gz; do
            if [ -f "$volume_archive" ]; then
                if restore_volume "$service" "$volume_archive"; then
                    ((restore_count++))
                else
                    ((failed_count++))
                fi
            fi
        done
    done
else
    # Restore specific service
    if [ -d "$TEMP_DIR/$TARGET_SERVICE" ]; then
        for volume_archive in "$TEMP_DIR/$TARGET_SERVICE"/*.tar.gz; do
            if [ -f "$volume_archive" ]; then
                if restore_volume "$TARGET_SERVICE" "$volume_archive"; then
                    ((restore_count++))
                else
                    ((failed_count++))
                fi
            fi
        done
    else
        error "Service '$TARGET_SERVICE' not found in backup"
        error "Available services: ${AVAILABLE_SERVICES[*]}"
        exit 1
    fi
fi

echo ""
log "Restore summary:"
log "  ✓ Successful: $restore_count"
if [ $failed_count -gt 0 ]; then
    warn "  ✗ Failed: $failed_count"
fi

# Prompt to restart services
echo ""
warn "Restore complete. You may need to restart the services:"
info "  docker compose --profile dns-core restart"
info "  # or"
info "  make restart"
