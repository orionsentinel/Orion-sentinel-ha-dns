#!/usr/bin/env bash
# =============================================================================
# Orion Sentinel DNS HA - Command Line Installer
# =============================================================================
# A comprehensive CLI installer for the HA DNS stack
#
# Features:
#   - Interactive and non-interactive modes
#   - Supports all deployment modes (single-pi-ha, two-pi-simple, two-pi-ha)
#   - Configuration validation and generation
#   - Dry-run capability
#   - Full automation support
#
# Usage:
#   ./cli-install.sh                          # Interactive mode
#   ./cli-install.sh --mode single-pi-ha      # Non-interactive with mode
#   ./cli-install.sh --help                   # Show help
#
# =============================================================================

set -u

# Version
VERSION="1.0.0"

# Script directory and repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default configuration
CONFIG_FILE="${REPO_ROOT}/.env"
CONFIG_EXAMPLE="${REPO_ROOT}/.env.example"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration defaults
DEFAULT_HOST_IP="192.168.8.250"
DEFAULT_PRIMARY_DNS_IP="192.168.8.251"
DEFAULT_SECONDARY_DNS_IP="192.168.8.252"
DEFAULT_UNBOUND_PRIMARY_IP="192.168.8.253"
DEFAULT_UNBOUND_SECONDARY_IP="192.168.8.254"
DEFAULT_VIP_ADDRESS="192.168.8.255"
DEFAULT_NETWORK_INTERFACE="eth0"
DEFAULT_SUBNET="192.168.8.0/24"
DEFAULT_GATEWAY="192.168.8.1"
DEFAULT_TZ="Europe/London"

# CLI options
DEPLOY_MODE=""
INTERACTIVE=true
DRY_RUN=false
SKIP_DOCKER=false
SKIP_VALIDATION=false
FORCE=false
VERBOSE=false
GENERATE_CONFIG=false
NODE_ROLE="MASTER"

# Configuration values (can be set via CLI)
HOST_IP=""
PRIMARY_DNS_IP=""
SECONDARY_DNS_IP=""
VIP_ADDRESS=""
NETWORK_INTERFACE=""
SUBNET=""
GATEWAY=""
TZ=""
PIHOLE_PASSWORD=""
GRAFANA_ADMIN_PASSWORD=""
VRRP_PASSWORD=""

# =============================================================================
# Utility Functions
# =============================================================================

log() { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err() { echo -e "${RED}[✗]${NC} $*" >&2; }
info() { echo -e "${BLUE}[i]${NC} $*"; }
debug() { [[ "$VERBOSE" == true ]] && echo -e "${CYAN}[DEBUG]${NC} $*"; }
section() { echo -e "\n${CYAN}${BOLD}═══ $* ═══${NC}\n"; }

# Show banner
show_banner() {
    echo -e "${CYAN}${BOLD}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║   ███████╗██████╗ ██╗ ██████╗ ███╗   ██╗                         ║
║   ██╔═══██╗██╔══██╗██║██╔═══██╗████╗  ██║                         ║
║   ██║   ██║██████╔╝██║██║   ██║██╔██╗ ██║                         ║
║   ██║   ██║██╔══██╗██║██║   ██║██║╚██╗██║                         ║
║   ╚██████╔╝██║  ██║██║╚██████╔╝██║ ╚████║                         ║
║    ╚═════╝ ╚═╝  ╚═╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝                         ║
║                                                                   ║
║   Sentinel HA DNS Stack - Command Line Installer                  ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "  Version: ${BOLD}${VERSION}${NC}"
    echo ""
}

# Show help
show_help() {
    cat << EOF
${BOLD}Orion Sentinel DNS HA - Command Line Installer${NC}

${BOLD}USAGE:${NC}
    $(basename "$0") [OPTIONS]

${BOLD}OPTIONS:${NC}
    ${BOLD}Deployment Mode:${NC}
    --mode <mode>           Set deployment mode:
                            - single-pi-ha: One Pi with 2 Pi-hole + 2 Unbound (default)
                            - two-pi-simple: Two Pis, active-passive, manual failover
                            - two-pi-ha: Two Pis with full HA and auto failover

    --node-role <role>      Set node role for two-pi modes:
                            - MASTER: Primary node (default)
                            - BACKUP: Secondary node

    ${BOLD}Configuration:${NC}
    --host-ip <ip>          Host IP address (default: $DEFAULT_HOST_IP)
    --vip <ip>              Virtual IP address for HA (default: $DEFAULT_VIP_ADDRESS)
    --interface <iface>     Network interface (default: $DEFAULT_NETWORK_INTERFACE)
    --subnet <cidr>         Network subnet (default: $DEFAULT_SUBNET)
    --gateway <ip>          Network gateway (default: $DEFAULT_GATEWAY)
    --timezone <tz>         Timezone (default: $DEFAULT_TZ)
    --pihole-password <pw>  Pi-hole admin password
    --grafana-password <pw> Grafana admin password
    --vrrp-password <pw>    VRRP/Keepalived password

    ${BOLD}Behavior:${NC}
    --non-interactive       Run in non-interactive mode (use defaults or CLI args)
    --generate-config       Generate .env file only, don't deploy
    --dry-run               Show what would be done without making changes
    --skip-docker           Skip Docker installation check
    --skip-validation       Skip prerequisite validation
    --force                 Force installation even if checks fail
    --verbose               Enable verbose output

    ${BOLD}General:${NC}
    --version               Show version
    --help                  Show this help message

${BOLD}EXAMPLES:${NC}
    # Interactive installation
    $(basename "$0")

    # Single-Pi HA mode with specific IPs
    $(basename "$0") --mode single-pi-ha --host-ip 192.168.1.100 --vip 192.168.1.200

    # Two-Pi HA mode for primary node
    $(basename "$0") --mode two-pi-ha --node-role MASTER --host-ip 192.168.1.10

    # Generate configuration only
    $(basename "$0") --generate-config --mode single-pi-ha

    # Non-interactive with passwords
    $(basename "$0") --non-interactive --mode single-pi-ha \\
        --pihole-password "SecurePass123" \\
        --grafana-password "GrafanaPass456"

    # Dry-run to see what would happen
    $(basename "$0") --dry-run --mode single-pi-ha

${BOLD}DEPLOYMENT MODES:${NC}
    ${BOLD}single-pi-ha:${NC}
        - 1 Raspberry Pi with 2 Pi-hole + 2 Unbound containers
        - Container-level redundancy
        - Best for: Home labs, testing, single Pi setups

    ${BOLD}two-pi-simple:${NC}
        - 2 Raspberry Pis, primary services only on Pi1
        - Manual failover required
        - Best for: Simple two-Pi setups

    ${BOLD}two-pi-ha:${NC}
        - 2 Raspberry Pis with full HA
        - Keepalived manages floating VIP with automatic failover
        - Best for: Production, high availability requirements

${BOLD}MORE INFORMATION:${NC}
    Documentation: docs/install-single-pi.md, docs/install-two-pi-ha.md
    Repository: https://github.com/yorgosroussakis/Orion-sentinel-ha-dns

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --mode)
                DEPLOY_MODE="$2"
                shift 2
                ;;
            --node-role)
                NODE_ROLE="$(echo "$2" | tr '[:lower:]' '[:upper:]')"
                shift 2
                ;;
            --host-ip)
                HOST_IP="$2"
                shift 2
                ;;
            --vip)
                VIP_ADDRESS="$2"
                shift 2
                ;;
            --interface)
                NETWORK_INTERFACE="$2"
                shift 2
                ;;
            --subnet)
                SUBNET="$2"
                shift 2
                ;;
            --gateway)
                GATEWAY="$2"
                shift 2
                ;;
            --timezone)
                TZ="$2"
                shift 2
                ;;
            --pihole-password)
                PIHOLE_PASSWORD="$2"
                shift 2
                ;;
            --grafana-password)
                GRAFANA_ADMIN_PASSWORD="$2"
                shift 2
                ;;
            --vrrp-password)
                VRRP_PASSWORD="$2"
                shift 2
                ;;
            --non-interactive)
                INTERACTIVE=false
                shift
                ;;
            --generate-config)
                GENERATE_CONFIG=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --skip-docker)
                SKIP_DOCKER=true
                shift
                ;;
            --skip-validation)
                SKIP_VALIDATION=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --version)
                echo "Orion Sentinel DNS HA CLI Installer v${VERSION}"
                exit 0
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                err "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

# =============================================================================
# Validation Functions
# =============================================================================

validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        local IFS='.'
        local -a octets
        read -ra octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if ((octet > 255)); then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

