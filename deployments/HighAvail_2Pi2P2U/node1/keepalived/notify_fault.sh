#!/bin/bash
# Notification script for when this node encounters a fault

TYPE=$1
NAME=$2
STATE=$3

HOSTNAME=$(hostname)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

MESSAGE="🔴 Keepalived FAULT: ${HOSTNAME} encountered a fault for ${NAME}"
DETAILS="State: ${STATE}, Time: ${TIMESTAMP}"

# Log to syslog
logger -t keepalived-notify "FAULT: ${MESSAGE}"

# Send Signal notification if configured (always notify on faults)
if [ -n "$SIGNAL_NUMBER" ]; then
    curl -X POST http://localhost:8080/alert \
        -H "Content-Type: application/json" \
        -d "{\"message\": \"${MESSAGE}\", \"details\": \"${DETAILS}\", \"priority\": \"high\"}" \
        2>/dev/null || true
fi

# Create a flag file for monitoring
echo "${TIMESTAMP}" > /tmp/keepalived_state_fault

# Optional: Update Prometheus metrics
if command -v curl &> /dev/null; then
    echo "keepalived_state{node=\"${HOSTNAME}\"} -1" | \
        curl --data-binary @- http://localhost:9091/metrics/job/keepalived 2>/dev/null || true
fi

exit 0
