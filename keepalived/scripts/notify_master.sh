#!/usr/bin/env bash
set -euo pipefail

TYPE="${1:-INSTANCE}"
NAME="${2:-VI_1}"
STATE="${3:-MASTER}"

timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
message="${timestamp} [MASTER] VIP=${VIP_ADDRESS:-} IFACE=${NETWORK_INTERFACE:-} NODE_ROLE=${NODE_ROLE:-} ROUTER_ID=${ROUTER_ID:-} TYPE=${TYPE} NAME=${NAME} STATE=${STATE}"

echo "${message}"
{ echo "${message}" >> /var/log/keepalived-notify.log; } || true

# Push to Prometheus Pushgateway if configured and curl is available
if [ -n "${PROM_PUSHGATEWAY_URL:-}" ] && command -v curl >/dev/null 2>&1; then
  job="${PROM_JOB_NAME:-orion_dns_ha}"
  instance="${PROM_INSTANCE_LABEL:-${ROUTER_ID:-unknown}}"
  router_id="${ROUTER_ID:-unknown}"

  cat <<EOF | curl -s --data-binary @- "${PROM_PUSHGATEWAY_URL}/metrics/job/${job}/instance/${instance}" || true
# TYPE keepalived_vrrp_state gauge
keepalived_vrrp_state{job="${job}",instance="${instance}",router_id="${router_id}",name="${NAME}",type="${TYPE}",state="${STATE}"} 1
EOF
fi
