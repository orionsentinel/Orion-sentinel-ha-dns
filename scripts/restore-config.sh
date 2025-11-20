#!/bin/bash
# Configuration Restore Script for Orion Sentinel DNS HA
# Restores configuration from backup created by backup-config.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[restore]${NC} $*"; }
warn() { echo -e "${YELLOW}[restore][WARNING]${NC} $*"; }
error() { echo -e "${RED}[restore][ERROR]${NC} $*" >&2; }
info() { echo -e "${BLUE}[restore][INFO]${NC} $*"; }

usage() {
    cat <<EOF
Usage: $0 <backup-file.tar.gz> [options]

Restore configuration from backup

Options:
    --skip-pihole       Skip Pi-hole data restoration
    --skip-compose      Skip docker-compose file restoration
    --dry-run           Show what would be restored without making changes
    --help              Show this help message

Examples:
    $0 dns-ha-backup-20231120_143022.tar.gz
    $0 backups/dns-ha-backup-20231120_143022.tar.gz --dry-run
    $0 /path/to/backup.tar.gz --skip-pihole

EOF
    exit 1
}

# Parse arguments
BACKUP_FILE=""
SKIP_PIHOLE=false
SKIP_COMPOSE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-pihole)
            SKIP_PIHOLE=true
            shift
            ;;
        --skip-compose)
            SKIP_COMPOSE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            usage
            ;;
        *)
            if [ -z "$BACKUP_FILE" ]; then
                BACKUP_FILE="$1"
            else
                error "Unknown option: $1"
                usage
            fi
            shift
            ;;
    esac
done

# Validate backup file
if [ -z "$BACKUP_FILE" ]; then
    error "No backup file specified"
    usage
fi

if [ ! -f "$BACKUP_FILE" ]; then
    error "Backup file not found: $BACKUP_FILE"
    exit 1
fi

# Verify checksum if available
CHECKSUM_FILE="${BACKUP_FILE}.sha256"
if [ -f "$CHECKSUM_FILE" ]; then
    log "Verifying backup checksum..."
    if sha256sum -c "$CHECKSUM_FILE"; then
        log "✅ Checksum verified"
    else
        error "❌ Checksum verification failed! Backup may be corrupted."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
else
    warn "No checksum file found, skipping verification"
fi

# Extract backup to temporary directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

log "Extracting backup to temporary directory..."
tar xzf "$BACKUP_FILE" -C "$TEMP_DIR"

# Find the backup directory
BACKUP_DIR=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "dns-ha-backup-*" | head -n 1)

if [ -z "$BACKUP_DIR" ] || [ ! -d "$BACKUP_DIR" ]; then
    error "Invalid backup archive structure"
    exit 1
fi

# Display backup info
if [ -f "$BACKUP_DIR/backup-info.txt" ]; then
    echo ""
    echo "================================================================"
    cat "$BACKUP_DIR/backup-info.txt"
    echo "================================================================"
    echo ""
fi

if [ "$DRY_RUN" = true ]; then
    warn "DRY-RUN MODE: No changes will be made"
    echo ""
fi

# Confirm restoration
if [ "$DRY_RUN" = false ]; then
    warn "This will overwrite current configuration files!"
    read -p "Continue with restoration? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Restoration cancelled"
        exit 0
    fi
fi

# Create backup of current configuration before restoring
if [ "$DRY_RUN" = false ]; then
    log "Creating safety backup of current configuration..."
    SAFETY_BACKUP="$REPO_ROOT/backups/pre-restore-backup-$(date '+%Y%m%d_%H%M%S').tar.gz"
    mkdir -p "$REPO_ROOT/backups"
    
    if [ -f "$REPO_ROOT/.env" ]; then
        tar czf "$SAFETY_BACKUP" -C "$REPO_ROOT" .env 2>/dev/null || true
    fi
    
    log "Safety backup created: $SAFETY_BACKUP"
fi

# Restore .env file
if [ -f "$BACKUP_DIR/.env" ]; then
    if [ "$DRY_RUN" = true ]; then
        info "[DRY-RUN] Would restore .env file"
    else
        log "Restoring .env file..."
        cp "$BACKUP_DIR/.env" "$REPO_ROOT/.env"
        log "✅ .env restored"
    fi
else
    warn "No .env file in backup"
fi

