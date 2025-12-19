#!/usr/bin/env bash
# =============================================================================
# Orion Sentinel DNS HA - Pi-hole Configuration Sync Script
# =============================================================================
# This script syncs Pi-hole configuration from primary to secondary node
# Based on Gravity Sync approach
#
# Features:
# - Syncs adlists, allow/deny lists, regex rules
# - Syncs local DNS records and custom hosts
# - Optionally syncs gravity database
# - Can be run manually or via systemd timer
#
# Usage:
#   ./scripts/pihole-sync.sh [--dry-run] [--no-gravity]
#
# Environment Variables:
#   PIHOLE_SYNC_ENABLED: Set to "true" to enable sync (default: false)
#   PRIMARY_NODE_IP: IP of primary node (e.g., 192.168.8.250)
#   SECONDARY_NODE_IP: IP of secondary node (e.g., 192.168.8.251)
#   SYNC_GRAVITY_DB: Sync gravity database (default: true)
# =============================================================================

set -euo pipefail

COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_RESET='\033[0m'

# Configuration
PIHOLE_SYNC_ENABLED="${PIHOLE_SYNC_ENABLED:-false}"
PRIMARY_NODE_IP="${PRIMARY_NODE_IP:-}"
SECONDARY_NODE_IP="${SECONDARY_NODE_IP:-}"
SYNC_GRAVITY_DB="${SYNC_GRAVITY_DB:-true}"
DRY_RUN=false

# Pi-hole directories (inside container)
PIHOLE_DIR="/etc/pihole"
DNSMASQ_DIR="/etc/dnsmasq.d"

# Container name
PIHOLE_CONTAINER="pihole_unbound"

# Parse command-line arguments
for arg in "$@"; do
  case $arg in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --no-gravity)
      SYNC_GRAVITY_DB=false
      shift
      ;;
    *)
      # Unknown option
      ;;
  esac
done

# =============================================================================
# Functions
# =============================================================================

log_info() {
  echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $1"
}

log_success() {
  echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $1"
}

log_warning() {
  echo -e "${COLOR_YELLOW}[WARNING]${COLOR_RESET} $1"
}

log_error() {
  echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $1"
}

