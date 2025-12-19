#!/usr/bin/env bash
set -euo pipefail

KEEPALIVED_CONFIG_DIR="${KEEPALIVED_CONFIG_DIR:-/etc/keepalived}"
CONFIG_PATH="${KEEPALIVED_CONFIG_DIR}/keepalived.conf"

mkdir -p "${KEEPALIVED_CONFIG_DIR}"

# Always copy and fix script permissions on every container start
# This is required because /etc/keepalived is a bind mount from the repo
echo "=== Copying scripts and fixing permissions ==="
for script in check_dns.sh notify_master.sh notify_backup.sh notify_fault.sh; do
  cp "/usr/local/share/keepalived/${script}" "${KEEPALIVED_CONFIG_DIR}/${script}"
  chown root:root "${KEEPALIVED_CONFIG_DIR}/${script}"
  chmod 700 "${KEEPALIVED_CONFIG_DIR}/${script}"
  echo "  ✓ ${script}: copied and secured (root:root, 700)"
done

NODE_ROLE="${NODE_ROLE:-MASTER}"
KEEPALIVED_PRIORITY="${KEEPALIVED_PRIORITY:-200}"
VIP_ADDRESS="${VIP_ADDRESS:-192.168.8.250}"
VIP_NETMASK="${VIP_NETMASK:-32}"
NETWORK_INTERFACE="${NETWORK_INTERFACE:-eth1}"
VIRTUAL_ROUTER_ID="${VIRTUAL_ROUTER_ID:-51}"
VRRP_PASSWORD="${VRRP_PASSWORD:-oriondns}"
ROUTER_ID="${ROUTER_ID:-orion-dns-ha}"
USE_UNICAST_VRRP="${USE_UNICAST_VRRP:-true}"
PEER_IP="${PEER_IP:-}"
UNICAST_SRC_IP="${UNICAST_SRC_IP:-}"
CHECK_DNS_TARGET="${CHECK_DNS_TARGET:-127.0.0.1}"
CHECK_DNS_FQDN="${CHECK_DNS_FQDN:-github.com}"
CHECK_INTERVAL="${CHECK_INTERVAL:-5}"
CHECK_TIMEOUT="${CHECK_TIMEOUT:-3}"
CHECK_WEIGHT="${CHECK_WEIGHT:--20}"
CHECK_FALL="${CHECK_FALL:-2}"
CHECK_RISE="${CHECK_RISE:-2}"

# ============================================================================
# VALIDATION: Enforce strict requirements
# ============================================================================
echo "=== Validating environment variables ==="

