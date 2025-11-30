#!/usr/bin/env bash
# VIP and DNS Health Check Script for Two-Pi HA Mode
# ===================================================
#
# This script verifies that:
# 1. The VIP is present on the expected network interface
# 2. DNS resolution works via the VIP
# 3. DNS resolution works via the HOST_IP
#
# Usage:
#   bash scripts/vip-health.sh
#
# Exit codes:
#   0 - All checks passed
#   1 - One or more checks failed

set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err() { echo -e "${RED}[✗]${NC} $*" >&2; }

# Find repo root and load .env
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || (cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd))"
ENV_FILE="$REPO_ROOT/.env"

if [[ ! -f "$ENV_FILE" ]]; then
    err ".env file not found at $ENV_FILE"
    exit 1
fi

# Load environment variables
set -a
# shellcheck disable=SC1090
source "$ENV_FILE" 2>/dev/null || true
set +a

# Get configuration from env with fallbacks
VIP="${VIP_ADDRESS:-${DNS_VIP:-}}"
HOST="${HOST_IP:-}"
INTERFACE="${NETWORK_INTERFACE:-eth0}"
TEST_DOMAIN="${TEST_DOMAIN:-google.com}"

ERRORS=0

echo "=========================================="
echo "VIP and DNS Health Check"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  VIP_ADDRESS:       ${VIP:-NOT SET}"
echo "  HOST_IP:           ${HOST:-NOT SET}"
echo "  NETWORK_INTERFACE: ${INTERFACE}"
echo "  TEST_DOMAIN:       ${TEST_DOMAIN}"
echo ""

# Check 1: VIP is configured
if [[ -z "$VIP" ]]; then
    err "VIP_ADDRESS (or DNS_VIP) is not set in .env"
    ((ERRORS++))
else
    log "VIP_ADDRESS is configured: $VIP"
fi

# Check 2: HOST_IP is configured
if [[ -z "$HOST" ]]; then
    warn "HOST_IP is not set in .env (optional but recommended)"
fi

# Check 3: VIP is present on the network interface
echo ""
echo "Checking VIP presence on ${INTERFACE}..."

if [[ -n "$VIP" ]]; then
    if ip addr show "${INTERFACE}" 2>/dev/null | grep -q "${VIP}"; then
        log "VIP ${VIP} is present on ${INTERFACE}"
        
        # Show the actual line from ip addr
        echo "  $(ip addr show "${INTERFACE}" | grep "${VIP}")"
    else
        err "VIP ${VIP} is NOT present on ${INTERFACE}"
        echo "  This node may be in BACKUP state, or keepalived may not be running."
        echo "  Run: docker logs keepalived"
        ((ERRORS++))
    fi
else
    warn "Skipping VIP presence check (VIP not configured)"
fi

# Check 4: DNS resolution via VIP
echo ""
echo "Checking DNS resolution..."

if [[ -n "$VIP" ]]; then
    echo "Testing DNS via VIP (${VIP})..."
    if command -v dig &> /dev/null; then
        result=$(dig +short +time=3 +tries=1 "${TEST_DOMAIN}" "@${VIP}" 2>&1)
        if [[ -n "$result" ]] && [[ ! "$result" =~ "connection refused" ]] && [[ ! "$result" =~ "timed out" ]]; then
            log "DNS via VIP works: ${TEST_DOMAIN} -> ${result}"
        else
            err "DNS via VIP failed: ${result:-no response}"
            ((ERRORS++))
        fi
    elif command -v nslookup &> /dev/null; then
        if nslookup "${TEST_DOMAIN}" "${VIP}" &> /dev/null; then
            log "DNS via VIP works"
        else
            err "DNS via VIP failed"
            ((ERRORS++))
        fi
    else
        warn "Neither dig nor nslookup found, skipping DNS test"
    fi
fi

# Check 5: DNS resolution via HOST_IP
if [[ -n "$HOST" ]]; then
    echo "Testing DNS via HOST_IP (${HOST})..."
    if command -v dig &> /dev/null; then
        result=$(dig +short +time=3 +tries=1 "${TEST_DOMAIN}" "@${HOST}" 2>&1)
        if [[ -n "$result" ]] && [[ ! "$result" =~ "connection refused" ]] && [[ ! "$result" =~ "timed out" ]]; then
            log "DNS via HOST_IP works: ${TEST_DOMAIN} -> ${result}"
        else
            err "DNS via HOST_IP failed: ${result:-no response}"
            ((ERRORS++))
        fi
    fi
fi

# Check 6: Keepalived container status
echo ""
echo "Checking keepalived container..."

if command -v docker &> /dev/null; then
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^keepalived$"; then
        status=$(docker inspect --format='{{.State.Status}}' keepalived 2>/dev/null)
        if [[ "$status" == "running" ]]; then
            log "Keepalived container is running"
            
            # Check keepalived process inside container
            if docker exec keepalived pgrep keepalived &> /dev/null; then
                log "Keepalived process is running inside container"
            else
                err "Keepalived process is NOT running inside container"
                ((ERRORS++))
            fi
        else
            err "Keepalived container status: $status"
            ((ERRORS++))
        fi
    else
        warn "Keepalived container not found (may not be deployed yet)"
    fi
else
    warn "Docker not available, skipping container checks"
fi

# Check 7: Pi-hole container status
echo ""
echo "Checking Pi-hole container..."

if command -v docker &> /dev/null; then
    # Check for either primary or secondary Pi-hole
    pihole_container=""
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^pihole_primary$"; then
        pihole_container="pihole_primary"
    elif docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^pihole_secondary$"; then
        pihole_container="pihole_secondary"
    fi
    
    if [[ -n "$pihole_container" ]]; then
        status=$(docker inspect --format='{{.State.Status}}' "$pihole_container" 2>/dev/null)
        if [[ "$status" == "running" ]]; then
            log "Pi-hole container ($pihole_container) is running"
        else
            err "Pi-hole container ($pihole_container) status: $status"
            ((ERRORS++))
        fi
    else
        warn "Pi-hole container not found"
    fi
fi

# Summary
echo ""
echo "=========================================="
if [[ $ERRORS -eq 0 ]]; then
    log "All health checks PASSED"
    echo ""
    echo "Your two-pi-ha DNS stack appears healthy!"
    echo "Clients can use ${VIP:-VIP_ADDRESS} for DNS queries."
    exit 0
else
    err "Health check FAILED with $ERRORS error(s)"
    echo ""
    echo "Troubleshooting steps:"
    echo "  1. Check keepalived logs: docker logs keepalived"
    echo "  2. Check Pi-hole logs: docker logs pihole_primary (or pihole_secondary)"
    echo "  3. Verify .env configuration matches your network"
    echo "  4. Ensure no firewall is blocking port 53 or VRRP (protocol 112)"
    exit 1
fi
