#!/bin/bash
# Health check script for Keepalived
# Verifies that the local Pi-hole DNS service is responding

# Exit codes:
# 0 = healthy (keepalived continues)
# 1 = unhealthy (keepalived reduces priority or fails over)

# Configuration
TIMEOUT=2
RETRIES=3
TEST_DOMAIN="google.com"

# Detect local Pi-hole IP based on hostname
if [[ "$(hostname)" =~ "primary" ]] || [[ "$NODE_ROLE" == "primary" ]]; then
    LOCAL_DNS="127.0.0.1"
    PIHOLE_IP="192.168.8.251"
elif [[ "$(hostname)" =~ "secondary" ]] || [[ "$NODE_ROLE" == "secondary" ]]; then
    LOCAL_DNS="127.0.0.1"
    PIHOLE_IP="192.168.8.252"
else
    # Fallback: try to query localhost
    LOCAL_DNS="127.0.0.1"
fi

# Function to check DNS resolution
check_dns() {
    local dns_server=$1
    dig @${dns_server} ${TEST_DOMAIN} +time=${TIMEOUT} +tries=1 > /dev/null 2>&1
    return $?
}

# Function to check if Pi-hole container is running
check_pihole_container() {
    if [[ "$(hostname)" =~ "primary" ]] || [[ "$NODE_ROLE" == "primary" ]]; then
        docker ps | grep -q "pihole_primary.*Up"
    elif [[ "$(hostname)" =~ "secondary" ]] || [[ "$NODE_ROLE" == "secondary" ]]; then
        docker ps | grep -q "pihole_secondary.*Up"
    else
        return 1
    fi
    return $?
}

# Function to check if Unbound container is running
check_unbound_container() {
    if [[ "$(hostname)" =~ "primary" ]] || [[ "$NODE_ROLE" == "primary" ]]; then
        docker ps | grep -q "unbound_primary.*Up"
    elif [[ "$(hostname)" =~ "secondary" ]] || [[ "$NODE_ROLE" == "secondary" ]]; then
        docker ps | grep -q "unbound_secondary.*Up"
    else
        return 1
    fi
    return $?
}

# Main health check logic
main() {
    # Check 1: Verify Docker containers are running
    if ! check_pihole_container; then
        logger -t keepalived-check "FAILED: Pi-hole container not running"
        exit 1
    fi

    if ! check_unbound_container; then
        logger -t keepalived-check "FAILED: Unbound container not running"
        exit 1
    fi

    # Check 2: Verify DNS resolution works
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
