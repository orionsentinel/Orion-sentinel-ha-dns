# Health Checking and High Availability

Comprehensive guide to health checking and HA failover in Orion Sentinel DNS HA.

## Overview

The DNS HA stack implements multiple layers of health checking to ensure:
- **Service availability**: All DNS components are running and responding
- **Automatic failover**: Keepalived VIP fails over when primary node fails
- **Self-healing**: Unhealthy containers are automatically restarted
- **Monitoring visibility**: Health status exposed via metrics and HTTP endpoints

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Health Checking Layers                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. Docker Healthchecks                                    │
│     ├─ health_checker.py validates all services            │
│     ├─ Runs every 30s inside containers                    │
│     └─ Triggers container restart if unhealthy             │
│                                                             │
│  2. Keepalived Track Scripts                               │
│     ├─ Monitors critical services (Pi-hole, Unbound)       │
│     ├─ Adjusts VRRP priority based on health               │
│     └─ Triggers VIP failover if services fail              │
│                                                             │
│  3. HTTP Health Endpoint (optional)                         │
│     ├─ Exposes /health, /ready, /live endpoints            │
│     ├─ Used by external monitors and load balancers        │
│     └─ Returns JSON health status                          │
│                                                             │
│  4. Prometheus Metrics                                      │
│     ├─ Exporters collect service metrics                   │
│     ├─ Alertmanager fires alerts on failures               │
│     └─ Grafana visualizes health trends                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Health Check Components

### 1. health_checker.py

Python script that performs comprehensive health checks:

**Checks performed:**
- **Pi-hole API**: Verifies both primary and secondary instances are responding to API requests
- **Unbound DNS**: Tests DNS resolution through both Unbound instances
- **Keepalived VIP**: Confirms VIP is assigned and operational
- **Docker Containers**: Validates all critical containers are running
- **System Resources**: Monitors CPU, memory, and disk usage (optional)

**Exit codes:**
- `0` - Healthy: All checks passed
- `1` - Degraded: Some non-critical checks failed (e.g., secondary down)
- `2` - Unhealthy: Critical failure (e.g., VIP unavailable)

**Usage:**
```bash
# Run health check
python3 health/health_checker.py

# Get JSON output
python3 health/health_checker.py --format json

# Quiet mode (exit code only)
python3 health/health_checker.py --quiet
```

### 2. Docker Healthchecks

Docker's built-in healthcheck mechanism monitors container health:

**Configuration in docker-compose.yml:**
```yaml
services:
  pihole_primary:
    healthcheck:
      test: ["CMD", "dig", "@127.0.0.1", "google.com", "+short"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
```

**Behavior:**
- Container marked "healthy" or "unhealthy" based on test result
- After `retries` consecutive failures, container marked unhealthy
- Docker can automatically restart unhealthy containers
- Health status visible in `docker ps` output

### 3. Keepalived Track Scripts

Keepalived uses health check scripts to influence failover:

**Configuration in keepalived.conf:**
```conf
vrrp_script check_pihole {
    script "/opt/health/docker-healthcheck.sh"
    interval 10
    weight -20      # Decrease priority by 20 if check fails
    rise 2          # Require 2 successes to be UP
    fall 2          # Require 2 failures to be DOWN
}

vrrp_instance VI_1 {
    state MASTER
    interface eth0
    virtual_router_id 51
    priority 100
    
    track_script {
        check_pihole
    }
    
    # VIP configuration
    virtual_ipaddress {
        192.168.8.255/24
    }
}
```

**How it works:**
1. Track script runs every 10 seconds
2. If script fails, priority decreases by `weight` (20)
3. If priority drops below backup node, VIP fails over
4. When service recovers, priority restores and VIP can fail back

### 4. HTTP Health Endpoint

Optional HTTP service exposes health status via REST API:

**Start the service:**
```bash
python3 health/dns-health-service.py --port 8888
```

**Endpoints:**

| Endpoint | Purpose | Response | HTTP Code |
|----------|---------|----------|-----------|
| `/health` | Simple status | `{"status": "healthy"}` | 200 or 503 |
| `/health/detailed` | Full results | Complete check results | 200 or 503 |
| `/ready` | Readiness probe | `{"ready": true}` | 200 or 503 |
| `/live` | Liveness probe | `{"alive": true}` | 200 |

**Example:**
```bash
# Check overall health
curl http://localhost:8888/health

# Get detailed status
curl http://localhost:8888/health/detailed | jq
```

## HA Failover Behavior

### Normal Operation (Primary Active)

```
Pi #1 (Primary)                     Pi #2 (Secondary)
┌─────────────────┐                ┌─────────────────┐
│ Priority: 100   │                │ Priority: 90    │
│ VIP: ACTIVE     │                │ VIP: inactive   │
│ State: MASTER   │                │ State: BACKUP   │
└─────────────────┘                └─────────────────┘
        │                                   │
        └───────── VIP: 192.168.8.255 ─────┘
                          │
                   Clients use VIP
```

### Failover (Primary Fails)

