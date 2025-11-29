#!/usr/bin/env bash
# Self-Healing Service for Orion Sentinel DNS HA
# Monitors and automatically recovers failing services
#
# Features:
# - Continuous health monitoring
# - Automatic service restart on failure
# - Cascading failure detection
# - Circuit breaker pattern for external dependencies
# - Notification on failures and recoveries
# - Metrics collection for observability
#
# Usage:
#   ./self-heal.sh [options]
#
# Options:
#   --daemon        Run as background daemon
#   --once          Run health check once and exit
#   --status        Show service status
#   --restart <svc> Restart a specific service
#   -h, --help      Show this help message

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load configuration
if [ -f "$REPO_ROOT/.env" ]; then
    # shellcheck disable=SC1091
    source "$REPO_ROOT/.env"
fi

# Configuration with defaults
CHECK_INTERVAL="${HEALTH_CHECK_INTERVAL:-60}"
MAX_RESTART_ATTEMPTS="${MAX_RESTART_ATTEMPTS:-3}"
RESTART_COOLDOWN="${RESTART_COOLDOWN:-300}"
CIRCUIT_BREAKER_THRESHOLD="${CIRCUIT_BREAKER_THRESHOLD:-5}"
CIRCUIT_BREAKER_TIMEOUT="${CIRCUIT_BREAKER_TIMEOUT:-300}"
LOG_DIR="${LOG_DIR:-$REPO_ROOT/logs}"
LOG_FILE="${LOG_DIR}/self-heal.log"
METRICS_FILE="${LOG_DIR}/self-heal-metrics.json"
STATE_FILE="${LOG_DIR}/self-heal-state.json"
VIP_ADDRESS="${VIP_ADDRESS:-192.168.8.255}"
TEST_DOMAIN="${TEST_DOMAIN:-google.com}"
NOTIFICATION_WEBHOOK="${NOTIFICATION_WEBHOOK:-}"
NOTIFICATION_SIGNAL="${NOTIFICATION_SIGNAL:-false}"

# Services to monitor
MONITORED_SERVICES=(
    "pihole_primary"
    "pihole_secondary"
    "unbound_primary"
    "unbound_secondary"
    "keepalived"
)

# State tracking
declare -A SERVICE_FAILURES
declare -A SERVICE_LAST_RESTART
declare -A CIRCUIT_BREAKER_STATE

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Initialize state
init_state() {
    for service in "${MONITORED_SERVICES[@]}"; do
        SERVICE_FAILURES[$service]=0
        SERVICE_LAST_RESTART[$service]=0
        CIRCUIT_BREAKER_STATE[$service]="closed"
    done
    
    # Load persisted state if exists
    if [ -f "$STATE_FILE" ]; then
        log_debug "Loading persisted state from $STATE_FILE"
        # In a production system, you'd parse the JSON here
    fi
}

# Save state to disk
save_state() {
    local timestamp
    timestamp=$(date -Iseconds)
    
    cat > "$STATE_FILE" <<EOF
{
    "timestamp": "$timestamp",
    "services": {
$(for service in "${MONITORED_SERVICES[@]}"; do
    echo "        \"$service\": {"
    echo "            \"failures\": ${SERVICE_FAILURES[$service]:-0},"
    echo "            \"last_restart\": ${SERVICE_LAST_RESTART[$service]:-0},"
    echo "            \"circuit_breaker\": \"${CIRCUIT_BREAKER_STATE[$service]:-closed}\""
    echo "        }$([ "$service" != "${MONITORED_SERVICES[-1]}" ] && echo ",")"
done)
    }
}
EOF
}