validate_cidr() {
    local cidr=$1
    if [[ $cidr =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        local ip=${cidr%/*}
        local prefix=${cidr#*/}
        if validate_ip "$ip" && ((prefix >= 0 && prefix <= 32)); then
            return 0
        fi
    fi
    return 1
}

validate_mode() {
    local mode=$1
    case "$mode" in
        single-pi-ha|two-pi-simple|two-pi-ha)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

validate_role() {
    local role=$1
    case "$role" in
        MASTER|BACKUP)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Check system prerequisites
check_prerequisites() {
    section "Checking System Prerequisites"
    
    local all_checks_passed=true
    
    # Check OS
    if [[ "$(uname -s)" != "Linux" ]]; then
        err "This installer requires Linux"
        all_checks_passed=false
    else
        log "Running on Linux"
    fi
    
    # Check architecture
    local arch
    arch=$(uname -m)
    case "$arch" in
        aarch64|armv7l|x86_64)
            log "Architecture: $arch (supported)"
            ;;
        *)
            err "Unsupported architecture: $arch"
            all_checks_passed=false
            ;;
    esac
    
    # Check if Raspberry Pi (informational only)
    if [[ -f /proc/device-tree/model ]]; then
        local model
        model=$(tr -d '\0' < /proc/device-tree/model)
        log "Hardware: $model"
    else
        info "Not running on Raspberry Pi hardware (this is okay)"
    fi
    
    # Check disk space (minimum 5GB)
    local available_gb
    available_gb=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ "$available_gb" -lt 5 ]]; then
        err "Insufficient disk space: ${available_gb}GB available (minimum 5GB required)"
        all_checks_passed=false
    else
        log "Available disk space: ${available_gb}GB"
    fi
    
    # Check memory (minimum 2GB recommended)
    local total_mem_kb
    total_mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_mem_gb=$((total_mem_kb / 1024 / 1024))
    if [[ "$total_mem_gb" -lt 2 ]]; then
        warn "Low memory: ${total_mem_gb}GB detected (2GB+ recommended)"
    else
        log "Total memory: ${total_mem_gb}GB"
    fi
    
    # Check network connectivity
    if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        log "Network connectivity verified"
    else
        warn "Network connectivity check failed (may be fine behind firewall)"
    fi
    
    # Check required commands
    local required_cmds=("git" "curl")
    for cmd in "${required_cmds[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            log "$cmd is installed"
        else
            err "$cmd is not installed"
            info "Install with: sudo apt-get install -y $cmd"
            all_checks_passed=false
        fi
    done
    
    if [[ "$all_checks_passed" == false ]]; then
        if [[ "$FORCE" == false ]]; then
            err "Some prerequisite checks failed"
            info "Use --force to continue anyway"
            exit 1
        else
            warn "Continuing despite failed checks (--force)"
        fi
    fi
    
    log "All prerequisite checks passed"
}

# Check Docker installation
check_docker() {
    if [[ "$SKIP_DOCKER" == true ]]; then
        info "Skipping Docker check (--skip-docker)"
        return 0
    fi
    
    section "Checking Docker Installation"
    
    # Check if Docker is installed
    if command -v docker >/dev/null 2>&1; then
        log "Docker is installed"
        local docker_version
        docker_version=$(docker --version 2>/dev/null || echo "unknown")
        info "Version: $docker_version"
    else
        warn "Docker is not installed"
        
        if [[ "$DRY_RUN" == true ]]; then
            info "[DRY-RUN] Would install Docker"
            return 0
        fi
        
        if [[ "$INTERACTIVE" == true ]]; then
            echo ""
            read -r -p "Would you like to install Docker? (Y/n): " response
            if [[ "$response" =~ ^[Nn]$ ]]; then
                err "Docker is required to run this stack"
                exit 1
            fi
        fi
        
        info "Installing Docker..."
        if curl -fsSL https://get.docker.com | sh; then
            log "Docker installed successfully"
        else
            err "Failed to install Docker"
            exit 1
        fi
    fi
    
    # Check if Docker daemon is running
    if docker info >/dev/null 2>&1; then
        log "Docker daemon is running"
    else
        warn "Docker is installed but not running"
        info "Attempting to start Docker service..."
        
        if [[ "$DRY_RUN" == true ]]; then
            info "[DRY-RUN] Would start Docker service"
            return 0
        fi
        
        if command -v systemctl >/dev/null 2>&1; then
            sudo systemctl start docker 2>/dev/null || true
            sleep 3
        fi
        
        if docker info >/dev/null 2>&1; then
            log "Docker daemon started successfully"
        else
            err "Failed to start Docker daemon"
            exit 1
        fi
    fi
    
    # Check Docker permissions
    if docker ps >/dev/null 2>&1; then
        log "Docker permissions verified"
    else
        warn "Current user lacks Docker permissions"
        if [[ "$DRY_RUN" == true ]]; then
            info "[DRY-RUN] Would add user to docker group"
            return 0
        fi
        
        if getent group docker >/dev/null 2>&1; then
            sudo usermod -aG docker "$USER" || true
            log "User added to docker group"
            warn "You need to log out and back in for group changes to take effect"
            warn "Or run: newgrp docker"
        fi
    fi
    
    # Check Docker Compose
    if docker compose version >/dev/null 2>&1; then
        log "Docker Compose plugin is available"
        local compose_version
        compose_version=$(docker compose version 2>/dev/null || echo "unknown")
        info "Version: $compose_version"
    else
        warn "Docker Compose plugin not found"
        
        if [[ "$DRY_RUN" == true ]]; then
            info "[DRY-RUN] Would install Docker Compose plugin"
            return 0
        fi
        
        info "Installing Docker Compose plugin..."
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update -qq
            if sudo apt-get install -y docker-compose-plugin; then
                log "Docker Compose plugin installed"
            else
                err "Failed to install Docker Compose plugin"
                exit 1
            fi
        else
            err "Cannot install Docker Compose (apt-get not available)"
            exit 1
        fi
    fi
}

