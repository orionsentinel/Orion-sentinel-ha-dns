#!/bin/bash

################################################################################
# Unified Stack Deployment Script
# 
# This script deploys the HA DNS stack with optional VPN configuration:
# - Prompts user for deployment preferences
# - Configures DNS stack (required)
# - Optionally configures VPN Edition (WireGuard)
# - Validates prerequisites
# - Provides post-installation instructions
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

generate_secret() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}

generate_password() {
    openssl rand -base64 16 | tr -d "=+/" | cut -c1-16
}

# Welcome banner
clear
print_header "HA DNS Stack Deployment Wizard"
echo -e "${CYAN}This script will guide you through deploying your HA DNS stack.${NC}"
echo -e "${CYAN}You can choose to deploy DNS only or DNS + VPN Edition.${NC}"
echo ""

# Detect current directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CURRENT_DIR=$(pwd)

# Prerequisites check
print_header "Step 1: Prerequisites Check"

print_info "Checking Docker..."
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
    print_success "Docker installed: $DOCKER_VERSION"
else
    print_error "Docker not found. Please install Docker first."
    echo "  Visit: https://docs.docker.com/engine/install/"
    exit 1
fi

print_info "Checking Docker Compose..."
if docker compose version &> /dev/null; then
    COMPOSE_VERSION=$(docker compose version | awk '{print $4}')
    print_success "Docker Compose installed: $COMPOSE_VERSION"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_VERSION=$(docker-compose --version | awk '{print $4}' | sed 's/,//')
    print_success "Docker Compose (standalone) installed: $COMPOSE_VERSION"
else
    print_error "Docker Compose not found. Please install Docker Compose."
    echo "  Visit: https://docs.docker.com/compose/install/"
    exit 1
fi

print_info "Checking OpenSSL (for secret generation)..."
if command -v openssl &> /dev/null; then
    print_success "OpenSSL installed"
else
    print_error "OpenSSL not found. Please install OpenSSL."
    exit 1
fi

echo ""

# Deployment type selection
print_header "Step 2: Select Deployment Type"
echo "Choose your deployment tier:"
echo ""
echo "  1) Starter          - 1 Pi, DNS only (10 min setup)"
echo "  2) VPN Edition      - 1 Pi, DNS + VPN with QR codes (20-30 min setup) ⭐ Recommended"
echo "  3) Production       - 2 Pis, hardware redundancy (30 min setup)"
echo "  4) Production VPN   - 2 Pis, DNS + VPN (35-45 min setup)"
echo "  5) Maximum          - 2 Pis, full redundancy (45 min setup)"
echo "  6) Maximum VPN      - 2 Pis, full redundancy + VPN (45-60 min setup)"
echo ""
read -p "Enter your choice (1-6): " DEPLOYMENT_CHOICE

case $DEPLOYMENT_CHOICE in
    1)
        DEPLOYMENT_TYPE="HighAvail_1Pi2P2U"
        ENABLE_VPN="no"
        ;;
    2)
        DEPLOYMENT_TYPE="HighAvail_1Pi2P2U"
        ENABLE_VPN="yes"
        ;;
    3)
        DEPLOYMENT_TYPE="HighAvail_2Pi1P1U"
        ENABLE_VPN="no"
        ;;
    4)
        DEPLOYMENT_TYPE="HighAvail_2Pi1P1U"
        ENABLE_VPN="yes"
        ;;
    5)
        DEPLOYMENT_TYPE="HighAvail_2Pi2P2U"
        ENABLE_VPN="no"
        ;;
    6)
        DEPLOYMENT_TYPE="HighAvail_2Pi2P2U"
        ENABLE_VPN="yes"
        ;;
    *)
        print_error "Invalid choice. Exiting."
        exit 1
        ;;
esac

echo ""
print_info "Selected: $DEPLOYMENT_TYPE $([ "$ENABLE_VPN" = "yes" ] && echo "+ VPN Edition")"
echo ""

# Confirm deployment path
DEPLOYMENT_PATH="$REPO_ROOT/deployments/$DEPLOYMENT_TYPE"
if [ "$ENABLE_VPN" = "yes" ]; then
    DEPLOYMENT_PATH="${DEPLOYMENT_PATH}_VPN"
fi