# Logging functions
log() { 
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $*"
    echo -e "${GREEN}${msg}${NC}"
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

log_warn() { 
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $*"
    echo -e "${YELLOW}${msg}${NC}"
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

log_error() { 
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*"
    echo -e "${RED}${msg}${NC}" >&2
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

log_debug() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [DEBUG] $*"
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

# Show usage information
usage() {
    cat <<EOF
Usage: $0 [options]

Self-Healing Service for Orion Sentinel DNS HA
Monitors and automatically recovers failing services.

Options:
    --daemon        Run as background daemon
    --once          Run health check once and exit
    --status        Show service status
    --restart <svc> Restart a specific service
    --reset         Reset failure counters and circuit breakers
    -h, --help      Show this help message

Environment Variables:
    HEALTH_CHECK_INTERVAL      Seconds between health checks (default: 60)
    MAX_RESTART_ATTEMPTS       Max restart attempts before circuit breaker (default: 3)
    RESTART_COOLDOWN           Seconds between restart attempts (default: 300)
    CIRCUIT_BREAKER_TIMEOUT    Seconds before circuit breaker resets (default: 300)
    NOTIFICATION_WEBHOOK       Webhook URL for notifications
    NOTIFICATION_SIGNAL        Enable Signal notifications (true/false)

Examples:
    # Run as daemon
    $0 --daemon
    
    # Check health once
    $0 --once
    
    # Show current status
    $0 --status

EOF
    exit 0
}

# Send notification
send_notification() {
    local severity="$1"
    local message="$2"
    
    log_debug "Sending notification: [$severity] $message"
    
    # Send webhook notification if configured
    if [ -n "$NOTIFICATION_WEBHOOK" ]; then
        curl -s -X POST "$NOTIFICATION_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{\"severity\": \"$severity\", \"message\": \"$message\", \"hostname\": \"$(hostname)\", \"timestamp\": \"$(date -Iseconds)\"}" \
            > /dev/null 2>&1 || log_warn "Failed to send webhook notification"
    fi
    
    # Send Signal notification if enabled
    if [ "$NOTIFICATION_SIGNAL" = "true" ]; then
        local signal_api="${SIGNAL_API_URL:-http://localhost:8080}"
        local emoji=""
        case "$severity" in
            critical) emoji="🚨" ;;
            warning) emoji="⚠️" ;;
            info) emoji="ℹ️" ;;
            recovery) emoji="✅" ;;
        esac
        
        curl -s -X POST "$signal_api/test" \
            -H "Content-Type: application/json" \
            -d "{\"message\": \"$emoji [$severity] $message\"}" \
            > /dev/null 2>&1 || log_warn "Failed to send Signal notification"
    fi
}

# Check if Docker container is healthy
check_container_health() {
    local container="$1"
    
    # Check if container exists and is running
    if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${container}$"; then
        return 1
    fi
    
    # Check Docker healthcheck status if available
    local health_status
    health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none")
    
    case "$health_status" in
        healthy)
            return 0
            ;;
        unhealthy)
            return 1
            ;;
        none|starting)
            # No healthcheck defined or still starting, check if running
            local state
            state=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "unknown")
            [ "$state" = "running" ] && return 0 || return 1
            ;;
        *)
            return 1
            ;;
    esac
}

# Check DNS resolution
check_dns_resolution() {
    local dns_server="${1:-$VIP_ADDRESS}"
    
    # Try dig first, then nslookup
    if command -v dig &> /dev/null; then
        dig "@${dns_server}" "$TEST_DOMAIN" +short +time=3 +tries=1 &> /dev/null
        return $?
    elif command -v nslookup &> /dev/null; then
        nslookup "$TEST_DOMAIN" "$dns_server" &> /dev/null
        return $?
    else
        log_warn "Neither dig nor nslookup available, skipping DNS check"
        return 0
    fi
}

# Check VIP availability
check_vip() {
    # Check if VIP is assigned locally
    if ip addr show 2>/dev/null | grep -q "$VIP_ADDRESS"; then
        log_debug "VIP $VIP_ADDRESS is active on this node (MASTER)"
        return 0
    else
        log_debug "VIP $VIP_ADDRESS is not on this node (BACKUP or not configured)"
        return 0  # Not having VIP is normal for backup node
    fi
}

# Check circuit breaker state
is_circuit_open() {
    local service="$1"
    local state="${CIRCUIT_BREAKER_STATE[$service]:-closed}"
    
    if [ "$state" = "open" ]; then
        local last_failure="${SERVICE_LAST_RESTART[$service]:-0}"
        local current_time
        current_time=$(date +%s)
        local elapsed=$((current_time - last_failure))
        
        if [ $elapsed -ge "$CIRCUIT_BREAKER_TIMEOUT" ]; then
            log "Circuit breaker for $service reset (half-open state)"
            CIRCUIT_BREAKER_STATE[$service]="half-open"
            return 1
        fi
        
        log_debug "Circuit breaker for $service is OPEN (${elapsed}s / ${CIRCUIT_BREAKER_TIMEOUT}s)"
        return 0
    fi
    
    return 1
}

# Open circuit breaker
open_circuit() {
    local service="$1"
    CIRCUIT_BREAKER_STATE[$service]="open"
    log_error "Circuit breaker OPENED for $service - too many failures"
    send_notification "critical" "Circuit breaker opened for $service - manual intervention required"
}

