#!/bin/bash
# Configuration Backup Script for Orion Sentinel DNS HA
# Backs up critical configuration and data for disaster recovery

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
BACKUP_DIR="${BACKUP_DIR:-$REPO_ROOT/backups}"
BACKUP_NAME="dns-ha-backup-${TIMESTAMP}"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[backup]${NC} $*"; }
warn() { echo -e "${YELLOW}[backup][WARNING]${NC} $*"; }
error() { echo -e "${RED}[backup][ERROR]${NC} $*" >&2; }

# Create backup directory
mkdir -p "$BACKUP_PATH"

log "Starting configuration backup..."
log "Backup location: $BACKUP_PATH"

# Backup .env file
if [ -f "$REPO_ROOT/.env" ]; then
    log "Backing up .env file..."
    cp "$REPO_ROOT/.env" "$BACKUP_PATH/.env"
    # Note: Sensitive values are backed up but not logged
else
    warn ".env file not found"
fi

# Backup stack-specific .env files if they exist
log "Checking for stack-specific .env files..."
for stack_dir in "$REPO_ROOT/stacks"/*; do
    if [ -d "$stack_dir" ] && [ -f "$stack_dir/.env" ]; then
        stack_name=$(basename "$stack_dir")
        log "  Backing up .env from stacks/$stack_name/"
        mkdir -p "$BACKUP_PATH/stacks/$stack_name"
        cp "$stack_dir/.env" "$BACKUP_PATH/stacks/$stack_name/.env"
    fi
done

# Backup docker-compose files
log "Backing up docker-compose files..."
mkdir -p "$BACKUP_PATH/stacks"
for stack_dir in "$REPO_ROOT/stacks"/*; do
    if [ -d "$stack_dir" ]; then
        stack_name=$(basename "$stack_dir")
        mkdir -p "$BACKUP_PATH/stacks/$stack_name"
        
        # Copy compose files
        for compose_file in "$stack_dir"/docker-compose*.yml; do
            if [ -f "$compose_file" ]; then
                cp "$compose_file" "$BACKUP_PATH/stacks/$stack_name/"
            fi
        done
        
        # Copy override files if they exist
        if [ -f "$stack_dir/docker-compose.override.yml" ]; then
            cp "$stack_dir/docker-compose.override.yml" "$BACKUP_PATH/stacks/$stack_name/"
        fi
    fi
done

# Backup configuration templates
if [ -d "$REPO_ROOT/config" ]; then
    log "Backing up configuration templates..."
    cp -r "$REPO_ROOT/config" "$BACKUP_PATH/"
fi

# Backup Keepalived configuration
log "Backing up Keepalived configuration..."
mkdir -p "$BACKUP_PATH/keepalived"
if [ -d "$REPO_ROOT/stacks/dns/keepalived" ]; then
    cp -r "$REPO_ROOT/stacks/dns/keepalived"/* "$BACKUP_PATH/keepalived/" 2>/dev/null || true
fi

# Backup Unbound configuration
log "Backing up Unbound configuration..."
mkdir -p "$BACKUP_PATH/unbound"
if [ -d "$REPO_ROOT/stacks/dns/unbound" ]; then
    cp -r "$REPO_ROOT/stacks/dns/unbound"/* "$BACKUP_PATH/unbound/" 2>/dev/null || true
fi

# Backup Pi-hole configuration (from Docker volumes)
log "Backing up Pi-hole configuration from Docker volumes..."
mkdir -p "$BACKUP_PATH/pihole"

# Try to backup Pi-hole gravity database and configuration
for instance in primary secondary; do
    container="pihole_${instance}"
    
    if docker ps -q -f name="$container" > /dev/null 2>&1; then
        log "  Backing up Pi-hole $instance..."
        
        # Backup gravity database
        docker exec "$container" tar czf /tmp/pihole-backup.tar.gz \
            /etc/pihole /etc/dnsmasq.d 2>/dev/null || warn "Could not backup $container config"
        
        docker cp "$container:/tmp/pihole-backup.tar.gz" \
            "$BACKUP_PATH/pihole/${instance}-config.tar.gz" 2>/dev/null || warn "Could not copy $container backup"
        
        docker exec "$container" rm -f /tmp/pihole-backup.tar.gz 2>/dev/null || true
        
        # Export custom DNS records
        docker exec "$container" pihole -a -l > "$BACKUP_PATH/pihole/${instance}-customdns.txt" 2>/dev/null || true
    else
        warn "Container $container is not running, skipping Pi-hole backup"
    fi
done

# Backup profiles
if [ -d "$REPO_ROOT/profiles" ]; then
    log "Backing up DNS security profiles..."
    cp -r "$REPO_ROOT/profiles" "$BACKUP_PATH/"
fi

# Backup Prometheus configuration (if exists)
if [ -d "$REPO_ROOT/stacks/monitoring/prometheus" ]; then
    log "Backing up Prometheus configuration..."
    mkdir -p "$BACKUP_PATH/prometheus"
    cp -r "$REPO_ROOT/stacks/monitoring/prometheus"/* "$BACKUP_PATH/prometheus/" 2>/dev/null || true
fi

# Backup Grafana dashboards (if exists)
if [ -d "$REPO_ROOT/stacks/monitoring/grafana" ]; then
    log "Backing up Grafana dashboards..."
    mkdir -p "$BACKUP_PATH/grafana"
    cp -r "$REPO_ROOT/stacks/monitoring/grafana"/* "$BACKUP_PATH/grafana/" 2>/dev/null || true
fi

# Export Grafana dashboards from running instance (optional)
if docker ps -q -f name="grafana" > /dev/null 2>&1; then
    log "Exporting Grafana dashboards from running instance..."
    # TODO: Use Grafana API to export dashboards
    # This requires Grafana admin credentials
fi

# Create backup metadata
log "Creating backup metadata..."
cat > "$BACKUP_PATH/backup-info.txt" <<EOF
Orion Sentinel DNS HA - Configuration Backup
=============================================

Backup Created: $(date)
Backup Name: $BACKUP_NAME
Hostname: $(hostname)
System: $(uname -a)

Contents:
- Environment configuration (.env)
- Docker Compose files
- Keepalived configuration
- Unbound configuration  
- Pi-hole configuration and databases
- DNS security profiles
- Prometheus configuration
- Grafana dashboards

Restore Instructions:
1. Copy this backup to target system
2. Extract: tar xzf ${BACKUP_NAME}.tar.gz
3. Run: bash scripts/restore-config.sh $BACKUP_NAME

EOF

# List what was backed up
log "Creating file manifest..."
find "$BACKUP_PATH" -type f > "$BACKUP_PATH/manifest.txt"

# Create compressed archive
log "Creating compressed archive..."
cd "$BACKUP_DIR"
tar czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME"

# Calculate checksum
log "Calculating checksum..."
sha256sum "${BACKUP_NAME}.tar.gz" > "${BACKUP_NAME}.tar.gz.sha256"

# Cleanup temporary directory
rm -rf "$BACKUP_PATH"

# Display summary
BACKUP_SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" | cut -f1)

echo ""
echo "================================================================"
log "Backup completed successfully!"
echo "================================================================"
log "Backup file: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
log "Size: $BACKUP_SIZE"
log "Checksum: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz.sha256"
echo ""
log "To restore this backup on another system:"
log "  1. Copy the backup file to the target system"
log "  2. Run: bash scripts/restore-config.sh ${BACKUP_NAME}.tar.gz"
echo ""

# Optional: Cleanup old backups (keep last 10)
KEEP_BACKUPS=${KEEP_BACKUPS:-10}
if [ "$KEEP_BACKUPS" -gt 0 ]; then
    log "Cleaning up old backups (keeping last $KEEP_BACKUPS)..."
    cd "$BACKUP_DIR"
    ls -t dns-ha-backup-*.tar.gz 2>/dev/null | tail -n +$((KEEP_BACKUPS + 1)) | xargs -r rm -f
    ls -t dns-ha-backup-*.tar.gz.sha256 2>/dev/null | tail -n +$((KEEP_BACKUPS + 1)) | xargs -r rm -f
fi

log "Backup completed: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