check_prerequisites() {
  log_info "Checking prerequisites..."
  
  if [ "$PIHOLE_SYNC_ENABLED" != "true" ]; then
    log_error "Pi-hole sync is not enabled"
    log_info "Set PIHOLE_SYNC_ENABLED=true in your .env file to enable"
    exit 1
  fi
  
  if [ -z "$PRIMARY_NODE_IP" ]; then
    log_error "PRIMARY_NODE_IP is not set"
    exit 1
  fi
  
  if [ -z "$SECONDARY_NODE_IP" ]; then
    log_error "SECONDARY_NODE_IP is not set"
    exit 1
  fi
  
  # Check if this is the secondary node (using standard grep without -P)
  local_ips=$(ip -4 addr show | grep -oE 'inet [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | awk '{print $2}')
  if ! echo "$local_ips" | grep -q "$SECONDARY_NODE_IP"; then
    log_error "This script must be run on the SECONDARY node"
    log_info "Current node IPs: $(echo $local_ips | tr '\n' ' ')"
    log_info "Expected secondary IP: $SECONDARY_NODE_IP"
    exit 1
  fi
  
  # Check if Pi-hole container is running
  if ! docker ps --format '{{.Names}}' | grep -q "^${PIHOLE_CONTAINER}$"; then
    log_error "Pi-hole container '${PIHOLE_CONTAINER}' is not running"
    exit 1
  fi
  
  # Check SSH access to primary
  # Note: Using root user for simplicity. For production, consider using a dedicated
  # service account with minimal privileges and proper SSH key restrictions.
  if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "root@${PRIMARY_NODE_IP}" exit 2>/dev/null; then
    log_warning "Cannot SSH to primary node at ${PRIMARY_NODE_IP}"
    log_info "Make sure SSH key-based authentication is set up"
    log_info "Run: ssh-copy-id root@${PRIMARY_NODE_IP}"
    exit 1
  fi
  
  log_success "Prerequisites check passed"
}

sync_file() {
  local file_path="$1"
  local description="$2"
  
  log_info "Syncing ${description}..."
  
  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Would sync ${file_path}"
    return
  fi
  
  # Create temp directory and set cleanup trap
  temp_dir=$(mktemp -d)
  cleanup_sync_file() {
    rm -rf "$temp_dir"
  }
  trap cleanup_sync_file RETURN
  
  # Copy from primary via SSH
  if ssh "root@${PRIMARY_NODE_IP}" "docker exec ${PIHOLE_CONTAINER} test -f ${file_path}" 2>/dev/null; then
    ssh "root@${PRIMARY_NODE_IP}" "docker exec ${PIHOLE_CONTAINER} cat ${file_path}" > "${temp_dir}/$(basename ${file_path})" 2>/dev/null || {
      log_warning "Failed to fetch ${file_path} from primary"
      return 1
    }
    
    # Copy to local container
    docker exec -i ${PIHOLE_CONTAINER} sh -c "cat > ${file_path}" < "${temp_dir}/$(basename ${file_path})" || {
      log_error "Failed to write ${file_path} to secondary"
      return 1
    }
    
    log_success "Synced ${description}"
  else
    log_info "${file_path} does not exist on primary, skipping"
  fi
}

sync_gravity() {
  log_info "Syncing gravity database..."
  
  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Would sync gravity database"
    return
  fi
  
  # Stop Pi-hole DNS temporarily
  docker exec ${PIHOLE_CONTAINER} pihole restartdns >/dev/null 2>&1 || true
  
  # Create temp directory and set cleanup trap
  temp_dir=$(mktemp -d)
  cleanup_sync_gravity() {
    rm -rf "$temp_dir"
  }
  trap cleanup_sync_gravity RETURN
  
  # Fetch gravity database from primary
  ssh "root@${PRIMARY_NODE_IP}" "docker exec ${PIHOLE_CONTAINER} cat ${PIHOLE_DIR}/gravity.db" > "${temp_dir}/gravity.db" || {
    log_error "Failed to fetch gravity database from primary"
    return 1
  }
  
  # Copy to local container
  docker exec -i ${PIHOLE_CONTAINER} sh -c "cat > ${PIHOLE_DIR}/gravity.db" < "${temp_dir}/gravity.db" || {
    log_error "Failed to write gravity database to secondary"
    return 1
  }
  
  # Fix permissions
  docker exec ${PIHOLE_CONTAINER} chown pihole:pihole ${PIHOLE_DIR}/gravity.db
  docker exec ${PIHOLE_CONTAINER} chmod 644 ${PIHOLE_DIR}/gravity.db
  
  # Restart DNS
  docker exec ${PIHOLE_CONTAINER} pihole restartdns
  
  log_success "Synced gravity database"
}

# =============================================================================
# Main
# =============================================================================

echo "============================================================================="
echo "  Orion Sentinel DNS HA - Pi-hole Configuration Sync"
echo "============================================================================="
echo ""

if [ "$DRY_RUN" = true ]; then
  log_warning "Running in DRY RUN mode - no changes will be made"
  echo ""
fi

check_prerequisites

echo ""
log_info "Starting sync from primary (${PRIMARY_NODE_IP}) to secondary (${SECONDARY_NODE_IP})"
echo ""

# Sync configuration files
sync_file "${PIHOLE_DIR}/adlists.list" "Ad lists"
sync_file "${PIHOLE_DIR}/whitelist.txt" "Whitelist"
sync_file "${PIHOLE_DIR}/blacklist.txt" "Blacklist"
sync_file "${PIHOLE_DIR}/regex.list" "Regex filters"
sync_file "${PIHOLE_DIR}/custom.list" "Custom DNS records"
sync_file "${DNSMASQ_DIR}/02-pihole-dhcp.conf" "DHCP configuration"
sync_file "${DNSMASQ_DIR}/03-pihole-wildcard.conf" "Wildcard blocking"
sync_file "${DNSMASQ_DIR}/04-pihole-static-dhcp.conf" "Static DHCP leases"
sync_file "${DNSMASQ_DIR}/05-pihole-custom-cname.conf" "Custom CNAME records"
sync_file "${DNSMASQ_DIR}/06-rfc6761.conf" "RFC6761 configuration"

# Optionally sync gravity database
if [ "$SYNC_GRAVITY_DB" = true ]; then
  sync_gravity
else
  log_info "Skipping gravity database sync (disabled)"
fi

echo ""
log_success "Sync complete!"
echo ""

if [ "$DRY_RUN" = false ]; then
  log_info "To apply changes, run: docker exec ${PIHOLE_CONTAINER} pihole restartdns reload"
  log_info "Or wait for next scheduled gravity update"
fi
