#!/usr/bin/env bash
# Interactive setup script for rpi-ha-dns-stack
# Guides users through configuration and deployment

set -euo pipefail
IFS=$'\n\t'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"
ENV_EXAMPLE="$REPO_ROOT/.env.example"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[setup]${NC} $*"; }
warn() { echo -e "${YELLOW}[setup][WARNING]${NC} $*"; }
err() { echo -e "${RED}[setup][ERROR]${NC} $*" >&2; }
info() { echo -e "${BLUE}[setup][INFO]${NC} $*"; }

prompt() {
    local var_name=$1
    local prompt_text=$2
    local default_value=$3
    local current_value=""
    
    if [[ -f "$ENV_FILE" ]]; then
        current_value=$(grep "^${var_name}=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2- || echo "")
    fi
    
    if [[ -n "$current_value" && "$current_value" != "$default_value" ]]; then
        default_value="$current_value"
    fi
    
    read -p "$prompt_text [$default_value]: " input
    echo "${input:-$default_value}"
}

prompt_password() {
    local var_name=$1
    local prompt_text=$2
    local password=""
    
    while true; do
        read -s -p "$prompt_text: " password
        echo
        if [[ -n "$password" ]]; then
            read -s -p "Confirm password: " password_confirm
            echo
            if [[ "$password" == "$password_confirm" ]]; then
                echo "$password"
                return
            else
                err "Passwords do not match. Please try again."
            fi
        else
            err "Password cannot be empty. Please try again."
        fi
    done
}

show_welcome() {
    clear
    cat << 'EOF'
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║   RPi HA DNS Stack - Interactive Setup                        ║
║                                                                ║
║   This script will guide you through configuring your         ║
║   high-availability DNS stack for Raspberry Pi 5              ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝

EOF
    read -p "Press ENTER to begin setup..."
}

configure_network() {
    log "Step 1: Network Configuration"
    echo
    info "Configure your network settings. The stack uses static IPs for DNS services."
    echo
    
    HOST_IP=$(prompt "HOST_IP" "Host (Raspberry Pi) IP address" "192.168.8.240")
    PRIMARY_DNS_IP=$(prompt "PRIMARY_DNS_IP" "Primary DNS IP address" "192.168.8.241")
    SECONDARY_DNS_IP=$(prompt "SECONDARY_DNS_IP" "Secondary DNS IP address" "192.168.8.242")
    VIP_ADDRESS=$(prompt "VIP_ADDRESS" "Keepalived VIP address" "192.168.8.245")
    NETWORK_INTERFACE=$(prompt "NETWORK_INTERFACE" "Network interface name" "eth0")
    SUBNET=$(prompt "SUBNET" "Network subnet (CIDR)" "192.168.8.0/24")
    GATEWAY=$(prompt "GATEWAY" "Network gateway" "192.168.8.1")
    
    echo
    info "Network configuration captured:"
    echo "  Host IP: $HOST_IP"
    echo "  Primary DNS: $PRIMARY_DNS_IP"
    echo "  Secondary DNS: $SECONDARY_DNS_IP"
    echo "  VIP: $VIP_ADDRESS"
    echo
}

configure_timezone() {
    log "Step 2: Timezone Configuration"
    echo
    TZ=$(prompt "TZ" "Timezone (e.g., America/New_York, Europe/London)" "America/New_York")
    echo
}

configure_passwords() {
    log "Step 3: Security Configuration"
    echo
    warn "You will be asked to set passwords for Pi-hole, Grafana, and Keepalived."
    warn "Make sure to use strong, unique passwords."
    echo
    
    PIHOLE_PASSWORD=$(prompt_password "PIHOLE_PASSWORD" "Set Pi-hole admin password")
    GRAFANA_ADMIN_USER=$(prompt "GRAFANA_ADMIN_USER" "Grafana admin username" "admin")
    GRAFANA_ADMIN_PASSWORD=$(prompt_password "GRAFANA_ADMIN_PASSWORD" "Set Grafana admin password")
    VRRP_PASSWORD=$(prompt_password "VRRP_PASSWORD" "Set Keepalived VRRP password")
    
    echo
    info "Passwords configured successfully"
    echo
}

configure_signal() {
    log "Step 4: Signal Notifications (Optional)"
    echo
    info "Configure Signal notifications for alerts via CallMeBot."
    info "To get your API key:"
    info "  1. Send 'I allow callmebot to send me messages' to +34 644 51 38 46 on Signal"
    info "  2. You will receive your API key in response"
    echo
    
    read -p "Do you want to configure Signal notifications now? (y/N): " configure_signal_choice
    
    if [[ "$configure_signal_choice" =~ ^[Yy]$ ]]; then
        SIGNAL_PHONE_NUMBER=$(prompt "SIGNAL_PHONE_NUMBER" "Your phone number (with country code, e.g., +1234567890)" "+1234567890")
        SIGNAL_API_KEY=$(prompt "SIGNAL_API_KEY" "CallMeBot API key" "your-api-key-here")
    else
        SIGNAL_PHONE_NUMBER="+1234567890"
        SIGNAL_API_KEY="your-api-key-here"
        warn "Skipping Signal configuration. You can set it up later by editing .env"
    fi
    echo
}

configure_prometheus() {
    log "Step 5: Monitoring Configuration"
    echo
    PROMETHEUS_RETENTION=$(prompt "PROMETHEUS_RETENTION" "Prometheus data retention period" "30d")
    WATCHDOG_CHECK_INTERVAL=$(prompt "WATCHDOG_CHECK_INTERVAL" "AI-Watchdog check interval (seconds)" "30")
    echo
}

create_env_file() {
    log "Creating .env file with your configuration..."
    
    cat > "$ENV_FILE" << EOF
# Network Configuration
HOST_IP=$HOST_IP
PRIMARY_DNS_IP=$PRIMARY_DNS_IP
SECONDARY_DNS_IP=$SECONDARY_DNS_IP
VIP_ADDRESS=$VIP_ADDRESS
NETWORK_INTERFACE=$NETWORK_INTERFACE
SUBNET=$SUBNET
GATEWAY=$GATEWAY

# Timezone
TZ=$TZ

# Pi-hole Configuration
PIHOLE_PASSWORD=$PIHOLE_PASSWORD
PIHOLE_DNS1=127.0.0.1#5335
PIHOLE_DNS2=127.0.0.1#5335
WEBPASSWORD=\${PIHOLE_PASSWORD}

# Grafana
GRAFANA_ADMIN_USER=$GRAFANA_ADMIN_USER
GRAFANA_ADMIN_PASSWORD=$GRAFANA_ADMIN_PASSWORD

# Signal Notifications
SIGNAL_WEBHOOK_URL=https://api.callmebot.com/signal/send.php
SIGNAL_PHONE_NUMBER=$SIGNAL_PHONE_NUMBER
SIGNAL_API_KEY=$SIGNAL_API_KEY

# Keepalived
VRRP_PASSWORD=$VRRP_PASSWORD

# AI-Watchdog
WATCHDOG_CHECK_INTERVAL=$WATCHDOG_CHECK_INTERVAL
WATCHDOG_RESTART_THRESHOLD=3
WATCHDOG_ALERT_COOLDOWN=300

# Prometheus
PROMETHEUS_RETENTION=$PROMETHEUS_RETENTION

# Docker Networks
OBSERVABILITY_NETWORK=observability_net
DNS_NETWORK=dns_net
EOF

    log "Configuration saved to $ENV_FILE"
    echo
}

show_summary() {
    log "Configuration Summary"
    echo
    cat << EOF
Network Settings:
  Host IP:         $HOST_IP
  Primary DNS:     $PRIMARY_DNS_IP
  Secondary DNS:   $SECONDARY_DNS_IP
  VIP:             $VIP_ADDRESS
  Interface:       $NETWORK_INTERFACE
  Subnet:          $SUBNET

Timezone:          $TZ

Service URLs (after deployment):
  Pi-hole:         http://$PRIMARY_DNS_IP/admin
  Grafana:         http://$HOST_IP:3000
  Prometheus:      http://$HOST_IP:9090
  Alertmanager:    http://$HOST_IP:9093

Signal Notifications:
  Phone:           $SIGNAL_PHONE_NUMBER
  Configured:      $([ "$SIGNAL_API_KEY" != "your-api-key-here" ] && echo "Yes" || echo "No")

Monitoring:
  Retention:       $PROMETHEUS_RETENTION
  Watchdog Check:  ${WATCHDOG_CHECK_INTERVAL}s

EOF
}

prompt_deployment() {
    echo
    log "Ready to deploy the stack!"
    echo
    read -p "Would you like to run the deployment now? (Y/n): " deploy_choice
    
    if [[ ! "$deploy_choice" =~ ^[Nn]$ ]]; then
        log "Starting deployment..."
        bash "$REPO_ROOT/scripts/install.sh"
    else
        info "Deployment skipped. To deploy later, run:"
        echo "  bash scripts/install.sh"
        echo
        info "Your configuration is saved in: $ENV_FILE"
    fi
}

backup_existing_env() {
    if [[ -f "$ENV_FILE" ]]; then
        backup_file="$ENV_FILE.backup.$(date +%Y%m%d_%H%M%S)"
        log "Backing up existing .env to: $backup_file"
        cp "$ENV_FILE" "$backup_file"
    fi
}

main() {
    if [[ $EUID -ne 0 ]] && ! groups | grep -q docker; then
        warn "This script may require sudo or docker group membership."
        warn "If you encounter permission errors, run with sudo or add your user to docker group."
        echo
    fi
    
    show_welcome
    
    # Backup existing .env if it exists
    backup_existing_env
    
    # Step-by-step configuration
    configure_network
    configure_timezone
    configure_passwords
    configure_signal
    configure_prometheus
    
    # Create the .env file
    create_env_file
    
    # Show summary
    show_summary
    
    # Ask if user wants to deploy now
    prompt_deployment
    
    echo
    log "Setup complete! 🎉"
    echo
    info "For manual deployment, run: bash scripts/install.sh"
    info "For testing notifications: curl -X POST http://$HOST_IP:8080/test -H 'Content-Type: application/json' -d '{\"message\":\"Test\"}'"
    echo
}

main "$@"
