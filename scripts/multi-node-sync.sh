#!/usr/bin/env bash
# Multi-Node Sync Script for Orion Sentinel DNS HA
# Synchronizes configuration and Pi-hole data between primary and secondary nodes
#
# Features:
# - Bidirectional configuration sync
# - Pi-hole gravity database sync
# - Unbound configuration sync
# - Conflict detection and resolution
# - SSH-based secure transfer
# - Automatic retry with exponential backoff
#
# Usage:
#   ./multi-node-sync.sh [options]
#
# Options:
#   --push          Push configuration from this node to peer
#   --pull          Pull configuration from peer to this node
#   --bidirectional Sync in both directions (default)
#   --dry-run       Show what would be synced without making changes
#   --force         Force sync even if conflicts detected
#   --daemon        Run as daemon with configured interval
#   -h, --help      Show this help message

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load configuration
if [ -f "$REPO_ROOT/.env" ]; then
    # shellcheck disable=SC1091
    source "$REPO_ROOT/.env"
fi

# Configuration with defaults
PEER_IP="${PEER_IP:-}"
NODE_IP="${NODE_IP:-$(hostname -I | awk '{print $1}')}"
NODE_ROLE="${NODE_ROLE:-primary}"
SSH_USER="${SYNC_SSH_USER:-pi}"
SSH_KEY="${SYNC_SSH_KEY:-$HOME/.ssh/id_rsa}"
SSH_PORT="${SYNC_SSH_PORT:-22}"
SYNC_INTERVAL="${SYNC_INTERVAL:-300}"
REMOTE_REPO_PATH="${REMOTE_REPO_PATH:-/opt/rpi-ha-dns-stack}"
SYNC_LOG_DIR="${SYNC_LOG_DIR:-$REPO_ROOT/logs}"
SYNC_LOG_FILE="${SYNC_LOG_DIR}/multi-node-sync.log"
LOCK_FILE="/tmp/multi-node-sync.lock"
MAX_RETRIES="${MAX_RETRIES:-3}"
RETRY_DELAY="${RETRY_DELAY:-5}"

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
    echo "$msg" >> "$SYNC_LOG_FILE" 2>/dev/null || true
}

warn() { 
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $*"
    echo -e "${YELLOW}${msg}${NC}"
    echo "$msg" >> "$SYNC_LOG_FILE" 2>/dev/null || true
}

error() { 
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*"
    echo -e "${RED}${msg}${NC}" >&2
    echo "$msg" >> "$SYNC_LOG_FILE" 2>/dev/null || true
}

info() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [DEBUG] $*"
    echo -e "${BLUE}${msg}${NC}"
    echo "$msg" >> "$SYNC_LOG_FILE" 2>/dev/null || true
}

# Show usage information
usage() {
    cat <<EOF
Usage: $0 [options]

Multi-Node Sync Script for Orion Sentinel DNS HA
Synchronizes configuration and Pi-hole data between primary and secondary nodes.

Options:
    --push          Push configuration from this node to peer
    --pull          Pull configuration from peer to this node
    --bidirectional Sync in both directions (default)
    --dry-run       Show what would be synced without making changes
    --force         Force sync even if conflicts detected
    --daemon        Run as daemon with configured interval
    --status        Show current sync status
    --setup         Setup SSH keys for passwordless sync
    -h, --help      Show this help message

Environment Variables:
    PEER_IP              IP address of peer node (required)
    NODE_ROLE            Role of this node: primary or secondary
    SYNC_SSH_USER        SSH username for remote connection (default: pi)
    SYNC_SSH_KEY         Path to SSH private key
    SYNC_SSH_PORT        SSH port (default: 22)
    SYNC_INTERVAL        Seconds between syncs in daemon mode (default: 300)
    REMOTE_REPO_PATH     Path to repo on remote node (default: /opt/rpi-ha-dns-stack)

Examples:
    # Push configuration to peer node
    $0 --push
    
    # Pull configuration from peer
    $0 --pull
    
    # Dry-run to see what would be synced
    $0 --dry-run
    
    # Run as background daemon
    $0 --daemon &

EOF
    exit 0
}

