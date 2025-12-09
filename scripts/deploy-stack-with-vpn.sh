#!/usr/bin/env bash
# Unified Deployment Script with Optional VPN Configuration
# Deploys HA DNS stack with optional WireGuard VPN integration
# Usage: bash scripts/deploy-stack-with-vpn.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

info() {
    echo -e "${BLUE}[DEPLOY]${NC} $*"
}

# Banner
show_banner() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║   RPi HA DNS Stack - Unified Deployment Wizard       ║"
    echo "║   High Availability DNS with Optional VPN Access     ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Check prerequisites
check_prerequisites() {
    info "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! docker compose version &> /dev/null; then
        error "Docker Compose plugin is not installed."
        exit 1
    fi
    
    log "✓ Docker and Docker Compose are installed"
}

# Detect deployment type
detect_deployment() {
    echo ""
    info "Select your deployment type:"
    echo "  1) HighAvail_1Pi2P2U - 1 Raspberry Pi with DNS only"
    echo "  2) HighAvail_2Pi1P1U - 2 Raspberry Pis (Production tier)"
    echo "  3) HighAvail_2Pi2P2U - 2 Raspberry Pis (Maximum redundancy)"
    echo ""
    
    while true; do
        read -rp "Enter your choice (1-3): " DEPLOYMENT_CHOICE
        case $DEPLOYMENT_CHOICE in
            1)
                DEPLOYMENT_TYPE="HighAvail_1Pi2P2U"
                DEPLOYMENT_DESC="1 Pi, DNS only"
                break
                ;;
            2)
                DEPLOYMENT_TYPE="HighAvail_2Pi1P1U"
                DEPLOYMENT_DESC="2 Pis, hardware redundancy"
                break
                ;;
            3)
                DEPLOYMENT_TYPE="HighAvail_2Pi2P2U"
                DEPLOYMENT_DESC="2 Pis, full redundancy"
                break
                ;;
            *)
                warn "Invalid choice. Please enter 1, 2, or 3."
                ;;
        esac
    done
    
    log "Selected deployment: $DEPLOYMENT_DESC"
}

# Ask about VPN configuration
ask_vpn_config() {
    echo ""
    info "═══════════════════════════════════════════════════════"
    info "VPN Configuration (Optional)"
    info "═══════════════════════════════════════════════════════"
    echo ""
    echo "Do you want to enable WireGuard VPN for remote access?"
    echo ""
    echo "Benefits of VPN Edition:"
    echo "  • Secure remote access to your home network"
    echo "  • Ad-blocking everywhere (via Pi-hole)"
    echo "  • Access local services (Jellyfin, NAS, etc.)"
    echo "  • QR code setup for mobile devices (2 minutes)"
    echo "  • Automatic DNS failover (uses HA VIP)"
    echo ""
    echo "Requirements:"
    echo "  • Public IP or DDNS (like DuckDNS)"
    echo "  • Router port forwarding (51820/UDP)"
    echo "  • +5-10 minutes setup time"
    echo ""
    
    while true; do
        read -rp "Enable VPN configuration? (yes/no): " ENABLE_VPN
        case $ENABLE_VPN in
            [Yy][Ee][Ss]|[Yy])
                ENABLE_VPN="yes"
                log "✓ VPN will be configured"
                break
                ;;
            [Nn][Oo]|[Nn])
                ENABLE_VPN="no"
                log "✓ DNS-only deployment (VPN skipped)"
                break
                ;;
            *)
                warn "Please answer 'yes' or 'no'"
                ;;
        esac
    done
}

# Deploy DNS stack
deploy_dns_stack() {
    local deployment_path="$REPO_ROOT/deployments/${DEPLOYMENT_TYPE}"
    
    if [ ! -d "$deployment_path" ]; then
        error "Deployment directory not found: $deployment_path"
        exit 1
    fi
    
    info "Deploying DNS stack..."
    cd "$deployment_path"
    
    # Check for .env file
    if [ ! -f ".env" ]; then
        if [ -f ".env.example" ]; then
            log "Creating .env from .env.example..."
            cp .env.example .env
            warn "Please edit .env file with your configuration before continuing."
            read -rp "Press Enter after you've edited .env..."
        else
            error ".env.example not found in $deployment_path"
            exit 1
        fi
    fi
    
    # Create network if needed
    if ! docker network inspect dns_net &> /dev/null; then
        log "Creating Docker network: dns_net"
        docker network create --subnet=192.168.8.0/24 dns_net
    fi
    
    # Deploy DNS stack
    log "Starting DNS containers..."
    docker compose up -d
    
    log "✓ DNS stack deployed successfully"
    
    # Wait for services to start
    sleep 5
}