if [ ! -d "$DEPLOYMENT_PATH" ]; then
    print_error "Deployment path not found: $DEPLOYMENT_PATH"
    print_info "Please ensure you're running this script from the repository root."
    exit 1
fi

print_success "Deployment path: $DEPLOYMENT_PATH"
echo ""

# VPN Configuration (if enabled)
if [ "$ENABLE_VPN" = "yes" ]; then
    print_header "Step 3: VPN Configuration"
    
    print_info "The VPN Edition requires a few configuration parameters."
    echo ""
    
    # WG_HOST
    echo -e "${CYAN}Enter your public IP or DDNS hostname:${NC}"
    echo "  Examples: myhome.duckdns.org, 123.45.67.89"
    echo "  (This is where VPN clients will connect)"
    read -p "WG_HOST: " WG_HOST
    
    if [ -z "$WG_HOST" ]; then
        print_error "WG_HOST cannot be empty"
        exit 1
    fi
    
    # WG_PEERS
    echo ""
    echo -e "${CYAN}How many VPN peers (devices) do you need?${NC}"
    echo "  Examples: 3, phone,laptop,tablet"
    read -p "WG_PEERS (number or comma-separated names) [3]: " WG_PEERS
    WG_PEERS=${WG_PEERS:-3}
    
    # Generate secrets
    print_info "Generating secure secrets..."
    SESSION_SECRET=$(generate_secret)
    WGUI_PASSWORD=$(generate_password)
    print_success "Secrets generated"
    
    echo ""
    print_success "VPN Configuration:"
    echo "  WG_HOST: $WG_HOST"
    echo "  WG_PEERS: $WG_PEERS"
    echo "  WG_PEER_DNS: 192.168.8.255 (HA VIP)"
    echo "  WGUI_PASSWORD: $WGUI_PASSWORD (save this!)"
    echo ""
else
    print_header "Step 3: VPN Configuration"
    print_info "VPN not selected. Deploying DNS stack only."
    echo ""
fi

# Confirm deployment
print_header "Step 4: Confirm Deployment"
echo "Ready to deploy:"
echo "  Type: $DEPLOYMENT_TYPE $([ "$ENABLE_VPN" = "yes" ] && echo "+ VPN Edition")"
echo "  Path: $DEPLOYMENT_PATH"
[ "$ENABLE_VPN" = "yes" ] && echo "  VPN Host: $WG_HOST"
echo ""
read -p "Proceed with deployment? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    print_warning "Deployment cancelled."
    exit 0
fi

# Navigate to deployment directory
cd "$DEPLOYMENT_PATH"

# Deploy DNS stack
print_header "Step 5: Deploying DNS Stack"

# Handle multi-node deployments
if [[ "$DEPLOYMENT_TYPE" == *"2Pi"* ]]; then
    print_info "This is a 2-Pi deployment."
    print_warning "You need to deploy on both nodes separately."
    echo ""
    echo "Current steps for Node 1:"
    
    cd node1
    
    if [ ! -f ".env" ]; then
        if [ -f ".env.example" ]; then
            print_info "Creating .env from .env.example..."
            cp .env.example .env
            print_success ".env created"
        fi
    else
        print_success ".env already exists"
    fi
    
    print_info "Creating Docker network..."
    docker network create --subnet=192.168.8.0/24 dns_net 2>/dev/null || print_warning "Network dns_net already exists"
    
    print_info "Deploying DNS stack on Node 1..."
    docker compose up -d
    print_success "DNS stack deployed on Node 1"
    
    cd ..
    
    echo ""
    print_warning "IMPORTANT: Deploy on Node 2 next"
    echo "Run these commands on your second Pi:"
    echo ""
    echo "  cd $DEPLOYMENT_PATH/node2"
    echo "  cp .env.example .env"
    echo "  nano .env  # Configure Node 2 IP addresses"
    echo "  docker network create --subnet=192.168.8.0/24 dns_net"
    echo "  docker compose up -d"
    echo ""
else
    # Single Pi deployment
    if [ ! -f ".env" ]; then
        if [ -f ".env.example" ]; then
            print_info "Creating .env from .env.example..."
            cp .env.example .env
            print_success ".env created"
        fi
    else
        print_success ".env already exists"
    fi
    
    print_info "Creating Docker network..."
    docker network create --subnet=192.168.8.0/24 dns_net 2>/dev/null || print_warning "Network dns_net already exists"
    
    print_info "Deploying DNS stack..."
    docker compose up -d
    print_success "DNS stack deployed"