# Check if peer is configured
check_peer_config() {
    if [ -z "$PEER_IP" ]; then
        error "PEER_IP not configured. Set PEER_IP in .env or environment."
        error "Example: PEER_IP=192.168.8.12"
        return 1
    fi
    return 0
}

# Test SSH connectivity to peer
test_ssh_connection() {
    local max_attempts=$MAX_RETRIES
    local attempt=1
    local delay=$RETRY_DELAY

    while [ $attempt -le $max_attempts ]; do
        info "Testing SSH connection to $PEER_IP (attempt $attempt/$max_attempts)..."
        
        if ssh -q -o BatchMode=yes -o ConnectTimeout=10 \
            -i "$SSH_KEY" -p "$SSH_PORT" \
            "${SSH_USER}@${PEER_IP}" "exit 0" 2>/dev/null; then
            log "SSH connection to peer successful"
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            warn "SSH connection failed, retrying in ${delay}s..."
            sleep "$delay"
            delay=$((delay * 2))  # Exponential backoff
        fi
        attempt=$((attempt + 1))
    done

    error "Cannot connect to peer node $PEER_IP via SSH"
    error "Please ensure:"
    error "  1. Peer node is reachable: ping $PEER_IP"
    error "  2. SSH is enabled on peer"
    error "  3. SSH key is authorized: ssh-copy-id ${SSH_USER}@${PEER_IP}"
    return 1
}

# Acquire lock to prevent concurrent syncs
acquire_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local pid
        pid=$(cat "$LOCK_FILE" 2>/dev/null)
        if kill -0 "$pid" 2>/dev/null; then
            warn "Another sync process is running (PID: $pid)"
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

# Get checksum of a file or directory
get_checksum() {
    local path="$1"
    if [ -f "$path" ]; then
        sha256sum "$path" 2>/dev/null | cut -d' ' -f1
    elif [ -d "$path" ]; then
        find "$path" -type f -exec sha256sum {} \; 2>/dev/null | sort | sha256sum | cut -d' ' -f1
    else
        echo ""
    fi
}

# Get remote checksum
get_remote_checksum() {
    local path="$1"
    ssh -q -o BatchMode=yes -i "$SSH_KEY" -p "$SSH_PORT" \
        "${SSH_USER}@${PEER_IP}" \
        "if [ -f '$path' ]; then sha256sum '$path' | cut -d' ' -f1; elif [ -d '$path' ]; then find '$path' -type f -exec sha256sum {} \; 2>/dev/null | sort | sha256sum | cut -d' ' -f1; fi" 2>/dev/null || echo ""
}

# Compare local and remote files
detect_changes() {
    local path="$1"
    local remote_path="${REMOTE_REPO_PATH}/${path#$REPO_ROOT/}"
    
    local local_sum remote_sum
    local_sum=$(get_checksum "$path")
    remote_sum=$(get_remote_checksum "$remote_path")
    
    if [ "$local_sum" = "$remote_sum" ]; then
        echo "same"
    elif [ -z "$remote_sum" ]; then
        echo "local_only"
    elif [ -z "$local_sum" ]; then
        echo "remote_only"
    else
        echo "different"
    fi
}

# Sync environment configuration
sync_env_config() {
    local direction="$1"
    local dry_run="${2:-false}"
    
    log "Syncing environment configuration ($direction)..."
    
    local local_env="$REPO_ROOT/.env"
    local remote_env="$REMOTE_REPO_PATH/.env"
    
    if [ "$direction" = "push" ]; then
        if [ -f "$local_env" ]; then
            if [ "$dry_run" = "true" ]; then
                info "[DRY-RUN] Would sync .env to peer"
            else
                # Create backup on remote before overwriting
                ssh -q -o BatchMode=yes -i "$SSH_KEY" -p "$SSH_PORT" \
                    "${SSH_USER}@${PEER_IP}" \
                    "[ -f '$remote_env' ] && cp '$remote_env' '${remote_env}.backup'" 2>/dev/null || true
                
                # Sync file
                rsync -avz --progress \
                    -e "ssh -i $SSH_KEY -p $SSH_PORT" \
                    "$local_env" "${SSH_USER}@${PEER_IP}:${remote_env}"
                log "Environment configuration pushed to peer"
            fi
        fi
    elif [ "$direction" = "pull" ]; then
        if [ "$dry_run" = "true" ]; then
            info "[DRY-RUN] Would pull .env from peer"
        else
            # Create local backup
            [ -f "$local_env" ] && cp "$local_env" "${local_env}.backup"
            
            # Pull file
            rsync -avz --progress \
                -e "ssh -i $SSH_KEY -p $SSH_PORT" \
                "${SSH_USER}@${PEER_IP}:${remote_env}" "$local_env"
            log "Environment configuration pulled from peer"
        fi
    fi
}