# =============================================================================
# Interactive Configuration
# =============================================================================

prompt() {
    local prompt_text=$1
    local default_value=$2
    local result
    
    read -r -p "$prompt_text [$default_value]: " result
    echo "${result:-$default_value}"
}

prompt_password() {
    local prompt_text=$1
    local password=""
    
    while true; do
        read -r -s -p "$prompt_text: " password
        echo >&2
        if [[ -n "$password" && ${#password} -ge 8 ]]; then
            read -r -s -p "Confirm password: " password_confirm
            echo >&2
            if [[ "$password" == "$password_confirm" ]]; then
                echo "$password"
                return 0
            else
                err "Passwords do not match. Please try again." >&2
            fi
        else
            err "Password must be at least 8 characters. Please try again." >&2
        fi
    done
}

interactive_mode_selection() {
    section "Deployment Mode Selection"
    
    echo "Choose your deployment mode:"
    echo ""
    echo "  [1] ${BOLD}single-pi-ha${NC} (Default)"
    echo "      One Raspberry Pi with 2 Pi-hole + 2 Unbound containers"
    echo "      Container-level redundancy, simpler setup"
    echo ""
    echo "  [2] ${BOLD}two-pi-simple${NC}"
    echo "      Two Raspberry Pis, primary services on Pi1 only"
    echo "      Manual failover, Pi2 is standby"
    echo ""
    echo "  [3] ${BOLD}two-pi-ha${NC}"
    echo "      Two Raspberry Pis with full high availability"
    echo "      Automatic failover with Keepalived VIP"
    echo ""
    
    local choice
    read -r -p "Enter choice (1-3) [1]: " choice
    choice=${choice:-1}
    
    case "$choice" in
        1) DEPLOY_MODE="single-pi-ha" ;;
        2) DEPLOY_MODE="two-pi-simple" ;;
        3) DEPLOY_MODE="two-pi-ha" ;;
        *) 
            warn "Invalid choice, using single-pi-ha"
            DEPLOY_MODE="single-pi-ha"
            ;;
    esac
    
    log "Selected deployment mode: $DEPLOY_MODE"
    
    # For two-pi modes, ask for node role
    if [[ "$DEPLOY_MODE" == "two-pi-ha" ]]; then
        echo ""
        echo "Select node role:"
        echo "  [1] ${BOLD}MASTER${NC} (Primary node, higher priority)"
        echo "  [2] ${BOLD}BACKUP${NC} (Secondary node, takes over if primary fails)"
        echo ""
        read -r -p "Enter choice (1-2) [1]: " role_choice
        role_choice=${role_choice:-1}
        
        case "$role_choice" in
            1) NODE_ROLE="MASTER" ;;
            2) NODE_ROLE="BACKUP" ;;
            *) NODE_ROLE="MASTER" ;;
        esac
        log "Selected node role: $NODE_ROLE"
    fi
}