# Close circuit breaker
close_circuit() {
    local service="$1"
    if [ "${CIRCUIT_BREAKER_STATE[$service]:-closed}" != "closed" ]; then
        CIRCUIT_BREAKER_STATE[$service]="closed"
        SERVICE_FAILURES[$service]=0
        log "Circuit breaker CLOSED for $service - service recovered"
        send_notification "recovery" "Service $service has recovered, circuit breaker closed"
    fi
}

# Restart a service
restart_service() {
    local service="$1"
    local current_time
    current_time=$(date +%s)
    
    # Check cooldown
    local last_restart="${SERVICE_LAST_RESTART[$service]:-0}"
    local elapsed=$((current_time - last_restart))
    
    if [ $elapsed -lt "$RESTART_COOLDOWN" ]; then
        log_debug "Service $service in cooldown (${elapsed}s / ${RESTART_COOLDOWN}s)"
        return 1
    fi
    
    # Check circuit breaker
    if is_circuit_open "$service"; then
        log_warn "Circuit breaker is open for $service, not restarting"
        return 1
    fi
    
    log "Attempting to restart $service..."
    
    # Increment failure count
    SERVICE_FAILURES[$service]=$((${SERVICE_FAILURES[$service]:-0} + 1))
    SERVICE_LAST_RESTART[$service]=$current_time
    
    # Check if we've hit the failure threshold
    if [ "${SERVICE_FAILURES[$service]}" -ge "$MAX_RESTART_ATTEMPTS" ]; then
        open_circuit "$service"
        return 1
    fi
    
    # Attempt restart
    if docker restart "$service" &> /dev/null; then
        log "Service $service restarted successfully (attempt ${SERVICE_FAILURES[$service]}/$MAX_RESTART_ATTEMPTS)"
        send_notification "warning" "Service $service was restarted (attempt ${SERVICE_FAILURES[$service]}/$MAX_RESTART_ATTEMPTS)"
        
        # Wait for service to be healthy
        sleep 10
        
        if check_container_health "$service"; then
            close_circuit "$service"
            return 0
        else
            log_warn "Service $service still unhealthy after restart"
            return 1
        fi
    else
        log_error "Failed to restart service $service"
        return 1
    fi
}

# Perform health check on all services
perform_health_check() {
    local overall_healthy=true
    local timestamp
    timestamp=$(date -Iseconds)
    
    log "Performing health check..."
    
    # Check each monitored service
    for service in "${MONITORED_SERVICES[@]}"; do
        if check_container_health "$service"; then
            log_debug "Service $service is healthy"
            close_circuit "$service"
        else
            log_warn "Service $service is unhealthy"
            overall_healthy=false
            
            # Skip if circuit is open
            if is_circuit_open "$service"; then
                continue
            fi
            
            # Attempt restart
            restart_service "$service"
        fi
    done
    
    # Check DNS resolution through VIP
    if check_dns_resolution "$VIP_ADDRESS"; then
        log_debug "DNS resolution through VIP is working"
    else
        log_warn "DNS resolution through VIP failed"
        overall_healthy=false
        
        # Try individual DNS servers
        for dns in "192.168.8.251" "192.168.8.252"; do
            if check_dns_resolution "$dns"; then
                log_debug "DNS resolution through $dns is working"
                break
            fi
        done
    fi
    
    # Check VIP status
    check_vip
    
    # Update metrics
    update_metrics "$overall_healthy"
    
    # Save state
    save_state
    
    if [ "$overall_healthy" = true ]; then
        log "Health check completed - all services healthy"
    else
        log_warn "Health check completed - some services unhealthy"
    fi
}

# Update metrics file
update_metrics() {
    local healthy="$1"
    local timestamp
    timestamp=$(date -Iseconds)
    
    cat > "$METRICS_FILE" <<EOF
{
    "timestamp": "$timestamp",
    "overall_healthy": $healthy,
    "services": {
$(for service in "${MONITORED_SERVICES[@]}"; do
    local is_healthy=false
    check_container_health "$service" && is_healthy=true
    echo "        \"$service\": {"
    echo "            \"healthy\": $is_healthy,"
    echo "            \"failure_count\": ${SERVICE_FAILURES[$service]:-0},"
    echo "            \"circuit_breaker\": \"${CIRCUIT_BREAKER_STATE[$service]:-closed}\""
    echo "        }$([ "$service" != "${MONITORED_SERVICES[-1]}" ] && echo ",")"
done)
    },
    "dns_resolution": $(check_dns_resolution "$VIP_ADDRESS" && echo "true" || echo "false"),
    "vip_active": $(ip addr show 2>/dev/null | grep -q "$VIP_ADDRESS" && echo "true" || echo "false"),
    "uptime_seconds": $(cat /proc/uptime | cut -d' ' -f1 | cut -d'.' -f1)
}
EOF
}

