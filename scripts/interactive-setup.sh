#!/usr/bin/env bash
# Interactive Deployment Selector and Setup Script
# Guides users through choosing the right HA DNS deployment option

set -euo pipefail
IFS=$'\n\t'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ASCII Art Banner
show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║    RPi High Availability DNS Stack - Setup Wizard            ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

log() { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err() { echo -e "${RED}[✗]${NC} $*" >&2; }
info() { echo -e "${BLUE}[i]${NC} $*"; }
section() { echo -e "\n${CYAN}${BOLD}$*${NC}\n"; }

# Wait for user to press Enter
press_enter() {
    echo ""
    read -p "Press Enter to continue..."
}

# Check prerequisites
check_prerequisites() {
    section "═══ Step 1: Checking Prerequisites ═══"
    
    local all_good=true
    
    # Check if running on Linux
    if [[ "$(uname -s)" != "Linux" ]]; then
        err "This script must run on Linux (Raspberry Pi OS)"
        all_good=false
    else
        log "Running on Linux"
    fi
    
    # Check if running as root or with sudo
    if [[ $EUID -eq 0 ]]; then
        warn "Running as root - this is okay but not required"
        SUDO=""
    else
        SUDO="sudo"
    fi
    
    # Check Docker
    if command -v docker &> /dev/null; then
        local docker_version=$(docker --version | grep -oP '\d+\.\d+\.\d+' | head -1)
        log "Docker installed: version $docker_version"
    else
        warn "Docker not found - installing now..."
        info "Installing Docker..."
        curl -fsSL https://get.docker.com | $SUDO sh
        $SUDO usermod -aG docker $USER || true
        log "Docker installed"
        warn "You may need to log out and back in for Docker permissions to take effect"
    fi
    
    # Check Docker Compose
    if docker compose version &> /dev/null; then
        local compose_version=$(docker compose version | grep -oP '\d+\.\d+\.\d+' | head -1)
        log "Docker Compose installed: version $compose_version"
    else
        warn "Docker Compose not found - installing now..."
        info "Installing Docker Compose plugin..."
        $SUDO apt-get update -qq
        $SUDO apt-get install -y docker-compose-plugin
        log "Docker Compose installed"
    fi
    
    # Check Git
    if command -v git &> /dev/null; then
        log "Git installed"
    else
        warn "Git not found - will need to be installed"
        info "Run: sudo apt install git"
        all_good=false
    fi
    
    # Check network tools
    if command -v ip &> /dev/null; then
        log "Network tools available"
    else
        warn "Network tools not found"
        all_good=false
    fi
    
    # Check disk space
    local available_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $available_space -gt 10 ]]; then
        log "Sufficient disk space: ${available_space}GB available"
    else
        warn "Low disk space: only ${available_space}GB available"
        warn "Recommended: at least 10GB free"
    fi
    
    # Check RAM
    local total_ram=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $total_ram -ge 4 ]]; then
        log "Sufficient RAM: ${total_ram}GB"
    else
        warn "Low RAM: ${total_ram}GB detected"
        warn "Recommended: at least 4GB RAM"
    fi
    
    echo ""
    if [[ "$all_good" == true ]]; then
        log "All prerequisites met!"
    else
        err "Some prerequisites are missing"
        echo ""
        read -p "Do you want to continue anyway? (y/N): " continue_anyway
        if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
            echo "Please install missing prerequisites and run this script again."
            exit 1
        fi
    fi
    
    press_enter
}

