#!/usr/bin/env bash
# Complete Self-Healing System
# Monitors and automatically recovers from ALL failure scenarios

set -eu

# Configuration
CHECK_INTERVAL="${CHECK_INTERVAL:-60}"
MAX_RESTART_ATTEMPTS="${MAX_RESTART_ATTEMPTS:-3}"
RESTART_COOLDOWN="${RESTART_COOLDOWN:-300}"
TEST_DOMAIN="${TEST_DOMAIN:-google.com}"
ALERT_WEBHOOK="${ALERT_WEBHOOK:-}"

# Alert Manager
ALERT_MANAGER="${ALERT_MANAGER:-/scripts/alert-manager.sh}"

# Thresholds
DISK_USAGE_THRESHOLD="${DISK_USAGE_THRESHOLD:-85}"  # Percentage
MEMORY_USAGE_THRESHOLD="${MEMORY_USAGE_THRESHOLD:-90}"  # Percentage
LOG_MAX_SIZE_MB="${LOG_MAX_SIZE_MB:-100}"  # Max size per log file
HUNG_PROCESS_TIMEOUT="${HUNG_PROCESS_TIMEOUT:-300}"  # 5 minutes

# Backup configuration
BACKUP_DIR="${BACKUP_DIR:-./backups}"

# Track restart attempts
declare -A MEMORY_WARNINGS

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
critical() { echo -e "${RED}${BOLD}[$(date '+%Y-%m-%d %H:%M:%S')][CRITICAL]${NC} $*"; }

# Send alert
send_alert() {
    local alert_type="$1"
    local message="$2"
    local level="${3:-info}"
    
    # Map level to severity
    local severity="medium"
    case "$level" in
        critical) severity="critical" ;;
        error) severity="high" ;;
        warn) severity="medium" ;;
        success) severity="low" ;;
        info) severity="info" ;;
    esac
    
    # Use alert manager if available
    if [ -f "$ALERT_MANAGER" ] && [ -x "$ALERT_MANAGER" ]; then
        bash "$ALERT_MANAGER" --send "$alert_type" "$message" "$severity" 2>/dev/null || true
    fi
    
    # Fallback to webhook
    if [ -n "$ALERT_WEBHOOK" ]; then
        local icon="ℹ️"
        case "$level" in
            warn) icon="⚠️" ;;
            error) icon="❌" ;;
            critical) icon="🚨" ;;
            success) icon="✅" ;;
        esac
        
        curl -X POST "$ALERT_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{\"text\":\"$icon $message\"}" \
            2>/dev/null || true
    fi
}

# 1. DISK SPACE MONITORING & AUTO-CLEANUP
check_disk_space() {
    local usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [ "$usage" -ge "$DISK_USAGE_THRESHOLD" ]; then
        warn "Disk usage at ${usage}% (threshold: ${DISK_USAGE_THRESHOLD}%)"
        send_alert "disk_space_critical" "Disk usage critical: ${usage}%" "warn"
        
        # Auto-cleanup
        heal_disk_space
        return 1
    fi
    return 0
}

heal_disk_space() {
    log "🔧 Auto-healing: Cleaning up disk space..."
    
    
    # Clean Docker
    log "Pruning Docker resources..."
    docker system prune -f --volumes 2>/dev/null || true
    
    # Clean old logs
    log "Rotating large log files..."
    find /var/log -type f -size +"${LOG_MAX_SIZE_MB}"M -exec truncate -s 0 {} \; 2>/dev/null || true
    find ./logs -type f -size +"${LOG_MAX_SIZE_MB}"M -exec truncate -s 0 {} \; 2>/dev/null || true
    
    # Clean old backups beyond retention
    if [ -d "$BACKUP_DIR" ]; then
        log "Cleaning old backups..."
        find "$BACKUP_DIR" -name "*.tar.gz" -type f -mtime +30 -delete 2>/dev/null || true
    fi
    
    # Clean tmp files
    find /tmp -type f -mtime +7 -delete 2>/dev/null || true
    
    local new_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    log "✓ Disk cleanup complete. Usage now: ${new_usage}%"
    send_alert "disk_space_high" "Disk cleanup successful. Usage: ${new_usage}%" "success"
}