# Deploy VPN stack
deploy_vpn_stack() {
    local deployment_path="$REPO_ROOT/deployments/${DEPLOYMENT_TYPE}_VPN"
    local vpn_compose=""
    
    # Determine VPN compose file location
    if [ "$DEPLOYMENT_TYPE" = "HighAvail_1Pi2P2U" ]; then
        vpn_compose="$deployment_path/docker-compose.vpn.yml"
    else
        # For 2-Pi deployments, VPN is on node1
        vpn_compose="$deployment_path/node1/docker-compose.vpn.yml"
        cd "$deployment_path/node1"
    fi
    
    if [ ! -f "$vpn_compose" ]; then
        error "VPN compose file not found: $vpn_compose"
        error "Please ensure VPN Edition deployment exists for $DEPLOYMENT_TYPE"
        exit 1
    fi
    
    info "Configuring VPN..."
    
    # Run VPN installation script
    if [ -x "$REPO_ROOT/scripts/install_vpn_edition.sh" ]; then
        log "Running VPN configuration wizard..."
        bash "$REPO_ROOT/scripts/install_vpn_edition.sh"
    else
        # Fallback: manual configuration
        warn "Automated VPN installer not found. Using manual configuration..."
        
        if [ ! -f ".env.vpn" ]; then
            if [ -f ".env.vpn.example" ]; then
                cp .env.vpn.example .env.vpn
                warn "Please edit .env.vpn with your VPN configuration."
                echo ""
                echo "Required settings:"
                echo "  WG_HOST=your-public-ip-or-ddns.duckdns.org"
                echo "  WG_PEERS=phone,laptop,tablet"
                echo "  WG_PEER_DNS=192.168.8.255"
                echo ""
                read -rp "Press Enter after you've edited .env.vpn..."
            fi
        fi
        
        log "Starting VPN containers..."
        docker compose -f docker-compose.vpn.yml --env-file .env.vpn --profile ui up -d
    fi
    
    log "✓ VPN stack deployed successfully"
}

# Show post-deployment summary
show_summary() {
    echo ""
    info "═══════════════════════════════════════════════════════"
    info "Deployment Complete!"
    info "═══════════════════════════════════════════════════════"
    echo ""
    
    log "Deployment Type: $DEPLOYMENT_DESC"
    
    if [ "$ENABLE_VPN" = "yes" ]; then
        log "VPN Edition: Enabled"
        echo ""
        echo "Next Steps:"
        echo "  1. Configure router port forwarding:"
        echo "     Forward UDP port 51820 to 192.168.8.250"
        echo ""
        echo "  2. Access WireGuard-UI for QR codes:"
        echo "     http://192.168.8.250:5000"
        echo "     (Username: admin, Password: from .env.vpn)"
        echo ""
        echo "  3. Mobile Setup:"
        echo "     - Install WireGuard app"
        echo "     - Scan QR code from Web UI"
        echo "     - Toggle VPN ON"
        echo ""
        echo "  4. Test VPN connection:"
        echo "     - Connect from mobile data"
        echo "     - Visit http://192.168.8.251/admin (Pi-hole)"
        echo "     - Check ad-blocking works"
        echo ""
    else
        log "VPN Edition: Disabled (DNS-only)"
        echo ""
        echo "Next Steps:"
        echo "  1. Access Pi-hole Admin:"
        echo "     http://192.168.8.251/admin"
        echo ""
        echo "  2. Configure DNS on your devices:"
        echo "     Primary DNS: 192.168.8.255 (HA VIP)"
        echo ""
    fi
    
    echo "Additional Services:"
    echo "  • Grafana Monitoring: http://192.168.8.250:3000"
    echo "  • Prometheus: http://192.168.8.250:9090"
    echo ""
    
    info "Documentation:"
    echo "  • End User Guide: docs/VPN_EDITION_END_USER_GUIDE.md"
    echo "  • Security Guide: docs/VPN_EDITION_SECURITY_HARDENING.md"
    echo "  • Router Setup: docs/VPN_EDITION_ROUTER_CONFIG.md"
    echo ""
    
    log "✓ Stack is ready!"
}

# Main deployment flow
main() {
    show_banner
    check_prerequisites
    detect_deployment
    ask_vpn_config
    
    echo ""
    info "═══════════════════════════════════════════════════════"
    info "Starting Deployment"
    info "═══════════════════════════════════════════════════════"
    
    # Check if VPN edition deployment exists
    if [ "$ENABLE_VPN" = "yes" ]; then
        local vpn_deployment="$REPO_ROOT/deployments/${DEPLOYMENT_TYPE}_VPN"
        if [ ! -d "$vpn_deployment" ]; then
            error "VPN Edition deployment not found: ${DEPLOYMENT_TYPE}_VPN"
            error "Please deploy DNS stack first, then add VPN separately."
            exit 1
        fi
    fi
    
    # Deploy DNS stack
    deploy_dns_stack
    
    # Deploy VPN stack if requested
    if [ "$ENABLE_VPN" = "yes" ]; then
        deploy_vpn_stack
    fi
    
    # Show summary
    show_summary
}

# Run main function
main "$@"
