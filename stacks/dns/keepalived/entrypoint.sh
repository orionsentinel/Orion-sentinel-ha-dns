#!/bin/bash
# Keepalived entrypoint script
# Generates keepalived.conf from environment variables and starts keepalived

set -e

# Required environment variables
: "${VIP_ADDRESS:?VIP_ADDRESS environment variable is required}"
: "${HOST_IP:?HOST_IP environment variable is required}"
: "${VRRP_PASSWORD:?VRRP_PASSWORD environment variable is required}"

# Optional environment variables with defaults
NETWORK_INTERFACE="${NETWORK_INTERFACE:-eth0}"
VIRTUAL_ROUTER_ID="${VIRTUAL_ROUTER_ID:-51}"
KEEPALIVED_PRIORITY="${KEEPALIVED_PRIORITY:-100}"
PI1_IP="${PI1_IP:-}"
PI2_IP="${PI2_IP:-}"
PI1_HOSTNAME="${PI1_HOSTNAME:-}"
PI2_HOSTNAME="${PI2_HOSTNAME:-}"
NODE_ROLE="${NODE_ROLE:-}"
SUBNET="${SUBNET:-}"

# Determine state (MASTER or BACKUP) based on priority
if [[ "$KEEPALIVED_PRIORITY" -ge 100 ]]; then
    STATE="MASTER"
else
    STATE="BACKUP"
fi

# Determine peer IP for unicast
PEER_IP=""
if [[ -n "$PI1_IP" ]] && [[ -n "$PI2_IP" ]]; then
    if [[ "$HOST_IP" == "$PI1_IP" ]]; then
        PEER_IP="$PI2_IP"
    elif [[ "$HOST_IP" == "$PI2_IP" ]]; then
        PEER_IP="$PI1_IP"
    fi
fi

# Extract CIDR prefix from VIP (default to /24)
VIP_CIDR="${VIP_ADDRESS}/24"
if [[ -n "$SUBNET" ]]; then
    # Extract prefix from SUBNET if available
    PREFIX="${SUBNET#*/}"
    if [[ "$PREFIX" =~ ^[0-9]+$ ]]; then
        VIP_CIDR="${VIP_ADDRESS}/${PREFIX}"
    fi
fi

# Generate router ID - prefer explicit values, fall back to IP-based detection
if [[ -n "${PI1_HOSTNAME:-}" ]] && [[ "$HOST_IP" == "$PI1_IP" ]]; then
    ROUTER_ID="${PI1_HOSTNAME}"
elif [[ -n "${PI2_HOSTNAME:-}" ]] && [[ "$HOST_IP" == "$PI2_IP" ]]; then
    ROUTER_ID="${PI2_HOSTNAME}"
elif [[ -n "${NODE_ROLE:-}" ]]; then
    ROUTER_ID="dns-${NODE_ROLE}"
elif [[ "$HOST_IP" == "$PI1_IP" ]]; then
    ROUTER_ID="pi1-dns"
elif [[ "$HOST_IP" == "$PI2_IP" ]]; then
    ROUTER_ID="pi2-dns"
else
    ROUTER_ID="dns-ha"
fi

echo "=========================================="
echo "Keepalived Configuration"
echo "=========================================="
echo "HOST_IP:             $HOST_IP"
echo "VIP_ADDRESS:         $VIP_CIDR"
echo "PEER_IP:             ${PEER_IP:-none (multicast mode)}"
echo "STATE:               $STATE"
echo "PRIORITY:            $KEEPALIVED_PRIORITY"
echo "INTERFACE:           $NETWORK_INTERFACE"
echo "VIRTUAL_ROUTER_ID:   $VIRTUAL_ROUTER_ID"
echo "ROUTER_ID:           $ROUTER_ID"
echo "=========================================="

# Generate keepalived.conf
CONFIG_FILE="/etc/keepalived/keepalived.conf"

cat > "$CONFIG_FILE" << EOF
# Keepalived Configuration
# Generated automatically from environment variables
# DO NOT EDIT - changes will be overwritten on container restart

global_defs {
    router_id ${ROUTER_ID}
    max_auto_priority 100
    enable_script_security
    script_user root
    
    # Send gratuitous ARP when becoming MASTER
    vrrp_garp_master_refresh 60
    vrrp_garp_master_repeat 3
    vrrp_garp_master_refresh_repeat 2
}

# Health check script to verify DNS is working
vrrp_script check_dns {
    script "/etc/keepalived/check_dns.sh"
    interval 5
    timeout 3
    weight -20
    fall 3
    rise 2
}

vrrp_instance VI_1 {
    state ${STATE}
    interface ${NETWORK_INTERFACE}
    virtual_router_id ${VIRTUAL_ROUTER_ID}
    priority ${KEEPALIVED_PRIORITY}
    advert_int 1
    
    authentication {
        auth_type PASS
        auth_pass ${VRRP_PASSWORD}
    }
EOF

# Add unicast configuration if we have peer info
if [[ -n "$PEER_IP" ]]; then
    cat >> "$CONFIG_FILE" << EOF
    
    # Unicast VRRP between two Pis
    unicast_src_ip ${HOST_IP}
    unicast_peer {
        ${PEER_IP}
    }
EOF
fi

# Add virtual IP and track script
cat >> "$CONFIG_FILE" << EOF
    
    virtual_ipaddress {
        ${VIP_CIDR} dev ${NETWORK_INTERFACE}
    }
    
    track_script {
        check_dns
    }
    
    # Notification scripts
    notify_master "/etc/keepalived/notify_master.sh"
    notify_backup "/etc/keepalived/notify_backup.sh"
    notify_fault  "/etc/keepalived/notify_fault.sh"
}
EOF

echo "Generated $CONFIG_FILE:"
echo "----------------------------------------"
cat "$CONFIG_FILE"
echo "----------------------------------------"

# Start keepalived
echo "Starting keepalived..."
exec keepalived --dont-fork --log-console --log-detail