fi

# Deploy VPN stack (if enabled)
if [ "$ENABLE_VPN" = "yes" ]; then
    print_header "Step 6: Deploying VPN Stack"
    
    # Navigate to node1 for multi-node deployments
    if [[ "$DEPLOYMENT_TYPE" == *"2Pi"* ]]; then
        cd node1
    fi
    
    # Create .env.vpn file
    if [ -f ".env.vpn.example" ]; then
        print_info "Creating .env.vpn configuration..."
        
        cat > .env.vpn << EOF
# VPN Edition Configuration
# Generated by deploy-stack.sh on $(date)

# General
TZ=UTC
PUID=1000
PGID=1000

# WireGuard Server Configuration
WG_HOST=$WG_HOST
WG_PORT=51820
WG_PEERS=$WG_PEERS
WG_SUBNET=10.6.0.0/24
WG_PEER_DNS=192.168.8.255
WG_ALLOWEDIPS=192.168.8.0/24,10.6.0.0/24

# WireGuard Config Directory
WG_CONFIG_DIR=/opt/rpi-ha-dns-stack/config/wireguard

# WireGuard-UI Configuration
WGUI_USERNAME=admin
WGUI_PASSWORD=$WGUI_PASSWORD
WGUI_SESSION_SECRET=$SESSION_SECRET
WGUI_ENDPOINT_ADDRESS=$WG_HOST:51820
EOF
        
        print_success ".env.vpn created"
    else
        print_error ".env.vpn.example not found"
        exit 1
    fi
    
    # Create WireGuard config directory
    print_info "Creating WireGuard config directory..."
    sudo mkdir -p /opt/rpi-ha-dns-stack/config/wireguard
    sudo chown -R "$(id -u):$(id -g)" /opt/rpi-ha-dns-stack/config/wireguard
    print_success "Config directory created"
    
    # Deploy VPN stack
    print_info "Deploying VPN stack..."
    docker compose -f docker-compose.vpn.yml --env-file .env.vpn --profile ui up -d
    print_success "VPN stack deployed"
    
    # Navigate back if needed
    if [[ "$DEPLOYMENT_TYPE" == *"2Pi"* ]]; then
        cd ..
    fi
fi

# Final instructions
print_header "Deployment Complete! 🎉"

echo -e "${GREEN}Your HA DNS stack is now running!${NC}"
echo ""

print_info "DNS Stack Access:"
echo "  Pi-hole Admin: http://192.168.8.251/admin"
if [[ "$DEPLOYMENT_TYPE" == *"2Pi"* ]]; then
    echo "  Pi-hole Secondary: http://192.168.8.252/admin"
fi
echo "  VIP Address: 192.168.8.255 (automatic failover)"
echo ""

if [ "$ENABLE_VPN" = "yes" ]; then
    print_info "VPN Stack Access:"
    echo "  WireGuard-UI: http://192.168.8.250:5000"
    echo "  Username: admin"
    echo "  Password: $WGUI_PASSWORD"
    echo ""
    
    print_warning "Next Steps for VPN:"
    echo "  1. Configure port forwarding on your router:"
    echo "     Forward UDP port 51820 → 192.168.8.250"
    echo ""
    echo "  2. Set up DDNS (if using dynamic IP):"
    echo "     See: docs/VPN_EDITION_ROUTER_CONFIG.md"
    echo ""
    echo "  3. Access WireGuard-UI to get QR codes:"
    echo "     http://192.168.8.250:5000"
    echo ""
    echo "  4. Share QR codes with end users for instant setup!"
    echo ""
    
    print_info "Documentation:"
    echo "  End User Guide: docs/VPN_EDITION_END_USER_GUIDE.md"
    echo "  Security Hardening: docs/VPN_EDITION_SECURITY_HARDENING.md"
    echo "  Router Config: docs/VPN_EDITION_ROUTER_CONFIG.md"
    echo ""
fi

print_info "Useful Commands:"
echo "  Check status:    docker ps"
echo "  View logs:       docker compose logs -f"
echo "  Stop stack:      docker compose down"
if [ "$ENABLE_VPN" = "yes" ]; then
    echo "  Stop VPN:        docker compose -f docker-compose.vpn.yml down"
fi
echo ""

print_success "Deployment finished successfully!"
echo ""
