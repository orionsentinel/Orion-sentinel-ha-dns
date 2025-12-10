#!/usr/bin/env bash
# =============================================================================
# Orion DNS HA - Restore Script
# =============================================================================
#
# Restores configuration from a backup tarball created by orion-dns-backup.sh.
#
# Usage:
#   ./orion-dns-restore.sh <backup-file.tgz>         # Restore from backup
#   ./orion-dns-restore.sh --list                    # List available backups
#   ./orion-dns-restore.sh --dry-run <backup-file>   # Preview restore
#
# Exit Codes:
#   0 - Restore completed successfully
#   1 - Restore failed or invalid arguments
#
# Environment Variables:
#   REPO_DIR  - Path to repository (default: /opt/orion-dns-ha)
#
# =============================================================================

set -euo pipefail

# Configuration
REPO_DIR="${REPO_DIR:-/opt/orion-dns-ha}"
BACKUP_DIR="${REPO_DIR}/backups"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[restore]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[restore][WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[restore][ERROR]${NC} $*" >&2
}

log_info() {
    echo -e "${BLUE}[restore][INFO]${NC} $*"
}

# Show usage
usage() {
    cat <<EOF
Usage: $0 [options] <backup-file.tgz>

Restore configuration from a backup tarball.

Options:
    --list          List available backups in ${BACKUP_DIR}
    --dry-run       Preview what would be restored without making changes
    -h, --help      Show this help message

Examples:
    # List available backups
    $0 --list

    # Preview restore
    $0 --dry-run backups/dns-ha-backup-pi1-20240115-031500.tgz

    # Restore from backup
    $0 backups/dns-ha-backup-pi1-20240115-031500.tgz

Restore Process:
    1. Stop the DNS stack (docker compose down)
    2. Extract backup over existing files
    3. Start the DNS stack (docker compose up -d)

WARNING: This will overwrite existing configuration files!
         Create a backup before restoring if needed.

EOF
    exit 0
}

# List available backups
list_backups() {
    log "Available backups in ${BACKUP_DIR}:"
    echo ""
    
    if [[ ! -d "${BACKUP_DIR}" ]]; then
        log_warn "Backup directory does not exist: ${BACKUP_DIR}"
        exit 1
    fi
    
    # List backups with size and date
    local count=0
    while IFS= read -r -d '' backup; do
        local size
        size="$(du -h "${backup}" | cut -f1)"
        local date
        date="$(stat -c '%y' "${backup}" 2>/dev/null | cut -d'.' -f1 || stat -f '%Sm' "${backup}" 2>/dev/null)"
        local filename
        filename="$(basename "${backup}")"
        
        echo "  ${filename}"
        echo "    Size: ${size}, Created: ${date}"
        echo ""
        ((count++)) || true
    done < <(find "${BACKUP_DIR}" -name 'dns-ha-backup-*.tgz' -type f -print0 | sort -z)
    
    if [[ ${count} -eq 0 ]]; then
        log_warn "No backups found."
    else
        log "${count} backup(s) found."
    fi
    
    exit 0
}

# Preview restore (dry-run)
dry_run() {
    local backup_file="$1"
    
    log "Dry-run: Previewing contents of ${backup_file}"
    echo ""
    
    if [[ ! -f "${backup_file}" ]]; then
        log_error "Backup file not found: ${backup_file}"
        exit 1
    fi
    
    log_info "Contents of backup:"
    tar -tzf "${backup_file}" | head -50
    
    local total_files
    total_files="$(tar -tzf "${backup_file}" | wc -l)"
    
    echo ""
    log_info "Total files in backup: ${total_files}"
    log_info "Backup would be extracted to: ${REPO_DIR}"
    log_warn "No changes made (dry-run mode)."
    
    exit 0
}

# Perform restore
restore() {
    local backup_file="$1"
    
    # Validate backup file
    if [[ ! -f "${backup_file}" ]]; then
        log_error "Backup file not found: ${backup_file}"
        exit 1
    fi
    
    # Make path absolute if relative
    if [[ ! "${backup_file}" = /* ]]; then
        backup_file="$(pwd)/${backup_file}"
    fi
    
    log "Starting restore from: ${backup_file}"
    
    # Change to repo directory
    if [[ ! -d "${REPO_DIR}" ]]; then
        log_error "Repository directory not found: ${REPO_DIR}"
        exit 1
    fi
    
    cd "${REPO_DIR}"
    
    # Confirmation prompt (skip if non-interactive)
    if [[ -t 0 ]]; then
        echo ""
        log_warn "This will overwrite existing configuration files in ${REPO_DIR}"
        echo -n "Are you sure you want to continue? [y/N] "
        read -r response
        
        if [[ ! "${response}" =~ ^[Yy]$ ]]; then
            log "Restore cancelled by user."
            exit 0
        fi
    fi
    
    # Step 1: Stop the DNS stack
    log "Stopping DNS stack..."
    if docker compose ps -q 2>/dev/null | grep -q .; then
        docker compose down || log_warn "Failed to stop stack (may not be running)"
    else
        log_info "No containers running."
    fi
    
    # Step 2: Extract backup
    log "Extracting backup..."
    if ! tar -xzf "${backup_file}" -C "${REPO_DIR}"; then
        log_error "Failed to extract backup."
        exit 1
    fi
    log "Backup extracted successfully."
    
    # Step 3: Start the DNS stack
    log "Starting DNS stack..."
    
    # Determine which profile to use based on NODE_ROLE if set
    if [[ -f "${REPO_DIR}/.env" ]]; then
        # shellcheck source=/dev/null
        source "${REPO_DIR}/.env" 2>/dev/null || true
    fi
    
    local profile=""
    case "${NODE_ROLE:-}" in
        MASTER)
            profile="two-node-ha-primary"
            ;;
        BACKUP)
            profile="two-node-ha-backup"
            ;;
        *)
            # Try to auto-detect or use default
            if docker compose config --profiles 2>/dev/null | grep -q "two-node-ha"; then
                log_info "Using default profile from compose.yml"
            fi
            ;;
    esac
    
    if [[ -n "${profile}" ]]; then
        docker compose --profile "${profile}" up -d || log_warn "Failed to start stack with profile ${profile}"
    else
        docker compose up -d || log_warn "Failed to start stack"
    fi
    
    # Step 4: Verify
    log "Verifying restore..."
    sleep 5
    
    if docker compose ps -q 2>/dev/null | grep -q .; then
        log "Containers started:"
        docker compose ps --format "table {{.Name}}\t{{.Status}}"
    else
        log_warn "No containers running after restore."
    fi
    
    echo ""
    log "Restore completed!"
    log_info "Check DNS resolution: dig @<VIP> github.com"
    log_info "Check Pi-hole admin: http://<NODE_IP>/admin"
    
    exit 0
}

# =============================================================================
# Main
# =============================================================================
main() {
    local dry_run_mode=false
    local backup_file=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --list)
                list_backups
                ;;
            --dry-run)
                dry_run_mode=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                ;;
            *)
                backup_file="$1"
                shift
                ;;
        esac
    done
    
    # Validate
    if [[ -z "${backup_file}" ]]; then
        log_error "No backup file specified."
        echo ""
        usage
    fi
    
    if [[ "${dry_run_mode}" == true ]]; then
        dry_run "${backup_file}"
    else
        restore "${backup_file}"
    fi
}

main "$@"
