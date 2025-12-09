#!/usr/bin/env bash
# =============================================================================
# Bootstrap Script for Raspberry Pi Node Setup
# =============================================================================
#
# Purpose:
#   Automated first-time setup of a Raspberry Pi for HA DNS deployment
#
# What it does:
#   - Installs Docker and Docker Compose
#   - Clones repository (or updates existing clone)
#   - Creates .env from template
#   - Sets hostname
#   - Configures system prerequisites
#   - Validates environment
#
# Usage:
#   # For Pi1 (primary):
#   sudo ./scripts/bootstrap-node.sh --node=pi1 --ip=192.168.8.250
#
#   # For Pi2 (secondary):
#   sudo ./scripts/bootstrap-node.sh --node=pi2 --ip=192.168.8.251
#
# =============================================================================

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Configuration
REPO_URL="${REPO_URL:-https://github.com/orionsentinel/Orion-sentinel-ha-dns.git}"
INSTALL_DIR="${INSTALL_DIR:-/opt/orion-dns-ha}"
NODE_NAME=""
NODE_IP=""
SKIP_DOCKER_INSTALL=false
SKIP_HOSTNAME_SET=false

# Logging functions
log() { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err() { echo -e "${RED}[✗]${NC} $*" >&2; }
info() { echo -e "${BLUE}[i]${NC} $*"; }
section() { echo -e "\n${BOLD}${BLUE}━━━ $* ━━━${NC}\n"; }

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Bootstrap a Raspberry Pi node for Orion Sentinel HA DNS

OPTIONS:
    --node=NAME         Node name (pi1 or pi2) [REQUIRED]
    --ip=IP_ADDRESS     IP address for this node [REQUIRED]
    --skip-docker       Skip Docker installation
    --skip-hostname     Skip hostname configuration
    --install-dir=DIR   Installation directory (default: /opt/orion-dns-ha)
    --help              Show this help message

EXAMPLES:
    # Setup Pi1 as primary
    sudo $0 --node=pi1 --ip=192.168.8.250

    # Setup Pi2 as secondary
    sudo $0 --node=pi2 --ip=192.168.8.251

EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --node=*)
            NODE_NAME="${1#*=}"
            shift
            ;;
        --ip=*)
            NODE_IP="${1#*=}"
            shift
            ;;
        --skip-docker)
            SKIP_DOCKER_INSTALL=true
            shift
            ;;
        --skip-hostname)
            SKIP_HOSTNAME_SET=true
            shift
            ;;
        --install-dir=*)
            INSTALL_DIR="${1#*=}"
            shift
            ;;
        --help)
            usage
            ;;
        *)
            err "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate required arguments
if [[ -z "$NODE_NAME" ]] || [[ -z "$NODE_IP" ]]; then
    err "Both --node and --ip are required"
    usage
fi

if [[ "$NODE_NAME" != "pi1" ]] && [[ "$NODE_NAME" != "pi2" ]]; then
    err "Node name must be either 'pi1' or 'pi2'"
    exit 1
fi

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    err "This script must be run as root (use sudo)"
    exit 1
fi

# =============================================================================
# System Checks
# =============================================================================

check_system() {
    section "System Checks"
    
    # Check OS
    if [[ ! -f /etc/os-release ]]; then
        err "Cannot determine OS version"
        exit 1
    fi
    
    source /etc/os-release
    info "OS: $PRETTY_NAME"
    
    # Check architecture
    ARCH=$(uname -m)
    info "Architecture: $ARCH"
    
    if [[ "$ARCH" != "aarch64" ]] && [[ "$ARCH" != "armv7l" ]] && [[ "$ARCH" != "x86_64" ]]; then
        warn "Unsupported architecture: $ARCH (proceeding anyway)"
    fi
    
    # Check available disk space
    AVAIL_SPACE=$(df -BG / | tail -1 | awk '{print $4}' | sed 's/G//')
    if [[ $AVAIL_SPACE -lt 5 ]]; then
        warn "Low disk space: ${AVAIL_SPACE}GB available (recommend at least 10GB)"
    else
        log "Available disk space: ${AVAIL_SPACE}GB"
    fi
    
    log "System checks passed"
}

# =============================================================================
# Docker Installation
# =============================================================================

install_docker() {
    section "Docker Installation"
    
    if [[ "$SKIP_DOCKER_INSTALL" == true ]]; then
        info "Skipping Docker installation (--skip-docker flag)"
        return 0
    fi
    
    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
        log "Docker already installed: $DOCKER_VERSION"
    else
        info "Installing Docker..."
        curl -fsSL https://get.docker.com | sh
        log "Docker installed successfully"
    fi
    
    # Check Docker Compose plugin
    if docker compose version &> /dev/null; then
        COMPOSE_VERSION=$(docker compose version --short)
        log "Docker Compose plugin already installed: $COMPOSE_VERSION"
    else
        info "Installing Docker Compose plugin..."
        apt-get update -qq
        apt-get install -y docker-compose-plugin
        log "Docker Compose plugin installed"
    fi
    
    # Add current user to docker group (if not root)
    if [[ -n "${SUDO_USER:-}" ]]; then
        usermod -aG docker "$SUDO_USER" || true
        log "Added $SUDO_USER to docker group (logout/login required)"
    fi
    
    # Enable Docker service
    systemctl enable docker
    systemctl start docker
    log "Docker service enabled and started"
}

# =============================================================================
# Repository Setup
# =============================================================================

