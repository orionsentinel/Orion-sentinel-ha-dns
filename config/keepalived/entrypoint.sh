#!/bin/bash
# =============================================================================
# Keepalived Container Entrypoint
# =============================================================================
# Processes the keepalived.conf template and substitutes environment variables
# =============================================================================

set -euo pipefail

# Configuration file paths
TEMPLATE_FILE="/etc/keepalived/keepalived.conf.tmpl"
CONFIG_FILE="/etc/keepalived/keepalived.conf"

# Check if template exists
if [[ ! -f "$TEMPLATE_FILE" ]]; then
    echo "ERROR: Template file $TEMPLATE_FILE not found"
    exit 1
fi

# Set defaults for optional variables
export NODE_NAME="${NODE_NAME:-orion-dns-$(hostname)}"
export NODE_ROLE="${NODE_ROLE:-MASTER}"
export KEEPALIVED_PRIORITY="${KEEPALIVED_PRIORITY:-200}"
export NETWORK_INTERFACE="${NETWORK_INTERFACE:-eth0}"
export VIRTUAL_ROUTER_ID="${VIRTUAL_ROUTER_ID:-51}"
export VIP_NETMASK="${VIP_NETMASK:-24}"
export USE_UNICAST_VRRP="${USE_UNICAST_VRRP:-false}"

# Required variables check
if [[ -z "${VIP_ADDRESS:-}" ]]; then
    echo "ERROR: VIP_ADDRESS environment variable is required"
    exit 1
fi

if [[ -z "${VRRP_PASSWORD:-}" ]]; then
    echo "ERROR: VRRP_PASSWORD environment variable is required"
    exit 1
fi

# Build unicast configuration if enabled
USE_UNICAST_VRRP_CONF=""
if [[ "${USE_UNICAST_VRRP}" == "true" ]]; then
    if [[ -n "${PEER_IP:-}" ]]; then
        USE_UNICAST_VRRP_CONF="unicast_peer {\n        ${PEER_IP}\n    }"
    else
        echo "WARNING: USE_UNICAST_VRRP is true but PEER_IP is not set. Using multicast."
    fi
fi

# Process template and substitute environment variables
echo "Generating keepalived configuration..."
echo "  Node Role: $NODE_ROLE"
echo "  Priority: $KEEPALIVED_PRIORITY"
echo "  VIP: $VIP_ADDRESS"
echo "  Interface: $NETWORK_INTERFACE"
echo "  Unicast Mode: $USE_UNICAST_VRRP"

# Use envsubst to replace environment variables
export USE_UNICAST_VRRP_CONF
envsubst < "$TEMPLATE_FILE" > "$CONFIG_FILE"

echo "Keepalived configuration generated successfully"

# Make notification scripts executable
chmod +x /etc/keepalived/*.sh 2>/dev/null || true

# Execute keepalived
exec "$@"