# Hardware survey
hardware_survey() {
    section "═══ Step 2: Hardware Survey ═══"
    
    echo "Let's understand your hardware setup:"
    echo ""
    
    # Count Raspberry Pis
    echo "How many Raspberry Pi devices do you have for this DNS setup?"
    echo "  1 - Single Raspberry Pi"
    echo "  2 - Two Raspberry Pis (for hardware redundancy)"
    echo ""
    read -p "Enter number (1 or 2): " PI_COUNT
    
    while [[ ! "$PI_COUNT" =~ ^[12]$ ]]; do
        warn "Please enter 1 or 2"
        read -p "Enter number (1 or 2): " PI_COUNT
    done
    
    # Check RAM if possible
    local ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    info "Detected RAM on this Pi: ${ram_gb}GB"
    
    if [[ $PI_COUNT -eq 2 ]]; then
        echo ""
        echo "Do both Raspberry Pis have the same amount of RAM?"
        read -p "(Y/n): " same_ram
        if [[ "$same_ram" =~ ^[Nn]$ ]]; then
            read -p "Enter RAM (GB) for second Pi: " ram_gb_2
        else
            ram_gb_2=$ram_gb
        fi
    fi
    
    press_enter
}

# Show deployment options
show_deployment_options() {
    section "═══ Step 3: Choose Deployment Option ═══"
    
    if [[ $PI_COUNT -eq 1 ]]; then
        info "You have 1 Raspberry Pi - showing single-Pi option:"
        echo ""
        echo "┌────────────────────────────────────────────────────────────┐"
        echo "│  Option: HighAvail_1Pi2P2U                                │"
        echo "│  ────────────────────────────────────────────────────────  │"
        echo "│  Architecture: 1 Pi with 2 Pi-hole + 2 Unbound           │"
        echo "│  Redundancy:   Container-level only                       │"
        echo "│  RAM Required: 4GB minimum                                │"
        echo "│  Best For:     Home labs, testing, learning               │"
        echo "│                                                            │"
        echo "│  ✅ Simple setup                                           │"
        echo "│  ✅ Low cost (1 device)                                    │"
        echo "│  ✅ Container failover                                     │"
        echo "│  ⚠️  Single point of failure (hardware)                   │"
        echo "└────────────────────────────────────────────────────────────┘"
        echo ""
        SELECTED_DEPLOYMENT="HighAvail_1Pi2P2U"
        log "Selected: $SELECTED_DEPLOYMENT"
        
    else
        echo "You have 2 Raspberry Pis - choose your redundancy level:"
        echo ""
        echo "┌────────────────────────────────────────────────────────────┐"
        echo "│  [1] HighAvail_2Pi1P1U (RECOMMENDED) ⭐                   │"
        echo "│  ────────────────────────────────────────────────────────  │"
        echo "│  Architecture: 2 Pis, 1 Pi-hole + 1 Unbound each         │"
        echo "│  Redundancy:   Hardware + Node-level                      │"
        echo "│  RAM Required: 4GB per Pi                                 │"
        echo "│  Best For:     Production, small offices                  │"
        echo "│                                                            │"
        echo "│  ✅ Hardware redundancy                                    │"
        echo "│  ✅ Automatic failover (5-10s)                             │"
        echo "│  ✅ Balanced complexity                                    │"
        echo "│  ✅ Efficient resources                                    │"
        echo "└────────────────────────────────────────────────────────────┘"
        echo ""
        echo "┌────────────────────────────────────────────────────────────┐"
        echo "│  [2] HighAvail_2Pi2P2U (Advanced)                         │"
        echo "│  ────────────────────────────────────────────────────────  │"
        echo "│  Architecture: 2 Pis, 2 Pi-hole + 2 Unbound each         │"
        echo "│  Redundancy:   Triple (Container + Hardware + Node)       │"
        echo "│  RAM Required: 8GB per Pi (recommended)                   │"
        echo "│  Best For:     Mission-critical environments              │"
        echo "│                                                            │"
        echo "│  ✅ Maximum redundancy                                     │"
        echo "│  ✅ Survives multiple failures                             │"
        echo "│  ⚠️  High complexity                                       │"
        echo "│  ⚠️  High resource usage                                   │"
        echo "└────────────────────────────────────────────────────────────┘"
        echo ""
        
        # Give recommendation based on RAM
        if [[ $ram_gb -ge 8 ]]; then
            info "Recommendation: Both options work with your RAM"
            info "Choose [1] for simplicity or [2] for maximum redundancy"
        else
            info "Recommendation: Choose [1] (HighAvail_2Pi1P1U)"
            warn "Option [2] needs 8GB RAM per Pi for best performance"
        fi
        
        echo ""
        read -p "Enter your choice (1 or 2): " deployment_choice
        
        while [[ ! "$deployment_choice" =~ ^[12]$ ]]; do
            warn "Please enter 1 or 2"
            read -p "Enter your choice (1 or 2): " deployment_choice
        done
        
        if [[ "$deployment_choice" == "1" ]]; then
            SELECTED_DEPLOYMENT="HighAvail_2Pi1P1U"
        else
            SELECTED_DEPLOYMENT="HighAvail_2Pi2P2U"
        fi
        
        log "Selected: $SELECTED_DEPLOYMENT"
    fi
    
    press_enter
}

