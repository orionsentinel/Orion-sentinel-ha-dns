#!/usr/bin/env bash
# Health Monitor and Auto-Recovery System
# Continuously monitors all services and automatically restarts failed ones
# Includes functional tests to verify services work properly

set -u

# Configuration
CHECK_INTERVAL="${CHECK_INTERVAL:-60}"  # Check every 60 seconds
MAX_RESTART_ATTEMPTS="${MAX_RESTART_ATTEMPTS:-3}"
RESTART_COOLDOWN="${RESTART_COOLDOWN:-300}"  # 5 minutes between restart attempts
TEST_DOMAIN="${TEST_DOMAIN:-google.com}"
ALERT_WEBHOOK="${ALERT_WEBHOOK:-}"  # Optional webhook for alerts

# Track restart attempts
declare -A RESTART_COUNTS
declare -A LAST_RESTART_TIME

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*"; }
info() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*"; }
warn() { echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')][WARN]${NC} $*"; }
err() { echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')][ERROR]${NC} $*"; }

# Send alert if webhook is configured
send_alert() {
    local message="$1"
    if [ -n "$ALERT_WEBHOOK" ]; then
        curl -X POST "$ALERT_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{\"text\":\"$message\"}" \
            2>/dev/null || true
    fi
}

# Check if container is running
is_container_running() {
    local container="$1"
    docker ps --format '{{.Names}}' | grep -q "^${container}$"
}

# Functional test: DNS resolution
test_dns_resolution() {
    local container="$1"
    local test_ip=""
    
    # Get container IP
    if [[ "$container" =~ pihole ]]; then
        test_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container" 2>/dev/null || echo "")
    else
        return 0  # Skip DNS test for non-Pi-hole containers
    fi
    
    if [ -z "$test_ip" ]; then
        return 1
    fi
    
    # Test DNS resolution
    if timeout 5 dig @${test_ip} ${TEST_DOMAIN} +short > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Functional test: Pi-hole status
test_pihole_status() {
    local container="$1"
    
    if ! [[ "$container" =~ pihole ]]; then
        return 0  # Skip for non-Pi-hole containers
    fi
    
    # Check if Pi-hole status command works
    if docker exec "$container" pihole status 2>/dev/null | grep -q "Pi-hole blocking is enabled"; then
        return 0
    else
        return 1
    fi
}

# Functional test: Database integrity
test_database_integrity() {
    local container="$1"
    
    if ! [[ "$container" =~ pihole ]]; then
        return 0  # Skip for non-Pi-hole containers
    fi
    
    # Check if gravity database is accessible and has data
    local domain_count=$(docker exec "$container" bash -c \
        "sqlite3 /etc/pihole/gravity.db 'SELECT COUNT(*) FROM gravity;' 2>/dev/null" || echo "0")
    
    if [ "$domain_count" -gt 0 ]; then
        return 0
    else
        return 1
    fi
}

# Functional test: Keepalived VIP
test_keepalived_vip() {
    local container="$1"
    
    if ! [[ "$container" =~ keepalived ]]; then
        return 0  # Skip for non-keepalived containers
    fi
    
    # Check if keepalived process is running
    if docker exec "$container" pgrep keepalived > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Comprehensive health check
check_container_health() {
    local container="$1"
    local health_status="healthy"
    local failed_tests=()
    
    # Test 1: Container running
    if ! is_container_running "$container"; then
        health_status="stopped"
        failed_tests+=("container_stopped")
        return 1
    fi
    
    # Test 2: DNS resolution (for Pi-hole containers)
    if [[ "$container" =~ pihole ]]; then
        if ! test_dns_resolution "$container"; then
            health_status="unhealthy"
            failed_tests+=("dns_resolution_failed")
        fi
        
        # Test 3: Pi-hole status
        if ! test_pihole_status "$container"; then
            health_status="unhealthy"
            failed_tests+=("pihole_status_failed")
        fi
        
        # Test 4: Database integrity
        if ! test_database_integrity "$container"; then
            health_status="unhealthy"
            failed_tests+=("database_integrity_failed")
        fi
    fi
    
    # Test 5: Keepalived VIP (for keepalived containers)
    if [[ "$container" =~ keepalived ]]; then
        if ! test_keepalived_vip "$container"; then
            health_status="unhealthy"
            failed_tests+=("keepalived_process_failed")
        fi
    fi
    
    # Report status
    if [ "$health_status" != "healthy" ]; then
        err "$container is $health_status"
        for test in "${failed_tests[@]}"; do
            err "  Failed test: $test"
        done
        return 1
    else
        return 0
    fi
}

# Restart container with cooldown and attempt tracking
restart_container() {
    local container="$1"
    local current_time=$(date +%s)
    
    # Initialize tracking if needed
    if [ -z "${RESTART_COUNTS[$container]:-}" ]; then
        RESTART_COUNTS[$container]=0
        LAST_RESTART_TIME[$container]=0
    fi
    
    # Check cooldown
    local time_since_last=$((current_time - ${LAST_RESTART_TIME[$container]}))
    if [ $time_since_last -lt $RESTART_COOLDOWN ]; then
        warn "Container $container is in cooldown period (${time_since_last}s < ${RESTART_COOLDOWN}s)"
        return 1
    fi
    
    # Check max attempts
    if [ ${RESTART_COUNTS[$container]} -ge $MAX_RESTART_ATTEMPTS ]; then
        err "Container $container has reached maximum restart attempts (${RESTART_COUNTS[$container]})"
        send_alert "⚠️ Container $container has failed ${RESTART_COUNTS[$container]} times and will not be restarted automatically"
        return 1
    fi
    
    # Attempt restart
    warn "Attempting to restart $container (attempt $((${RESTART_COUNTS[$container]} + 1))/$MAX_RESTART_ATTEMPTS)..."
    
    if docker restart "$container" > /dev/null 2>&1; then
        RESTART_COUNTS[$container]=$((${RESTART_COUNTS[$container]} + 1))
        LAST_RESTART_TIME[$container]=$current_time
        log "✓ Container $container restarted successfully"
        send_alert "✅ Container $container was automatically restarted"
        
        # Wait for container to stabilize
        sleep 10
        
        # Verify restart was successful
        if check_container_health "$container"; then
            log "✓ Container $container is now healthy after restart"
            # Reset restart count on successful recovery
            RESTART_COUNTS[$container]=0
            return 0
        else
            err "Container $container still unhealthy after restart"
            return 1
        fi
    else
        err "Failed to restart container $container"
        return 1
    fi
}

# Monitor single container
monitor_container() {
    local container="$1"
    
    if ! check_container_health "$container"; then
        warn "Container $container is unhealthy, attempting recovery..."
        
        if restart_container "$container"; then
            log "✓ Container $container recovered successfully"
        else
            err "Failed to recover container $container"
        fi
    else
        # Container is healthy
        if [ "${RESTART_COUNTS[$container]:-0}" -gt 0 ]; then
            # Reset counter if container has been healthy for a while
            local time_since_last=$(($(date +%s) - ${LAST_RESTART_TIME[$container]:-0}))
            if [ $time_since_last -gt $((RESTART_COOLDOWN * 2)) ]; then
                RESTART_COUNTS[$container]=0
                info "Reset restart counter for $container (healthy for $((time_since_last / 60)) minutes)"
            fi
        fi
    fi
}

# Get all monitored containers
get_monitored_containers() {
    # Get all running containers except this health monitor
    docker ps --format '{{.Names}}' | grep -v "health-monitor" || true
}

# Show health dashboard
show_health_dashboard() {
    echo ""
    log "========================================="
    log "Health Monitor Dashboard"
    log "========================================="
    
    local all_containers=$(get_monitored_containers)
    local healthy_count=0
    local unhealthy_count=0
    local stopped_count=0
    
    for container in $all_containers; do
        if is_container_running "$container"; then
            if check_container_health "$container" 2>/dev/null; then
                echo -e "${GREEN}✓${NC} $container: healthy"
                healthy_count=$((healthy_count + 1))
            else
                echo -e "${YELLOW}⚠${NC} $container: unhealthy (restarts: ${RESTART_COUNTS[$container]:-0})"
                unhealthy_count=$((unhealthy_count + 1))
            fi
        else
            echo -e "${RED}✗${NC} $container: stopped"
            stopped_count=$((stopped_count + 1))
        fi
    done
    
    echo ""
    info "Summary: $healthy_count healthy, $unhealthy_count unhealthy, $stopped_count stopped"
    log "========================================="
    echo ""
}

# Run functional test suite
run_functional_tests() {
    log "Running functional test suite..."
    
    local tests_passed=0
    local tests_failed=0
    
    # Test DNS resolution via VIP
    if timeout 5 dig @192.168.8.255 ${TEST_DOMAIN} +short > /dev/null 2>&1; then
        log "✓ DNS resolution via VIP: PASS"
        tests_passed=$((tests_passed + 1))
    else
        err "✗ DNS resolution via VIP: FAIL"
        tests_failed=$((tests_failed + 1))
    fi
    
    # Test blocklist count
    local piholes
    piholes=$(docker ps --format '{{.Names}}' | grep pihole | head -1)
    if [ -n "$piholes" ]; then
        local domain_count=$(docker exec "$piholes" bash -c \
            "sqlite3 /etc/pihole/gravity.db 'SELECT COUNT(*) FROM gravity;' 2>/dev/null" || echo "0")
        
        if [ "$domain_count" -gt 100000 ]; then
            log "✓ Blocklist count ($domain_count domains): PASS"
            tests_passed=$((tests_passed + 1))
        else
            warn "⚠ Blocklist count ($domain_count domains): LOW"
            tests_failed=$((tests_failed + 1))
        fi
    fi
    
    info "Functional tests: $tests_passed passed, $tests_failed failed"
}

# Main monitoring loop
main() {
    log "Health Monitor and Auto-Recovery System started"
    log "Check interval: $CHECK_INTERVAL seconds"
    log "Max restart attempts: $MAX_RESTART_ATTEMPTS"
    log "Restart cooldown: $RESTART_COOLDOWN seconds"
    log "Test domain: $TEST_DOMAIN"
    echo ""
    
    # Initial functional test
    run_functional_tests
    
    local iteration=0
    
    while true; do
        iteration=$((iteration + 1))
        
        # Show dashboard periodically
        if [ $((iteration % 10)) -eq 0 ]; then
            show_health_dashboard
        fi
        
        # Monitor all containers
        for container in $(get_monitored_containers); do
            monitor_container "$container"
        done
        
        # Run functional tests periodically
        if [ $((iteration % 30)) -eq 0 ]; then
            run_functional_tests
        fi
        
        sleep "$CHECK_INTERVAL"
    done
}

# Handle signals
trap 'log "Health monitor shutting down..."; exit 0' SIGTERM SIGINT

# Run main loop
main