interactive_network_config() {
    section "Network Configuration"
    
    # Detect current values
    local detected_ip
    detected_ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "$DEFAULT_HOST_IP")
    local detected_interface
    detected_interface=$(ip route show default 2>/dev/null | grep -oP 'dev \K\S+' | head -1 || echo "$DEFAULT_NETWORK_INTERFACE")
    
    info "Detected IP: $detected_ip"
    info "Detected Interface: $detected_interface"
    echo ""
    
    HOST_IP=$(prompt "Host IP address" "${HOST_IP:-$detected_ip}")
    NETWORK_INTERFACE=$(prompt "Network interface" "${NETWORK_INTERFACE:-$detected_interface}")
    
    # Calculate defaults based on host IP
    local default_subnet
    default_subnet=$(echo "$HOST_IP" | awk -F. '{print $1"."$2"."$3".0/24"}')
    local default_gateway
    default_gateway=$(echo "$HOST_IP" | awk -F. '{print $1"."$2"."$3".1"}')
    local default_vip
    default_vip=$(echo "$HOST_IP" | awk -F. '{print $1"."$2"."$3".249"}')
    
    SUBNET=$(prompt "Network subnet (CIDR)" "${SUBNET:-$default_subnet}")
    GATEWAY=$(prompt "Network gateway" "${GATEWAY:-$default_gateway}")
    
    if [[ "$DEPLOY_MODE" == "single-pi-ha" ]]; then
        VIP_ADDRESS=$(prompt "Virtual IP (VIP) for DNS" "${VIP_ADDRESS:-$default_vip}")
    elif [[ "$DEPLOY_MODE" == "two-pi-ha" ]]; then
        VIP_ADDRESS=$(prompt "Virtual IP (VIP) for HA failover" "${VIP_ADDRESS:-$default_vip}")
    else
        VIP_ADDRESS="$HOST_IP"
    fi
    
    TZ=$(prompt "Timezone" "${TZ:-$DEFAULT_TZ}")
}

interactive_password_config() {
    section "Security Configuration"
    
    info "Set passwords for your services (minimum 8 characters)"
    echo ""
    
    if [[ -z "$PIHOLE_PASSWORD" ]]; then
        PIHOLE_PASSWORD=$(prompt_password "Pi-hole admin password")
    fi
    
    if [[ -z "$GRAFANA_ADMIN_PASSWORD" ]]; then
        # Generate a random password for Grafana if not provided
        echo ""
        info "Generating random password for Grafana..."
        GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 24)
        log "Grafana password generated (will be shown in summary)"
    fi
    
    if [[ "$DEPLOY_MODE" == "two-pi-ha" && -z "$VRRP_PASSWORD" ]]; then
        echo ""
        info "VRRP password is needed for Keepalived HA communication"
        VRRP_PASSWORD=$(prompt_password "VRRP/Keepalived password")
    elif [[ -z "$VRRP_PASSWORD" ]]; then
        VRRP_PASSWORD=$(openssl rand -base64 16)
    fi
    
    log "Passwords configured"
}

# =============================================================================
# Configuration Generation
# =============================================================================

