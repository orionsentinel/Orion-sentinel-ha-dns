#!/bin/bash
# Health check script for Keepalived
# Verifies that the local Pi-hole DNS service is responding
#
# Exit codes:
# 0 = healthy (keepalived continues)
# 1 = unhealthy (keepalived reduces priority or fails over)

# Configuration
TIMEOUT=2
RETRIES=3
TEST_DOMAIN="google.com"

# Detect which Pi-hole container to check based on environment
# HOST_IP is set by the entrypoint script
HOST_IP="${HOST_IP:-}"
PI1_IP="${PI1_IP:-}"
PI2_IP="${PI2_IP:-}"

# Determine container name based on which Pi this is
if [[ "$HOST_IP" == "$PI1_IP" ]] || [[ "${NODE_ROLE:-}" == "primary" ]] || [[ "${NODE_ROLE:-}" == "MASTER" ]]; then
    PIHOLE_CONTAINER="pihole_primary"
    LOCAL_DNS="127.0.0.1"
elif [[ "$HOST_IP" == "$PI2_IP" ]] || [[ "${NODE_ROLE:-}" == "secondary" ]] || [[ "${NODE_ROLE:-}" == "BACKUP" ]]; then
    PIHOLE_CONTAINER="pihole_secondary"
    LOCAL_DNS="127.0.0.1"
else
    # Fallback: try to detect from running containers
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "pihole_primary"; then
        PIHOLE_CONTAINER="pihole_primary"
    elif docker ps --format '{{.Names}}' 2>/dev/null | grep -q "pihole_secondary"; then
        PIHOLE_CONTAINER="pihole_secondary"
    else
        PIHOLE_CONTAINER=""
    fi
    LOCAL_DNS="127.0.0.1"
fi

# Function to check DNS resolution
check_dns() {
    local dns_server=$1
    dig @${dns_server} ${TEST_DOMAIN} +time=${TIMEOUT} +tries=1 +short > /dev/null 2>&1
    return $?
}

# Function to check if Pi-hole container is running and healthy
check_pihole_container() {
    if [[ -z "$PIHOLE_CONTAINER" ]]; then
        return 1
    fi
    
    # Check if container exists and is running
    local status
    status=$(docker inspect --format='{{.State.Status}}' "$PIHOLE_CONTAINER" 2>/dev/null)
    if [[ "$status" != "running" ]]; then
        return 1
    fi
    
    return 0
}

# Function to check if Unbound container is running
check_unbound_container() {
    local unbound_container
    if [[ "$PIHOLE_CONTAINER" == "pihole_primary" ]]; then
        unbound_container="unbound_primary"
    else
        unbound_container="unbound_secondary"
    fi
    
    local status
    status=$(docker inspect --format='{{.State.Status}}' "$unbound_container" 2>/dev/null)
    if [[ "$status" != "running" ]]; then
        return 1
    fi
    
    return 0
}

# Main health check logic
main() {
    # Check 1: Verify Pi-hole container is running
    if ! check_pihole_container; then
        logger -t keepalived-check "FAILED: Pi-hole container ($PIHOLE_CONTAINER) not running"
        exit 1
    fi

    # Check 2: Verify Unbound container is running
    if ! check_unbound_container; then
        logger -t keepalived-check "WARNING: Unbound container not running (continuing anyway)"
        # Don't fail on unbound - Pi-hole might still work with other upstream
    fi

    # Check 3: Verify DNS resolution works
    # Since keepalived runs with host networking, 127.0.0.1:53 should reach Pi-hole
    attempt=1
    while [ $attempt -le $RETRIES ]; do
        if check_dns ${LOCAL_DNS}; then
            logger -t keepalived-check "SUCCESS: DNS check passed (attempt $attempt)"
            exit 0
        fi
        attempt=$((attempt + 1))
        sleep 1
    done

    # All retries failed
    logger -t keepalived-check "FAILED: DNS resolution failed after $RETRIES attempts"
    exit 1
}

# Run the check
main
