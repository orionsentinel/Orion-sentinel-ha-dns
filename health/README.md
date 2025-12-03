# Health Checking Module

Comprehensive health checking system for the Orion Sentinel DNS HA stack.

## Components

### 1. `orion-dns-ha-health.sh` ⭐ NEW

**Comprehensive Two-Pi HA health check wrapper** - The recommended tool for quick health status.

Features:
- **All-in-one health check**: Docker, containers, VIP ownership, DNS resolution, Keepalived
- **Multiple output formats**: Human-readable, JSON, quiet mode
- **Smart status codes**: Green (0), Yellow (1), Red (2) for automation
- **Node-aware**: Adapts checks based on NODE_ROLE (primary/secondary)

**Usage:**

```bash
# Run all checks with colored output
bash scripts/orion-dns-ha-health.sh

# Quiet mode (exit code only)
bash scripts/orion-dns-ha-health.sh --quiet

# JSON output for automation/monitoring
bash scripts/orion-dns-ha-health.sh --json
```

**Exit Codes:**
- `0` - GREEN: All systems healthy
- `1` - YELLOW: Degraded but operational (e.g., secondary down, monitoring issues)
- `2` - RED: Critical failure (VIP missing, DNS not resolving)

**What it checks:**
1. ✅ Docker daemon is running
2. ✅ DNS containers are running and healthy (Pi-hole, Unbound, Keepalived)
3. ✅ VIP ownership status (MASTER vs BACKUP)
4. ✅ DNS resolution via localhost and VIP
5. ✅ Keepalived process health and recent errors

**Example output:**
```
═══════════════════════════════════════════════════════════
  Orion DNS HA Health Check
═══════════════════════════════════════════════════════════

ℹ Node Role: primary
ℹ VIP Address: 192.168.8.249
ℹ Interface: eth0

1. Docker Service
✓ Docker daemon is running

2. DNS Containers
✓ pihole_primary is running and healthy
✓ unbound_primary is running and healthy
✓ keepalived is running and healthy

3. Virtual IP (VIP) Status
✓ VIP 192.168.8.249 is assigned to this node (eth0)
✓ Keepalived is in MASTER state

4. DNS Resolution
✓ Local DNS resolution working (127.0.0.1)
✓ VIP DNS resolution working (192.168.8.249)

5. Keepalived Health
✓ Keepalived process is running
✓ No recent errors in Keepalived logs

═══════════════════════════════════════════════════════════
  Summary
═══════════════════════════════════════════════════════════

  Passed:   11 checks
  Degraded: 0 checks
  Failed:   0 checks

Overall Status: HEALTHY ✓
```

---

### 2. `health_checker.py`

Python-based health checker that performs:
- **Pi-hole API checks**: Verifies both primary and secondary Pi-hole instances are responding
- **Unbound DNS checks**: Tests DNS resolution through both Unbound instances
- **Keepalived VIP status**: Confirms VIP assignment and failover status
- **Docker container health**: Monitors all critical containers
- **Resource checks**: (Future) Memory and disk usage monitoring

**Usage:**

```bash
# Run health check with text output
python3 health/health_checker.py

# Get JSON output for parsing
python3 health/health_checker.py --format json

# Quiet mode (exit code only)
python3 health/health_checker.py --quiet
```

**Exit Codes:**
- `0` - Healthy: All checks passed
- `1` - Degraded: Some non-critical checks failed (e.g., secondary instance down)
- `2` - Unhealthy: Critical checks failed (e.g., VIP unavailable)

### 2. `docker-healthcheck.sh`

Shell wrapper for use in Docker `HEALTHCHECK` directives. Calls `health_checker.py` and returns appropriate exit codes.

**Usage in docker-compose.yml:**

```yaml
services:
  dns-health:
    healthcheck:
      test: ["CMD", "/health/docker-healthcheck.sh"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

### 3. `dns-health-service.py` (Optional)

HTTP service that exposes health status via REST API. Useful for:
- External monitoring systems (Prometheus, Nagios, etc.)
- Load balancers
- Kubernetes health probes
- Remote monitoring dashboards

**Endpoints:**

| Endpoint | Description | HTTP 200 When |
|----------|-------------|---------------|
| `/health` | Simple status | System is healthy |
| `/health/detailed` | Full check results | System is healthy or degraded |
| `/ready` | Readiness probe | At least 1 Pi-hole + 1 Unbound working |
| `/live` | Liveness probe | Service is running |

**Usage:**

```bash
# Start the health service
python3 health/dns-health-service.py --port 8888

# Test it
curl http://localhost:8888/health
curl http://localhost:8888/health/detailed
```

**Docker Integration:**

Add to your `docker-compose.yml`:

```yaml
services:
  dns-health:
    build:
      context: .
      dockerfile: health/Dockerfile
    ports:
      - "8888:8888"
    environment:
      - PIHOLE_PRIMARY_IP=192.168.8.251
      - PIHOLE_SECONDARY_IP=192.168.8.252
      - UNBOUND_PRIMARY_IP=192.168.8.253
      - UNBOUND_SECONDARY_IP=192.168.8.254
      - VIP_ADDRESS=192.168.8.255
    networks:
      - dns_net
    restart: unless-stopped
```

## Configuration

The health checker reads configuration from environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `PIHOLE_PRIMARY_IP` | 192.168.8.251 | Primary Pi-hole IP address |
| `PIHOLE_SECONDARY_IP` | 192.168.8.252 | Secondary Pi-hole IP address |
| `UNBOUND_PRIMARY_IP` | 192.168.8.253 | Primary Unbound IP address |
| `UNBOUND_SECONDARY_IP` | 192.168.8.254 | Secondary Unbound IP address |
| `VIP_ADDRESS` | 192.168.8.255 | Keepalived VIP address |
| `PIHOLE_PASSWORD` | (empty) | Pi-hole API password (if needed) |

## Dependencies

**Python packages:**
- Python 3.7+
- `requests` (optional, for Pi-hole API checks)

**System tools:**
- `dig` (preferred) or `nslookup` for DNS testing
- `docker` CLI for container checks
- `ip` command for VIP status

## Integration with Keepalived

The health checker can be used in Keepalived's `track_script` to influence failover decisions:

```conf
vrrp_script check_dns_health {
    script "/opt/rpi-ha-dns-stack/health/docker-healthcheck.sh"
    interval 10
    weight -20
}

vrrp_instance VI_1 {
    track_script {
        check_dns_health
    }
}
```

## Monitoring Integration

### Prometheus Exporter

Create a simple exporter wrapper:

```python
# TODO: Example Prometheus exporter using health_checker
```

### Alertmanager Rules

Example alert based on health status:

```yaml
# TODO: Example Prometheus alert rules
```

## Troubleshooting

**Issue: "requests module not available"**
- Install: `pip3 install requests` or `apt install python3-requests`
- Health checker will work without it, but Pi-hole API checks will be skipped

**Issue: "dig: command not found"**
- Install: `apt install dnsutils`
- Health checker will fall back to `nslookup` if available

**Issue: Health check fails in Docker**
- Ensure the health checker script is accessible in the container
- Mount the `health/` directory: `-v ./health:/health`
- Check container logs: `docker logs <container>`

## See Also

- [docs/health-and-ha.md](../docs/health-and-ha.md) - Health checking and HA concepts
- [docs/observability.md](../docs/observability.md) - Monitoring and metrics
- [stacks/dns/docker-compose.yml](../stacks/dns/docker-compose.yml) - Docker healthcheck integration