```
Pi #1 (Primary)                     Pi #2 (Secondary)
┌─────────────────┐                ┌─────────────────┐
│ Priority: 80    │ ←── Service    │ Priority: 90    │
│ VIP: inactive   │     fails      │ VIP: ACTIVE     │
│ State: BACKUP   │                │ State: MASTER   │
└─────────────────┘                └─────────────────┘
                                            │
                                    VIP moves to Pi #2
                                            │
                                     Clients use VIP
```

**Failover triggers:**
1. Primary node hardware failure
2. Network disconnection
3. Critical service failure (Pi-hole/Unbound down)
4. Health check script failures

**Failover time:**
- Detection: 10-30 seconds (depends on check interval)
- Switchover: 1-3 seconds (VRRP advertisement interval)
- Total: ~15-35 seconds worst case

## Interpreting Health Status

### Healthy State
```
✅ pihole_primary: API OK (blocking 123456 domains, 45678 queries today)
✅ pihole_secondary: API OK (blocking 123456 domains, 45679 queries today)
✅ unbound_primary: DNS resolution OK (response: < 3s)
✅ unbound_secondary: DNS resolution OK (response: < 3s)
✅ keepalived_vip: VIP 192.168.8.255 is ACTIVE on this node (MASTER)
✅ container_pihole_primary: Container running and healthy
✅ container_pihole_secondary: Container running and healthy
✅ container_unbound_primary: Container running and healthy
✅ container_unbound_secondary: Container running and healthy
✅ container_keepalived: Container running and healthy
```

### Degraded State (Secondary Down)
```
✅ pihole_primary: API OK (blocking 123456 domains, 45678 queries today)
❌ pihole_secondary: Cannot connect to API
✅ unbound_primary: DNS resolution OK (response: < 3s)
✅ unbound_secondary: DNS resolution OK (response: < 3s)
✅ keepalived_vip: VIP 192.168.8.255 is ACTIVE on this node (MASTER)
```

**Interpretation**: System is functional but redundancy is reduced. DNS queries still work through primary instance.

**Action**: Investigate why secondary is down and restart it.

### Unhealthy State (VIP Lost)
```
✅ pihole_primary: API OK (blocking 123456 domains, 45678 queries today)
✅ pihole_secondary: API OK (blocking 123456 domains, 45679 queries today)
✅ unbound_primary: DNS resolution OK (response: < 3s)
✅ unbound_secondary: DNS resolution OK (response: < 3s)
❌ keepalived_vip: VIP check failed
```

**Interpretation**: Services are healthy but VIP is not assigned. Either:
1. This is the backup node (normal)
2. Keepalived failed (critical)
3. Network issue preventing VIP assignment

**Action**: Check `ip addr show` to verify VIP location and check Keepalived logs.

## Monitoring Integration

### Prometheus Alerts

Health checks feed into Prometheus alerting:

```yaml
# Alert if both Pi-hole instances are down
- alert: AllPiHolesDown
  expr: count(up{job=~"pihole.*"} == 0) == count(up{job=~"pihole.*"})
  for: 1m
  labels:
    severity: critical
  annotations:
    summary: "All Pi-hole instances are down!"
```

### Grafana Dashboards

Visualize health metrics in Grafana:
- Service uptime graphs
- Health check pass/fail rates
- Failover event timeline
- VIP assignment history

See [observability.md](observability.md) for dashboard details.

## Troubleshooting

### Health Check Failing but Service Works

**Symptoms**: Health checker reports failure, but manual tests succeed.

**Causes**:
- Timeout too short for slow Pi
- Network latency to VIP
- Credential issues (Pi-hole password incorrect)

**Solutions**:
```bash
# Run health check with debug output
python3 health/health_checker.py --format json | jq

# Test Pi-hole API manually
curl http://192.168.8.251/admin/api.php

# Test DNS resolution manually
dig @192.168.8.251 google.com
```

### Frequent Failovers

**Symptoms**: VIP bounces between nodes frequently.

**Causes**:
- Both nodes have similar priority (flapping)
- Network instability
- Resource exhaustion causing intermittent failures

**Solutions**:
```bash
# Check Keepalived logs
docker logs keepalived

# Increase failover thresholds in keepalived.conf
# rise 3   # Require 3 successes before UP
# fall 3   # Require 3 failures before DOWN

# Check system resources
free -h
df -h
top
```

### VIP Not Assigned to Either Node

**Symptoms**: Both nodes report VIP inactive.

**Causes**:
- Keepalived not running
- VRRP multicast blocked
- Configuration error

**Solutions**:
```bash
# Check Keepalived container
docker ps | grep keepalived

# Check VRRP multicast (should see 224.0.0.18)
tcpdump -i eth0 vrrp

# Verify configuration
docker exec keepalived cat /etc/keepalived/keepalived.conf
```

## Best Practices

1. **Set appropriate timeouts**: Balance between fast detection and false positives
2. **Monitor both nodes**: Even backup node should be monitored
3. **Test failover regularly**: Simulate failures monthly to verify failover works
4. **Keep logs**: Store health check results for trend analysis
5. **Alert on degraded state**: Don't wait for complete failure to act
6. **Document recovery procedures**: Have runbook ready for common issues

## See Also

- [Observability Guide](observability.md) - Monitoring and metrics
- [Backup and Migration](backup-and-migration.md) - Disaster recovery
- [Operational Runbook](../OPERATIONAL_RUNBOOK.md) - Day-to-day operations
