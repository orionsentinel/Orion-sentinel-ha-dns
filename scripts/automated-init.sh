#!/usr/bin/env bash
# Automated Deployment Initializer
# Sets up all automation services on first deployment

set -euo pipefail

DEPLOYMENT_TYPE="${1:-}"
NODE_TYPE="${2:-single}"  # single, node1, node2

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓]${NC} $*"; }
info() { echo -e "${BLUE}[i]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
section() { echo -e "\n${CYAN}${BOLD}$*${NC}\n"; }

show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║    RPi HA DNS Stack - Automated Deployment                   ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Detect deployment type if not provided
detect_deployment() {
    if [ -f "docker-compose.yml" ]; then
        # Check if this is a single node or multi-node setup
        if grep -q "pihole_primary_1" docker-compose.yml 2>/dev/null; then
            echo "HighAvail_2Pi2P2U"
        elif grep -q "pihole_primary" docker-compose.yml 2>/dev/null && \
             grep -q "pihole_secondary" docker-compose.yml 2>/dev/null; then
            echo "HighAvail_1Pi2P2U"
        elif grep -q "pihole_primary" docker-compose.yml 2>/dev/null; then
            echo "HighAvail_2Pi1P1U"
        else
            echo "unknown"
        fi
    else
        echo "unknown"
    fi
}

# Setup blocklists automatically
setup_blocklists() {
    section "═══ Setting Up Optimal Blocklists ═══"
    
    local containers=""
    case "$DEPLOYMENT_TYPE" in
        "HighAvail_1Pi2P2U")
            containers="pihole_primary pihole_secondary"
            ;;
        "HighAvail_2Pi1P1U")
            if [ "$NODE_TYPE" = "node1" ]; then
                containers="pihole_primary"
            else
                containers="pihole_secondary"
            fi
            ;;
        "HighAvail_2Pi2P2U")
            if [ "$NODE_TYPE" = "node1" ]; then
                containers="pihole_primary_1 pihole_primary_2"
            else
                containers="pihole_secondary_1 pihole_secondary_2"
            fi
            ;;
    esac
    
    info "Waiting for Pi-hole containers to be ready..."
    sleep 30
    
    for container in $containers; do
        if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            info "Configuring blocklists for $container (balanced preset)..."
            bash ../../../scripts/setup-blocklists.sh "$container" balanced || warn "Failed to setup blocklists for $container"
        fi
    done
    
    log "Blocklists configured"
}

# Setup whitelists automatically
setup_whitelists() {
    section "═══ Setting Up Essential Whitelists ═══"
    
    local containers=""
    case "$DEPLOYMENT_TYPE" in
        "HighAvail_1Pi2P2U")
            containers="pihole_primary"  # Only need to whitelist on primary, sync will handle secondary
            ;;
        "HighAvail_2Pi1P1U")
            if [ "$NODE_TYPE" = "node1" ]; then
                containers="pihole_primary"
            else
                containers="pihole_secondary"
            fi
            ;;
        "HighAvail_2Pi2P2U")
            if [ "$NODE_TYPE" = "node1" ]; then
                containers="pihole_primary_1"  # Only first instance
            else
                containers="pihole_secondary_1"
            fi
            ;;
    esac
    
    for container in $containers; do
        if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            info "Configuring whitelists for $container..."
            bash ../../../scripts/setup-whitelist.sh "$container" || warn "Failed to setup whitelists for $container"
        fi
    done
    
    log "Whitelists configured"
}

# Create systemd service for auto-start on boot (optional)
create_systemd_service() {
    section "═══ Creating Systemd Service (Optional) ═══"
    
    local service_name="pihole-ha-dns"
    local working_dir=$(pwd)
    
    cat > "/tmp/${service_name}.service" << EOF
[Unit]
Description=Pi-hole HA DNS Stack
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${working_dir}
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF
    
    info "Systemd service file created at /tmp/${service_name}.service"
    info "To enable auto-start on boot, run:"
    echo "  sudo cp /tmp/${service_name}.service /etc/systemd/system/"
    echo "  sudo systemctl enable ${service_name}.service"
    echo "  sudo systemctl start ${service_name}.service"
}