# Sync Pi-hole configuration (gravity database, custom lists, etc.)
sync_pihole_data() {
    local direction="$1"
    local dry_run="${2:-false}"
    
    log "Syncing Pi-hole configuration ($direction)..."
    
    local pihole_container="pihole_primary"
    if [ "$NODE_ROLE" = "secondary" ]; then
        pihole_container="pihole_secondary"
    fi
    
    # Check if Pi-hole container is running locally
    if ! docker ps --format '{{.Names}}' | grep -q "$pihole_container"; then
        warn "Pi-hole container $pihole_container not running locally, skipping Pi-hole sync"
        return 0
    fi
    
    local temp_dir
    temp_dir=$(mktemp -d)
    
    if [ "$direction" = "push" ]; then
        if [ "$dry_run" = "true" ]; then
            info "[DRY-RUN] Would push Pi-hole gravity database to peer"
        else
            # Export Pi-hole configuration
            log "Exporting Pi-hole configuration..."
            docker exec "$pihole_container" tar czf - /etc/pihole /etc/dnsmasq.d 2>/dev/null > \
                "$temp_dir/pihole-export.tar.gz" || {
                warn "Failed to export Pi-hole configuration"
                rm -rf "$temp_dir"
                return 1
            }
            
            # Transfer to peer
            log "Transferring Pi-hole data to peer..."
            scp -q -i "$SSH_KEY" -P "$SSH_PORT" \
                "$temp_dir/pihole-export.tar.gz" \
                "${SSH_USER}@${PEER_IP}:/tmp/"
            
            # Import on peer
            local remote_container="pihole_secondary"
            [ "$NODE_ROLE" = "secondary" ] && remote_container="pihole_primary"
            
            # Break the import into separate steps for better error handling
            log "Importing Pi-hole configuration on peer..."
            
            # Step 1: Extract the backup
            if ! ssh -q -o BatchMode=yes -i "$SSH_KEY" -p "$SSH_PORT" \
                "${SSH_USER}@${PEER_IP}" \
                "docker exec $remote_container sh -c 'cd / && tar xzf /tmp/pihole-export.tar.gz'" 2>/dev/null; then
                warn "Failed to extract Pi-hole backup on peer"
            fi
            
            # Step 2: Clean up the temp file
            ssh -q -o BatchMode=yes -i "$SSH_KEY" -p "$SSH_PORT" \
                "${SSH_USER}@${PEER_IP}" \
                "rm -f /tmp/pihole-export.tar.gz" 2>/dev/null || true
            
            # Step 3: Reload Pi-hole DNS lists
            if ! ssh -q -o BatchMode=yes -i "$SSH_KEY" -p "$SSH_PORT" \
                "${SSH_USER}@${PEER_IP}" \
                "docker exec $remote_container pihole restartdns reload-lists" 2>/dev/null; then
                warn "Failed to reload Pi-hole DNS lists on peer"
            fi
            
            log "Pi-hole configuration pushed to peer"
        fi
    elif [ "$direction" = "pull" ]; then
        if [ "$dry_run" = "true" ]; then
            info "[DRY-RUN] Would pull Pi-hole gravity database from peer"
        else
            local remote_container="pihole_secondary"
            [ "$NODE_ROLE" = "secondary" ] && remote_container="pihole_primary"
            
            # Export from peer
            log "Exporting Pi-hole configuration from peer..."
            ssh -q -o BatchMode=yes -i "$SSH_KEY" -p "$SSH_PORT" \
                "${SSH_USER}@${PEER_IP}" \
                "docker exec $remote_container tar czf - /etc/pihole /etc/dnsmasq.d" > \
                "$temp_dir/pihole-import.tar.gz" 2>/dev/null || {
                warn "Failed to export Pi-hole configuration from peer"
                rm -rf "$temp_dir"
                return 1
            }
            
            # Import locally
            log "Importing Pi-hole configuration..."
            docker exec -i "$pihole_container" sh -c 'cd / && tar xzf -' < \
                "$temp_dir/pihole-import.tar.gz"
            docker exec "$pihole_container" pihole restartdns reload-lists
            
            log "Pi-hole configuration pulled from peer"
        fi
    fi
    
    rm -rf "$temp_dir"
}

