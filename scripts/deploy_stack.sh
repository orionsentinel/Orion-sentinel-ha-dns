#!/bin/bash

################################################################################
# RPi HA DNS Stack - Unified Deployment Script
# 
# This script deploys the HA DNS stack with optional VPN Edition integration.
# It prompts the user for deployment preferences and configures accordingly.
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
    echo -e "\n${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}\n"
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

# Welcome banner
clear
print_header "RPi HA DNS Stack - Deployment Wizard"
echo "Welcome to the automated deployment wizard!"
echo "This script will guide you through setting up your HA DNS stack"
echo "with optional VPN Edition integration."
echo ""

# Step 1: Check prerequisites
print_header "Step 1/5: Checking Prerequisites"

print_info "Checking Docker installation..."
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | cut -d ' ' -f3 | cut -d ',' -f1)
    print_success "Docker $DOCKER_VERSION found"
else
    print_error "Docker not found. Please install Docker first:"
    echo "  curl -fsSL https://get.docker.com | sh"
    exit 1
fi

print_info "Checking Docker Compose installation..."
if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
    if docker compose version &> /dev/null; then
        COMPOSE_VERSION=$(docker compose version --short)
        print_success "Docker Compose v$COMPOSE_VERSION found"
    else
        COMPOSE_VERSION=$(docker-compose --version | cut -d ' ' -f3 | cut -d ',' -f1)
        print_success "Docker Compose v$COMPOSE_VERSION found"
    fi
else
    print_error "Docker Compose not found. Please install Docker Compose first"
    exit 1
fi

print_info "Checking OpenSSL for secret generation..."
if command -v openssl &> /dev/null; then
    print_success "OpenSSL found"
else
    print_error "OpenSSL not found. Install with: sudo apt-get install openssl"
    exit 1
fi

# Step 2: Select deployment tier
print_header "Step 2/5: Select Deployment Tier"
echo "Choose your deployment option:"
echo ""
echo "  1) HighAvail_1Pi2P2U     - 1 Pi, DNS only (10 min setup)"
echo "  2) HighAvail_1Pi2P2U_VPN - 1 Pi, DNS + VPN (15 min setup) ⭐ RECOMMENDED"
echo "  3) HighAvail_2Pi1P1U     - 2 Pis, Production (30 min setup)"
echo "  4) HighAvail_2Pi1P1U_VPN - 2 Pis, Production + VPN (35 min setup)"
echo "  5) HighAvail_2Pi2P2U     - 2 Pis, Maximum (45 min setup)"
echo "  6) HighAvail_2Pi2P2U_VPN - 2 Pis, Maximum + VPN (50 min setup)"
echo ""

while true; do
    echo -n "Enter your choice (1-6): "
    read -r DEPLOYMENT_CHOICE
    
    case $DEPLOYMENT_CHOICE in
        1) DEPLOYMENT_TIER="HighAvail_1Pi2P2U"; ENABLE_VPN="no"; break ;;
        2) DEPLOYMENT_TIER="HighAvail_1Pi2P2U_VPN"; ENABLE_VPN="yes"; break ;;
        3) DEPLOYMENT_TIER="HighAvail_2Pi1P1U"; ENABLE_VPN="no"; break ;;
        4) DEPLOYMENT_TIER="HighAvail_2Pi1P1U_VPN"; ENABLE_VPN="yes"; break ;;
        5) DEPLOYMENT_TIER="HighAvail_2Pi2P2U"; ENABLE_VPN="no"; break ;;
        6) DEPLOYMENT_TIER="HighAvail_2Pi2P2U_VPN"; ENABLE_VPN="yes"; break ;;
        *) print_error "Invalid choice. Please enter 1-6." ;;
    esac
done

print_success "Selected: $DEPLOYMENT_TIER"

# Alternative path: Ask about VPN if user selected non-VPN tier
if [[ $ENABLE_VPN == "no" ]]; then
    echo ""
    echo "Would you like to add VPN remote access to this deployment?"
    echo "This allows secure access to your home network from anywhere."
    echo ""
    
    while true; do
        echo -n "Enable VPN Edition? (yes/no): "
        read -r VPN_RESPONSE
        
        case $VPN_RESPONSE in
            yes|y|Y|YES)
                ENABLE_VPN="yes"
                # Update deployment tier to VPN version
                DEPLOYMENT_TIER="${DEPLOYMENT_TIER}_VPN"
                print_success "VPN Edition will be configured"
                break
                ;;
            no|n|N|NO)
                print_info "VPN Edition will not be configured"
                break
                ;;
            *)
                print_error "Please answer yes or no"
                ;;
        esac
    done