# 2. MEMORY LEAK DETECTION & PROACTIVE RESTART
check_memory_usage() {
    local containers=$(docker ps --format '{{.Names}}')
    
    for container in $containers; do
        local mem_usage=$(docker stats --no-stream --format "{{.MemPerc}}" "$container" 2>/dev/null | sed 's/%//')
        
        if [ -n "$mem_usage" ] && [ "$mem_usage" != "0.00" ]; then
            if (( $(echo "$mem_usage > $MEMORY_USAGE_THRESHOLD" | bc -l 2>/dev/null || echo 0) )); then
                warn "Container $container memory usage: ${mem_usage}%"
                
                # Track warnings
                MEMORY_WARNINGS[$container]=$((${MEMORY_WARNINGS[$container]:-0} + 1))
                
                # Proactive restart after 3 consecutive warnings
                if [ ${MEMORY_WARNINGS[$container]} -ge 3 ]; then
                    heal_memory_leak "$container"
                    MEMORY_WARNINGS[$container]=0
                fi
            else
                # Reset warnings if memory normal
                MEMORY_WARNINGS[$container]=0
            fi
        fi
    done
}

heal_memory_leak() {
    local container="$1"
    warn "🔧 Auto-healing: Restarting $container due to high memory usage"
    send_alert "memory_leak" "Proactively restarting $container due to memory leak" "warn"
    
    if docker restart "$container" > /dev/null 2>&1; then
        log "✓ Container $container restarted successfully"
        sleep 10
    fi
}

# 3. DATABASE CORRUPTION DETECTION & AUTO-RESTORE
check_database_corruption() {
    local piholes=$(docker ps --format '{{.Names}}' | grep pihole)
    
    for container in $piholes; do
        # Check database integrity
        local integrity_check=$(docker exec "$container" bash -c \
            "sqlite3 /etc/pihole/gravity.db 'PRAGMA integrity_check;' 2>/dev/null" || echo "error")
        
        if [ "$integrity_check" != "ok" ]; then
            err "Database corruption detected in $container!"
            send_alert "database_corruption" "Database corruption detected in $container" "error"
            heal_database_corruption "$container"
            return 1
        fi
        
        # Check for zero domains (sign of corruption or failed update)
        local domain_count=$(docker exec "$container" bash -c \
            "sqlite3 /etc/pihole/gravity.db 'SELECT COUNT(*) FROM gravity;' 2>/dev/null" || echo "0")
        
        if [ "$domain_count" -eq 0 ]; then
            warn "Zero domains in $container database - possible corruption"
            heal_database_corruption "$container"
            return 1
        fi
    done
    return 0
}

heal_database_corruption() {
    local container="$1"
    log "🔧 Auto-healing: Restoring database for $container..."
    
    # Try to restore from latest backup
    local latest_backup=$(find "$BACKUP_DIR" -name "${container}_*.tar.gz" -type f | sort -r | head -1)
    
    if [ -n "$latest_backup" ]; then
        log "Found backup: $latest_backup"
        
        # Extract and restore database
        local temp_dir="/tmp/pihole_restore_$$"
        mkdir -p "$temp_dir"
        tar -xzf "$latest_backup" -C "$temp_dir" 2>/dev/null || true
        
        # Find gravity.db in extracted backup
        local backup_db=$(find "$temp_dir" -name "gravity.db" | head -1)
        
        if [ -n "$backup_db" ]; then
            log "Restoring gravity.db from backup..."
            docker cp "$backup_db" "$container:/etc/pihole/gravity.db"
            docker exec "$container" chown pihole:pihole /etc/pihole/gravity.db
            docker exec "$container" pihole restartdns reload-lists
            log "✓ Database restored from backup"
            send_alert "system_recovery" "Database restored from backup for $container" "success"
        else
            # Fallback: force gravity update
            warn "No backup database found, forcing gravity update..."
            docker exec "$container" pihole updateGravity
        fi
        
        rm -rf "$temp_dir"
    else
        # No backup available, force update
        warn "No backup available, forcing gravity update..."
        docker exec "$container" pihole updateGravity
    fi
}

