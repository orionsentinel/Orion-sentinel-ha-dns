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