fi

# Step 3: Navigate to deployment directory
print_header "Step 3/5: Preparing Deployment Directory"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
DEPLOYMENT_DIR="$REPO_ROOT/deployments/$DEPLOYMENT_TIER"

if [ ! -d "$DEPLOYMENT_DIR" ]; then
    print_error "Deployment directory not found: $DEPLOYMENT_DIR"
    exit 1
fi

print_success "Deployment directory: $DEPLOYMENT_DIR"
cd "$DEPLOYMENT_DIR" || exit 1

# Step 4: Configure DNS Stack
print_header "Step 4/5: Configure DNS Stack"

if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        print_info "Creating .env from .env.example..."
        cp .env.example .env
        print_success ".env file created"
    else
        print_error ".env.example not found in deployment directory"
        exit 1
    fi
else
    print_warning ".env already exists, skipping creation"
fi

print_info "Please review and edit .env with your configuration"
echo "  - Set HOST_IP to your Pi's IP address"
echo "  - Set VIP if needed (for HA deployments)"
echo "  - Configure Pi-hole password"
echo ""
echo -n "Press Enter when ready to continue..."
read -r

# Step 5: Configure VPN (if enabled)
if [[ $ENABLE_VPN == "yes" ]]; then
    print_header "Step 5/5: Configure VPN Edition"
    
    # Determine VPN config location
    if [[ $DEPLOYMENT_TIER == *"2Pi"* ]]; then
        VPN_CONFIG_DIR="$DEPLOYMENT_DIR/node1"
    else
        VPN_CONFIG_DIR="$DEPLOYMENT_DIR"
    fi
    
    cd "$VPN_CONFIG_DIR" || exit 1
    
    # Check if .env.vpn exists
    if [ ! -f ".env.vpn" ]; then
        if [ -f ".env.vpn.example" ]; then
            print_info "Creating .env.vpn configuration..."
            cp .env.vpn.example .env.vpn
            
            # Generate secrets
            print_info "Generating secure secrets..."
            SESSION_SECRET=$(generate_secret)
            WGUI_PASSWORD=$(generate_password)
            
            # Update .env.vpn with generated secrets
            sed -i "s/SESSION_SECRET=.*/SESSION_SECRET=$SESSION_SECRET/" .env.vpn
            sed -i "s/WGUI_PASSWORD=.*/WGUI_PASSWORD=$WGUI_PASSWORD/" .env.vpn
            
            print_success "Secrets generated successfully"
            
            # Prompt for WG_HOST
            echo ""
            echo "VPN Configuration:"
            echo ""
            echo "WG_HOST: Your public IP or DDNS hostname"
            echo "  Examples: myhome.duckdns.org, 123.45.67.89"
            echo ""
            echo -n "Enter WG_HOST: "
            read -r WG_HOST
            
            if [ -n "$WG_HOST" ]; then
                sed -i "s/WG_HOST=.*/WG_HOST=$WG_HOST/" .env.vpn
                print_success "WG_HOST configured: $WG_HOST"
            else
                print_warning "WG_HOST not set. You'll need to configure it manually in .env.vpn"
            fi
            
            # Prompt for WG_PEERS
            echo ""
            echo "WG_PEERS: List of VPN clients (comma-separated or number)"
            echo "  Examples: phone,laptop,tablet OR 3"
            echo ""
            echo -n "Enter WG_PEERS [default: 3]: "
            read -r WG_PEERS
            
            if [ -z "$WG_PEERS" ]; then
                WG_PEERS="3"
            fi
            
            sed -i "s/WG_PEERS=.*/WG_PEERS=$WG_PEERS/" .env.vpn
            print_success "WG_PEERS configured: $WG_PEERS"
            
            print_success ".env.vpn configured successfully"
        else
            print_error ".env.vpn.example not found in $VPN_CONFIG_DIR"
            exit 1
        fi
    else
        print_warning ".env.vpn already exists, skipping VPN configuration"
    fi
    
    # Create WireGuard config directory
    WG_CONFIG_DIR="/opt/rpi-ha-dns-stack/config/wireguard"
    if [ ! -d "$WG_CONFIG_DIR" ]; then
        print_info "Creating WireGuard config directory..."
        sudo mkdir -p "$WG_CONFIG_DIR"
        sudo chown -R "$USER:$USER" "$WG_CONFIG_DIR"
        print_success "Config directory created: $WG_CONFIG_DIR"
    else
        print_info "WireGuard config directory already exists"
    fi
else
    print_header "Step 5/5: VPN Configuration (Skipped)"
    print_info "VPN Edition not enabled"
fi