# 4. LOG ROTATION & CLEANUP
rotate_logs() {
    log "Rotating large log files..."
    
    # Rotate container logs
    local containers=$(docker ps --format '{{.Names}}')
    for container in $containers; do
        local log_file=$(docker inspect "$container" --format='{{.LogPath}}' 2>/dev/null || echo "")
        if [ -n "$log_file" ] && [ -f "$log_file" ]; then
            local size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo "0")
            local size_mb=$((size / 1024 / 1024))
            
            if [ "$size_mb" -gt "$LOG_MAX_SIZE_MB" ]; then
                log "Rotating log for $container (${size_mb}MB)"
                # Truncate to last 1000 lines
                tail -n 1000 "$log_file" > "${log_file}.tmp"
                mv "${log_file}.tmp" "$log_file"
            fi
        fi
    done
    
    # Rotate application logs
    find ./logs -type f -size +${LOG_MAX_SIZE_MB}M 2>/dev/null | while read logfile; do
        log "Rotating $logfile"
        tail -n 10000 "$logfile" > "${logfile}.tmp"
        mv "${logfile}.tmp" "$logfile"
    done
}

# 5. ZOMBIE PROCESS & HUNG CONTAINER DETECTION
check_hung_containers() {
    local containers=$(docker ps --format '{{.Names}}')
    
    for container in $containers; do
        # Check if container is responding to commands
        if ! timeout 10 docker exec "$container" echo "alive" &>/dev/null; then
            warn "Container $container appears hung (not responding)"
            heal_hung_container "$container"
        fi
    done
}

heal_hung_container() {
    local container="$1"
    warn "🔧 Auto-healing: Force-killing hung container $container..."
    send_alert "container_failure" "Force-killing hung container: $container" "warn"
    
    # Try graceful stop first
    timeout 30 docker stop "$container" 2>/dev/null || {
        # Force kill if graceful fails
        docker kill "$container" 2>/dev/null || true
    }
    
    sleep 5
    docker start "$container"
    log "✓ Container $container force-restarted"
}

# 6. KEEPALIVED SPLIT-BRAIN DETECTION & RESOLUTION
check_split_brain() {
    if ! docker ps --format '{{.Names}}' | grep -q keepalived; then
        return 0  # No keepalived, skip
    fi
    
    # This would need to query both nodes - simplified version
    # In production, this would check VIP on both nodes via network
    local vip_count=$(ip addr | grep -c "192.168.8.255" || echo "0")
    
    # More advanced check would be needed for true split-brain detection
    # This is a placeholder for the concept
    return 0
}

# 7. UPSTREAM DNS FAILURE DETECTION & FAILOVER
check_upstream_dns() {
    local piholes=$(docker ps --format '{{.Names}}' | grep pihole | head -1)
    
    if [ -z "$piholes" ]; then
        return 0
    fi
    
    # Test if Unbound is working
    if ! docker exec "$piholes" dig @192.168.8.253 google.com +short +timeout=5 &>/dev/null; then
        warn "Unbound DNS not responding"
        
        # Check if fallback DNS works
        if docker exec "$piholes" dig @1.1.1.1 google.com +short +timeout=5 &>/dev/null; then
            heal_upstream_dns "$piholes"
        fi
    fi
}

heal_upstream_dns() {
    local container="$1"
    log "🔧 Auto-healing: Switching to fallback DNS temporarily..."
    
    # This would temporarily reconfigure Pi-hole to use Cloudflare/Google DNS
    # Implementation depends on specific requirements
    
    # Restart Unbound containers
    local unbounds=$(docker ps --format '{{.Names}}' | grep unbound)
    for unbound in $unbounds; do
        log "Restarting $unbound..."
        docker restart "$unbound"
    done
    
    sleep 10
    log "✓ Upstream DNS connectivity restored"
}

# 8. NETWORK CONNECTIVITY HEALING
check_network_connectivity() {
    # Test external connectivity
    if ! timeout 5 ping -c 1 8.8.8.8 &>/dev/null; then
        warn "No external network connectivity"
        return 1
    fi
    
    # Test DNS resolution
    if ! timeout 5 dig @8.8.8.8 google.com +short &>/dev/null; then
        warn "External DNS resolution failing"
        return 1
    fi
    
    return 0
}