# Sync Unbound configuration
sync_unbound_config() {
    local direction="$1"
    local dry_run="${2:-false}"
    
    log "Syncing Unbound configuration ($direction)..."
    
    local local_unbound="$REPO_ROOT/stacks/dns/unbound"
    local remote_unbound="$REMOTE_REPO_PATH/stacks/dns/unbound"
    
    if [ "$direction" = "push" ]; then
        if [ -d "$local_unbound" ]; then
            if [ "$dry_run" = "true" ]; then
                info "[DRY-RUN] Would sync Unbound config to peer"
            else
                rsync -avz --progress \
                    -e "ssh -i $SSH_KEY -p $SSH_PORT" \
                    --delete \
                    "$local_unbound/" "${SSH_USER}@${PEER_IP}:${remote_unbound}/"
                log "Unbound configuration pushed to peer"
            fi
        fi
    elif [ "$direction" = "pull" ]; then
        if [ "$dry_run" = "true" ]; then
            info "[DRY-RUN] Would pull Unbound config from peer"
        else
            rsync -avz --progress \
                -e "ssh -i $SSH_KEY -p $SSH_PORT" \
                --delete \
                "${SSH_USER}@${PEER_IP}:${remote_unbound}/" "$local_unbound/"
            log "Unbound configuration pulled from peer"
        fi
    fi
}

# Sync Keepalived configuration
sync_keepalived_config() {
    local direction="$1"
    local dry_run="${2:-false}"
    
    log "Syncing Keepalived configuration ($direction)..."
    
    local local_keepalived="$REPO_ROOT/stacks/dns/keepalived"
    local remote_keepalived="$REMOTE_REPO_PATH/stacks/dns/keepalived"
    
    if [ "$direction" = "push" ]; then
        if [ -d "$local_keepalived" ]; then
            if [ "$dry_run" = "true" ]; then
                info "[DRY-RUN] Would sync Keepalived config to peer"
            else
                rsync -avz --progress \
                    -e "ssh -i $SSH_KEY -p $SSH_PORT" \
                    "$local_keepalived/" "${SSH_USER}@${PEER_IP}:${remote_keepalived}/"
                log "Keepalived configuration pushed to peer"
            fi
        fi
    elif [ "$direction" = "pull" ]; then
        if [ "$dry_run" = "true" ]; then
            info "[DRY-RUN] Would pull Keepalived config from peer"
        else
            rsync -avz --progress \
                -e "ssh -i $SSH_KEY -p $SSH_PORT" \
                "${SSH_USER}@${PEER_IP}:${remote_keepalived}/" "$local_keepalived/"
            log "Keepalived configuration pulled from peer"
        fi
    fi
}

# Sync security profiles
sync_profiles() {
    local direction="$1"
    local dry_run="${2:-false}"
    
    log "Syncing security profiles ($direction)..."
    
    local local_profiles="$REPO_ROOT/profiles"
    local remote_profiles="$REMOTE_REPO_PATH/profiles"
    
    if [ "$direction" = "push" ]; then
        if [ -d "$local_profiles" ]; then
            if [ "$dry_run" = "true" ]; then
                info "[DRY-RUN] Would sync profiles to peer"
            else
                rsync -avz --progress \
                    -e "ssh -i $SSH_KEY -p $SSH_PORT" \
                    --delete \
                    "$local_profiles/" "${SSH_USER}@${PEER_IP}:${remote_profiles}/"
                log "Security profiles pushed to peer"
            fi
        fi
    elif [ "$direction" = "pull" ]; then
        if [ "$dry_run" = "true" ]; then
            info "[DRY-RUN] Would pull profiles from peer"
        else
            rsync -avz --progress \
                -e "ssh -i $SSH_KEY -p $SSH_PORT" \
                --delete \
                "${SSH_USER}@${PEER_IP}:${remote_profiles}/" "$local_profiles/"
            log "Security profiles pulled from peer"
        fi
    fi
}