generate_env_file() {
    section "Generating Configuration"
    
    local env_file="${CONFIG_FILE}"
    
    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] Would generate .env file:"
        env_file="/dev/stdout"
    fi
    
    # Set derived values
    PRIMARY_DNS_IP="${PRIMARY_DNS_IP:-$(echo "$HOST_IP" | awk -F. '{print $1"."$2"."$3".251"}')}"
    SECONDARY_DNS_IP="${SECONDARY_DNS_IP:-$(echo "$HOST_IP" | awk -F. '{print $1"."$2"."$3".252"}')}"
    local unbound_primary
    unbound_primary=$(echo "$HOST_IP" | awk -F. '{print $1"."$2"."$3".253"}')
    local unbound_secondary
    unbound_secondary=$(echo "$HOST_IP" | awk -F. '{print $1"."$2"."$3".254"}')
    
    # Generate the environment file
    {
        echo "# Orion Sentinel DNS HA - Configuration"
        echo "# Generated by CLI installer v${VERSION}"
        echo "# Mode: ${DEPLOY_MODE}"
        echo "# Generated: $(date)"
        echo ""
        echo "# Deployment Mode"
        echo "DEPLOY_MODE=${DEPLOY_MODE}"
        echo "NODE_ROLE=${NODE_ROLE}"
        echo ""
        echo "# Network Configuration"
        echo "HOST_IP=${HOST_IP}"
        echo "PRIMARY_DNS_IP=${PRIMARY_DNS_IP}"
        echo "SECONDARY_DNS_IP=${SECONDARY_DNS_IP}"
        echo "UNBOUND_PRIMARY_IP=${unbound_primary}"
        echo "UNBOUND_SECONDARY_IP=${unbound_secondary}"
        echo "VIP_ADDRESS=${VIP_ADDRESS}"
        echo "NETWORK_INTERFACE=${NETWORK_INTERFACE}"
        echo "SUBNET=${SUBNET}"
        echo "GATEWAY=${GATEWAY}"
        echo ""
        echo "# Timezone"
        echo "TZ=${TZ}"
        echo ""
        echo "# Pi-hole Configuration"
        echo "PIHOLE_PASSWORD=${PIHOLE_PASSWORD}"
        echo "PIHOLE_DNS1=127.0.0.1#5335"
        echo "PIHOLE_DNS2=127.0.0.1#5335"
        echo 'WEBPASSWORD=${PIHOLE_PASSWORD}'
        echo ""
        echo "# Grafana Configuration"
        echo "GRAFANA_ADMIN_USER=admin"
        echo "GRAFANA_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}"
        echo ""
        echo "# Keepalived Configuration"
        echo "VRRP_PASSWORD=${VRRP_PASSWORD}"
        if [[ "$NODE_ROLE" == "MASTER" ]]; then
            echo "VRRP_PRIORITY=100"
        else
            echo "VRRP_PRIORITY=90"
        fi
        echo ""
        echo "# AI-Watchdog Configuration"
        echo "WATCHDOG_CHECK_INTERVAL=30"
        echo "WATCHDOG_RESTART_THRESHOLD=3"
        echo "WATCHDOG_ALERT_COOLDOWN=300"
        echo ""
        echo "# Prometheus Configuration"
        echo "PROMETHEUS_RETENTION=30d"
        echo ""
        echo "# Docker Networks"
        echo "DNS_NETWORK=dns_net"
        echo "OBSERVABILITY_NETWORK=observability_net"
        echo ""
        echo "# Signal Notifications (optional - configure later)"
        echo "SIGNAL_NUMBER=+1234567890"
        echo "SIGNAL_RECIPIENTS=+1234567890"
    } > "$env_file"
    
    if [[ "$DRY_RUN" != true ]]; then
        log "Configuration saved to ${CONFIG_FILE}"
    fi
}

# =============================================================================
# Deployment Functions
# =============================================================================

create_docker_networks() {
    section "Creating Docker Networks"
    
    local dns_network="dns_net"
    local obs_network="observability_net"
    
    # Create macvlan network for DNS
    if docker network inspect "$dns_network" >/dev/null 2>&1; then
        log "DNS network '$dns_network' already exists"
    else
        if [[ "$DRY_RUN" == true ]]; then
            info "[DRY-RUN] Would create macvlan network: $dns_network"
        else
            info "Creating macvlan network '$dns_network'..."
            if ip link show "$NETWORK_INTERFACE" >/dev/null 2>&1; then
                if docker network create -d macvlan \
                    --subnet="$SUBNET" \
                    --gateway="$GATEWAY" \
                    -o parent="$NETWORK_INTERFACE" \
                    "$dns_network"; then
                    log "Created macvlan network: $dns_network"
                else
                    warn "Failed to create macvlan network, creating bridge network instead"
                    docker network create "$dns_network"
                    log "Created bridge network: $dns_network"
                fi
            else
                warn "Interface $NETWORK_INTERFACE not found, creating bridge network"
                docker network create "$dns_network"
                log "Created bridge network: $dns_network"
            fi
        fi
    fi
    
    # Create observability network
    if docker network inspect "$obs_network" >/dev/null 2>&1; then
        log "Observability network '$obs_network' already exists"
    else
        if [[ "$DRY_RUN" == true ]]; then
            info "[DRY-RUN] Would create bridge network: $obs_network"
        else
            docker network create "$obs_network"
            log "Created network: $obs_network"
        fi
    fi
}

create_directories() {
    section "Creating Volume Directories"
    
    local directories=(
        "stacks/dns/pihole1/etc-pihole"
        "stacks/dns/pihole1/etc-dnsmasq.d"
        "stacks/dns/pihole2/etc-pihole"
        "stacks/dns/pihole2/etc-dnsmasq.d"
        "stacks/dns/unbound"
        "stacks/dns/keepalived"
        "stacks/observability/prometheus"
        "stacks/observability/grafana"
        "stacks/observability/alertmanager"
        "stacks/ai-watchdog"
    )
    
    for dir in "${directories[@]}"; do
        if [[ "$DRY_RUN" == true ]]; then
            debug "[DRY-RUN] Would create: $REPO_ROOT/$dir"
        else
            mkdir -p "$REPO_ROOT/$dir"
        fi
    done
    
    log "Volume directories created"
}

