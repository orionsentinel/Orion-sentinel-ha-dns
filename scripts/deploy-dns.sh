#!/usr/bin/env bash
# DNS Stack Deployment Script
# Ensures proper network setup and container deployment

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DNS_STACK_DIR="$REPO_ROOT/stacks/dns"

# Load environment variables
if [[ -f "$REPO_ROOT/.env" ]]; then
    source "$REPO_ROOT/.env"
fi

NETWORK_NAME="dns_net"
NETWORK_INTERFACE="${NETWORK_INTERFACE:-eth0}"
SUBNET="${SUBNET:-192.168.8.0/24}"
GATEWAY="${GATEWAY:-192.168.8.1}"

log() { echo -e "\n[deploy-dns] $*"; }
err() { echo -e "\n[deploy-dns][ERROR] $*" >&2; }
warn() { echo -e "\n[deploy-dns][WARNING] $*"; }

# Function to check if network exists
network_exists() {
    docker network inspect "$1" >/dev/null 2>&1
}

# Function to create macvlan network
create_network() {
    log "Creating macvlan network '$NETWORK_NAME'"
    
    # Check if parent interface exists
    if ! ip link show "$NETWORK_INTERFACE" >/dev/null 2>&1; then
        err "Parent interface '$NETWORK_INTERFACE' does not exist!"
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
    
    log "Network '$NETWORK_NAME' created successfully"
}

# Main deployment flow
main() {
    log "Starting DNS stack deployment"
    
    # Change to DNS stack directory
    cd "$DNS_STACK_DIR"
    
    # Stop existing containers
    log "Stopping existing containers..."
    docker compose down || true
    
    # Check/create network
    if network_exists "$NETWORK_NAME"; then
        log "Network '$NETWORK_NAME' already exists"
        
        # Verify it's macvlan
        driver=$(docker network inspect "$NETWORK_NAME" --format='{{.Driver}}')
        if [[ "$driver" != "macvlan" ]]; then
            err "Network exists but is NOT macvlan (current: $driver)"
            err "This will cause DNS containers to be unreachable!"
            echo ""
            warn "The DNS stack requires a macvlan network to work properly."
            warn "A $driver network will not allow containers to have IPs on the host subnet."
            echo ""
            log "To fix this issue, you need to:"
            log "  1. Remove the incorrect network"
            log "  2. Recreate it as macvlan"
            echo ""
            read -r -p "Do you want to fix this now? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                log "Removing existing network..."
                docker network rm "$NETWORK_NAME" || {
                    err "Failed to remove network. Make sure all containers using it are stopped."
                    err "Run: docker compose down"
                    exit 1
                }
                create_network
            else
                err "Cannot proceed with incorrect network type."
                err "Please fix the network and try again, or use:"
                err "  bash scripts/fix-dns-network.sh"
                exit 1
            fi
        else
            log "Network is correctly configured as macvlan"
        fi
    else
        create_network
    fi
    
    # Build keepalived image
    log "Building keepalived image..."
    docker compose build keepalived
    
    # Start services
    log "Starting services..."
    docker compose up -d
    
    # Wait a moment for containers to initialize
    sleep 5
    
    # Show status
    log "Container status:"
    docker compose ps
    
    log "Deployment complete!"
    log ""
    log "Next steps:"
    log "  1. Wait 30-60 seconds for all services to fully initialize"
    log "  2. Verify containers are healthy: docker compose ps"
    log "  3. Check logs if needed: docker compose logs -f"
    echo ""
    log "Testing DNS:"
    warn "IMPORTANT: Due to macvlan networking, you CANNOT test DNS from the Pi itself!"
    log "Test from another device on your network with:"
    log "  dig google.com @192.168.8.255"
    log "  dig google.com @192.168.8.251  # Primary Pi-hole"
    log "  dig google.com @192.168.8.252  # Secondary Pi-hole"
    echo ""
    log "Access Pi-hole admin panels:"
    log "  Primary:   http://192.168.8.251/admin"
    log "  Secondary: http://192.168.8.252/admin"
    echo ""
    log "If you have issues, run: bash scripts/validate-network.sh"
}

main "$@"
