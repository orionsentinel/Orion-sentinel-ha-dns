#!/bin/bash

################################################################################
# VPN Edition Installation Script
# 
# This script automates the installation of the VPN Edition for any tier:
# - Generates secure random secrets
# - Creates configuration files
# - Validates prerequisites
# - Deploys the VPN stack
# - Provides post-installation instructions
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
    echo -e "${BLUE}ℹ${NC} $1"
}

generate_secret() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}

generate_password() {
    openssl rand -base64 16 | tr -d "=+/" | cut -c1-16
}

# Welcome
print_header "VPN Edition Installation"
echo "This script will set up WireGuard VPN with HA DNS integration"
echo ""

# Detect deployment type
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

print_info "Detecting deployment location..."
CURRENT_DIR=$(pwd)

# Determine if we're in a deployment directory
DEPLOYMENT_TYPE=""
ENV_VPN_PATH=""
COMPOSE_VPN_PATH=""

if [[ $CURRENT_DIR == *"/deployments/HighAvail_1Pi2P2U_VPN"* ]]; then
    DEPLOYMENT_TYPE="1Pi2P2U_VPN"
    ENV_VPN_PATH=".env.vpn"
    COMPOSE_VPN_PATH="docker-compose.vpn.yml"
elif [[ $CURRENT_DIR == *"/deployments/HighAvail_2Pi1P1U_VPN"* ]]; then
    DEPLOYMENT_TYPE="2Pi1P1U_VPN"
    if [[ $CURRENT_DIR == *"/node1" ]]; then
        ENV_VPN_PATH=".env.vpn"
        COMPOSE_VPN_PATH="docker-compose.vpn.yml"
    else
        print_error "Run this script from the node1/ directory for 2-Pi deployments"
        exit 1
    fi
elif [[ $CURRENT_DIR == *"/deployments/HighAvail_2Pi2P2U_VPN"* ]]; then
    DEPLOYMENT_TYPE="2Pi2P2U_VPN"
    if [[ $CURRENT_DIR == *"/node1" ]]; then
        ENV_VPN_PATH=".env.vpn"
        COMPOSE_VPN_PATH="docker-compose.vpn.yml"
    else
        print_error "Run this script from the node1/ directory for 2-Pi deployments"
        exit 1
    fi
elif [[ $CURRENT_DIR == *"/stacks/vpn"* ]]; then
    DEPLOYMENT_TYPE="standalone"
    ENV_VPN_PATH=".env.vpn"
    COMPOSE_VPN_PATH="docker-compose.vpn.yml"
else
    print_warning "Not in a VPN Edition deployment directory"
    echo "Please cd to one of:"
    echo "  - deployments/HighAvail_1Pi2P2U_VPN/"
    echo "  - deployments/HighAvail_2Pi1P1U_VPN/node1/"
    echo "  - deployments/HighAvail_2Pi2P2U_VPN/node1/"
    echo "  - stacks/vpn/"
    exit 1
fi

print_success "Detected deployment type: $DEPLOYMENT_TYPE"

# Prerequisites check
print_header "Checking Prerequisites"

# Check Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed"
    exit 1
fi
print_success "Docker installed"

# Check Docker Compose
if ! docker compose version &> /dev/null; then
    print_error "Docker Compose is not installed"
    exit 1
fi
print_success "Docker Compose installed"

# Check if DNS stack is running (for deployment directories)
if [[ $DEPLOYMENT_TYPE != "standalone" ]]; then
    if docker ps | grep -q "pihole"; then
        print_success "DNS stack is running"
    else
        print_warning "DNS stack does not appear to be running"
        echo "Deploy the DNS stack first with: docker compose up -d"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
fi

# Interactive configuration
print_header "VPN Configuration"

if [ -f "$ENV_VPN_PATH" ]; then
    print_warning ".env.vpn already exists"
    read -p "Overwrite existing configuration? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Using existing .env.vpn"
        ENV_EXISTS=true
    else
        ENV_EXISTS=false
    fi
else
    ENV_EXISTS=false
fi

