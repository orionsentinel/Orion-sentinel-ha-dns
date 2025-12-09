#!/usr/bin/env bash
# =============================================================================
# Keepalived FAULT State Notification Script
# =============================================================================
# Called when keepalived detects a fault condition
# =============================================================================

set -euo pipefail

readonly NODE_NAME="${NODE_NAME:-$(hostname)}"
readonly VIP_ADDRESS="${VIP_ADDRESS:-unknown}"
readonly TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Logging
logger -t keepalived-notify -p daemon.err "FAULT state detected - VIP: $VIP_ADDRESS"

echo "[$TIMESTAMP] ERROR: Node $NODE_NAME entered FAULT state - VIP $VIP_ADDRESS"

# Send critical notification if configured
if [[ -n "${ALERT_WEBHOOK:-}" ]]; then
    curl -X POST -H "Content-Type: application/json" \
        -d "{\"node\":\"$NODE_NAME\",\"state\":\"FAULT\",\"vip\":\"$VIP_ADDRESS\",\"timestamp\":\"$TIMESTAMP\",\"severity\":\"critical\"}" \
        "$ALERT_WEBHOOK" &>/dev/null || true
fi

exit 0