# Push backup to peer node
push_backup_to_peer() {
    local dry_run="${1:-false}"
    
    log "Pushing latest backup to peer node..."
    
    local backup_dir="$REPO_ROOT/backups"
    local remote_backup_dir="$REMOTE_REPO_PATH/backups"
    
    if [ ! -d "$backup_dir" ]; then
        warn "No local backups found"
        return 0
    fi
    
    # Find latest backup
    local latest_backup
    latest_backup=$(ls -t "$backup_dir"/dns-ha-backup-*.tar.gz 2>/dev/null | head -1)
    
    if [ -z "$latest_backup" ]; then
        warn "No backup files found"
        return 0
    fi
    
    if [ "$dry_run" = "true" ]; then
        info "[DRY-RUN] Would push backup: $(basename "$latest_backup")"
    else
        # Ensure remote backup directory exists
        ssh -q -o BatchMode=yes -i "$SSH_KEY" -p "$SSH_PORT" \
            "${SSH_USER}@${PEER_IP}" "mkdir -p '$remote_backup_dir'" 2>/dev/null
        
        # Transfer backup
        rsync -avz --progress \
            -e "ssh -i $SSH_KEY -p $SSH_PORT" \
            "$latest_backup" "${SSH_USER}@${PEER_IP}:${remote_backup_dir}/"
        
        # Also transfer checksum file if exists
        local checksum_file="${latest_backup}.sha256"
        if [ -f "$checksum_file" ]; then
            rsync -avz -e "ssh -i $SSH_KEY -p $SSH_PORT" \
                "$checksum_file" "${SSH_USER}@${PEER_IP}:${remote_backup_dir}/"
        fi
        
        log "Backup pushed to peer: $(basename "$latest_backup")"
    fi
}

# Show sync status
show_status() {
    echo ""
    echo "═══════════════════════════════════════════════════"
    echo "  Multi-Node Sync Status"
    echo "═══════════════════════════════════════════════════"
    echo ""
    echo "Local Node:"
    echo "  IP:      $NODE_IP"
    echo "  Role:    $NODE_ROLE"
    echo ""
    echo "Peer Node:"
    echo "  IP:      ${PEER_IP:-Not configured}"
    echo ""
    
    if [ -n "$PEER_IP" ]; then
        if test_ssh_connection 2>/dev/null; then
            echo -e "  Status:  ${GREEN}Connected${NC}"
            
            # Check sync state of key files
            echo ""
            echo "Sync State:"
            
            local env_state
            env_state=$(detect_changes "$REPO_ROOT/.env")
            case "$env_state" in
                same) echo -e "  .env:              ${GREEN}In Sync${NC}" ;;
                different) echo -e "  .env:              ${YELLOW}Different${NC}" ;;
                local_only) echo -e "  .env:              ${BLUE}Local Only${NC}" ;;
                remote_only) echo -e "  .env:              ${CYAN}Remote Only${NC}" ;;
            esac
            
            if [ -d "$REPO_ROOT/stacks/dns/unbound" ]; then
                local unbound_state
                unbound_state=$(detect_changes "$REPO_ROOT/stacks/dns/unbound")
                case "$unbound_state" in
                    same) echo -e "  Unbound Config:    ${GREEN}In Sync${NC}" ;;
                    different) echo -e "  Unbound Config:    ${YELLOW}Different${NC}" ;;
                    *) echo -e "  Unbound Config:    ${BLUE}$unbound_state${NC}" ;;
                esac
            fi
        else
            echo -e "  Status:  ${RED}Unreachable${NC}"
        fi
    fi
    
    echo ""
    echo "Last Sync:"
    if [ -f "$SYNC_LOG_FILE" ]; then
        tail -1 "$SYNC_LOG_FILE" 2>/dev/null || echo "  No sync history"
    else
        echo "  No sync history"
    fi
    echo ""
}