# Restore configuration templates
if [ -d "$BACKUP_DIR/config" ]; then
    if [ "$DRY_RUN" = true ]; then
        info "[DRY-RUN] Would restore config/ directory"
    else
        log "Restoring configuration templates..."
        mkdir -p "$REPO_ROOT/config"
        cp -r "$BACKUP_DIR/config"/* "$REPO_ROOT/config/" 2>/dev/null || true
        log "✅ Configuration templates restored"
    fi
fi

# Restore Keepalived configuration
if [ -d "$BACKUP_DIR/keepalived" ]; then
    if [ "$DRY_RUN" = true ]; then
        info "[DRY-RUN] Would restore Keepalived configuration"
    else
        log "Restoring Keepalived configuration..."
        mkdir -p "$REPO_ROOT/stacks/dns/keepalived"
        cp -r "$BACKUP_DIR/keepalived"/* "$REPO_ROOT/stacks/dns/keepalived/" 2>/dev/null || true
        log "✅ Keepalived configuration restored"
    fi
fi

# Restore Unbound configuration
if [ -d "$BACKUP_DIR/unbound" ]; then
    if [ "$DRY_RUN" = true ]; then
        info "[DRY-RUN] Would restore Unbound configuration"
    else
        log "Restoring Unbound configuration..."
        mkdir -p "$REPO_ROOT/stacks/dns/unbound"
        cp -r "$BACKUP_DIR/unbound"/* "$REPO_ROOT/stacks/dns/unbound/" 2>/dev/null || true
        log "✅ Unbound configuration restored"
    fi
fi

# Restore docker-compose files
if [ "$SKIP_COMPOSE" = false ] && [ -d "$BACKUP_DIR/stacks" ]; then
    if [ "$DRY_RUN" = true ]; then
        info "[DRY-RUN] Would restore docker-compose files"
    else
        log "Restoring docker-compose files..."
        for stack_dir in "$BACKUP_DIR/stacks"/*; do
            if [ -d "$stack_dir" ]; then
                stack_name=$(basename "$stack_dir")
                mkdir -p "$REPO_ROOT/stacks/$stack_name"
                cp -r "$stack_dir"/* "$REPO_ROOT/stacks/$stack_name/" 2>/dev/null || true
            fi
        done
        log "✅ Docker-compose files restored"
    fi
fi

# Restore profiles
if [ -d "$BACKUP_DIR/profiles" ]; then
    if [ "$DRY_RUN" = true ]; then
        info "[DRY-RUN] Would restore DNS security profiles"
    else
        log "Restoring DNS security profiles..."
        mkdir -p "$REPO_ROOT/profiles"
        cp -r "$BACKUP_DIR/profiles"/* "$REPO_ROOT/profiles/" 2>/dev/null || true
        log "✅ Profiles restored"
    fi
fi

# Restore Pi-hole configuration
if [ "$SKIP_PIHOLE" = false ] && [ -d "$BACKUP_DIR/pihole" ]; then
    log "Pi-hole data restoration available..."
    
    for instance in primary secondary; do
        config_file="$BACKUP_DIR/pihole/${instance}-config.tar.gz"
        container="pihole_${instance}"
        
        if [ -f "$config_file" ]; then
            if [ "$DRY_RUN" = true ]; then
                info "[DRY-RUN] Would restore Pi-hole $instance configuration"
            else
                # Check if container is running
                if docker ps -q -f name="$container" > /dev/null 2>&1; then
                    log "Restoring Pi-hole $instance configuration..."
                    
                    # Copy backup to container
                    docker cp "$config_file" "$container:/tmp/pihole-backup.tar.gz"
                    
                    # Extract in container
                    docker exec "$container" sh -c "cd / && tar xzf /tmp/pihole-backup.tar.gz"
                    docker exec "$container" rm -f /tmp/pihole-backup.tar.gz
                    
                    log "✅ Pi-hole $instance configuration restored"
                    warn "   Restart Pi-hole $instance for changes to take effect"
                else
                    warn "Container $container is not running, skipping Pi-hole restoration"
                    info "   Start the stack first, then run restore again"
                fi
            fi
        fi
    done
fi

# Restore Prometheus configuration
if [ -d "$BACKUP_DIR/prometheus" ]; then
    if [ "$DRY_RUN" = true ]; then
        info "[DRY-RUN] Would restore Prometheus configuration"
    else
        log "Restoring Prometheus configuration..."
        mkdir -p "$REPO_ROOT/stacks/monitoring/prometheus"
        cp -r "$BACKUP_DIR/prometheus"/* "$REPO_ROOT/stacks/monitoring/prometheus/" 2>/dev/null || true
        log "✅ Prometheus configuration restored"
    fi
fi

# Restore Grafana dashboards
if [ -d "$BACKUP_DIR/grafana" ]; then
    if [ "$DRY_RUN" = true ]; then
        info "[DRY-RUN] Would restore Grafana dashboards"
    else
        log "Restoring Grafana dashboards..."
        mkdir -p "$REPO_ROOT/stacks/monitoring/grafana"
        cp -r "$BACKUP_DIR/grafana"/* "$REPO_ROOT/stacks/monitoring/grafana/" 2>/dev/null || true
        log "✅ Grafana dashboards restored"
    fi
fi

# Summary
echo ""
echo "================================================================"
if [ "$DRY_RUN" = true ]; then
    log "Dry-run completed. No changes were made."
    log "Run without --dry-run to apply restoration."
else
    log "Configuration restoration completed successfully!"
    echo ""
    log "Next steps:"
    log "  1. Review restored configuration files"
    log "  2. Update .env file with correct IP addresses if needed"
    log "  3. Restart the stack: docker compose down && docker compose up -d"
    log "  4. Verify services are running: docker ps"
    log "  5. Test DNS resolution: dig @192.168.8.255 google.com"
fi
echo "================================================================"
echo ""