# Show what will be deployed
show_deployment_summary() {
    section "═══ Step 4: Deployment Summary ═══"
    
    echo "You have chosen: ${BOLD}$SELECTED_DEPLOYMENT${NC}"
    echo ""
    
    case "$SELECTED_DEPLOYMENT" in
        "HighAvail_1Pi2P2U")
            echo "This will deploy on THIS Raspberry Pi:"
            echo "  • 2x Pi-hole containers"
            echo "  • 2x Unbound containers"
            echo "  • 1x Keepalived container (local VIP)"
            echo "  • 1x Pi-hole sync container"
            echo ""
            echo "Network IPs:"
            echo "  • Pi-hole Primary:   192.168.8.251"
            echo "  • Pi-hole Secondary: 192.168.8.252"
            echo "  • Unbound Primary:   192.168.8.253"
            echo "  • Unbound Secondary: 192.168.8.254"
            echo "  • VIP (clients use): 192.168.8.255"
            ;;
            
        "HighAvail_2Pi1P1U")
            echo "This will deploy across TWO Raspberry Pis:"
            echo ""
            echo "Pi #1 (Primary):"
            echo "  • 1x Pi-hole container"
            echo "  • 1x Unbound container"
            echo "  • 1x Keepalived container (MASTER)"
            echo ""
            echo "Pi #2 (Secondary):"
            echo "  • 1x Pi-hole container"
            echo "  • 1x Unbound container"
            echo "  • 1x Keepalived container (BACKUP)"
            echo ""
            echo "Network IPs:"
            echo "  • Pi #1 host:        192.168.8.11"
            echo "  • Pi #2 host:        192.168.8.12"
            echo "  • Pi-hole on Pi #1:  192.168.8.251"
            echo "  • Pi-hole on Pi #2:  192.168.8.252"
            echo "  • Unbound on Pi #1:  192.168.8.253"
            echo "  • Unbound on Pi #2:  192.168.8.254"
            echo "  • VIP (clients use): 192.168.8.255"
            ;;
            
        "HighAvail_2Pi2P2U")
            echo "This will deploy across TWO Raspberry Pis:"
            echo ""
            echo "Pi #1 (Primary):"
            echo "  • 2x Pi-hole containers"
            echo "  • 2x Unbound containers"
            echo "  • 1x Keepalived container (MASTER)"
            echo "  • 1x Pi-hole sync container"
            echo ""
            echo "Pi #2 (Secondary):"
            echo "  • 2x Pi-hole containers"
            echo "  • 2x Unbound containers"
            echo "  • 1x Keepalived container (BACKUP)"
            echo "  • 1x Pi-hole sync container"
            echo ""
            echo "Network IPs:"
            echo "  • Pi #1 host:         192.168.8.11"
            echo "  • Pi #2 host:         192.168.8.12"
            echo "  • Pi-holes on Pi #1:  192.168.8.251, .252"
            echo "  • Pi-holes on Pi #2:  192.168.8.255, .256"
            echo "  • Unbounds on Pi #1:  192.168.8.253, .254"
            echo "  • Unbounds on Pi #2:  192.168.8.257, .258"
            echo "  • VIP (clients use):  192.168.8.259"
            ;;
    esac
    
    echo ""
    warn "Make sure these IPs don't conflict with existing devices!"
    echo ""
    
    press_enter
}

