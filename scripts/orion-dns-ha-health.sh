#!/usr/bin/env bash
# =============================================================================
# Orion DNS HA Health Check Script
# =============================================================================
#
# Comprehensive health check for Two-Pi HA DNS deployments.
# Checks Docker containers, VIP ownership, and DNS resolution.
#
# Exit Codes:
#   0 - GREEN:  All systems healthy
#   1 - YELLOW: Degraded but operational (e.g., secondary down, monitoring issues)
#   2 - RED:    Critical failure (VIP missing, DNS not resolving)
#
# Usage:
#   ./orion-dns-ha-health.sh              # Run all checks with colored output
#   ./orion-dns-ha-health.sh --quiet      # Exit code only, no output
#   ./orion-dns-ha-health.sh --json       # JSON output for automation
#
# =============================================================================

set -euo pipefail

# Role constants
readonly PRIMARY_ROLE="primary"
readonly SECONDARY_ROLE="secondary"

# Container name constants
readonly PIHOLE_PRIMARY="pihole_primary"
readonly PIHOLE_SECONDARY="pihole_secondary"
readonly UNBOUND_PRIMARY="unbound_primary"
readonly UNBOUND_SECONDARY="unbound_secondary"
readonly KEEPALIVED="keepalived"

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Flags
QUIET=false
JSON=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --quiet|-q)
            QUIET=true
            shift
            ;;
        --json|-j)
            JSON=true
            shift
            ;;
        --help|-h)
            head -n 25 "$0" | tail -n +2 | sed 's/^# //'
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Load environment if available
if [[ -f .env ]]; then
    set -a
    source .env 2>/dev/null || true
    set +a
fi

VIP_ADDRESS="${VIP_ADDRESS:-}"
NETWORK_INTERFACE="${NETWORK_INTERFACE:-eth0}"
NODE_ROLE="${NODE_ROLE:-unknown}"

# Results tracking
declare -a CHECKS_PASSED=()
declare -a CHECKS_DEGRADED=()
declare -a CHECKS_FAILED=()

log_green() {
    if [[ "$QUIET" == false && "$JSON" == false ]]; then
        echo -e "${GREEN}✓${NC} $*"
    fi
    CHECKS_PASSED+=("$1")
}

log_yellow() {
    if [[ "$QUIET" == false && "$JSON" == false ]]; then
        echo -e "${YELLOW}⚠${NC} $*"
    fi
    CHECKS_DEGRADED+=("$1")
}

log_red() {
    if [[ "$QUIET" == false && "$JSON" == false ]]; then
        echo -e "${RED}✗${NC} $*"
    fi
    CHECKS_FAILED+=("$1")
}

log_info() {
    if [[ "$QUIET" == false && "$JSON" == false ]]; then
        echo -e "${BLUE}ℹ${NC} $*"
    fi
}

section() {
    if [[ "$QUIET" == false && "$JSON" == false ]]; then
        echo ""
        echo -e "${BOLD}$*${NC}"
    fi
}

# =============================================================================
# CHECK 1: Docker Service
# =============================================================================
check_docker() {
    section "1. Docker Service"
    
    if ! command -v docker &> /dev/null; then
        log_red "Docker is not installed"
        return 2
    fi
    
    if ! docker info &> /dev/null; then
        log_red "Docker daemon is not running"
        return 2
    fi
    
    log_green "Docker daemon is running"
    return 0
}

# =============================================================================
# CHECK 2: Critical DNS Containers
# =============================================================================
check_containers() {
    section "2. DNS Containers"
    
    local status=0
    
    # Determine which containers should be running based on node role
    if [[ "$NODE_ROLE" == "$PRIMARY_ROLE" ]]; then
        EXPECTED_CONTAINERS=("$PIHOLE_PRIMARY" "$UNBOUND_PRIMARY" "$KEEPALIVED")
    elif [[ "$NODE_ROLE" == "$SECONDARY_ROLE" ]]; then
        EXPECTED_CONTAINERS=("$PIHOLE_SECONDARY" "$UNBOUND_SECONDARY" "$KEEPALIVED")
    else
        # Unknown role, check all possible containers
        EXPECTED_CONTAINERS=("$PIHOLE_PRIMARY" "$PIHOLE_SECONDARY" "$UNBOUND_PRIMARY" "$UNBOUND_SECONDARY" "$KEEPALIVED")
    fi
    
    for container in "${EXPECTED_CONTAINERS[@]}"; do
        if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            # Container exists and is running
            local health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "no-healthcheck")
            
            if [[ "$health_status" == "healthy" ]] || [[ "$health_status" == "no-healthcheck" ]]; then
                log_green "$container is running and healthy"
            elif [[ "$health_status" == "starting" ]]; then
                log_yellow "$container is starting (health check in progress)"
                status=1
            else
                log_red "$container is running but unhealthy (status: $health_status)"
                status=2
            fi
        else
            # Check if container exists but is stopped
            if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
                log_red "$container exists but is not running"
                status=2
            else
                # Container doesn't exist - might be expected on this node
                if [[ "$NODE_ROLE" == "$PRIMARY_ROLE" && ("$container" == "$PIHOLE_SECONDARY" || "$container" == "$UNBOUND_SECONDARY") ]]; then
                    # Not expected on primary
                    continue
                elif [[ "$NODE_ROLE" == "$SECONDARY_ROLE" && ("$container" == "$PIHOLE_PRIMARY" || "$container" == "$UNBOUND_PRIMARY") ]]; then
                    # Not expected on secondary
                    continue
                else
                    log_yellow "$container not found (may not be deployed)"
                    status=1
                fi
            fi
        fi
    done
    
    return $status
}