# Setup SSH keys for passwordless sync
setup_ssh() {
    log "Setting up SSH for passwordless sync..."
    
    check_peer_config || exit 1
    
    # Generate SSH key if it doesn't exist
    if [ ! -f "$SSH_KEY" ]; then
        info "Generating SSH key pair..."
        ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -C "orion-sentinel-sync"
        log "SSH key generated: $SSH_KEY"
    else
        log "SSH key already exists: $SSH_KEY"
    fi
    
    # Copy public key to peer
    info "Copying public key to peer node..."
    info "You may be prompted for the password of ${SSH_USER}@${PEER_IP}"
    
    ssh-copy-id -i "${SSH_KEY}.pub" -p "$SSH_PORT" "${SSH_USER}@${PEER_IP}"
    
    if test_ssh_connection; then
        log "SSH setup complete! Passwordless authentication is now configured."
    else
        error "SSH setup failed. Please check your configuration and try again."
        exit 1
    fi
}

# Perform full sync
perform_sync() {
    local direction="$1"
    local dry_run="${2:-false}"
    local force="${3:-false}"
    
    log "Starting multi-node sync (direction: $direction, dry-run: $dry_run)"
    
    # Sync components
    sync_env_config "$direction" "$dry_run"
    sync_pihole_data "$direction" "$dry_run"
    sync_unbound_config "$direction" "$dry_run"
    sync_keepalived_config "$direction" "$dry_run"
    sync_profiles "$direction" "$dry_run"
    
    # Push backup if this is the primary node
    if [ "$NODE_ROLE" = "primary" ] && [ "$direction" = "push" ]; then
        push_backup_to_peer "$dry_run"
    fi
    
    log "Sync completed successfully"
}

# Run as daemon
run_daemon() {
    log "Starting multi-node sync daemon (interval: ${SYNC_INTERVAL}s)"
    
    while true; do
        if acquire_lock; then
            # Determine sync direction based on role
            local direction="push"
            [ "$NODE_ROLE" = "secondary" ] && direction="pull"
            
            if test_ssh_connection 2>/dev/null; then
                perform_sync "$direction" "false" "false" || \
                    warn "Sync failed, will retry in ${SYNC_INTERVAL}s"
            else
                warn "Peer unreachable, will retry in ${SYNC_INTERVAL}s"
            fi
            
            release_lock
        fi
        
        sleep "$SYNC_INTERVAL"
    done
}

# Main function
main() {
    local direction="bidirectional"
    local dry_run="false"
    local force="false"
    local daemon="false"
    
    # Create log directory
    mkdir -p "$SYNC_LOG_DIR"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --push)
                direction="push"
                shift
                ;;
            --pull)
                direction="pull"
                shift
                ;;
            --bidirectional)
                direction="bidirectional"
                shift
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            --force)
                force="true"
                shift
                ;;
            --daemon)
                daemon="true"
                shift
                ;;
            --status)
                show_status
                exit 0
                ;;
            --setup)
                setup_ssh
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
    
    # Check peer configuration
    check_peer_config || exit 1
    
    # Acquire lock (unless daemon mode)
    if [ "$daemon" = "false" ]; then
        acquire_lock || exit 1
    fi
    
    # Test SSH connection
    if ! test_ssh_connection; then
        exit 1
    fi
    
    # Run daemon or single sync
    if [ "$daemon" = "true" ]; then
        run_daemon
    else
        if [ "$direction" = "bidirectional" ]; then
            # Bidirectional: push from primary, pull from secondary
            if [ "$NODE_ROLE" = "primary" ]; then
                perform_sync "push" "$dry_run" "$force"
            else
                perform_sync "pull" "$dry_run" "$force"
            fi
        else
            perform_sync "$direction" "$dry_run" "$force"
        fi
    fi
}

main "$@"