# Configure network settings
configure_network() {
    section "═══ Step 5: Network Configuration ═══"
    
    # Detect current IP
    local current_ip=$(ip -4 addr show eth0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
    if [[ -z "$current_ip" ]]; then
        current_ip=$(ip -4 addr show wlan0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
    fi
    
    if [[ -n "$current_ip" ]]; then
        info "Current IP detected: $current_ip"
    fi
    
    # Detect interface
    if ip link show eth0 &>/dev/null; then
        NETWORK_INTERFACE="eth0"
        log "Using ethernet interface: eth0"
    elif ip link show wlan0 &>/dev/null; then
        NETWORK_INTERFACE="wlan0"
        warn "Using WiFi interface: wlan0"
        warn "Ethernet is strongly recommended for DNS servers!"
    else
        warn "Could not detect network interface"
        read -p "Enter network interface name (e.g., eth0): " NETWORK_INTERFACE
    fi
    
    # Get network details
    read -p "Enter your network subnet (e.g., 192.168.8.0/24) [$DEFAULT_SUBNET]: " SUBNET
    SUBNET=${SUBNET:-$DEFAULT_SUBNET}
    
    read -p "Enter your network gateway (e.g., 192.168.8.1) [$DEFAULT_GATEWAY]: " GATEWAY
    GATEWAY=${GATEWAY:-$DEFAULT_GATEWAY}
    
    # Get timezone
    local detected_tz=$(timedatectl show -p Timezone --value 2>/dev/null || echo "Europe/London")
    read -p "Enter your timezone [$detected_tz]: " TZ
    TZ=${TZ:-$detected_tz}
    
    log "Network configured"
    press_enter
}

# Configure passwords
configure_passwords() {
    section "═══ Step 6: Security Configuration ═══"
    
    echo "Set passwords for your services:"
    echo ""
    
    # Pi-hole password
    while true; do
        read -s -p "Pi-hole admin password: " PIHOLE_PASSWORD
        echo ""
        read -s -p "Confirm Pi-hole password: " PIHOLE_PASSWORD2
        echo ""
        if [[ "$PIHOLE_PASSWORD" == "$PIHOLE_PASSWORD2" ]]; then
            if [[ ${#PIHOLE_PASSWORD} -ge 8 ]]; then
                log "Pi-hole password set"
                break
            else
                warn "Password must be at least 8 characters"
            fi
        else
            warn "Passwords don't match, try again"
        fi
    done
    
    # Grafana password
    while true; do
        read -s -p "Grafana admin password: " GRAFANA_PASSWORD
        echo ""
        read -s -p "Confirm Grafana password: " GRAFANA_PASSWORD2
        echo ""
        if [[ "$GRAFANA_PASSWORD" == "$GRAFANA_PASSWORD2" ]]; then
            if [[ ${#GRAFANA_PASSWORD} -ge 8 ]]; then
                log "Grafana password set"
                break
            else
                warn "Password must be at least 8 characters"
            fi
        else
            warn "Passwords don't match, try again"
        fi
    done
    
    # VRRP password (for multi-node setups)
    if [[ "$PI_COUNT" -eq 2 ]]; then
        while true; do
            read -s -p "VRRP/Keepalived password: " VRRP_PASSWORD
            echo ""
            read -s -p "Confirm VRRP password: " VRRP_PASSWORD2
            echo ""
            if [[ "$VRRP_PASSWORD" == "$VRRP_PASSWORD2" ]]; then
                if [[ ${#VRRP_PASSWORD} -ge 8 ]]; then
                    log "VRRP password set"
                    break
                else
                    warn "Password must be at least 8 characters"
                fi
            else
                warn "Passwords don't match, try again"
            fi
        done
    fi
    
    log "All passwords configured"
    press_enter
}

# Show next steps
show_next_steps() {
    section "═══ Configuration Complete! ═══"
    
    local deployment_path="$REPO_ROOT/deployments/$SELECTED_DEPLOYMENT"
    
    log "Configuration has been saved"
    echo ""
    echo "Next steps:"
    echo ""
    
    case "$SELECTED_DEPLOYMENT" in
        "HighAvail_1Pi2P2U")
            echo "1. Review the configuration:"
            echo "   ${CYAN}cd $deployment_path${NC}"
            echo "   ${CYAN}cat .env${NC}"
            echo ""
            echo "2. Create the Docker network:"
            echo "   ${CYAN}sudo docker network create -d macvlan \\${NC}"
            echo "   ${CYAN}  --subnet=$SUBNET --gateway=$GATEWAY \\${NC}"
            echo "   ${CYAN}  -o parent=$NETWORK_INTERFACE dns_net${NC}"
            echo ""
            echo "3. Deploy the stack:"
            echo "   ${CYAN}cd $deployment_path${NC}"
            echo "   ${CYAN}docker compose up -d${NC}"
            echo ""
            echo "4. Access Pi-hole admin:"
            echo "   ${CYAN}http://192.168.8.251/admin${NC}"
            ;;
            
        "HighAvail_2Pi1P1U")
            echo "1. On THIS Pi (Primary), create the Docker network:"
            echo "   ${CYAN}sudo docker network create -d macvlan \\${NC}"
            echo "   ${CYAN}  --subnet=$SUBNET --gateway=$GATEWAY \\${NC}"
            echo "   ${CYAN}  -o parent=$NETWORK_INTERFACE dns_net${NC}"
            echo ""
            echo "2. Deploy on THIS Pi:"
            echo "   ${CYAN}cd $deployment_path/node1${NC}"
            echo "   ${CYAN}docker compose up -d${NC}"
            echo ""
            echo "3. On SECOND Pi, repeat network creation and deploy:"
            echo "   ${CYAN}cd $deployment_path/node2${NC}"
            echo "   ${CYAN}docker compose up -d${NC}"
            echo ""
            echo "4. Configuration sync is handled automatically via built-in sync containers"
            echo ""
            echo "5. Access Pi-hole admin on Primary:"
            echo "   ${CYAN}http://192.168.8.251/admin${NC}"
            ;;
            
        "HighAvail_2Pi2P2U")
            echo "1. On THIS Pi (Primary), create the Docker network:"
            echo "   ${CYAN}sudo docker network create -d macvlan \\${NC}"
            echo "   ${CYAN}  --subnet=$SUBNET --gateway=$GATEWAY \\${NC}"
            echo "   ${CYAN}  -o parent=$NETWORK_INTERFACE dns_net${NC}"
            echo ""
            echo "2. Deploy on THIS Pi:"
            echo "   ${CYAN}cd $deployment_path/node1${NC}"
            echo "   ${CYAN}docker compose up -d${NC}"
            echo ""
            echo "3. On SECOND Pi, repeat network creation and deploy:"
            echo "   ${CYAN}cd $deployment_path/node2${NC}"
            echo "   ${CYAN}docker compose up -d${NC}"
            echo ""
            echo "4. Configuration sync is handled automatically via built-in sync containers"
            echo ""
            echo "5. Access Pi-hole admin:"
            echo "   ${CYAN}http://192.168.8.251/admin${NC} (Pi #1, Instance 1)"
            echo "   ${CYAN}http://192.168.8.252/admin${NC} (Pi #1, Instance 2)"
            ;;
    esac
    
    echo ""
    info "For detailed instructions, see:"
    echo "   ${CYAN}$deployment_path/README.md${NC}"
    echo ""
    log "Setup wizard complete!"
}

# Create environment files
create_env_files() {
    local deployment_path="$REPO_ROOT/deployments/$SELECTED_DEPLOYMENT"
    
    case "$SELECTED_DEPLOYMENT" in
        "HighAvail_1Pi2P2U")
            cat > "$deployment_path/.env" << EOF
# Network Configuration
NETWORK_INTERFACE=$NETWORK_INTERFACE
SUBNET=$SUBNET
GATEWAY=$GATEWAY
VIP_ADDRESS=192.168.8.255

# Timezone
TZ=$TZ

# Pi-hole Configuration
PIHOLE_PASSWORD=$PIHOLE_PASSWORD

# Grafana Configuration
GRAFANA_ADMIN_PASSWORD=$GRAFANA_PASSWORD

# Sync Configuration
SYNC_INTERVAL=300
EOF
            log "Created: $deployment_path/.env"
            ;;
            
        "HighAvail_2Pi1P1U"|"HighAvail_2Pi2P2U")
            # Node 1 (Primary)
            local vip="192.168.8.255"
            if [[ "$SELECTED_DEPLOYMENT" == "HighAvail_2Pi2P2U" ]]; then
                vip="192.168.8.259"
            fi
            
            cat > "$deployment_path/node1/.env" << EOF
# Node Configuration
NODE_ROLE=primary
NODE_IP=192.168.8.11
PEER_IP=192.168.8.12

# Network Configuration
NETWORK_INTERFACE=$NETWORK_INTERFACE
SUBNET=$SUBNET
GATEWAY=$GATEWAY
VIP_ADDRESS=$vip

# Timezone
TZ=$TZ

# Pi-hole Configuration
PIHOLE_PASSWORD=$PIHOLE_PASSWORD

# Keepalived Configuration
KEEPALIVED_PRIORITY=100
VIRTUAL_ROUTER_ID=51
VRRP_PASSWORD=$VRRP_PASSWORD

# Sync Configuration
SYNC_INTERVAL=300
EOF
            log "Created: $deployment_path/node1/.env"
            
            # Node 2 (Secondary)
            cat > "$deployment_path/node2/.env" << EOF
# Node Configuration
NODE_ROLE=secondary
NODE_IP=192.168.8.12
PEER_IP=192.168.8.11

# Network Configuration
NETWORK_INTERFACE=$NETWORK_INTERFACE
SUBNET=$SUBNET
GATEWAY=$GATEWAY
VIP_ADDRESS=$vip

# Timezone
TZ=$TZ

# Pi-hole Configuration
PIHOLE_PASSWORD=$PIHOLE_PASSWORD

# Keepalived Configuration
KEEPALIVED_PRIORITY=90
VIRTUAL_ROUTER_ID=51
VRRP_PASSWORD=$VRRP_PASSWORD

# Sync Configuration
SYNC_INTERVAL=300
EOF
            log "Created: $deployment_path/node2/.env"
            ;;
    esac
}

# Main execution
main() {
    # Default values
    DEFAULT_SUBNET="192.168.8.0/24"
    DEFAULT_GATEWAY="192.168.8.1"
    
    show_banner
    
    echo "Welcome to the RPi HA DNS Stack Setup Wizard!"
    echo ""
    echo "This wizard will guide you through:"
    echo "  • Checking prerequisites"
    echo "  • Surveying your hardware"
    echo "  • Choosing the right deployment option"
    echo "  • Configuring network and security settings"
    echo ""
    press_enter
    
    check_prerequisites
    hardware_survey
    show_deployment_options
    show_deployment_summary
    configure_network
    configure_passwords
    create_env_files
    show_next_steps
}

# Run main function
main "$@"
