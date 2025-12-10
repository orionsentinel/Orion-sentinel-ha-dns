#!/usr/bin/env bash
set -euo pipefail

KEEPALIVED_CONFIG_DIR="${KEEPALIVED_CONFIG_DIR:-/etc/keepalived}"
CONFIG_PATH="${KEEPALIVED_CONFIG_DIR}/keepalived.conf"

mkdir -p "${KEEPALIVED_CONFIG_DIR}"

for script in check_dns.sh notify_master.sh notify_backup.sh notify_fault.sh; do
  if [ ! -f "${KEEPALIVED_CONFIG_DIR}/${script}" ]; then
    cp "/usr/local/share/keepalived/${script}" "${KEEPALIVED_CONFIG_DIR}/${script}"
    chmod +x "${KEEPALIVED_CONFIG_DIR}/${script}"
  fi
done

NODE_ROLE="${NODE_ROLE:-MASTER}"
KEEPALIVED_PRIORITY="${KEEPALIVED_PRIORITY:-200}"
VIP_ADDRESS="${VIP_ADDRESS:-192.168.8.250}"
VIP_NETMASK="${VIP_NETMASK:-24}"
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

if [ "${USE_UNICAST_VRRP}" = "true" ] && [ -n "${PEER_IP}" ]; then
  if [ -n "${UNICAST_SRC_IP}" ]; then
cat >> "${CONFIG_PATH}" <<EOF
    unicast_src_ip ${UNICAST_SRC_IP}
EOF
  fi
cat >> "${CONFIG_PATH}" <<EOF
    unicast_peer {
        ${PEER_IP}
    }
EOF
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

echo "Generated keepalived.conf:"
sed 's/auth_pass .*/auth_pass ****/' "${CONFIG_PATH}"

export VIP_ADDRESS NETWORK_INTERFACE NODE_ROLE ROUTER_ID

# Export Prometheus Pushgateway settings for notify scripts
export PROM_PUSHGATEWAY_URL="${PROM_PUSHGATEWAY_URL:-}"
export PROM_JOB_NAME="${PROM_JOB_NAME:-orion_dns_ha}"
export PROM_INSTANCE_LABEL="${PROM_INSTANCE_LABEL:-}"

exec keepalived --dont-fork --log-console --log-detail --vrrp
