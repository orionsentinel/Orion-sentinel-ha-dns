#!/usr/bin/env bash
# =============================================================================
# Keepalived BACKUP State Notification Script
# =============================================================================
# Called when this node becomes BACKUP and releases the VIP
# =============================================================================

set -euo pipefail

readonly NODE_NAME="${NODE_NAME:-$(hostname)}"
readonly VIP_ADDRESS="${VIP_ADDRESS:-unknown}"
readonly TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Logging
logger -t keepalived-notify "Transition to BACKUP state - VIP: $VIP_ADDRESS"

echo "[$TIMESTAMP] Node $NODE_NAME transitioned to BACKUP - VIP $VIP_ADDRESS released"

# Send notification if configured
if [[ "${NOTIFY_ON_FAILBACK:-false}" == "true" ]] && [[ -n "${ALERT_WEBHOOK:-}" ]]; then
    curl -X POST -H "Content-Type: application/json" \
        -d "{\"node\":\"$NODE_NAME\",\"state\":\"BACKUP\",\"vip\":\"$VIP_ADDRESS\",\"timestamp\":\"$TIMESTAMP\"}" \
        "$ALERT_WEBHOOK" &>/dev/null || true
fi

exit 0
