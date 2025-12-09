#!/bin/bash
# backup-volumes.sh - Backup critical Docker volumes for Orion Sentinel DNS HA
#
# This script backs up all important volumes to a timestamped tar.gz archive
# Default backup location: /srv/backups/orion/DATE
#
# Usage:
#   sudo ./backup/backup-volumes.sh [backup-destination]
#
# Example:
#   sudo ./backup/backup-volumes.sh /srv/backups/orion

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
DATE=$(date '+%Y-%m-%d')

# Default backup destination
DEFAULT_BACKUP_BASE="/srv/backups/orion"
BACKUP_BASE="${1:-$DEFAULT_BACKUP_BASE}"
BACKUP_DIR="$BACKUP_BASE/$DATE"
BACKUP_NAME="orion-dns-volumes-${TIMESTAMP}.tar.gz"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[backup]${NC} $*"; }
warn() { echo -e "${YELLOW}[backup][WARNING]${NC} $*"; }
error() { echo -e "${RED}[backup][ERROR]${NC} $*" >&2; }
info() { echo -e "${BLUE}[backup][INFO]${NC} $*"; }

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root (use sudo)"
    exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"
log "Backup directory: $BACKUP_DIR"

# Create temporary working directory
TEMP_DIR=$(mktemp -d -t orion-backup-XXXXXX)
trap 'rm -rf "$TEMP_DIR"' EXIT

log "Starting volume backup at $(date)"
log "Temporary working directory: $TEMP_DIR"

# List of critical volumes to backup
# Format: "service_name:volume_name:description"
CRITICAL_VOLUMES=(
    "pihole_primary:pihole-etc:/etc/pihole (Pi-hole configuration)"
    "pihole_primary:pihole-dnsmasq:/etc/dnsmasq.d (DNS configuration)"
    "unbound_primary:unbound-conf:/opt/unbound/etc/unbound (Unbound configuration)"
    "keepalived:keepalived-conf:/etc/keepalived (Keepalived configuration)"
)

info "Critical volumes to backup:"
for vol_spec in "${CRITICAL_VOLUMES[@]}"; do
    IFS=':' read -r service volume desc <<< "$vol_spec"
    info "  - $desc"
done
echo ""

# Function to backup a volume
backup_volume() {
    local service=$1
    local volume=$2
    local desc=$3
    
    log "Backing up: $desc..."
    
    # Check if container exists and is running
    if ! docker compose ps -q "$service" > /dev/null 2>&1; then
        warn "Service $service is not running, attempting to backup volume anyway..."
    fi
    
    # Create subdirectory for this service
    local service_dir="$TEMP_DIR/$service"
    mkdir -p "$service_dir"
    
    # Use docker run to create a temporary container and copy volume data
    # This works even if the service container is not running
    local volume_name
    volume_name=$(docker volume ls -q | grep -E "${service}.*${volume##*/}" | head -n1)
    
    if [ -z "$volume_name" ]; then
        warn "Could not find volume for $service:$volume, skipping..."
        return 1
    fi
    
    log "  Volume name: $volume_name"
    
    # Create tar archive of the volume
    docker run --rm \
        -v "$volume_name:/volume:ro" \
        -v "$service_dir:/backup" \
        alpine:latest \
        tar czf "/backup/${volume##*/}.tar.gz" -C /volume .
    
    if [ $? -eq 0 ]; then
        log "  ✓ Backup complete for $desc"
        return 0
    else
        error "  ✗ Failed to backup $desc"
        return 1
    fi
}

# Backup configuration files
log "Backing up configuration files..."
mkdir -p "$TEMP_DIR/config"

if [ -f "$REPO_ROOT/.env" ]; then
    cp "$REPO_ROOT/.env" "$TEMP_DIR/config/.env"
    log "  ✓ Backed up .env file"
fi

if [ -f "$REPO_ROOT/compose.yml" ]; then
    cp "$REPO_ROOT/compose.yml" "$TEMP_DIR/config/compose.yml"
    log "  ✓ Backed up compose.yml"
fi

# Backup custom configuration directory if it exists
if [ -d "$REPO_ROOT/config" ]; then
    cp -r "$REPO_ROOT/config" "$TEMP_DIR/config/custom"
    log "  ✓ Backed up custom config directory"
fi

# Perform volume backups
echo ""
log "Starting volume backups..."
backup_count=0
failed_count=0

for vol_spec in "${CRITICAL_VOLUMES[@]}"; do
    IFS=':' read -r service volume desc <<< "$vol_spec"
    if backup_volume "$service" "$volume" "$desc"; then
        ((backup_count++))
    else
        ((failed_count++))
    fi
done

echo ""
log "Volume backup summary:"
log "  ✓ Successful: $backup_count"
if [ $failed_count -gt 0 ]; then
    warn "  ✗ Failed: $failed_count"
fi

# Create metadata file
cat > "$TEMP_DIR/backup-metadata.txt" <<EOF
Orion Sentinel DNS HA - Volume Backup
=====================================
Backup Date: $(date)
Backup Version: 1.0
Hostname: $(hostname)
Backup Contents:
  - Configuration files (.env, compose.yml)
  - Docker volumes (Pi-hole, Unbound, Keepalived)

Critical Volumes:
EOF

for vol_spec in "${CRITICAL_VOLUMES[@]}"; do
    IFS=':' read -r service volume desc <<< "$vol_spec"
    echo "  - $desc" >> "$TEMP_DIR/backup-metadata.txt"
done

# Create final tar.gz archive
log "Creating final backup archive..."
cd "$TEMP_DIR"
tar czf "$BACKUP_PATH" .
cd - > /dev/null

# Calculate size
BACKUP_SIZE=$(du -h "$BACKUP_PATH" | cut -f1)
log "✓ Backup complete!"
log "  Location: $BACKUP_PATH"
log "  Size: $BACKUP_SIZE"

# Create a 'latest' symlink
LATEST_LINK="$BACKUP_BASE/latest-volumes-backup.tar.gz"
ln -sf "$BACKUP_PATH" "$LATEST_LINK"
log "  Latest link: $LATEST_LINK"

# Keep only last 7 daily backups
log "Cleaning up old backups (keeping last 7 days)..."
find "$BACKUP_BASE" -name "orion-dns-volumes-*.tar.gz" -type f -mtime +7 -delete

log "Backup completed successfully at $(date)"