setup_repository() {
    section "Repository Setup"
    
    # Create installation directory
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    if [[ -d ".git" ]]; then
        info "Repository already exists, pulling latest changes..."
        git pull origin main || git pull origin master || warn "Failed to pull latest changes"
        log "Repository updated"
    else
        info "Cloning repository..."
        git clone "$REPO_URL" .
        log "Repository cloned"
    fi
    
    # Make scripts executable
    chmod +x scripts/*.sh 2>/dev/null || true
    log "Scripts made executable"
}

# =============================================================================
# Environment Configuration
# =============================================================================

configure_environment() {
    section "Environment Configuration"
    
    cd "$INSTALL_DIR"
    
    # Copy appropriate environment template
    if [[ ! -f .env ]]; then
        info "Creating .env from template..."
        
        if [[ -f .env.production.example ]]; then
            cp .env.production.example .env
        elif [[ -f .env.example ]]; then
            cp .env.example .env
        else
            err "No .env template found"
            exit 1
        fi
        
        # Apply node-specific configuration
        if [[ "$NODE_NAME" == "pi1" ]]; then
            info "Applying Pi1 configuration..."
            sed -i "s/^HOST_IP=.*/HOST_IP=$NODE_IP/" .env
            sed -i "s/^NODE_ROLE=.*/NODE_ROLE=MASTER/" .env
            sed -i "s/^KEEPALIVED_PRIORITY=.*/KEEPALIVED_PRIORITY=200/" .env
            sed -i "s/^NODE_NAME=.*/NODE_NAME=pi1-dns/" .env
        else
            info "Applying Pi2 configuration..."
            sed -i "s/^HOST_IP=.*/HOST_IP=$NODE_IP/" .env
            sed -i "s/^NODE_ROLE=.*/NODE_ROLE=BACKUP/" .env
            sed -i "s/^KEEPALIVED_PRIORITY=.*/KEEPALIVED_PRIORITY=150/" .env
            sed -i "s/^NODE_NAME=.*/NODE_NAME=pi2-dns/" .env
        fi
        
        log "Environment file created and configured for $NODE_NAME"
        warn "IMPORTANT: Edit .env and set all REQUIRED passwords before deployment"
        warn "  - PIHOLE_PASSWORD"
        warn "  - VRRP_PASSWORD"
        warn "  - VIP_ADDRESS (if different from default)"
    else
        log ".env file already exists, not overwriting"
        info "Review .env and ensure it's configured correctly for $NODE_NAME"
    fi
}

# =============================================================================
# System Configuration
# =============================================================================

configure_system() {
    section "System Configuration"
    
    # Set hostname
    if [[ "$SKIP_HOSTNAME_SET" != true ]]; then
        HOSTNAME="${NODE_NAME}-dns"
        info "Setting hostname to: $HOSTNAME"
        hostnamectl set-hostname "$HOSTNAME"
        log "Hostname set to: $HOSTNAME"
    else
        info "Skipping hostname configuration (--skip-hostname flag)"
    fi
    
    # Install required packages
    info "Installing required packages..."
    apt-get update -qq
    apt-get install -y \
        git \
        curl \
        dnsutils \
        net-tools \
        iputils-ping \
        vim \
        htop
    log "Required packages installed"
    
    # Configure static IP (informational only)
    info "Current IP configuration:"
    ip addr show | grep "inet " | grep -v "127.0.0.1"
    warn "Ensure static IP $NODE_IP is configured in your router or /etc/network/interfaces"
}

# =============================================================================
# Validation
# =============================================================================

validate_setup() {
    section "Validation"
    
    cd "$INSTALL_DIR"
    
    # Check if validate-env.sh exists
    if [[ -f scripts/validate-env.sh ]]; then
        info "Running environment validation..."
        bash scripts/validate-env.sh || warn "Environment validation found issues (review and fix)"
    else
        warn "validate-env.sh not found, skipping validation"
    fi
    
    # Check Docker
    if ! docker ps &>/dev/null; then
        warn "Docker is not accessible. You may need to logout/login or reboot"
    else
        log "Docker is accessible"
    fi
    
    log "Bootstrap validation complete"
}

# =============================================================================
# Summary
# =============================================================================

show_summary() {
    section "Bootstrap Complete"
    
    cat << EOF
${GREEN}✓ Node bootstrap completed successfully!${NC}

${BOLD}Node Configuration:${NC}
  Node Name: ${NODE_NAME}
  Node IP: ${NODE_IP}
  Install Directory: ${INSTALL_DIR}

${BOLD}Next Steps:${NC}

  1. Edit environment configuration:
     ${BLUE}cd $INSTALL_DIR && nano .env${NC}
     
     Set these REQUIRED variables:
     - PIHOLE_PASSWORD (generate with: openssl rand -base64 32)
     - VRRP_PASSWORD (generate with: openssl rand -base64 20)
     - VIP_ADDRESS (the floating IP for DNS)
     - PEER_IP (IP of the other Pi)

  2. Validate configuration:
     ${BLUE}cd $INSTALL_DIR && make validate-env${NC}

  3. Deploy DNS stack:
     ${BLUE}cd $INSTALL_DIR && make up-core${NC}

  4. Check health:
     ${BLUE}cd $INSTALL_DIR && make health-check${NC}

${BOLD}For Two-Pi HA Setup:${NC}
  - Run this script on BOTH Pis with their respective IPs
  - Ensure both Pis have the SAME VIP_ADDRESS and VRRP_PASSWORD
  - Ensure PEER_IP points to the other Pi

${BOLD}Documentation:${NC}
  - README.md - Quick start guide
  - docs/install-two-pi-ha.md - Detailed HA setup
  - TROUBLESHOOTING.md - Common issues

${YELLOW}Note: If you added your user to the docker group, logout and login again.${NC}

EOF
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║       Orion Sentinel HA DNS - Node Bootstrap             ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
    
    info "Bootstrapping $NODE_NAME at $NODE_IP"
    echo ""
    
    check_system
    install_docker
    setup_repository
    configure_environment
    configure_system
    validate_setup
    show_summary
}

# Run main function
main