# Validate VRRP_PASSWORD is exactly 8 characters (VRRP PASS auth limitation)
if [ ${#VRRP_PASSWORD} -ne 8 ]; then
  echo "❌ ERROR: VRRP_PASSWORD must be exactly 8 characters (VRRP PASS auth limitation)"
  echo "   Current length: ${#VRRP_PASSWORD}"
  echo "   Value: '${VRRP_PASSWORD}'"
  echo ""
  echo "   Fix: Set VRRP_PASSWORD to exactly 8 characters in your .env file"
  echo "   Example: VRRP_PASSWORD=oriondns"
  exit 1
fi
echo "  ✓ VRRP_PASSWORD: exactly 8 characters"

# Validate required variables
required_vars="NODE_ROLE KEEPALIVED_PRIORITY VIP_ADDRESS NETWORK_INTERFACE VIRTUAL_ROUTER_ID ROUTER_ID"
for var in $required_vars; do
  if [ -z "${!var:-}" ]; then
    echo "❌ ERROR: Required environment variable ${var} is not set"
    exit 1
  fi
done
echo "  ✓ Required variables: all set"

# IPv4 validation function
validate_ipv4() {
  local ip="$1"
  local var_name="$2"
  
  if ! echo "$ip" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
    echo "❌ ERROR: ${var_name}='${ip}' is not a valid IPv4 address"
    exit 1
  fi
  
  # Validate each octet is 0-255
  local IFS='.'
  # shellcheck disable=SC2206
  local octets=($ip)
  for octet in "${octets[@]}"; do
    if [ "$octet" -lt 0 ] || [ "$octet" -gt 255 ]; then
      echo "❌ ERROR: ${var_name}='${ip}' has invalid octet value: ${octet}"
      exit 1
    fi
  done
}

# Validate VIP_ADDRESS
validate_ipv4 "$VIP_ADDRESS" "VIP_ADDRESS"
echo "  ✓ VIP_ADDRESS: valid IPv4"

# Validate unicast VRRP configuration
if [ "${USE_UNICAST_VRRP}" = "true" ]; then
  if [ -z "$PEER_IP" ]; then
    echo "❌ ERROR: USE_UNICAST_VRRP=true requires PEER_IP to be set"
    echo "   PEER_IP is the IP address of the other node"
    echo "   Example for primary: PEER_IP=192.168.8.251"
    echo "   Example for secondary: PEER_IP=192.168.8.250"
    exit 1
  fi
  
  if [ -z "$UNICAST_SRC_IP" ]; then
    echo "❌ ERROR: USE_UNICAST_VRRP=true requires UNICAST_SRC_IP to be set"
    echo "   UNICAST_SRC_IP is the IP address of this node"
    echo "   Example for primary: UNICAST_SRC_IP=192.168.8.250"
    echo "   Example for secondary: UNICAST_SRC_IP=192.168.8.251"
    exit 1
  fi
  
  validate_ipv4 "$PEER_IP" "PEER_IP"
  validate_ipv4 "$UNICAST_SRC_IP" "UNICAST_SRC_IP"
  
  echo "  ✓ PEER_IP: valid IPv4 (${PEER_IP})"
  echo "  ✓ UNICAST_SRC_IP: valid IPv4 (${UNICAST_SRC_IP})"
  
  # Warn if peer IP and source IP are the same
  if [ "$PEER_IP" = "$UNICAST_SRC_IP" ]; then
    echo "⚠️  WARNING: PEER_IP and UNICAST_SRC_IP are the same!"
    echo "   This will prevent VRRP from working correctly"
    echo "   PEER_IP should be the OTHER node's IP address"
  fi
fi

echo "=== Validation complete ==="
echo ""

# ============================================================================
# Generate keepalived.conf
# ============================================================================
echo "=== Generating keepalived.conf ==="

cat > "${CONFIG_PATH}" <<EOF
global_defs {
    router_id ${ROUTER_ID}
    enable_script_security
    script_user root
}

vrrp_script check_dns {
    script "/etc/keepalived/check_dns.sh"
    interval ${CHECK_INTERVAL}
    timeout ${CHECK_TIMEOUT}
    weight ${CHECK_WEIGHT}
    fall ${CHECK_FALL}
    rise ${CHECK_RISE}
}

vrrp_instance VI_1 {
    state ${NODE_ROLE}
    interface ${NETWORK_INTERFACE}
    virtual_router_id ${VIRTUAL_ROUTER_ID}
    priority ${KEEPALIVED_PRIORITY}
    advert_int 1
    garp_master_delay 1
    garp_master_refresh 5
    authentication {
        auth_type PASS
        auth_pass ${VRRP_PASSWORD}
    }
EOF

# Always include unicast configuration when USE_UNICAST_VRRP=true
# This was validated above, so we know PEER_IP and UNICAST_SRC_IP are set
if [ "${USE_UNICAST_VRRP}" = "true" ]; then
cat >> "${CONFIG_PATH}" <<EOF
    unicast_src_ip ${UNICAST_SRC_IP}
    unicast_peer {
        ${PEER_IP}
    }
EOF
  echo "  ✓ Unicast VRRP: enabled (src=${UNICAST_SRC_IP}, peer=${PEER_IP})"
else
  echo "  ✓ Multicast VRRP: enabled"
fi

cat >> "${CONFIG_PATH}" <<EOF
    virtual_ipaddress {
        ${VIP_ADDRESS}/${VIP_NETMASK}
    }

    track_script {
        check_dns
    }

    notify_master "/etc/keepalived/notify_master.sh"
    notify_backup "/etc/keepalived/notify_backup.sh"
    notify_fault  "/etc/keepalived/notify_fault.sh"
}
EOF

echo ""
echo "=== Generated keepalived.conf ==="
sed 's/auth_pass .*/auth_pass ****/' "${CONFIG_PATH}"
echo "=== End of config ==="
echo ""

export VIP_ADDRESS NETWORK_INTERFACE NODE_ROLE ROUTER_ID

# Export Prometheus Pushgateway settings for notify scripts
export PROM_PUSHGATEWAY_URL="${PROM_PUSHGATEWAY_URL:-}"
export PROM_JOB_NAME="${PROM_JOB_NAME:-orion_dns_ha}"
export PROM_INSTANCE_LABEL="${PROM_INSTANCE_LABEL:-}"

echo "=== Starting keepalived ==="
exec keepalived --dont-fork --log-console --log-detail --vrrp