# Final deployment summary
print_header "Deployment Summary"
echo "Deployment Tier: $DEPLOYMENT_TIER"
echo "VPN Enabled: $ENABLE_VPN"
echo "Deployment Directory: $DEPLOYMENT_DIR"
echo ""

if [[ $ENABLE_VPN == "yes" ]]; then
    echo "VPN Configuration:"
    echo "  - Config location: $VPN_CONFIG_DIR/.env.vpn"
    echo "  - WireGuard UI: http://<your-pi-ip>:5000"
    echo "  - Generated password saved in .env.vpn"
    echo ""
fi

# Ask if user wants to deploy now
echo ""
echo -n "Would you like to deploy now? (yes/no): "
read -r DEPLOY_NOW

if [[ $DEPLOY_NOW =~ ^(yes|y|Y|YES)$ ]]; then
    print_header "Deploying Stack..."
    
    cd "$DEPLOYMENT_DIR" || exit 1
    
    # Create Docker network if it doesn't exist
    print_info "Creating Docker network..."
    if docker network create --subnet=192.168.8.0/24 dns_net 2>/dev/null; then
        print_success "Docker network created"
    else
        print_info "Docker network already exists"
    fi
    
    # Deploy DNS stack
    print_info "Deploying DNS stack..."
    if docker compose up -d; then
        print_success "DNS stack deployed successfully"
    else
        print_error "Failed to deploy DNS stack"
        exit 1
    fi
    
    # Deploy VPN stack if enabled
    if [[ $ENABLE_VPN == "yes" ]]; then
        cd "$VPN_CONFIG_DIR" || exit 1
        
        print_info "Deploying VPN stack..."
        if docker compose -f docker-compose.vpn.yml --env-file .env.vpn --profile ui up -d; then
            print_success "VPN stack deployed successfully"
        else
            print_error "Failed to deploy VPN stack"
            exit 1
        fi
    fi
    
    # Success message
    print_header "Deployment Complete! 🎉"
    print_success "Your HA DNS stack is now running!"
    echo ""
    echo "Next Steps:"
    echo ""
    echo "1. Access Pi-hole Admin:"
    echo "   http://192.168.8.251/admin (Primary)"
    echo "   http://192.168.8.252/admin (Secondary)"
    echo ""
    
    if [[ $ENABLE_VPN == "yes" ]]; then
        echo "2. Configure VPN:"
        echo "   - Access WireGuard-UI: http://<your-pi-ip>:5000"
        echo "   - Username: admin"
        echo "   - Password: (check .env.vpn file)"
        echo ""
        echo "3. Configure Router:"
        echo "   - Forward UDP port 51820 to your Pi"
        echo "   - See: docs/VPN_EDITION_ROUTER_CONFIG.md"
        echo ""
        echo "4. Generate QR Codes:"
        echo "   - Open WireGuard-UI and create peers"
        echo "   - Scan QR codes with WireGuard mobile app"
        echo ""
        echo "5. For detailed documentation:"
        echo "   - End User Guide: docs/VPN_EDITION_END_USER_GUIDE.md"
        echo "   - Security Hardening: docs/VPN_EDITION_SECURITY_HARDENING.md"
    else
        echo "2. Configure DNS on your devices to point to:"
        echo "   192.168.8.255 (VIP - recommended for automatic failover)"
        echo ""
        echo "3. To add VPN later, run:"
        echo "   cd deployments/${DEPLOYMENT_TIER}_VPN"
        echo "   ../../../scripts/install_vpn_edition.sh"
    fi
    echo ""
    print_success "Deployment wizard completed!"
    
else
    print_header "Manual Deployment Instructions"
    echo "To deploy the stack manually:"
    echo ""
    echo "1. Review and edit configuration files:"
    echo "   cd $DEPLOYMENT_DIR"
    echo "   nano .env"
    if [[ $ENABLE_VPN == "yes" ]]; then
        echo "   nano $VPN_CONFIG_DIR/.env.vpn"
    fi
    echo ""
    echo "2. Create Docker network:"
    echo "   docker network create --subnet=192.168.8.0/24 dns_net"
    echo ""
    echo "3. Deploy DNS stack:"
    echo "   cd $DEPLOYMENT_DIR"
    echo "   docker compose up -d"
    echo ""
    
    if [[ $ENABLE_VPN == "yes" ]]; then
        echo "4. Deploy VPN stack:"
        echo "   cd $VPN_CONFIG_DIR"
        echo "   docker compose -f docker-compose.vpn.yml --env-file .env.vpn --profile ui up -d"
        echo ""
    fi
    
    print_info "Configuration files have been prepared for manual deployment"
fi