create_env_symlinks() {
    section "Creating Environment Symlinks"
    
    local stack_dirs=(
        "stacks/dns"
        "stacks/observability"
        "stacks/ai-watchdog"
    )
    
    for stack_dir in "${stack_dirs[@]}"; do
        local full_path="$REPO_ROOT/$stack_dir"
        if [[ -d "$full_path" ]]; then
            if [[ "$DRY_RUN" == true ]]; then
                debug "[DRY-RUN] Would create symlink: $full_path/.env -> ../../.env"
            else
                if [[ ! -e "$full_path/.env" ]]; then
                    ln -sf "../../.env" "$full_path/.env"
                    log "Created symlink: $stack_dir/.env"
                else
                    debug "Symlink already exists: $stack_dir/.env"
                fi
            fi
        fi
    done
}

deploy_stacks() {
    section "Deploying Stacks"
    
    local profile=""
    case "$DEPLOY_MODE" in
        single-pi-ha)
            profile="single-pi-ha"
            ;;
        two-pi-simple)
            profile="two-pi-simple"
            ;;
        two-pi-ha)
            if [[ "$NODE_ROLE" == "MASTER" ]]; then
                profile="two-pi-ha-pi1"
            else
                profile="two-pi-ha-pi2"
            fi
            ;;
    esac
    
    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] Would deploy stacks with profile: $profile"
        info "[DRY-RUN] Command: docker compose -f stacks/dns/docker-compose.yml --profile $profile up -d"
        return 0
    fi
    
    cd "$REPO_ROOT" || exit 1
    
    # Deploy DNS stack
    info "Deploying DNS stack (profile: $profile)..."
    if docker compose -f stacks/dns/docker-compose.yml --profile "$profile" up -d; then
        log "DNS stack deployed"
    else
        err "Failed to deploy DNS stack"
        exit 1
    fi
    
    # Deploy observability stack
    info "Deploying observability stack..."
    if docker compose -f stacks/observability/docker-compose.yml up -d; then
        log "Observability stack deployed"
    else
        warn "Failed to deploy observability stack (non-critical)"
    fi
    
    # Deploy AI-watchdog stack
    info "Deploying AI-watchdog stack..."
    if docker compose -f stacks/ai-watchdog/docker-compose.yml up -d; then
        log "AI-watchdog stack deployed"
    else
        warn "Failed to deploy AI-watchdog stack (non-critical)"
    fi
}

# =============================================================================
# Summary and Completion
# =============================================================================

show_summary() {
    section "Configuration Summary"
    
    echo -e "${BOLD}Deployment Mode:${NC}     $DEPLOY_MODE"
    if [[ "$DEPLOY_MODE" == "two-pi-ha" ]]; then
        echo -e "${BOLD}Node Role:${NC}           $NODE_ROLE"
    fi
    echo ""
    echo -e "${BOLD}Network Configuration:${NC}"
    echo -e "  Host IP:           $HOST_IP"
    echo -e "  VIP Address:       $VIP_ADDRESS"
    echo -e "  Interface:         $NETWORK_INTERFACE"
    echo -e "  Subnet:            $SUBNET"
    echo -e "  Gateway:           $GATEWAY"
    echo ""
    echo -e "${BOLD}Service Credentials:${NC}"
    echo -e "  Pi-hole Password:  (configured)"
    echo -e "  Grafana Password:  ${GRAFANA_ADMIN_PASSWORD}"
    echo ""
    echo -e "${BOLD}Timezone:${NC}            $TZ"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo ""
        warn "This was a dry-run. No changes were made."
    fi
}