if [ "$ENV_EXISTS" = false ]; then
    # Check if .env.vpn.example exists
    if [ ! -f "${ENV_VPN_PATH}.example" ]; then
        print_error "${ENV_VPN_PATH}.example not found"
        exit 1
    fi

    # Copy example
    cp "${ENV_VPN_PATH}.example" "$ENV_VPN_PATH"
    print_success "Created .env.vpn from template"

    # Get WG_HOST
    echo ""
    print_info "WireGuard Public Endpoint Configuration"
    echo "This is how clients will reach your VPN server from the internet."
    echo ""
    echo "Options:"
    echo "  1. Static public IP: 203.0.113.45"
    echo "  2. DDNS hostname: myhome.duckdns.org"
    echo ""
    read -p "Enter your public IP or DDNS hostname: " WG_HOST
    
    if [ -z "$WG_HOST" ]; then
        print_error "WG_HOST is required"
        exit 1
    fi

    # Get WG_PORT (optional, default 51820)
    echo ""
    read -p "Enter WireGuard port (default 51820): " WG_PORT
    WG_PORT=${WG_PORT:-51820}

    # Get WG_PEERS
    echo ""
    print_info "VPN Client Configuration"
    echo "You can specify peers as:"
    echo "  - Number: '3' (generates peer1, peer2, peer3)"
    echo "  - Names: 'phone,laptop,tablet'"
    echo ""
    read -p "Enter number or names of peers (default: 3): " WG_PEERS
    WG_PEERS=${WG_PEERS:-3}

    # Generate secrets
    print_info "Generating secure secrets..."
    SESSION_SECRET=$(generate_secret)
    WGUI_PASSWORD=$(generate_password)

    # Update .env.vpn
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s|^WG_HOST=.*|WG_HOST=$WG_HOST|" "$ENV_VPN_PATH"
        sed -i '' "s|^WG_PORT=.*|WG_PORT=$WG_PORT|" "$ENV_VPN_PATH"
        sed -i '' "s|^WG_PEERS=.*|WG_PEERS=$WG_PEERS|" "$ENV_VPN_PATH"
        sed -i '' "s|^WGUI_SESSION_SECRET=.*|WGUI_SESSION_SECRET=$SESSION_SECRET|" "$ENV_VPN_PATH"
        sed -i '' "s|^WGUI_PASSWORD=.*|WGUI_PASSWORD=$WGUI_PASSWORD|" "$ENV_VPN_PATH"
    else
        # Linux
        sed -i "s|^WG_HOST=.*|WG_HOST=$WG_HOST|" "$ENV_VPN_PATH"
        sed -i "s|^WG_PORT=.*|WG_PORT=$WG_PORT|" "$ENV_VPN_PATH"
        sed -i "s|^WG_PEERS=.*|WG_PEERS=$WG_PEERS|" "$ENV_VPN_PATH"
        sed -i "s|^WGUI_SESSION_SECRET=.*|WGUI_SESSION_SECRET=$SESSION_SECRET|" "$ENV_VPN_PATH"
        sed -i "s|^WGUI_PASSWORD=.*|WGUI_PASSWORD=$WGUI_PASSWORD|" "$ENV_VPN_PATH"
    fi

    print_success "Configuration saved to .env.vpn"
    echo ""
    print_warning "IMPORTANT - Save these credentials securely:"
    echo "  WireGuard-UI Username: admin"
    echo "  WireGuard-UI Password: $WGUI_PASSWORD"
    echo ""
    read -p "Press Enter when you have saved these credentials..."
fi

# Create config directory
print_header "Creating WireGuard Configuration Directory"
WG_CONFIG_DIR="/opt/rpi-ha-dns-stack/config/wireguard"
if [ ! -d "$WG_CONFIG_DIR" ]; then
    sudo mkdir -p "$WG_CONFIG_DIR"
    sudo chown -R "$(id -u):$(id -g)" "$WG_CONFIG_DIR"
    print_success "Created $WG_CONFIG_DIR"
else
    print_success "Directory $WG_CONFIG_DIR already exists"
fi

# Deploy VPN stack
print_header "Deploying VPN Stack"

read -p "Deploy WireGuard with Web UI? (Y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    PROFILE_ARG=""
else
    PROFILE_ARG="--profile ui"
fi

print_info "Starting WireGuard VPN..."
docker compose -f "$COMPOSE_VPN_PATH" --env-file "$ENV_VPN_PATH" $PROFILE_ARG up -d

if [ $? -eq 0 ]; then
    print_success "VPN stack deployed successfully!"
else
    print_error "Failed to deploy VPN stack"
    exit 1
fi

# Wait for services to be ready
print_info "Waiting for services to initialize..."
sleep 5

# Get local IP
LOCAL_IP=$(hostname -I | awk '{print $1}')

# Post-installation instructions
print_header "Installation Complete! 🎉"

echo ""
print_success "VPN Edition is now running!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  NEXT STEPS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Configure Router Port Forwarding:"
echo "   • Forward UDP port $WG_PORT to $LOCAL_IP"
echo "   • External Port: $WG_PORT"
echo "   • Internal IP: $LOCAL_IP"
echo "   • Protocol: UDP"
echo ""
if [[ $PROFILE_ARG == *"ui"* ]]; then
    echo "2. Access WireGuard-UI (LAN only):"
    echo "   • URL: http://$LOCAL_IP:5000"
    echo "   • Username: admin"
    echo "   • Password: (see above or check .env.vpn)"
    echo ""
    echo "3. Generate QR Codes:"
    echo "   • Log into WireGuard-UI"
    echo "   • View each client"
    echo "   • Click 'Show QR Code'"
    echo "   • Scan with WireGuard mobile app"
    echo ""
else
    echo "2. Get Client Configurations:"
    echo "   • Configs: $WG_CONFIG_DIR/peer*/peer*.conf"
    echo "   • QR Codes: $WG_CONFIG_DIR/peer*/peer*.png"
    echo ""
    echo "   View QR for peer 1:"
    echo "   docker exec wireguard /app/show-peer 1"
    echo ""
fi
echo "4. Install WireGuard on Devices:"
echo "   • iOS/Android: Download 'WireGuard' from App Store/Play Store"
echo "   • Windows/macOS/Linux: Download from wireguard.com"
echo "   • Import config via QR code or .conf file"
echo ""
echo "5. Test Connection:"
echo "   • Enable VPN on your device"
echo "   • Visit http://192.168.8.251/admin (Pi-hole)"
echo "   • Check Pi-hole shows your VPN client IP (10.6.0.x)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_info "Configuration saved in: $ENV_VPN_PATH"
print_info "WireGuard configs: $WG_CONFIG_DIR/"
echo ""
print_warning "Security Reminder:"
echo "  • Never commit .env.vpn to version control"
echo "  • Keep WireGuard-UI accessible only from LAN"
echo "  • Use strong passwords"
echo "  • Regularly update Docker images"
echo ""
print_success "Installation complete! Happy VPNing! 🚀"
echo ""
