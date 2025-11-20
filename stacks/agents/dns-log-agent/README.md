# DNS Log Agent

Ships DNS logs from Pi-hole and Unbound to Security Pi's Loki for centralized analysis.

## Overview

This agent forwards DNS query logs to the **Orion Sentinel NSM AI** stack running on Security Pi (Pi #2) for:

- Security analysis and threat detection
- Domain risk scoring with AI
- Correlation with IDS alerts (Suricata)
- Long-term log retention and search

## Architecture

```
DNS Pi (192.168.8.250)                Security Pi (192.168.8.100)
┌────────────────────────┐           ┌─────────────────────────┐
│  Pi-hole Logs          │           │                         │
│  Unbound Logs          │           │  Loki (Log Storage)     │
│  Keepalived Logs       │           │  Grafana (Visualization)│
│                        │           │  AI Analyzer            │
│         ↓              │           │                         │
│  ┌──────────────┐      │           │                         │
│  │  Promtail    │──────┼──────────▶│  :3100/loki/api/v1/push │
│  └──────────────┘      │  HTTP     │                         │
│  (Log Shipper)         │           │                         │
└────────────────────────┘           └─────────────────────────┘
```

## Quick Start

### Prerequisites

1. **Security Pi** must be running with Loki accessible
2. Verify Loki is accessible:
   ```bash
   curl http://192.168.8.100:3100/ready
   ```

### Deploy Log Agent

```bash
cd /opt/rpi-ha-dns-stack

# Configure Loki URL if different from default
nano stacks/agents/dns-log-agent/promtail.yml
# Edit the `clients` section with correct Loki URL

# Start log agent
docker compose -f stacks/agents/dns-log-agent/docker-compose.yml up -d

# Verify agent is running
docker ps | grep dns-log-agent

# Check Promtail logs
docker logs dns-log-agent
```

### Verify Log Shipping

On Security Pi, check if logs are arriving:

```bash
# Query Loki for DNS logs
curl -G -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={job="pihole"}' | jq

# Or in Grafana Explore:
# {job="pihole"} |= "query"
```

## Configuration

### Promtail Configuration

Edit `promtail.yml` to customize log collection:

```yaml
clients:
  - url: http://192.168.8.100:3100/loki/api/v1/push
    # Optional: Add authentication
    # basic_auth:
    #   username: user
    #   password: pass

scrape_configs:
  # Pi-hole logs
  - job_name: pihole-primary
    static_configs:
      - targets: [localhost]
        labels:
          job: pihole
          instance: primary
          __path__: /var/log/pihole/primary/*.log

  # Add custom log sources
  - job_name: custom-logs
    static_configs:
      - targets: [localhost]
        labels:
          job: custom
          __path__: /var/log/custom/*.log
```

### Environment Variables

Set in `.env` file or docker-compose.yml:

```bash
# Loki endpoint (Security Pi)
LOKI_URL=http://192.168.8.100:3100

# Alternative: Using VPN
# LOKI_URL=http://10.0.0.2:3100
```

### Log Paths

Default log paths (configure in docker-compose.yml volumes):

```yaml
volumes:
  # Pi-hole logs
  - pihole-primary-logs:/var/log/pihole/primary:ro
  - pihole-secondary-logs:/var/log/pihole/secondary:ro
  
  # Unbound logs (if file logging enabled)
  - unbound-primary-logs:/var/log/unbound/primary:ro
  - unbound-secondary-logs:/var/log/unbound/secondary:ro
  
  # System logs
  - /var/log:/var/log:ro
```

## Log Sources

### Pi-hole Logs

**Query logs** contain:
- Client IP
- Query domain
- Query type (A, AAAA, etc.)
- Response status
- Timestamp

**Example entry:**
```
Nov 19 15:30:45 pihole dnsmasq[1234]: query[A] example.com from 192.168.8.10
Nov 19 15:30:45 pihole dnsmasq[1234]: cached example.com is 93.184.216.34
```

### Unbound Logs

**Query logs** (if enabled in unbound.conf):
- Query domain
- Query type
- Client IP
- Response time
- Cache hit/miss

**Example entry:**
```
[1700409045] unbound[5678]: query: example.com. A IN
[1700409045] unbound[5678]: reply: example.com. 300 IN A 93.184.216.34
```

### Keepalived Logs

**VRRP state changes**:
- Transition to MASTER/BACKUP
- VIP assignment/removal
- Health check failures

**Example entry:**
```
Nov 19 15:30:50 dns-pi Keepalived_vrrp[910]: VRRP_Instance(VI_1) Transition to MASTER STATE
```

## Labels and Filtering

Promtail adds labels for log organization:

```yaml
labels:
  job: pihole|unbound|keepalived|system
  instance: primary|secondary
  component: dns-blocker|dns-resolver|ha-manager|os
```

**Query examples in Grafana:**

```logql
# All Pi-hole logs
{job="pihole"}

# Only primary Pi-hole
{job="pihole", instance="primary"}

# DNS queries containing "malware"
{job="pihole"} |= "malware"

# Keepalived state changes
{job="keepalived"} |= "Transition to"

# Failed DNS queries
{job="unbound"} |= "SERVFAIL"
```

## Integration with Security Pi

### Grafana Dashboards

Create dashboards on Security Pi combining DNS + IDS logs:

**Example panel: DNS queries to suspicious domains**
```logql
{job="pihole"} |= "blocked"
  | logfmt
  | line_format "{{.domain}} from {{.client}}"
```

### AI Analysis

Security Pi AI can analyze DNS logs for:
- Malicious domain detection
- DGA (Domain Generation Algorithm) detection
- DNS tunneling detection
- Anomalous query patterns

### Correlation with IDS

Correlate DNS logs with Suricata IDS alerts:

```logql
# Find DNS queries before IDS alert
{job="pihole"} 
  | json 
  | client_ip="192.168.8.50"
  | __timestamp__ < alert_time
```

## Troubleshooting

### Logs Not Appearing in Loki

**Check Promtail is running:**
```bash
docker ps | grep dns-log-agent
docker logs dns-log-agent
```

**Verify network connectivity:**
```bash
docker exec dns-log-agent ping 192.168.8.100
docker exec dns-log-agent curl http://192.168.8.100:3100/ready
```

**Check log files are accessible:**
```bash
docker exec dns-log-agent ls -la /var/log/pihole/
```

### High Network Usage

Promtail ships logs continuously. To reduce bandwidth:

**Batch logs:**
```yaml
clients:
  - url: http://192.168.8.100:3100/loki/api/v1/push
    batchwait: 10s        # Wait 10s before sending
    batchsize: 102400     # Send when batch reaches 100KB
```

**Filter logs before shipping:**
```yaml
pipeline_stages:
  - match:
      selector: '{job="pihole"}'
      stages:
        - drop:
            expression: ".*localhost.*"  # Drop queries from localhost
```

### Promtail Container Crashes

**Check resource limits:**
```bash
# Increase memory limit
docker update --memory=256m dns-log-agent
```

**Check disk space:**
```bash
df -h /var/log
```

## Security Considerations

### Authentication

If Loki requires authentication:

```yaml
clients:
  - url: http://192.168.8.100:3100/loki/api/v1/push
    basic_auth:
      username: ${LOKI_USERNAME}
      password: ${LOKI_PASSWORD}
```

### Network Security

**Firewall rules:**
```bash
# On Security Pi, allow Loki from DNS Pi only
sudo iptables -A INPUT -p tcp -s 192.168.8.250 --dport 3100 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 3100 -j DROP
```

**TLS encryption:**
```yaml
clients:
  - url: https://192.168.8.100:3100/loki/api/v1/push
    tls_config:
      ca_file: /etc/ssl/certs/loki-ca.crt
```

### Log Privacy

DNS logs contain sensitive information. Consider:

1. **Anonymization**: Strip client IPs before shipping
   ```yaml
   pipeline_stages:
     - replace:
         expression: '(\d+\.\d+\.\d+\.)\d+'
         replace: '${1}XXX'
   ```

2. **Filtering**: Don't ship internal domain queries
   ```yaml
   pipeline_stages:
     - drop:
         expression: ".*\.local$"
   ```

3. **Retention**: Set short retention on Security Pi Loki (e.g., 7 days)

## Performance Tuning

### Log Rotation

Ensure log files are rotated to prevent disk fill:

```bash
# /etc/logrotate.d/pihole
/var/log/pihole/*.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
}
```

### Promtail Resource Limits

```yaml
services:
  promtail:
    deploy:
      resources:
        limits:
          memory: 256M
          cpus: '0.5'
        reservations:
          memory: 128M
```

## Alternative: Fluentd

For more complex log processing, use Fluentd instead of Promtail:

```yaml
# See docker-compose.yml (commented out section)
services:
  fluentd:
    image: fluent/fluentd:latest
    # Supports plugins for parsing, filtering, routing
```

**Benefits:**
- More plugins available
- Better parsing capabilities
- Can send to multiple destinations

**Drawbacks:**
- Higher resource usage
- More complex configuration

## Documentation

For more information:
- **[Orion Sentinel Integration](../../docs/ORION_SENTINEL_INTEGRATION.md)** - Full integration guide
- **[Promtail Documentation](https://grafana.com/docs/loki/latest/clients/promtail/)** - Official docs
- **[Loki LogQL](https://grafana.com/docs/loki/latest/logql/)** - Query language

## See Also

- [Observability Guide](../../docs/observability.md)
- [NSM/AI Integration](../../docs/ORION_SENTINEL_INTEGRATION.md)
- [Security Pi Repository](https://github.com/your-repo/orion-sentinel-nsm-ai)