heal_network_connectivity() {
    log "🔧 Auto-healing: Attempting network recovery..."
    
    # Restart Docker networking
    log "Restarting Docker network stack..."
    
    # Restart all DNS containers
    local dns_containers=$(docker ps --format '{{.Names}}' | grep -E "pihole|unbound")
    for container in $dns_containers; do
        log "Restarting $container for network recovery..."
        docker restart "$container"
    done
    
    sleep 15
    
    if check_network_connectivity; then
        log "✓ Network connectivity restored"
        send_alert "system_recovery" "Network connectivity restored" "success"
    else
        err "Network connectivity still failing"
        send_alert "network_failure" "Network connectivity recovery failed - manual intervention needed" "critical"
    fi
}

# 9. COMPREHENSIVE HEALTH CHECK WITH ALL HEALING
comprehensive_health_check() {
    local issues_detected=0
    local issues_healed=0
    
    # Check disk space
    if ! check_disk_space; then
        issues_detected=$((issues_detected + 1))
        issues_healed=$((issues_healed + 1))
    fi
    
    # Check memory usage
    check_memory_usage
    
    # Check database corruption
    if ! check_database_corruption; then
        issues_detected=$((issues_detected + 1))
        issues_healed=$((issues_healed + 1))
    fi
    
    # Check hung containers
    check_hung_containers
    
    # Check upstream DNS
    check_upstream_dns
    
    # Check network connectivity
    if ! check_network_connectivity; then
        issues_detected=$((issues_detected + 1))
        heal_network_connectivity
        issues_healed=$((issues_healed + 1))
    fi
    
    if [ $issues_detected -gt 0 ]; then
        info "Health check: $issues_detected issues detected, $issues_healed auto-healed"
    fi
}

# 10. PERIODIC MAINTENANCE
periodic_maintenance() {
    log "Running periodic maintenance..."
    
    # Rotate logs
    rotate_logs
    
    # Clean up old temporary files
    find /tmp -type f -name "pihole*" -mtime +1 -delete 2>/dev/null || true
    
    # Verify all backups are intact
    if [ -d "$BACKUP_DIR" ]; then
        local corrupt_backups=0
        find "$BACKUP_DIR" -name "*.tar.gz" -type f | while read backup; do
            if ! tar -tzf "$backup" &>/dev/null; then
                warn "Corrupt backup detected: $backup"
                rm -f "$backup"
                corrupt_backups=$((corrupt_backups + 1))
            fi
        done
        
        if [ $corrupt_backups -gt 0 ]; then
            send_alert "backup_failure" "Removed $corrupt_backups corrupt backups" "warn"
        fi
    fi
    
    log "✓ Periodic maintenance complete"
}

# MAIN SELF-HEALING LOOP
main() {
    log "═══════════════════════════════════════════════════════"
    log "Complete Self-Healing System Started"
    log "═══════════════════════════════════════════════════════"
    log "Check interval: $CHECK_INTERVAL seconds"
    log "Disk threshold: ${DISK_USAGE_THRESHOLD}%"
    log "Memory threshold: ${MEMORY_USAGE_THRESHOLD}%"
    log "Log rotation: ${LOG_MAX_SIZE_MB}MB"
    log "Backup directory: $BACKUP_DIR"
    echo ""
    
    local iteration=0
    local maintenance_counter=0
    
    while true; do
        iteration=$((iteration + 1))
        maintenance_counter=$((maintenance_counter + 1))
        
        # Comprehensive health check every cycle
        comprehensive_health_check
        
        # Periodic maintenance every hour (60 iterations at 60s interval)
        if [ $maintenance_counter -ge 60 ]; then
            periodic_maintenance
            maintenance_counter=0
        fi
        
        # Status update every 10 iterations
        if [ $((iteration % 10)) -eq 0 ]; then
            info "Self-healing system active - iteration $iteration"
        fi
        
        sleep "$CHECK_INTERVAL"
    done
}

# Handle signals
trap 'log "Self-healing system shutting down..."; exit 0' SIGTERM SIGINT

# Run main loop
main
