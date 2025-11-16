#!/bin/bash
# Notification script for when this node becomes BACKUP

TYPE=$1
NAME=$2
STATE=$3
PRIORITY=$4

HOSTNAME=$(hostname)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

MESSAGE="🟡 Keepalived State Change: ${HOSTNAME} entered BACKUP state for ${NAME}"
DETAILS="Priority: ${PRIORITY}, Time: ${TIMESTAMP}"

# Log to syslog
logger -t keepalived-notify "BACKUP: ${MESSAGE}"

# Send Signal notification if configured
if [ -n "$SIGNAL_NUMBER" ] && [ "$NOTIFY_ON_FAILBACK" = "true" ]; then
    curl -X POST http://localhost:8080/alert \
        -H "Content-Type: application/json" \
        -d "{\"message\": \"${MESSAGE}\", \"details\": \"${DETAILS}\"}" \
        2>/dev/null || true
fi

# Create a flag file for monitoring
echo "${TIMESTAMP}" > /tmp/keepalived_state_backup

# Optional: Update Prometheus metrics
if command -v curl &> /dev/null; then
    echo "keepalived_state{node=\"${HOSTNAME}\"} 0" | \
        curl --data-binary @- http://localhost:9091/metrics/job/keepalived 2>/dev/null || true
fi

exit 0
