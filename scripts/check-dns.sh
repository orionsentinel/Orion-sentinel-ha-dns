#!/usr/bin/env bash
# =============================================================================
# DNS Health Check Script for Keepalived and Manual Testing
# =============================================================================
#
# Purpose:
#   - Verifies Pi-hole and Unbound are operational
#   - Used by Keepalived to determine VIP assignment
#   - Can be run manually for diagnostics
#
# Exit Codes:
#   0 = All checks passed (healthy)
#   1 = One or more checks failed (unhealthy)
#
# Usage:
#   ./scripts/check-dns.sh              # Run all checks
#   ./scripts/check-dns.sh --verbose    # Show detailed output
#
# =============================================================================

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TIMEOUT="${DNS_CHECK_TIMEOUT:-2}"
readonly RETRIES="${DNS_CHECK_RETRIES:-3}"
readonly TEST_DOMAIN="${TEST_DOMAIN:-google.com}"
readonly PIHOLE_CONTAINER="${PIHOLE_CONTAINER:-pihole_primary}"
readonly UNBOUND_CONTAINER="${UNBOUND_CONTAINER:-unbound_primary}"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging
VERBOSE=false
if [[ "${1:-}" == "--verbose" ]]; then
    VERBOSE=true
fi

log_info() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}[INFO]${NC} $*"
    fi
}

log_success() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${GREEN}[✓]${NC} $*"
    fi
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[✗]${NC} $*" >&2
}

# =============================================================================
# Check Functions
# =============================================================================

check_container_running() {
    local container=$1
    local status
    
    log_info "Checking if container '$container' is running..."
    
    if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        log_error "Container '$container' is not running"
        return 1
    fi
    
    # Check container health status if healthcheck is defined
    local health
    health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no_healthcheck{{end}}' "$container" 2>/dev/null || echo "unknown")
    
    if [[ "$health" == "unhealthy" ]]; then
        log_error "Container '$container' is unhealthy"
        return 1
    elif [[ "$health" == "starting" ]]; then
        log_warning "Container '$container' is still starting"
        return 1
    fi
    
    log_success "Container '$container' is running (health: $health)"
    return 0
}

check_dns_resolution() {
    local dns_server=$1
    local port=${2:-53}
    local domain=${3:-$TEST_DOMAIN}
    local attempt=1
    
    log_info "Testing DNS resolution: $dns_server:$port for $domain"
    
    while [[ $attempt -le $RETRIES ]]; do
        if timeout "$TIMEOUT" dig "@${dns_server}" -p "$port" "$domain" +short +time="${TIMEOUT}" +tries=1 &>/dev/null; then
            log_success "DNS resolution successful on attempt $attempt"
            return 0
        fi
        log_warning "DNS resolution attempt $attempt/$RETRIES failed"
        attempt=$((attempt + 1))
        sleep 1
    done
    
    log_error "DNS resolution failed after $RETRIES attempts"
    return 1
}

check_pihole_responding() {
    log_info "Checking Pi-hole DNS response..."
    
    # Check if Pi-hole responds on port 53
    if ! check_dns_resolution "127.0.0.1" 53 "$TEST_DOMAIN"; then
        log_error "Pi-hole is not responding to DNS queries"
        return 1
    fi
    
    # Verify Pi-hole FTL is running inside container
    if ! docker exec "$PIHOLE_CONTAINER" pgrep -x pihole-FTL &>/dev/null; then
        log_error "pihole-FTL process not running in container"
        return 1
    fi
    
    log_success "Pi-hole is responding correctly"
    return 0
}

check_unbound_responding() {
    log_info "Checking Unbound DNS response..."
    
    # Try to query Unbound directly (port 5335)
    if docker exec "$UNBOUND_CONTAINER" drill "@127.0.0.1" -p 5335 "$TEST_DOMAIN" SOA &>/dev/null; then
        log_success "Unbound is responding correctly"
        return 0
    fi
    
    log_error "Unbound is not responding to DNS queries"
    return 1
}

check_vip_assigned() {
    local vip="${VIP_ADDRESS:-}"
    
    if [[ -z "$vip" ]]; then
        log_info "VIP_ADDRESS not set, skipping VIP check"
        return 0
    fi
    
    log_info "Checking if VIP $vip is assigned to this host..."
    
    if ip addr show | grep -q "$vip"; then
        log_success "VIP $vip is assigned to this host"
        return 0
    else
        log_warning "VIP $vip is NOT assigned to this host (this may be normal for BACKUP)"
        return 0  # Not a failure condition
    fi
}

# =============================================================================
# Main Health Check
# =============================================================================

main() {
    local failures=0
    local checks_run=0
    
    if [[ "$VERBOSE" == true ]]; then
        echo "========================================"
        echo "DNS Health Check - $(date)"
        echo "========================================"
    fi
    
    # Check 1: Pi-hole container
    checks_run=$((checks_run + 1))
    if ! check_container_running "$PIHOLE_CONTAINER"; then
        failures=$((failures + 1))
    fi
    
    # Check 2: Unbound container
    checks_run=$((checks_run + 1))
    if ! check_container_running "$UNBOUND_CONTAINER"; then
        failures=$((failures + 1))
    fi
    
    # Check 3: Pi-hole DNS resolution
    checks_run=$((checks_run + 1))
    if ! check_pihole_responding; then
        failures=$((failures + 1))
    fi
    
    # Check 4: Unbound DNS resolution
    checks_run=$((checks_run + 1))
    if ! check_unbound_responding; then
        failures=$((failures + 1))
    fi
    
    # Check 5: VIP assignment (informational)
    check_vip_assigned
    
    # Summary
    if [[ "$VERBOSE" == true ]]; then
        echo "========================================"
        echo "Checks run: $checks_run"
        echo "Failures: $failures"
        echo "========================================"
    fi
    
    if [[ $failures -eq 0 ]]; then
        if [[ "$VERBOSE" == true ]]; then
            echo -e "${GREEN}✓ All health checks passed${NC}"
        fi
        
        # Write status for monitoring
        echo "$(date '+%Y-%m-%d %H:%M:%S'): OK" > /tmp/dns_health_status 2>/dev/null || true
        
        exit 0
    else
        if [[ "$VERBOSE" == true ]]; then
            echo -e "${RED}✗ Health check failed: $failures/$checks_run checks failed${NC}"
        fi
        
        # Write status for monitoring
        echo "$(date '+%Y-%m-%d %H:%M:%S'): FAILED ($failures failures)" > /tmp/dns_health_status 2>/dev/null || true
        
        exit 1
    fi
}

# Run main function
main "$@"
