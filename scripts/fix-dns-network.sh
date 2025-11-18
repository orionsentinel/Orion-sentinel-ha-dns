#!/usr/bin/env bash
# Fix DNS Network Script
# Fixes the dns_net network if it was created with the wrong driver

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Load environment if available
if [[ -f "$REPO_ROOT/.env" ]]; then
    source "$REPO_ROOT/.env" || true
fi

NETWORK_NAME="${DNS_NETWORK:-dns_net}"
NETWORK_INTERFACE="${NETWORK_INTERFACE:-eth0}"
SUBNET="${SUBNET:-192.168.8.0/24}"
GATEWAY="${GATEWAY:-192.168.8.1}"
DNS_STACK_DIR="$REPO_ROOT/stacks/dns"

log() { echo -e "${GREEN}[✓]${NC} $*"; }
err() { echo -e "${RED}[✗]${NC} $*" >&2; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
info() { echo -e "${CYAN}[i]${NC} $*"; }
section() { echo -e "\n${CYAN}${BOLD}═══ $* ═══${NC}\n"; }

# Check if network exists
network_exists() {
    docker network inspect "$1" >/dev/null 2>&1
}

# Get network driver
get_network_driver() {
    docker network inspect "$1" --format='{{.Driver}}' 2>/dev/null
}

main() {
    section "DNS Network Fix Script"
    
    info "This script will fix the dns_net network if it was created incorrectly."
    echo ""
    
    # Check if network exists
    if ! network_exists "$NETWORK_NAME"; then
        warn "Network '$NETWORK_NAME' does not exist."
        info "Creating new macvlan network..."
        
        # Check parent interface exists
        if ! ip link show "$NETWORK_INTERFACE" >/dev/null 2>&1; then
            err "Parent interface '$NETWORK_INTERFACE' does not exist!"
            err "Available interfaces:"
            ip link show | grep -E '^[0-9]+:' | awk '{print "  " $2}' | sed 's/:$//'
            exit 1
        fi
        
        # Create network
        docker network create \
            -d macvlan \
            --subnet="$SUBNET" \
            --gateway="$GATEWAY" \
            -o parent="$NETWORK_INTERFACE" \
            "$NETWORK_NAME" || {
                err "Failed to create macvlan network"
                exit 1
            }
        
        log "Network '$NETWORK_NAME' created successfully!"
        echo ""
        info "You can now deploy the DNS stack with:"
        echo "  ${CYAN}cd stacks/dns && docker compose up -d${NC}"
        exit 0
    fi
    
    # Network exists - check driver
    actual_driver=$(get_network_driver "$NETWORK_NAME")
    
    if [[ "$actual_driver" == "macvlan" ]]; then
        log "Network '$NETWORK_NAME' is already correctly configured as macvlan."
        echo ""
        info "No action needed. You can deploy the stack with:"
        echo "  ${CYAN}cd stacks/dns && docker compose up -d${NC}"
        exit 0
    fi
    
    # Network exists but wrong driver
    warn "Network '$NETWORK_NAME' exists but has wrong driver: $actual_driver"
    warn "Expected: macvlan"
    echo ""
    info "To fix this, we need to:"
    echo "  1. Stop all DNS stack containers"
    echo "  2. Remove the incorrect network"
    echo "  3. Create a new macvlan network"
    echo "  4. Restart the DNS stack"
    echo ""
    
    # Ask for confirmation
    read -r -p "Do you want to proceed? (y/N): " response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        info "Aborted. No changes made."
        exit 0
    fi
    
    echo ""
    section "Fixing Network"
    
    # Step 1: Stop containers
    info "Stopping DNS stack containers..."
    if [[ -f "$DNS_STACK_DIR/docker-compose.yml" ]]; then
        cd "$DNS_STACK_DIR"
        docker compose down || {
            warn "Failed to stop some containers. Continuing anyway..."
        }
        log "Containers stopped"
    else
        warn "docker-compose.yml not found in $DNS_STACK_DIR"
        info "Attempting to stop containers manually..."
        docker stop $(docker ps -q --filter "network=$NETWORK_NAME") 2>/dev/null || true
    fi
    
    echo ""
    
    # Step 2: Remove incorrect network
    info "Removing incorrect network '$NETWORK_NAME'..."
    if docker network rm "$NETWORK_NAME" 2>/dev/null; then
        log "Network removed"
    else
        err "Failed to remove network. There may be containers still using it."
        info "Check with: docker ps -a --filter network=$NETWORK_NAME"
        info "Remove containers with: docker rm -f <container_id>"
        exit 1
    fi
    
    echo ""
    
    # Step 3: Create macvlan network
    info "Creating macvlan network..."
    
    # Check parent interface exists
    if ! ip link show "$NETWORK_INTERFACE" >/dev/null 2>&1; then
        err "Parent interface '$NETWORK_INTERFACE' does not exist!"
        err "Available interfaces:"
        ip link show | grep -E '^[0-9]+:' | awk '{print "  " $2}' | sed 's/:$//'
        exit 1
    fi
    
    docker network create \
        -d macvlan \
        --subnet="$SUBNET" \
        --gateway="$GATEWAY" \
        -o parent="$NETWORK_INTERFACE" \
        "$NETWORK_NAME" || {
            err "Failed to create macvlan network"
            exit 1
        }
    
    log "Network '$NETWORK_NAME' created successfully as macvlan!"
    
    echo ""
    
    # Step 4: Restart containers
    info "Restarting DNS stack..."
    if [[ -f "$DNS_STACK_DIR/docker-compose.yml" ]]; then
        cd "$DNS_STACK_DIR"
        
        # Build keepalived if needed
        if grep -q "build:" docker-compose.yml; then
            info "Building keepalived image..."
            docker compose build keepalived || warn "Build failed but continuing..."
        fi
        
        info "Starting containers..."
        docker compose up -d || {
            err "Failed to start containers"
            err "Check logs with: cd $DNS_STACK_DIR && docker compose logs"
            exit 1
        }
        
        log "DNS stack restarted successfully!"
        
        echo ""
        info "Waiting for containers to initialize..."
        sleep 5
        
        echo ""
        section "Container Status"
        docker compose ps
    else
        warn "docker-compose.yml not found. Please start containers manually."
    fi
    
    echo ""
    section "Fix Complete!"
    
    log "The dns_net network is now correctly configured as macvlan."
    echo ""
    info "Next steps:"
    echo "  1. Wait 30-60 seconds for services to fully initialize"
    echo "  2. Test DNS from another device on your network (NOT from the Pi itself):"
    echo "     ${CYAN}dig google.com @192.168.8.255${NC}"
    echo "  3. Access Pi-hole admin panels:"
    echo "     Primary:   ${CYAN}http://192.168.8.251/admin${NC}"
    echo "     Secondary: ${CYAN}http://192.168.8.252/admin${NC}"
    echo ""
    warn "Note: Due to macvlan networking, you CANNOT access container IPs"
    warn "directly from the Raspberry Pi host itself. This is a Docker limitation."
    warn "Test DNS queries from another device on your network."
    echo ""
}

main "$@"