show_next_steps() {
    section "Installation Complete!"
    
    echo -e "${GREEN}${BOLD}✓ Orion Sentinel DNS HA has been installed!${NC}"
    echo ""
    echo -e "${BOLD}Access your services:${NC}"
    echo -e "  Pi-hole:       ${CYAN}http://${VIP_ADDRESS}/admin${NC}"
    echo -e "  Grafana:       ${CYAN}http://${HOST_IP}:3000${NC}"
    echo -e "  Prometheus:    ${CYAN}http://${HOST_IP}:9090${NC}"
    echo ""
    echo -e "${BOLD}DNS Configuration:${NC}"
    echo -e "  Point your router/devices to: ${CYAN}${VIP_ADDRESS}${NC}"
    echo ""
    
    if [[ "$DEPLOY_MODE" == "two-pi-ha" && "$NODE_ROLE" == "MASTER" ]]; then
        echo -e "${YELLOW}${BOLD}Important:${NC} For full HA, install on the second Pi with:"
        echo -e "  ${CYAN}./scripts/cli-install.sh --mode two-pi-ha --node-role BACKUP${NC}"
        echo ""
    fi
    
    echo -e "${BOLD}Useful commands:${NC}"
    echo -e "  Check status:    ${CYAN}docker ps${NC}"
    echo -e "  View logs:       ${CYAN}docker compose -f stacks/dns/docker-compose.yml logs -f${NC}"
    echo -e "  Health check:    ${CYAN}bash scripts/health-check.sh${NC}"
    echo ""
    echo -e "${BOLD}Documentation:${NC}"
    echo -e "  • ${CYAN}docs/install-single-pi.md${NC} - Single Pi setup guide"
    echo -e "  • ${CYAN}docs/install-two-pi-ha.md${NC} - Two Pi HA setup guide"
    echo -e "  • ${CYAN}TROUBLESHOOTING.md${NC} - Common issues and solutions"
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    parse_args "$@"
    
    show_banner
    
    # Validate mode if provided
    if [[ -n "$DEPLOY_MODE" ]] && ! validate_mode "$DEPLOY_MODE"; then
        err "Invalid deployment mode: $DEPLOY_MODE"
        info "Valid modes: single-pi-ha, two-pi-simple, two-pi-ha"
        exit 1
    fi
    
    # Validate node role if provided
    if ! validate_role "$NODE_ROLE"; then
        err "Invalid node role: $NODE_ROLE"
        info "Valid roles: MASTER, BACKUP"
        exit 1
    fi
    
    # Interactive mode selection if no mode specified
    if [[ -z "$DEPLOY_MODE" ]]; then
        if [[ "$INTERACTIVE" == true ]]; then
            interactive_mode_selection
        else
            DEPLOY_MODE="single-pi-ha"
            info "Using default mode: single-pi-ha"
        fi
    else
        log "Using deployment mode: $DEPLOY_MODE"
    fi
    
    # Run prerequisite checks
    if [[ "$SKIP_VALIDATION" != true ]]; then
        check_prerequisites
    fi
    
    # Check Docker
    check_docker
    
    # Interactive network configuration
    if [[ "$INTERACTIVE" == true ]]; then
        interactive_network_config
        interactive_password_config
    else
        # Use defaults for non-interactive mode
        HOST_IP="${HOST_IP:-$DEFAULT_HOST_IP}"
        VIP_ADDRESS="${VIP_ADDRESS:-$DEFAULT_VIP_ADDRESS}"
        NETWORK_INTERFACE="${NETWORK_INTERFACE:-$DEFAULT_NETWORK_INTERFACE}"
        SUBNET="${SUBNET:-$DEFAULT_SUBNET}"
        GATEWAY="${GATEWAY:-$DEFAULT_GATEWAY}"
        TZ="${TZ:-$DEFAULT_TZ}"
        
        # Check for required passwords in non-interactive mode
        if [[ -z "$PIHOLE_PASSWORD" ]]; then
            PIHOLE_PASSWORD=$(openssl rand -base64 24)
            warn "Generated random Pi-hole password"
        fi
        if [[ -z "$GRAFANA_ADMIN_PASSWORD" ]]; then
            GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 24)
        fi
        if [[ -z "$VRRP_PASSWORD" ]]; then
            VRRP_PASSWORD=$(openssl rand -base64 16)
        fi
    fi
    
    # Show summary
    show_summary
    
    # Confirm before proceeding
    if [[ "$INTERACTIVE" == true && "$DRY_RUN" != true ]]; then
        echo ""
        read -r -p "Proceed with installation? (Y/n): " confirm
        if [[ "$confirm" =~ ^[Nn]$ ]]; then
            info "Installation cancelled"
            exit 0
        fi
    fi
    
    # Generate configuration
    generate_env_file
    
    if [[ "$GENERATE_CONFIG" == true ]]; then
        log "Configuration generated. Run without --generate-config to deploy."
        exit 0
    fi
    
    # Deploy
    create_directories
    create_env_symlinks
    create_docker_networks
    deploy_stacks
    
    # Show completion message
    if [[ "$DRY_RUN" != true ]]; then
        show_next_steps
    fi
}

# Run main function
main "$@"
