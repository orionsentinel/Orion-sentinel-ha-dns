#!/usr/bin/env bash
# =============================================================================
# Orion DNS HA - Host-Level Backup Script
# =============================================================================
#
# Creates timestamped compressed backups of critical configuration:
#   - compose.yml
#   - .env* files
#   - pihole/etc-pihole (gravity DB, settings)
#   - pihole/etc-dnsmasq.d (dnsmasq configs)
#   - keepalived/config (keepalived.conf + scripts)
#
# Implements retention-based pruning of old backups.
#
# Usage:
#   ./orion-dns-backup.sh                    # Run backup with defaults
#   BACKUP_RETENTION_DAYS=30 ./orion-dns-backup.sh  # Custom retention
#
# Exit Codes:
#   0 - Backup completed successfully
#   1 - Backup failed
#
# Environment Variables:
#   REPO_DIR               - Path to repository (default: /opt/orion-dns-ha)
#   BACKUP_RETENTION_DAYS  - Days to keep backups (default: 14)
#
# =============================================================================

set -euo pipefail

# Configuration
REPO_DIR="${REPO_DIR:-/opt/orion-dns-ha}"
BACKUP_DIR="${REPO_DIR}/backups"
HOST="$(hostname -s 2>/dev/null || echo unknown)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-14}"

# Create backup directory if it doesn't exist
mkdir -p "${BACKUP_DIR}"

BACKUP_FILE="${BACKUP_DIR}/dns-ha-backup-${HOST}-${TIMESTAMP}.tgz"

# Logging function
log() {
    echo "[$(date -Iseconds)] [backup] $*" >&2
}

log "Starting backup to ${BACKUP_FILE}"

# Change to repo directory
if [[ ! -d "${REPO_DIR}" ]]; then
    log "Repository directory ${REPO_DIR} not found."
    exit 1
fi

cd "${REPO_DIR}"

# Build list of files/directories to backup (only if they exist)
backup_items=()

if [[ -f "compose.yml" ]]; then
    backup_items+=("compose.yml")
fi

# Include all .env files (main and variants)
for envfile in .env .env.*; do
    if [[ -f "${envfile}" ]]; then
        backup_items+=("${envfile}")
    fi
done

if [[ -d "pihole/etc-pihole" ]]; then
    backup_items+=("pihole/etc-pihole")
fi

if [[ -d "pihole/etc-dnsmasq.d" ]]; then
    backup_items+=("pihole/etc-dnsmasq.d")
fi

if [[ -d "keepalived/config" ]]; then
    backup_items+=("keepalived/config")
fi

# Check if we have anything to backup
if [[ ${#backup_items[@]} -eq 0 ]]; then
    log "No items found to backup."
    exit 1
fi

log "Backing up: ${backup_items[*]}"

# Create the tarball
if ! tar -czf "${BACKUP_FILE}" \
    --exclude='backups' \
    "${backup_items[@]}"; then
    log "Backup tar failed."
    exit 1
fi

log "Backup completed: ${BACKUP_FILE}"

# Get backup file size
BACKUP_SIZE="$(du -h "${BACKUP_FILE}" | cut -f1)"
log "Backup size: ${BACKUP_SIZE}"

# =============================================================================
# Retention: delete backups older than RETENTION_DAYS
# =============================================================================
if [[ -n "${RETENTION_DAYS}" ]] && [[ "${RETENTION_DAYS}" -gt 0 ]]; then
    log "Pruning backups older than ${RETENTION_DAYS} days."
    find "${BACKUP_DIR}" -type f -name 'dns-ha-backup-*.tgz' -mtime "+${RETENTION_DAYS}" -print -delete 2>/dev/null || true
fi

log "Backup & prune done."
exit 0
