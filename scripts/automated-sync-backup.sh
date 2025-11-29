#!/usr/bin/env bash
# Automated Sync and Backup Service for Orion Sentinel DNS HA
# Combines backup creation with remote sync for complete disaster recovery
#
# Features:
# - Scheduled automated backups
# - Remote backup replication to peer node
# - Off-site backup support (NAS, cloud via rclone)
# - Backup verification and integrity checks
# - Retention policy management
# - Notification on backup completion/failure
#
# Usage:
#   ./automated-sync-backup.sh [options]
#
# Options:
#   --backup          Create a local backup
#   --sync            Sync backup to peer node
#   --offsite         Sync backup to off-site storage
#   --verify          Verify backup integrity
#   --all             Perform backup, sync, and verification (default)
#   --daemon          Run as daemon with scheduled backups
#   --status          Show backup status
#   -h, --help        Show this help message

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load configuration
if [ -f "$REPO_ROOT/.env" ]; then
    # shellcheck disable=SC1091
    source "$REPO_ROOT/.env"
fi

# Configuration with defaults
BACKUP_DIR="${BACKUP_DIR:-$REPO_ROOT/backups}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
BACKUP_KEEP_COUNT="${BACKUP_KEEP_COUNT:-10}"
PEER_IP="${PEER_IP:-}"
NODE_ROLE="${NODE_ROLE:-primary}"
SSH_USER="${SYNC_SSH_USER:-pi}"
SSH_KEY="${SYNC_SSH_KEY:-$HOME/.ssh/id_rsa}"
SSH_PORT="${SYNC_SSH_PORT:-22}"
REMOTE_BACKUP_DIR="${REMOTE_BACKUP_DIR:-/opt/rpi-ha-dns-stack/backups}"
OFFSITE_ENABLED="${OFFSITE_BACKUP_ENABLED:-false}"
OFFSITE_TYPE="${OFFSITE_TYPE:-}"  # nas, rclone, s3
OFFSITE_PATH="${OFFSITE_PATH:-}"  # Path or rclone remote
NAS_HOST="${NAS_HOST:-}"
NAS_PATH="${NAS_PATH:-}"
NAS_USER="${NAS_USER:-}"
RCLONE_REMOTE="${RCLONE_REMOTE:-}"
BACKUP_INTERVAL="${BACKUP_INTERVAL:-86400}"  # 24 hours default
LOG_DIR="${LOG_DIR:-$REPO_ROOT/logs}"
LOG_FILE="${LOG_DIR}/sync-backup.log"
LOCK_FILE="/tmp/sync-backup.lock"
NOTIFICATION_WEBHOOK="${NOTIFICATION_WEBHOOK:-}"
NOTIFICATION_SIGNAL="${NOTIFICATION_SIGNAL:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log() { 
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $*"
    echo -e "${GREEN}${msg}${NC}"
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

