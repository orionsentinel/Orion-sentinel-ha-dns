#!/usr/bin/env bash
# =============================================================================
# Orion DNS HA - Host-Level Auto-Heal Script
# =============================================================================
#
# This script runs on the host (not inside a container) to monitor DNS health
# and automatically restart containers when repeated failures occur.
#
# The script uses the same check_dns.sh that keepalived uses internally,
# ensuring consistency between VRRP failover decisions and auto-healing.
#
# Usage:
#   ./orion-dns-health.sh                    # Run health check
#   HEALTH_FAIL_THRESHOLD=3 ./orion-dns-health.sh  # Custom threshold
#
# Exit Codes:
#   0 - Health check passed or actions completed
#   1 - Error (e.g., docker not available)
#
# Environment Variables:
#   REPO_DIR                   - Path to repository (default: /opt/orion-dns-ha)
#   PIHOLE_CONTAINER_NAME      - Pi-hole container name (default: pihole_unbound)
#   KEEPALIVED_CONTAINER_NAME  - Keepalived container name (default: keepalived)
#   HEALTH_FAIL_THRESHOLD      - Failures before restart (default: 2)
#   CHECK_DNS_FQDN             - Domain to resolve (default: github.com)
#
# =============================================================================

set -euo pipefail

# Configuration with sensible defaults
REPO_DIR="${REPO_DIR:-/opt/orion-dns-ha}"
STATE_DIR="${REPO_DIR}/run"
mkdir -p "${STATE_DIR}" 2>/dev/null || true

FAIL_STATE_FILE="${STATE_DIR}/health.failcount"

# Container names
PIHOLE_CONTAINER="${PIHOLE_CONTAINER_NAME:-pihole_unbound}"
KEEPALIVED_CONTAINER="${KEEPALIVED_CONTAINER_NAME:-keepalived}"

# How many consecutive failures before we act
FAIL_THRESHOLD="${HEALTH_FAIL_THRESHOLD:-2}"

# What DNS check to run (reuse same FQDN as keepalived by default)
CHECK_DNS_FQDN="${CHECK_DNS_FQDN:-github.com}"

# Logging function
log() {
    echo "[$(date -Iseconds)] [health] $*" >&2
}

# =============================================================================
# 1) Quick sanity checks
# =============================================================================
if ! command -v docker >/dev/null 2>&1; then
    log "docker not found, aborting."
    exit 0  # do not spam systemd with failures
fi

if ! docker ps >/dev/null 2>&1; then
    log "docker daemon not responding, skipping health check."
    exit 0
fi

# If keepalived container doesn't exist or isn't running, we can't rely on its check script
if ! docker ps --format '{{.Names}}' | grep -q "^${KEEPALIVED_CONTAINER}\$"; then
    log "keepalived container '${KEEPALIVED_CONTAINER}' not running; skipping DNS health check."
    exit 0
fi

# =============================================================================
# 2) Run DNS health check via keepalived container
# =============================================================================
log "Running DNS health check via keepalived container..."

if docker exec "${KEEPALIVED_CONTAINER}" /etc/keepalived/check_dns.sh >/dev/null 2>&1; then
    log "DNS health OK."
    rm -f "${FAIL_STATE_FILE}" 2>/dev/null || true
    exit 0
fi

log "DNS health check FAILED."

# =============================================================================
# 3) Handle failure with throttling
# =============================================================================
fails=0
if [[ -f "${FAIL_STATE_FILE}" ]]; then
    fails="$(cat "${FAIL_STATE_FILE}" 2>/dev/null || echo 0)"
fi

fails=$((fails + 1))
echo "${fails}" > "${FAIL_STATE_FILE}"

log "Consecutive failures: ${fails} (threshold=${FAIL_THRESHOLD})"

if (( fails < FAIL_THRESHOLD )); then
    log "Below threshold, not restarting anything yet."
    exit 0
fi

# We've reached the threshold: try to heal.
log "Threshold reached. Attempting auto-heal actions."

# Reset fail count after actions, to avoid endless restarts on persistent failures
echo 0 > "${FAIL_STATE_FILE}"

# 1) Restart Pi-hole/Unbound container
if docker ps --format '{{.Names}}' | grep -q "^${PIHOLE_CONTAINER}\$"; then
    log "Restarting container: ${PIHOLE_CONTAINER}"
    docker restart "${PIHOLE_CONTAINER}" >/dev/null 2>&1 || log "Failed to restart ${PIHOLE_CONTAINER}"
else
    log "Container ${PIHOLE_CONTAINER} not found; skipping restart."
fi

# 2) If keepalived is not running, try to start it as well
if ! docker ps --format '{{.Names}}' | grep -q "^${KEEPALIVED_CONTAINER}\$"; then
    log "keepalived container not running; trying to start via docker compose."

    # Run compose from the repo directory; relies on the node's systemd / profiles to be set correctly.
    if [[ -d "${REPO_DIR}" ]]; then
        (cd "${REPO_DIR}" && docker compose up -d "${KEEPALIVED_CONTAINER}") \
            || log "Failed to start keepalived via docker compose."
    else
        log "Repo dir ${REPO_DIR} not found; cannot start keepalived."
    fi
fi

log "Auto-heal actions completed."
exit 0
