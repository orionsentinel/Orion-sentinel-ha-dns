#!/usr/bin/env bash
# =============================================================================
# Pi-hole Sync Script
# =============================================================================
#
# Synchronizes Pi-hole configuration from PRIMARY to SECONDARY node.
#
# What gets synced:
#   - Gravity database (blocklists, groups, adlists)
#   - Pi-hole configuration files
#   - Custom DNS records
#   - DHCP configuration (if enabled)
#
# Usage:
#   ./pihole-sync.sh                    # Sync from primary to secondary
#   PEER_IP=192.168.8.243 ./pihole-sync.sh  # Custom peer IP
#
# Environment Variables:
#   PEER_IP          - IP address of the peer node to sync to
#   NODE_IP          - IP address of this node (auto-detected if not set)
#   REPO_DIR         - Path to repository (default: /opt/orion-dns-ha)
#   SSH_USER         - SSH user for peer connection (default: pi)
#
# Prerequisites:
#   - SSH key-based authentication to peer node
#   - rsync installed on both nodes
#   - Docker running on both nodes
#
# =============================================================================

set -euo pipefail

# Configuration
REPO_DIR="${REPO_DIR:-/opt/orion-dns-ha}"
SSH_USER="${SSH_USER:-pi}"
PEER_IP="${PEER_IP:-}"

# Directories to sync
PIHOLE_CONFIG_DIR="${REPO_DIR}/pihole/etc-pihole"
DNSMASQ_CONFIG_DIR="${REPO_DIR}/pihole/etc-dnsmasq.d"

# Logging
log() {
    echo "[$(date -Iseconds)] [pihole-sync] $*" >&2
}

# =============================================================================
# Validation
# =============================================================================

if [[ -z "${PEER_IP}" ]]; then
    log "ERROR: PEER_IP not set. Cannot determine peer node to sync to."
    log "Usage: PEER_IP=192.168.8.243 $0"
    exit 1
fi

if ! command -v rsync >/dev/null 2>&1; then
    log "ERROR: rsync not found. Please install rsync using your package manager."
    log "Example: sudo apt-get install rsync  # Debian/Ubuntu"
    log "         sudo yum install rsync      # RHEL/CentOS"
    exit 1
fi

if [[ ! -d "${PIHOLE_CONFIG_DIR}" ]]; then
    log "ERROR: Pi-hole config directory not found: ${PIHOLE_CONFIG_DIR}"
    exit 1
fi

# Check SSH connectivity (with 10 second timeout for slower networks)
if ! ssh -o BatchMode=yes -o ConnectTimeout=10 "${SSH_USER}@${PEER_IP}" true 2>/dev/null; then
    log "ERROR: Cannot connect to peer node via SSH: ${SSH_USER}@${PEER_IP}"
    log "Ensure SSH key-based authentication is set up."
    exit 1
fi

log "Starting Pi-hole configuration sync to ${PEER_IP}..."

# =============================================================================
# Sync Configuration Files
# =============================================================================

# Sync Pi-hole config directory
log "Syncing Pi-hole configuration..."
rsync -avz --delete \
    --exclude='pihole-FTL.db' \
    --exclude='pihole-FTL.db-*' \
    --exclude='*.log' \
    --exclude='macvendor.db' \
    "${PIHOLE_CONFIG_DIR}/" \
    "${SSH_USER}@${PEER_IP}:${PIHOLE_CONFIG_DIR}/" || {
    log "ERROR: Failed to sync Pi-hole configuration"
    exit 1
}

# Sync dnsmasq config directory
if [[ -d "${DNSMASQ_CONFIG_DIR}" ]]; then
    log "Syncing dnsmasq configuration..."
    rsync -avz --delete \
        "${DNSMASQ_CONFIG_DIR}/" \
        "${SSH_USER}@${PEER_IP}:${DNSMASQ_CONFIG_DIR}/" || {
        log "WARNING: Failed to sync dnsmasq configuration"
    }
fi

# =============================================================================
# Restart Pi-hole on Secondary
# =============================================================================

log "Restarting Pi-hole on secondary node..."
ssh "${SSH_USER}@${PEER_IP}" \
    "cd ${REPO_DIR} && docker compose restart pihole_unbound" || {
    log "WARNING: Failed to restart Pi-hole on secondary node"
}

log "Pi-hole sync completed successfully!"
log "Gravity update recommended on secondary node:"
log "  ssh ${SSH_USER}@${PEER_IP} 'docker exec pihole_unbound pihole updateGravity'"

exit 0