# =============================================================================
# CHECK 3: VIP Ownership
# =============================================================================
check_vip() {
    section "3. Virtual IP (VIP) Status"
    
    if [[ -z "$VIP_ADDRESS" ]]; then
        log_yellow "VIP_ADDRESS not configured in .env (skipping VIP check)"
        return 1
    fi
    
    # Check if VIP is assigned to this node
    if ip addr show "$NETWORK_INTERFACE" 2>/dev/null | grep -q "$VIP_ADDRESS"; then
        log_green "VIP $VIP_ADDRESS is assigned to this node ($NETWORK_INTERFACE)"
        
        # Check keepalived state
        if docker logs "$KEEPALIVED" 2>/dev/null | tail -20 | grep -q "Entering MASTER STATE"; then
            log_green "Keepalived is in MASTER state"
        elif docker logs "$KEEPALIVED" 2>/dev/null | tail -20 | grep -q "Entering BACKUP STATE"; then
            log_yellow "Keepalived recently transitioned to BACKUP state (VIP may be stale)"
        fi
        return 0
    else
        # VIP not on this node - check if this is expected
        if [[ "$NODE_ROLE" == "$SECONDARY_ROLE" ]]; then
            log_info "VIP is not on this node (expected for BACKUP/secondary)"
            
            # Verify keepalived is in BACKUP state
            if docker logs "$KEEPALIVED" 2>/dev/null | tail -20 | grep -q "Entering BACKUP STATE"; then
                log_green "Keepalived is in BACKUP state (as expected)"
                return 0
            else
                log_yellow "VIP not assigned but Keepalived state unclear"
                return 1
            fi
        else
            log_red "VIP $VIP_ADDRESS is NOT assigned to this node (expected MASTER)"
            return 2
        fi
    fi
}

# =============================================================================
# CHECK 4: DNS Resolution via VIP
# =============================================================================
check_dns_resolution() {
    section "4. DNS Resolution"
    
    local status=0
    
    # Test DNS via localhost (direct to Pi-hole on this node)
    if command -v dig &> /dev/null; then
        if dig +short +timeout=2 google.com @127.0.0.1 &> /dev/null; then
            log_green "Local DNS resolution working (127.0.0.1)"
        else
            log_red "Local DNS resolution failed (127.0.0.1)"
            status=2
        fi
    elif command -v nslookup &> /dev/null; then
        if timeout 2 nslookup google.com 127.0.0.1 &> /dev/null; then
            log_green "Local DNS resolution working (127.0.0.1)"
        else
            log_red "Local DNS resolution failed (127.0.0.1)"
            status=2
        fi
    else
        log_yellow "Neither 'dig' nor 'nslookup' available (install dnsutils)"
        status=1
    fi
    
    # Test DNS via VIP (only if VIP is configured)
    if [[ -n "$VIP_ADDRESS" ]]; then
        if command -v dig &> /dev/null; then
            if dig +short +timeout=2 google.com @"$VIP_ADDRESS" &> /dev/null; then
                log_green "VIP DNS resolution working ($VIP_ADDRESS)"
            else
                log_red "VIP DNS resolution failed ($VIP_ADDRESS)"
                status=2
            fi
        elif command -v nslookup &> /dev/null; then
            if timeout 2 nslookup google.com "$VIP_ADDRESS" &> /dev/null; then
                log_green "VIP DNS resolution working ($VIP_ADDRESS)"
            else
                log_red "VIP DNS resolution failed ($VIP_ADDRESS)"
                status=2
            fi
        fi
    fi
    
    return $status
}

