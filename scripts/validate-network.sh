#!/usr/bin/env bash
# Network Validation Script
# Checks if the dns_net network is properly configured as macvlan

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
EXPECTED_DRIVER="macvlan"
NETWORK_INTERFACE="${NETWORK_INTERFACE:-eth0}"
SUBNET="${SUBNET:-192.168.8.0/24}"
GATEWAY="${GATEWAY:-192.168.8.1}"

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

# Get network subnet
get_network_subnet() {
    docker network inspect "$1" --format='{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null
}

# Get network gateway
get_network_gateway() {
    docker network inspect "$1" --format='{{range .IPAM.Config}}{{.Gateway}}{{end}}' 2>/dev/null
}

# Get network parent interface (for macvlan)
get_network_parent() {
    docker network inspect "$1" --format='{{index .Options "parent"}}' 2>/dev/null
}

# Main validation
main() {
    section "Docker Network Validation for DNS Stack"
    
    echo "Expected Configuration:"
    echo "  Network Name: $NETWORK_NAME"
    echo "  Driver:       $EXPECTED_DRIVER"
    echo "  Subnet:       $SUBNET"
    echo "  Gateway:      $GATEWAY"
    echo "  Parent:       $NETWORK_INTERFACE"
    echo ""
    
    # Check if network exists
    if ! network_exists "$NETWORK_NAME"; then
        err "Network '$NETWORK_NAME' does not exist!"
        echo ""
        warn "The network needs to be created before deploying the DNS stack."
        echo ""
        info "To create the network, run:"
        echo "  ${CYAN}bash scripts/deploy-dns.sh${NC}"
        echo ""
        info "Or create it manually with:"
        echo "  ${CYAN}docker network create -d macvlan \\"
        echo "    --subnet=$SUBNET \\"
        echo "    --gateway=$GATEWAY \\"
        echo "    -o parent=$NETWORK_INTERFACE \\"
        echo "    $NETWORK_NAME${NC}"
        echo ""
        exit 1
    fi
    
    log "Network '$NETWORK_NAME' exists"
    echo ""
    
    # Check network driver
    actual_driver=$(get_network_driver "$NETWORK_NAME")
    if [[ "$actual_driver" != "$EXPECTED_DRIVER" ]]; then
        err "Network driver mismatch!"
        echo "  Expected: $EXPECTED_DRIVER"
        echo "  Actual:   $actual_driver"
        echo ""
        warn "The DNS stack requires a macvlan network to work properly."
        warn "A bridge network will not allow containers to have IPs on the host subnet."
        echo ""
        info "To fix this issue:"
        echo "  1. Stop all containers: ${CYAN}cd stacks/dns && docker compose down${NC}"
        echo "  2. Remove the incorrect network: ${CYAN}docker network rm $NETWORK_NAME${NC}"
        echo "  3. Run the deployment script: ${CYAN}bash scripts/deploy-dns.sh${NC}"
        echo ""
        info "Or use the quick fix script:"
        echo "  ${CYAN}bash scripts/fix-dns-network.sh${NC}"
        echo ""
        exit 1
    fi
    
    log "Network driver is correct: $actual_driver"
    echo ""
    
    # Check subnet
    actual_subnet=$(get_network_subnet "$NETWORK_NAME")
    if [[ "$actual_subnet" != "$SUBNET" ]]; then
        warn "Network subnet mismatch!"
        echo "  Expected: $SUBNET"
        echo "  Actual:   $actual_subnet"
        echo ""
    else
        log "Network subnet is correct: $actual_subnet"
    fi
    
    # Check gateway
    actual_gateway=$(get_network_gateway "$NETWORK_NAME")
    if [[ "$actual_gateway" != "$GATEWAY" ]]; then
        warn "Network gateway mismatch!"
        echo "  Expected: $GATEWAY"
        echo "  Actual:   $actual_gateway"
        echo ""
    else
        log "Network gateway is correct: $actual_gateway"
    fi
    
    # Check parent interface (macvlan specific)
    if [[ "$actual_driver" == "macvlan" ]]; then
        actual_parent=$(get_network_parent "$NETWORK_NAME")
        if [[ "$actual_parent" != "$NETWORK_INTERFACE" ]]; then
            warn "Network parent interface mismatch!"
            echo "  Expected: $NETWORK_INTERFACE"
            echo "  Actual:   $actual_parent"
            echo ""
        else
            log "Network parent interface is correct: $actual_parent"
        fi
    fi
    
    echo ""
    section "Validation Summary"
    
    if [[ "$actual_driver" == "$EXPECTED_DRIVER" ]]; then
        log "Network is correctly configured!"
        echo ""
        info "You can now deploy the DNS stack with:"
        echo "  ${CYAN}cd stacks/dns && docker compose up -d${NC}"
        echo ""
        info "Or use the deployment script:"
        echo "  ${CYAN}bash scripts/deploy-dns.sh${NC}"
        echo ""
        exit 0
    else
        err "Network configuration has issues. Please fix them before deploying."
        exit 1
    fi
}

main "$@"
