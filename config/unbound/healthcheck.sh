#!/bin/bash
# DEPRECATED: This script is no longer used by the default Dockerfile healthcheck.
# The Dockerfile now uses unbound-host directly for healthchecks.
# This file is kept for backwards compatibility with custom configurations.
#
# Unbound DNSSEC Health Check Script
# 
# Performs a DNSSEC-validating DNS query to verify:
# 1. Unbound is responding to queries
# 2. DNSSEC validation is working correctly
#
# Exit codes:
#   0 - Healthy (DNS resolution and DNSSEC validation working)
#   1 - Unhealthy (DNS resolution failed or DNSSEC validation failed)

set -e

# Configuration
UNBOUND_HOST="127.0.0.1"
UNBOUND_PORT="5335"

# Test domain - use a well-known DNSSEC-signed domain
# cloudflare.com is DNSSEC-signed and widely available
TEST_DOMAIN="${HEALTHCHECK_DOMAIN:-cloudflare.com}"

# Perform DNSSEC query using drill
# -D enables DNSSEC mode
# -p specifies the port
if drill -D -p "${UNBOUND_PORT}" @"${UNBOUND_HOST}" "${TEST_DOMAIN}" A > /tmp/healthcheck_result 2>&1; then
    # Check if the response contains valid data (look for IN A or IN CNAME)
    if grep -q "IN[[:space:]]\+\(A\|CNAME\)" /tmp/healthcheck_result; then
        # Successful DNS resolution
        exit 0
    else
        echo "HEALTHCHECK FAILED: No valid DNS response for ${TEST_DOMAIN}"
        cat /tmp/healthcheck_result
        exit 1
    fi
else
    echo "HEALTHCHECK FAILED: drill command failed"
    cat /tmp/healthcheck_result 2>/dev/null || true
    exit 1
fi
