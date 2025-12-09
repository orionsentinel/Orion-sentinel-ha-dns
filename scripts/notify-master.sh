#!/usr/bin/env bash
# =============================================================================
# Keepalived MASTER State Notification Script
# =============================================================================
# Called when this node becomes MASTER and takes over the VIP
# =============================================================================

set -euo pipefail

readonly NODE_NAME="${NODE_NAME:-$(hostname)}"
readonly VIP_ADDRESS="${VIP_ADDRESS:-unknown}"
readonly TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Logging
logger -t keepalived-notify "Transition to MASTER state - VIP: $VIP_ADDRESS"

echo "[$TIMESTAMP] Node $NODE_NAME transitioned to MASTER - VIP $VIP_ADDRESS is now active on this node"

# Send notification if configured
if [[ "${NOTIFY_ON_FAILOVER:-false}" == "true" ]] && [[ -n "${ALERT_WEBHOOK:-}" ]]; then
    curl -X POST -H "Content-Type: application/json" \
        -d "{\"node\":\"$NODE_NAME\",\"state\":\"MASTER\",\"vip\":\"$VIP_ADDRESS\",\"timestamp\":\"$TIMESTAMP\"}" \
        "$ALERT_WEBHOOK" &>/dev/null || true
fi

exit 0