# Show current status
show_status() {
    echo ""
    echo "═══════════════════════════════════════════════════"
    echo "  Orion Sentinel DNS HA - Service Status"
    echo "═══════════════════════════════════════════════════"
    echo ""
    
    echo "Container Status:"
    echo "-----------------"
    for service in "${MONITORED_SERVICES[@]}"; do
        if check_container_health "$service"; then
            echo -e "  ${GREEN}✅ $service${NC}"
        else
            echo -e "  ${RED}❌ $service${NC}"
        fi
    done
    
    echo ""
    echo "DNS Resolution:"
    echo "---------------"
    if check_dns_resolution "$VIP_ADDRESS"; then
        echo -e "  ${GREEN}✅ VIP ($VIP_ADDRESS)${NC}"
    else
        echo -e "  ${RED}❌ VIP ($VIP_ADDRESS)${NC}"
    fi
    
    for dns in "192.168.8.251" "192.168.8.252"; do
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "pihole"; then
            if check_dns_resolution "$dns"; then
                echo -e "  ${GREEN}✅ $dns${NC}"
            else
                echo -e "  ${RED}❌ $dns${NC}"
            fi
        fi
    done
    
    echo ""
    echo "VIP Status:"
    echo "-----------"
    if ip addr show 2>/dev/null | grep -q "$VIP_ADDRESS"; then
        echo -e "  ${GREEN}✅ VIP is active on this node (MASTER)${NC}"
    else
        echo -e "  ${BLUE}ℹ️  VIP is on peer node (BACKUP)${NC}"
    fi
    
    echo ""
    echo "Circuit Breakers:"
    echo "-----------------"
    for service in "${MONITORED_SERVICES[@]}"; do
        local state="${CIRCUIT_BREAKER_STATE[$service]:-closed}"
        local failures="${SERVICE_FAILURES[$service]:-0}"
        
        case "$state" in
            closed)
                echo -e "  ${GREEN}🔒 $service: CLOSED (failures: $failures)${NC}"
                ;;
            half-open)
                echo -e "  ${YELLOW}🔓 $service: HALF-OPEN (failures: $failures)${NC}"
                ;;
            open)
                echo -e "  ${RED}🔴 $service: OPEN (failures: $failures)${NC}"
                ;;
        esac
    done
    
    echo ""
    
    # Show last health check if metrics file exists
    if [ -f "$METRICS_FILE" ]; then
        local last_check
        last_check=$(grep '"timestamp"' "$METRICS_FILE" 2>/dev/null | head -1 | cut -d'"' -f4)
        echo "Last health check: $last_check"
    fi
    
    echo ""
}

# Reset all circuit breakers and failure counts
reset_state() {
    log "Resetting all circuit breakers and failure counts..."
    
    for service in "${MONITORED_SERVICES[@]}"; do
        SERVICE_FAILURES[$service]=0
        SERVICE_LAST_RESTART[$service]=0
        CIRCUIT_BREAKER_STATE[$service]="closed"
    done
    
    save_state
    log "State reset complete"
}

# Run as daemon
run_daemon() {
    log "Starting self-healing daemon (interval: ${CHECK_INTERVAL}s)"
    send_notification "info" "Self-healing daemon started on $(hostname)"
    
    while true; do
        perform_health_check
        sleep "$CHECK_INTERVAL"
    done
}

# Main function
main() {
    local action="daemon"
    local target_service=""
    
    # Create log directory
    mkdir -p "$LOG_DIR"
    
    # Initialize state
    init_state
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --daemon)
                action="daemon"
                shift
                ;;
            --once)
                action="once"
                shift
                ;;
            --status)
                action="status"
                shift
                ;;
            --restart)
                action="restart"
                target_service="${2:-}"
                shift 2
                ;;
            --reset)
                action="reset"
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                echo "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    case "$action" in
        daemon)
            run_daemon
            ;;
        once)
            perform_health_check
            ;;
        status)
            show_status
            ;;
        restart)
            if [ -z "$target_service" ]; then
                log_error "No service specified for restart"
                exit 1
            fi
            restart_service "$target_service"
            ;;
        reset)
            reset_state
            ;;
    esac
}

main "$@"
