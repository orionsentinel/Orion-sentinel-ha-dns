#!/bin/bash
# Health Check Script for RPi HA DNS Stack
# Run this weekly via cron to verify system health

set -e

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "=========================================="
echo "RPi HA DNS Stack Health Check"
echo "Time: $TIMESTAMP"
echo "=========================================="

# Test 1: DNS Resolution
echo ""
echo "Test 1: DNS Resolution"
if dig @192.168.8.255 google.com +short > /dev/null 2>&1; then
    echo "✅ DNS resolution working (VIP)"
else
    echo "❌ DNS resolution FAILED (VIP)"
    exit 1
fi

if dig @192.168.8.251 google.com +short > /dev/null 2>&1; then
    echo "✅ DNS resolution working (Primary Pi-hole)"
else
    echo "⚠️  Primary Pi-hole DNS FAILED"
fi

if dig @192.168.8.252 google.com +short > /dev/null 2>&1; then
    echo "✅ DNS resolution working (Secondary Pi-hole)"
else
    echo "⚠️  Secondary Pi-hole DNS FAILED"
fi

# Test 2: Service Health
echo ""
echo "Test 2: Service Health"
REQUIRED_SERVICES="pihole_primary pihole_secondary unbound_primary unbound_secondary keepalived prometheus grafana"

for service in $REQUIRED_SERVICES; do
    if docker ps --format '{{.Names}}' | grep -q "^${service}$"; then
        echo "✅ $service is running"
    else
        echo "❌ $service is NOT running"
    fi
done

# Test 3: HA Failover Check
echo ""
echo "Test 3: HA Status"
if docker exec keepalived sh -c 'cat /var/run/keepalived.pid' > /dev/null 2>&1; then
    echo "✅ Keepalived is active"
    VIP_STATUS=$(ip addr show | grep "192.168.8.255" || echo "not found")
    if [ "$VIP_STATUS" != "not found" ]; then
        echo "✅ VIP is active on this node"
    else
        echo "ℹ️  VIP is on the other node (normal for standby)"
    fi
else
    echo "❌ Keepalived check FAILED"
fi

# Test 4: Disk Space
echo ""
echo "Test 4: Disk Space"
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -lt 80 ]; then
    echo "✅ Disk usage: ${DISK_USAGE}%"
else
    echo "⚠️  Disk usage HIGH: ${DISK_USAGE}%"
fi

# Test 5: Memory Usage
echo ""
echo "Test 5: Memory Usage"
MEMORY_USAGE=$(free | awk 'NR==2 {printf "%.0f", $3/$2 * 100}')
if [ "$MEMORY_USAGE" -lt 85 ]; then
    echo "✅ Memory usage: ${MEMORY_USAGE}%"
else
    echo "⚠️  Memory usage HIGH: ${MEMORY_USAGE}%"
fi

# Test 6: Container Health
echo ""
echo "Test 6: Container Health Checks"
UNHEALTHY=$(docker ps --filter "health=unhealthy" --format '{{.Names}}')
if [ -z "$UNHEALTHY" ]; then
    echo "✅ All containers healthy"
else
    echo "❌ Unhealthy containers: $UNHEALTHY"
fi

# Test 7: Prometheus Metrics
echo ""
echo "Test 7: Prometheus Metrics"
if curl -s http://localhost:9090/-/healthy > /dev/null 2>&1; then
    echo "✅ Prometheus is healthy"
else
    echo "❌ Prometheus health check FAILED"
fi

# Test 8: Encrypted DNS Gateway (DoH/DoT) - Only if enabled
# Check if gateway is enabled via environment variable or running container
DOH_DOT_ENABLED="${ORION_DOH_DOT_GATEWAY_ENABLED:-0}"
GATEWAY_CONTAINER_RUNNING=false
if docker ps --format '{{.Names}}' | grep -q "orion-dns-gateway"; then
    DOH_DOT_ENABLED=1
    GATEWAY_CONTAINER_RUNNING=true
fi

# Configurable API port (default: 4000 as per docker-compose.yml)
DOH_API_PORT="${DOH_API_PORT:-4000}"

if [ "$DOH_DOT_ENABLED" = "1" ]; then
    echo ""
    echo "Test 8: Encrypted DNS Gateway (DoH/DoT)"
    
    # Check if gateway container is running
    if [ "$GATEWAY_CONTAINER_RUNNING" = "true" ]; then
        echo "✅ orion-dns-gateway container is running"
    else
        echo "❌ orion-dns-gateway container is NOT running"
    fi
    
    # Check DoH endpoint via API
    if curl -s "http://localhost:${DOH_API_PORT}/api/blocking/status" > /dev/null 2>&1; then
        echo "✅ DoH gateway API responding"
    else
        echo "❌ DoH gateway API not responding"
    fi
    
    # Check DoT port (853) connectivity
    if nc -z localhost 853 2>/dev/null; then
        echo "✅ DoT port 853 is open"
    else
        echo "⚠️  DoT port 853 not accessible (may need external check)"
    fi
    
    # Check DoH port (443) connectivity
    if nc -z localhost 443 2>/dev/null; then
        echo "✅ DoH port 443 is open"
    else
        echo "⚠️  DoH port 443 not accessible (may need external check)"
    fi
fi

# Summary
echo ""
echo "=========================================="
echo "Health Check Complete"
echo "=========================================="
echo ""
echo "To run this automatically:"
echo "  sudo crontab -e"
echo "  Add: 0 2 * * 0 /path/to/health-check.sh >> /var/log/rpi-dns-health-check.log 2>&1"
echo ""