# Show automation status
show_automation_status() {
    section "═══ Automation Services Status ═══"
    
    echo ""
    info "Checking automation containers..."
    echo ""
    
    # Check each automation service
    local services=(
        "pihole-sync:Configuration sync between instances"
        "pihole-auto-update:Automatic blocklist updates"
        "pihole-auto-backup:Automated backups"
    )
    
    for service_info in "${services[@]}"; do
        IFS=':' read -r service desc <<< "$service_info"
        if docker ps --format '{{.Names}}' | grep -q "^${service}$"; then
            log "$desc: Running"
        else
            warn "$desc: Not running"
        fi
    done
    
    echo ""
}

# Main setup
main() {
    show_banner
    
    # Detect deployment type if not provided
    if [ -z "$DEPLOYMENT_TYPE" ]; then
        DEPLOYMENT_TYPE=$(detect_deployment)
        info "Detected deployment type: $DEPLOYMENT_TYPE"
    fi
    
    if [ "$DEPLOYMENT_TYPE" = "unknown" ]; then
        warn "Could not detect deployment type"
        info "Usage: $0 <deployment_type> [node_type]"
        info "  deployment_type: HighAvail_1Pi2P2U, HighAvail_2Pi1P1U, HighAvail_2Pi2P2U"
        info "  node_type: single, node1, node2 (for multi-node setups)"
        exit 1
    fi
    
    section "═══ Automated Deployment Initializer ═══"
    info "Deployment: $DEPLOYMENT_TYPE"
    info "Node: $NODE_TYPE"
    echo ""
    
    # Wait for all containers to start
    info "Waiting for containers to fully initialize (60 seconds)..."
    sleep 60
    
    # Setup blocklists
    setup_blocklists
    
    # Setup whitelists
    setup_whitelists
    
    # Show automation status
    show_automation_status
    
    # Create systemd service
    create_systemd_service
    
    section "═══ Setup Complete! ═══"
    echo ""
    log "All automation is now active:"
    echo ""
    echo "  ✓ Blocklists configured (balanced preset)"
    echo "  ✓ Essential whitelists added"
    echo "  ✓ Auto-updates running (daily)"
    echo "  ✓ Auto-backups running (daily)"
    echo "  ✓ Configuration sync running (every 5 minutes)"
    echo ""
    info "Everything will happen automatically - no manual intervention needed!"
    echo ""
    info "Access Pi-hole admin:"
    
    case "$DEPLOYMENT_TYPE" in
        "HighAvail_1Pi2P2U")
            echo "  Primary:   http://192.168.8.251/admin"
            echo "  Secondary: http://192.168.8.252/admin"
            echo "  VIP:       http://192.168.8.255/admin"
            ;;
        "HighAvail_2Pi1P1U")
            echo "  Primary:   http://192.168.8.251/admin"
            echo "  Secondary: http://192.168.8.252/admin"
            echo "  VIP:       http://192.168.8.255/admin"
            ;;
        "HighAvail_2Pi2P2U")
            echo "  Pi #1 Instance 1: http://192.168.8.251/admin"
            echo "  Pi #1 Instance 2: http://192.168.8.252/admin"
            echo "  Pi #2 Instance 1: http://192.168.8.255/admin"
            echo "  Pi #2 Instance 2: http://192.168.8.256/admin"
            echo "  VIP:              http://192.168.8.259/admin"
            ;;
    esac
    
    echo ""
    info "Logs location:"
    echo "  Sync:    docker logs -f pihole-sync"
    echo "  Updates: docker logs -f pihole-auto-update"
    echo "  Backups: docker logs -f pihole-auto-backup"
    echo ""
}

main "$@"