warn() { 
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $*"
    echo -e "${YELLOW}${msg}${NC}"
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

error() { 
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*"
    echo -e "${RED}${msg}${NC}" >&2
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

info() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [DEBUG] $*"
    echo -e "${BLUE}${msg}${NC}"
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

# Show usage information
usage() {
    cat <<EOF
Usage: $0 [options]

Automated Sync and Backup Service for Orion Sentinel DNS HA
Creates backups and replicates them to peer nodes and off-site storage.

Options:
    --backup          Create a local backup only
    --sync            Sync latest backup to peer node only
    --offsite         Sync backup to off-site storage only
    --verify          Verify backup integrity only
    --all             Perform backup, sync, and verification (default)
    --daemon          Run as daemon with scheduled backups
    --status          Show backup status
    --cleanup         Clean up old backups based on retention policy
    -h, --help        Show this help message

Environment Variables:
    BACKUP_DIR              Local backup directory (default: ./backups)
    BACKUP_RETENTION_DAYS   Days to keep backups (default: 30)
    BACKUP_KEEP_COUNT       Minimum number of backups to keep (default: 10)
    PEER_IP                 IP address of peer node for sync
    OFFSITE_BACKUP_ENABLED  Enable off-site backup (true/false)
    OFFSITE_TYPE            Off-site type: nas, rclone, s3
    OFFSITE_PATH            Off-site storage path/remote
    BACKUP_INTERVAL         Seconds between backups in daemon mode (default: 86400)

Examples:
    # Create backup and sync to peer
    $0 --all
    
    # Just create a local backup
    $0 --backup
    
    # Run as background daemon
    $0 --daemon &

EOF
    exit 0
}

# Acquire lock to prevent concurrent backups
acquire_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local pid
        pid=$(cat "$LOCK_FILE" 2>/dev/null)
        if kill -0 "$pid" 2>/dev/null; then
            warn "Another backup process is running (PID: $pid)"
            return 1
        else
            warn "Stale lock file found, removing..."
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
    return 0
}

# Release lock
release_lock() {
    rm -f "$LOCK_FILE"
}

# Cleanup on exit
cleanup() {
    release_lock
}
trap cleanup EXIT

# Send notification
send_notification() {
    local status="$1"
    local message="$2"
    
    # Send webhook notification if configured
    if [ -n "$NOTIFICATION_WEBHOOK" ]; then
        curl -s -X POST "$NOTIFICATION_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{\"status\": \"$status\", \"message\": \"$message\", \"timestamp\": \"$(date -Iseconds)\"}" \
            > /dev/null 2>&1 || warn "Failed to send webhook notification"
    fi
    
    # Send Signal notification if enabled
    if [ "$NOTIFICATION_SIGNAL" = "true" ]; then
        local signal_api="${SIGNAL_API_URL:-http://localhost:8080}"
        curl -s -X POST "$signal_api/test" \
            -H "Content-Type: application/json" \
            -d "{\"message\": \"[$status] $message\"}" \
            > /dev/null 2>&1 || warn "Failed to send Signal notification"
    fi
}

# Create local backup
create_backup() {
    log "Creating local backup..."
    
    mkdir -p "$BACKUP_DIR"
    
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_name="dns-ha-backup-${timestamp}"
    local backup_path="$BACKUP_DIR/${backup_name}.tar.gz"
    local temp_dir
    temp_dir=$(mktemp -d)
    local backup_temp="$temp_dir/$backup_name"
    mkdir -p "$backup_temp"
    
    # Backup .env file
    if [ -f "$REPO_ROOT/.env" ]; then
        cp "$REPO_ROOT/.env" "$backup_temp/"
        info "Backed up .env file"
    fi
    
    # Backup docker-compose files
    mkdir -p "$backup_temp/stacks"
    for stack_dir in "$REPO_ROOT/stacks"/*; do
        if [ -d "$stack_dir" ]; then
            local stack_name
            stack_name=$(basename "$stack_dir")
            mkdir -p "$backup_temp/stacks/$stack_name"
            cp "$stack_dir"/docker-compose*.yml "$backup_temp/stacks/$stack_name/" 2>/dev/null || true
            [ -f "$stack_dir/.env" ] && cp "$stack_dir/.env" "$backup_temp/stacks/$stack_name/"
        fi
    done
    info "Backed up docker-compose files"
    
    # Backup Keepalived configuration
    if [ -d "$REPO_ROOT/stacks/dns/keepalived" ]; then
        mkdir -p "$backup_temp/keepalived"
        cp -r "$REPO_ROOT/stacks/dns/keepalived"/* "$backup_temp/keepalived/" 2>/dev/null || true
        info "Backed up Keepalived configuration"
    fi
    
    # Backup Unbound configuration
    if [ -d "$REPO_ROOT/stacks/dns/unbound" ]; then
        mkdir -p "$backup_temp/unbound"
        cp -r "$REPO_ROOT/stacks/dns/unbound"/* "$backup_temp/unbound/" 2>/dev/null || true
        info "Backed up Unbound configuration"
    fi
    
    # Backup profiles
    if [ -d "$REPO_ROOT/profiles" ]; then
        cp -r "$REPO_ROOT/profiles" "$backup_temp/"
        info "Backed up DNS security profiles"
    fi
    
    # Backup Pi-hole data from containers
    mkdir -p "$backup_temp/pihole"
    for instance in primary secondary; do
        local container="pihole_${instance}"
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${container}$"; then
            info "Backing up Pi-hole $instance..."
            docker exec "$container" tar czf - /etc/pihole /etc/dnsmasq.d 2>/dev/null > \
                "$backup_temp/pihole/${instance}-config.tar.gz" || \
                warn "Could not backup $container config"
        fi
    done
    
    # Create backup metadata
    cat > "$backup_temp/backup-info.txt" <<EOF
Orion Sentinel DNS HA - Automated Backup
==========================================

Backup Created: $(date)
Backup Name: $backup_name
Hostname: $(hostname)
Node Role: $NODE_ROLE
System: $(uname -a)

Contents:
- Environment configuration (.env)
- Docker Compose files
- Keepalived configuration
- Unbound configuration
- Pi-hole configuration and databases
- DNS security profiles

Restore Instructions:
1. Copy this backup to target system
2. Extract: tar xzf ${backup_name}.tar.gz
3. Run: bash scripts/restore-config.sh ${backup_name}

EOF
    
    # Create file manifest
    find "$backup_temp" -type f > "$backup_temp/manifest.txt"
    
    # Create compressed archive
    log "Creating compressed archive..."
    cd "$temp_dir" || exit
    tar czf "$backup_path" "$backup_name"
    
    # Calculate checksum
    sha256sum "$backup_path" > "${backup_path}.sha256"
    
    # Cleanup temp directory
    rm -rf "$temp_dir"
    
    local backup_size
    backup_size=$(du -h "$backup_path" | cut -f1)
    log "Backup created: $backup_path ($backup_size)"
    
    echo "$backup_path"
}

# Sync backup to peer node
sync_to_peer() {
    local backup_file="$1"
    
    if [ -z "$PEER_IP" ]; then
        warn "PEER_IP not configured, skipping peer sync"
        return 0
    fi
    
    log "Syncing backup to peer node $PEER_IP..."
    
    # Test SSH connection
    if ! ssh -q -o BatchMode=yes -o ConnectTimeout=10 \
        -i "$SSH_KEY" -p "$SSH_PORT" \
        "${SSH_USER}@${PEER_IP}" "exit 0" 2>/dev/null; then
        error "Cannot connect to peer node $PEER_IP"
        return 1
    fi
    
    # Ensure remote backup directory exists
    ssh -q -o BatchMode=yes -i "$SSH_KEY" -p "$SSH_PORT" \
        "${SSH_USER}@${PEER_IP}" "mkdir -p '$REMOTE_BACKUP_DIR'" 2>/dev/null
    
    # Transfer backup file
    if rsync -avz --progress \
        -e "ssh -i $SSH_KEY -p $SSH_PORT" \
        "$backup_file" "${SSH_USER}@${PEER_IP}:${REMOTE_BACKUP_DIR}/"; then
        log "Backup synced to peer successfully"
        
        # Also sync checksum file
        if [ -f "${backup_file}.sha256" ]; then
            rsync -avz -e "ssh -i $SSH_KEY -p $SSH_PORT" \
                "${backup_file}.sha256" "${SSH_USER}@${PEER_IP}:${REMOTE_BACKUP_DIR}/"
        fi
        
        return 0
    else
        error "Failed to sync backup to peer"
        return 1
    fi
}

# Sync backup to off-site storage
sync_to_offsite() {
    local backup_file="$1"
    
    if [ "$OFFSITE_ENABLED" != "true" ]; then
        info "Off-site backup not enabled, skipping"
        return 0
    fi
    
    log "Syncing backup to off-site storage..."
    
    case "$OFFSITE_TYPE" in
        nas)
            if [ -z "$NAS_HOST" ] || [ -z "$NAS_PATH" ]; then
                error "NAS configuration incomplete (NAS_HOST, NAS_PATH required)"
                return 1
            fi
            
            log "Syncing to NAS: ${NAS_HOST}:${NAS_PATH}"
            if rsync -avz --progress \
                -e "ssh" \
                "$backup_file" "${NAS_USER}@${NAS_HOST}:${NAS_PATH}/"; then
                log "Backup synced to NAS successfully"
                
                # Sync checksum
                [ -f "${backup_file}.sha256" ] && \
                    rsync -avz -e "ssh" "${backup_file}.sha256" "${NAS_USER}@${NAS_HOST}:${NAS_PATH}/"
            else
                error "Failed to sync to NAS"
                return 1
            fi
            ;;
        
        rclone)
            if [ -z "$RCLONE_REMOTE" ]; then
                error "RCLONE_REMOTE not configured"
                return 1
            fi
            
            if ! command -v rclone &> /dev/null; then
                error "rclone not installed"
                return 1
            fi
            
            log "Syncing to rclone remote: $RCLONE_REMOTE"
            if rclone copy "$backup_file" "$RCLONE_REMOTE" --progress; then
                log "Backup synced to rclone remote successfully"
                
                # Sync checksum
                [ -f "${backup_file}.sha256" ] && \
                    rclone copy "${backup_file}.sha256" "$RCLONE_REMOTE"
            else
                error "Failed to sync to rclone remote"
                return 1
            fi
            ;;
        
        s3)
            if [ -z "$OFFSITE_PATH" ]; then
                error "OFFSITE_PATH (S3 bucket) not configured"
                return 1
            fi
            
            if ! command -v aws &> /dev/null; then
                error "AWS CLI not installed"
                return 1
            fi
            
            log "Syncing to S3: $OFFSITE_PATH"
            if aws s3 cp "$backup_file" "$OFFSITE_PATH/"; then
                log "Backup synced to S3 successfully"
                
                # Sync checksum
                [ -f "${backup_file}.sha256" ] && \
                    aws s3 cp "${backup_file}.sha256" "$OFFSITE_PATH/"
            else
                error "Failed to sync to S3"
                return 1
            fi
            ;;
        
        *)
            error "Unknown off-site type: $OFFSITE_TYPE"
            return 1
            ;;
    esac
    
    return 0
}

# Verify backup integrity
verify_backup() {
    local backup_file="${1:-}"
    
    if [ -z "$backup_file" ]; then
        # Find latest backup
        backup_file=$(ls -t "$BACKUP_DIR"/dns-ha-backup-*.tar.gz 2>/dev/null | head -1)
    fi
    
    if [ -z "$backup_file" ] || [ ! -f "$backup_file" ]; then
        error "No backup file found to verify"
        return 1
    fi
    
    log "Verifying backup integrity: $(basename "$backup_file")"
    
    local checksum_file="${backup_file}.sha256"
    
    # Verify checksum
    if [ -f "$checksum_file" ]; then
        cd "$(dirname "$backup_file")" || exit
        if sha256sum -c "$(basename "$checksum_file")" > /dev/null 2>&1; then
            log "✅ Checksum verification passed"
        else
            error "❌ Checksum verification failed!"
            return 1
        fi
    else
        warn "No checksum file found, skipping checksum verification"
    fi
    
    # Verify archive integrity
    if tar tzf "$backup_file" > /dev/null 2>&1; then
        log "✅ Archive integrity verified"
    else
        error "❌ Archive is corrupted!"
        return 1
    fi
    
    # Verify required files exist in archive
    local required_files=("backup-info.txt" "manifest.txt")
    local backup_contents
    backup_contents=$(tar tzf "$backup_file")
    
    for req_file in "${required_files[@]}"; do
        if echo "$backup_contents" | grep -q "$req_file"; then
            info "Found required file: $req_file"
        else
            warn "Missing expected file: $req_file"
        fi
    done
    
    log "Backup verification completed successfully"
    return 0
}

# Clean up old backups
cleanup_old_backups() {
    log "Cleaning up old backups..."
    
    local backup_count
    backup_count=$(find "$BACKUP_DIR" -name "dns-ha-backup-*.tar.gz" -type f 2>/dev/null | wc -l)
    
    if [ "$backup_count" -le "$BACKUP_KEEP_COUNT" ]; then
        info "Backup count ($backup_count) is within retention limit ($BACKUP_KEEP_COUNT), skipping cleanup"
        return 0
    fi
    
    # Delete backups older than retention period, but keep minimum count
    local deleted=0
    
    while IFS= read -r old_backup; do
        # Check if we're still above minimum count
        backup_count=$(find "$BACKUP_DIR" -name "dns-ha-backup-*.tar.gz" -type f 2>/dev/null | wc -l)
        if [ "$backup_count" -le "$BACKUP_KEEP_COUNT" ]; then
            break
        fi
        
        rm -f "$old_backup"
        rm -f "${old_backup}.sha256"
        deleted=$((deleted + 1))
        info "Deleted old backup: $(basename "$old_backup")"
    done < <(find "$BACKUP_DIR" -name "dns-ha-backup-*.tar.gz" -type f -mtime "+${BACKUP_RETENTION_DAYS}" 2>/dev/null | sort)
    
    if [ $deleted -gt 0 ]; then
        log "Cleaned up $deleted old backup(s)"
    else
        info "No old backups to clean up"
    fi
}

# Show backup status
show_status() {
    echo ""
    echo "═══════════════════════════════════════════════════"
    echo "  Backup Status"
    echo "═══════════════════════════════════════════════════"
    echo ""
    
    # Local backups
    echo "Local Backups:"
    echo "  Directory: $BACKUP_DIR"
    
    if [ -d "$BACKUP_DIR" ]; then
        local backup_count
        backup_count=$(find "$BACKUP_DIR" -name "dns-ha-backup-*.tar.gz" -type f 2>/dev/null | wc -l)
        echo "  Count: $backup_count"
        
        local total_size
        total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
        echo "  Total Size: $total_size"
        
        local latest_backup
        latest_backup=$(ls -t "$BACKUP_DIR"/dns-ha-backup-*.tar.gz 2>/dev/null | head -1)
        if [ -n "$latest_backup" ]; then
            echo "  Latest: $(basename "$latest_backup")"
            echo "  Created: $(stat -c %y "$latest_backup" 2>/dev/null | cut -d'.' -f1)"
        else
            echo "  Latest: None"
        fi
    else
        echo "  Status: Directory does not exist"
    fi
    
    echo ""
    echo "Peer Sync:"
    if [ -n "$PEER_IP" ]; then
        echo "  Peer IP: $PEER_IP"
        if ssh -q -o BatchMode=yes -o ConnectTimeout=5 \
            -i "$SSH_KEY" -p "$SSH_PORT" \
            "${SSH_USER}@${PEER_IP}" "exit 0" 2>/dev/null; then
            echo -e "  Status: ${GREEN}Connected${NC}"
            
            # Check peer backup count
            local peer_count
            peer_count=$(ssh -q -o BatchMode=yes -i "$SSH_KEY" -p "$SSH_PORT" \
                "${SSH_USER}@${PEER_IP}" \
                "find '$REMOTE_BACKUP_DIR' -name 'dns-ha-backup-*.tar.gz' -type f 2>/dev/null | wc -l" 2>/dev/null)
            echo "  Peer Backups: ${peer_count:-Unknown}"
        else
            echo -e "  Status: ${RED}Unreachable${NC}"
        fi
    else
        echo "  Status: Not configured"
    fi
    
    echo ""
    echo "Off-site Backup:"
    if [ "$OFFSITE_ENABLED" = "true" ]; then
        echo "  Type: $OFFSITE_TYPE"
        echo "  Status: Enabled"
    else
        echo "  Status: Disabled"
    fi
    
    echo ""
    echo "Retention Policy:"
    echo "  Max Age: $BACKUP_RETENTION_DAYS days"
    echo "  Min Count: $BACKUP_KEEP_COUNT backups"
    
    echo ""
}

# Run full backup cycle
run_backup_cycle() {
    local start_time
    start_time=$(date +%s)
    
    log "Starting backup cycle..."
    
    # Create backup
    local backup_file
    backup_file=$(create_backup)
    
    if [ -z "$backup_file" ] || [ ! -f "$backup_file" ]; then
        error "Backup creation failed"
        send_notification "error" "Backup creation failed on $(hostname)"
        return 1
    fi
    
    # Verify backup
    if ! verify_backup "$backup_file"; then
        error "Backup verification failed"
        send_notification "error" "Backup verification failed on $(hostname)"
        return 1
    fi
    
    # Sync to peer
    sync_to_peer "$backup_file" || \
        warn "Peer sync failed, but backup was created successfully"
    
    # Sync to off-site
    sync_to_offsite "$backup_file" || \
        warn "Off-site sync failed, but backup was created successfully"
    
    # Clean up old backups
    cleanup_old_backups
    
    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    log "Backup cycle completed in ${duration}s"
    send_notification "success" "Backup completed successfully on $(hostname) in ${duration}s"
    
    return 0
}

# Run as daemon
run_daemon() {
    log "Starting backup daemon (interval: ${BACKUP_INTERVAL}s)"
    
    while true; do
        if acquire_lock; then
            run_backup_cycle || warn "Backup cycle failed, will retry at next interval"
            release_lock
        else
            warn "Could not acquire lock, another backup may be running"
        fi
        
        log "Next backup in ${BACKUP_INTERVAL}s"
        sleep "$BACKUP_INTERVAL"
    done
}

# Main function
main() {
    local action="all"
    
    # Create log directory
    mkdir -p "$LOG_DIR"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --backup)
                action="backup"
                shift
                ;;
            --sync)
                action="sync"
                shift
                ;;
            --offsite)
                action="offsite"
                shift
                ;;
            --verify)
                action="verify"
                shift
                ;;
            --all)
                action="all"
                shift
                ;;
            --daemon)
                action="daemon"
                shift
                ;;
            --status)
                show_status
                exit 0
                ;;
            --cleanup)
                cleanup_old_backups
                exit 0
                ;;
            -h|--help)
                usage
                ;;
            *)
                error "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    # Acquire lock (unless daemon mode)
    if [ "$action" != "daemon" ]; then
        acquire_lock || exit 1
    fi
    
    case "$action" in
        backup)
            create_backup
            ;;
        sync)
            local latest_backup
            latest_backup=$(ls -t "$BACKUP_DIR"/dns-ha-backup-*.tar.gz 2>/dev/null | head -1)
            if [ -n "$latest_backup" ]; then
                sync_to_peer "$latest_backup"
            else
                error "No backup found to sync"
                exit 1
            fi
            ;;
        offsite)
            local latest_backup
            latest_backup=$(ls -t "$BACKUP_DIR"/dns-ha-backup-*.tar.gz 2>/dev/null | head -1)
            if [ -n "$latest_backup" ]; then
                sync_to_offsite "$latest_backup"
            else
                error "No backup found to sync"
                exit 1
            fi
            ;;
        verify)
            verify_backup
            ;;
        all)
            run_backup_cycle
            ;;
        daemon)
            run_daemon
            ;;
    esac
}

main "$@"