# =============================================================================
# CHECK 5: Keepalived Health
# =============================================================================
check_keepalived() {
    section "5. Keepalived Health"
    
    if ! docker ps --format '{{.Names}}' | grep -q "^${KEEPALIVED}$"; then
        log_red "Keepalived container is not running"
        return 2
    fi
    
    # Check if keepalived process is running inside container
    if docker exec "$KEEPALIVED" pgrep keepalived &> /dev/null; then
        log_green "Keepalived process is running"
    else
        log_red "Keepalived process is not running in container"
        return 2
    fi
    
    # Check for recent errors in logs
    local recent_errors=$(docker logs --since 5m "$KEEPALIVED" 2>&1 | grep -i "error\|failed\|fault" | wc -l)
    if [[ $recent_errors -gt 0 ]]; then
        log_yellow "Keepalived has $recent_errors error(s) in last 5 minutes"
        return 1
    else
        log_green "No recent errors in Keepalived logs"
    fi
    
    return 0
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    if [[ "$QUIET" == false && "$JSON" == false ]]; then
        echo ""
        echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${BOLD}  Orion DNS HA Health Check${NC}"
        echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
        echo ""
        log_info "Node Role: ${NODE_ROLE:-unknown}"
        log_info "VIP Address: ${VIP_ADDRESS:-not configured}"
        log_info "Interface: $NETWORK_INTERFACE"
    fi
    
    # Run all checks
    check_docker
    local docker_status=$?
    
    check_containers
    local container_status=$?
    
    check_vip
    local vip_status=$?
    
    check_dns_resolution
    local dns_status=$?
    
    check_keepalived
    local keepalived_status=$?
    
    # Determine overall status
    local overall_status=0
    
    # Critical failures (any check returned 2)
    if [[ $docker_status -eq 2 || $container_status -eq 2 || $vip_status -eq 2 || $dns_status -eq 2 || $keepalived_status -eq 2 ]]; then
        overall_status=2
    # Degraded (any check returned 1)
    elif [[ $docker_status -eq 1 || $container_status -eq 1 || $vip_status -eq 1 || $dns_status -eq 1 || $keepalived_status -eq 1 ]]; then
        overall_status=1
    fi
    
    # Output results
    if [[ "$JSON" == true ]]; then
        # JSON output
        cat << EOF
{
  "status": $([ $overall_status -eq 0 ] && echo '"healthy"' || ([ $overall_status -eq 1 ] && echo '"degraded"' || echo '"unhealthy"')),
  "exit_code": $overall_status,
  "node_role": "$NODE_ROLE",
  "vip_address": "$VIP_ADDRESS",
  "checks": {
    "docker": $([ $docker_status -eq 0 ] && echo '"pass"' || ([ $docker_status -eq 1 ] && echo '"degraded"' || echo '"fail"')),
    "containers": $([ $container_status -eq 0 ] && echo '"pass"' || ([ $container_status -eq 1 ] && echo '"degraded"' || echo '"fail"')),
    "vip": $([ $vip_status -eq 0 ] && echo '"pass"' || ([ $vip_status -eq 1 ] && echo '"degraded"' || echo '"fail"')),
    "dns": $([ $dns_status -eq 0 ] && echo '"pass"' || ([ $dns_status -eq 1 ] && echo '"degraded"' || echo '"fail"')),
    "keepalived": $([ $keepalived_status -eq 0 ] && echo '"pass"' || ([ $keepalived_status -eq 1 ] && echo '"degraded"' || echo '"fail"'))
  },
  "summary": {
    "passed": ${#CHECKS_PASSED[@]},
    "degraded": ${#CHECKS_DEGRADED[@]},
    "failed": ${#CHECKS_FAILED[@]}
  }
}
EOF
    elif [[ "$QUIET" == false ]]; then
        # Human-readable summary
        echo ""
        echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${BOLD}  Summary${NC}"
        echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "  ${GREEN}Passed:${NC}   ${#CHECKS_PASSED[@]} checks"
        echo -e "  ${YELLOW}Degraded:${NC} ${#CHECKS_DEGRADED[@]} checks"
        echo -e "  ${RED}Failed:${NC}   ${#CHECKS_FAILED[@]} checks"
        echo ""
        
        if [[ $overall_status -eq 0 ]]; then
            echo -e "${GREEN}${BOLD}Overall Status: HEALTHY ✓${NC}"
        elif [[ $overall_status -eq 1 ]]; then
            echo -e "${YELLOW}${BOLD}Overall Status: DEGRADED ⚠${NC}"
            echo -e "${YELLOW}System is operational but not optimal${NC}"
        else
            echo -e "${RED}${BOLD}Overall Status: UNHEALTHY ✗${NC}"
            echo -e "${RED}Critical issues detected - immediate attention required${NC}"
        fi
        echo ""
    fi
    
    exit $overall_status
}

main "$@"
