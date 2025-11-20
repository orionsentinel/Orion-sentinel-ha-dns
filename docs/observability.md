# DNS Observability Guide

Complete guide to monitoring and observability for Orion Sentinel DNS HA.

## Overview

Observability provides visibility into:
- **DNS query performance** - Query rates, latency, blocking effectiveness
- **Service health** - Uptime, availability, error rates
- **System resources** - CPU, memory, disk usage
- **High availability status** - VIP assignment, failover events
- **Security insights** - Blocked domains, threat patterns

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                   Observability Stack                         │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐      ┌──────────────┐      ┌───────────┐ │
│  │   Exporters  │ ───▶ │  Prometheus  │ ───▶ │  Grafana  │ │
│  └──────────────┘      └──────────────┘      └───────────┘ │
│   - Node              - Metrics storage     - Dashboards   │
│   - Pi-hole           - Alerting rules      - Visualization│
│   - Unbound           - Query engine        - Reports      │
│   - Blackbox                                                │
│   - cAdvisor          ┌──────────────┐                     │
│                       │ Alertmanager │                     │
│                       └──────────────┘                     │
│                       - Alert routing                       │
│                       - Notifications                       │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Components

### 1. Metrics Exporters

#### Node Exporter
**Purpose**: System-level metrics (CPU, memory, disk, network)

**Metrics provided:**
- `node_cpu_seconds_total` - CPU usage by mode
- `node_memory_*` - Memory statistics
- `node_filesystem_*` - Disk usage
- `node_network_*` - Network I/O

**Access**: http://192.168.8.250:9100/metrics

#### Pi-hole Exporter
**Purpose**: DNS blocking and query metrics

**Metrics provided:**
- `pihole_domains_being_blocked` - Total blocked domains
- `pihole_dns_queries_today` - Query count
- `pihole_ads_blocked_today` - Blocked query count
- `pihole_ads_percentage_today` - Block percentage

**Access**:
- Primary: http://192.168.8.250:9617/metrics
- Secondary: http://192.168.8.250:9618/metrics

#### Unbound Exporter
**Purpose**: DNS resolver performance metrics

**Metrics provided:**
- `unbound_queries_total` - Total queries processed
- `unbound_cache_hits_total` - Cache hit rate
- `unbound_cache_misses_total` - Cache miss rate
- `unbound_query_time_seconds` - Query latency

**Note**: Requires Unbound remote-control configuration

#### Blackbox Exporter
**Purpose**: DNS availability and latency probes

**Probes DNS endpoints** and provides:
- `probe_success` - Whether probe succeeded
- `probe_dns_lookup_time_seconds` - DNS resolution time
- `probe_duration_seconds` - Total probe duration

**Access**: http://192.168.8.250:9115

#### cAdvisor
**Purpose**: Container-level metrics

**Metrics provided:**
- `container_cpu_usage_seconds_total` - Container CPU usage
- `container_memory_usage_bytes` - Container memory
- `container_network_*` - Container network I/O

**Access**: http://192.168.8.250:8080

### 2. Prometheus

**Purpose**: Time-series metrics database and alerting

**Features:**
- Scrapes metrics from all exporters
- Stores metrics with configurable retention
- Evaluates alert rules
- Provides query API for Grafana

**Configuration**: `stacks/monitoring/prometheus/prometheus.yml`

**Access**: http://192.168.8.250:9090

**Query examples:**
```promql
# DNS query rate
rate(pihole_dns_queries_today[5m])

# Block percentage
(pihole_ads_blocked_today / pihole_dns_queries_today) * 100

# DNS latency
probe_dns_lookup_time_seconds

# System memory usage
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100
```

### 3. Grafana

**Purpose**: Visualization and dashboarding

**Features:**
- Pre-configured dashboards
- Custom dashboard creation
- Alert visualization
- Data exploration

**Access**: http://192.168.8.250:3000
- Username: `admin`
- Password: `${GRAFANA_ADMIN_PASSWORD}` (from .env)

**Dashboards included:**
- **DNS HA Overview** - Main dashboard with key metrics
- (Add custom dashboards as needed)

### 4. Alertmanager

**Purpose**: Alert routing and notification

**Features:**
- Routes alerts based on labels
- Groups related alerts
- Sends notifications (Email, Slack, Signal, etc.)
- Silences and inhibitions

**Access**: http://192.168.8.250:9093

## Deployment

### Enable Monitoring Stack

The monitoring exporters are defined in `stacks/monitoring/docker-compose.exporters.yml`:

```bash
# Deploy exporters alongside DNS stack
cd /opt/rpi-ha-dns-stack

# Start exporters
docker compose -f stacks/monitoring/docker-compose.exporters.yml up -d

# Verify exporters are running
docker ps | grep exporter

# Check metrics are being collected
curl http://localhost:9100/metrics  # Node exporter
curl http://localhost:9617/metrics  # Pi-hole exporter
```

### Configure Prometheus (if not already running)

If you don't have Prometheus in the observability stack:

```bash
# Uncomment Prometheus in docker-compose.exporters.yml
nano stacks/monitoring/docker-compose.exporters.yml

# Start Prometheus
docker compose -f stacks/monitoring/docker-compose.exporters.yml up -d prometheus

# Verify Prometheus is scraping targets
# Open http://192.168.8.250:9090/targets
```

### Import Grafana Dashboard

If Grafana isn't auto-provisioning dashboards:

1. Open Grafana: http://192.168.8.250:3000
2. Click **+** (Create) → **Import**
3. Upload `stacks/monitoring/grafana/dashboards/dns-ha-overview.json`
4. Select Prometheus datasource
5. Click **Import**

## Dashboard Overview

### DNS HA Overview Dashboard

**Panels included:**

1. **DNS Query Rate**
   - Real-time query rate per instance
   - Shows traffic distribution across Pi-hole instances

2. **Block Percentage**
   - Percentage of queries blocked
   - Gauge showing blocking effectiveness

3. **Pi-hole Status**
   - Up/Down status for each Pi-hole instance
   - Color-coded (green=up, red=down)

4. **DNS Latency**
   - DNS resolution time for each instance
   - Helps identify performance issues

5. **Domains Blocked**
   - Total number of domains on blocklists
   - Updated when gravity is refreshed

6. **Total Queries Today**
   - Cumulative query count
   - Resets daily

7. **System Resources**
   - CPU and memory usage graphs
   - Helps identify resource constraints

**Useful for:**
- Daily health monitoring
- Performance troubleshooting
- Capacity planning
- HA verification

### Creating Custom Dashboards

Example: Query latency by query type

```json
{
  "title": "DNS Query Latency by Type",
  "targets": [
    {
      "expr": "probe_dns_lookup_time_seconds{query_type=\"A\"}",
      "legendFormat": "A records"
    },
    {
      "expr": "probe_dns_lookup_time_seconds{query_type=\"AAAA\"}",
      "legendFormat": "AAAA records"
    }
  ],
  "type": "timeseries"
}
```

## Alert Rules

### Pre-configured Alerts

Located in `stacks/monitoring/prometheus/alerts/dns-alerts.yml`:

**Critical alerts:**
- `PiHoleDown` - Pi-hole instance is down
- `UnboundDown` - Unbound instance is down
- `AllPiHolesDown` - Complete DNS blocking failure
- `AllUnboundDown` - Complete DNS resolution failure

**Warning alerts:**
- `HighDNSFailureRate` - Many queries failing
- `HighDNSLatency` - Slow DNS responses
- `HighCPUUsage` - System resource constraint
- `HighMemoryUsage` - Memory pressure
- `LowDiskSpace` - Disk filling up

**Informational alerts:**
- `VIPFailover` - HA failover occurred

### Alert Notification

Configure Alertmanager to send notifications:

**Email notifications:**
```yaml
# stacks/observability/alertmanager/config.yml
receivers:
  - name: 'email'
    email_configs:
      - to: 'admin@example.com'
        from: 'alertmanager@dns-ha.local'
        smarthost: 'smtp.gmail.com:587'
        auth_username: 'your-email@gmail.com'
        auth_password: 'your-app-password'
```

**Signal notifications (via existing stack):**
Already configured if using Signal integration!

**Slack notifications:**
```yaml
receivers:
  - name: 'slack'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
        channel: '#dns-alerts'
        title: 'DNS HA Alert'
```

## Metrics Collection Best Practices

### Scrape Intervals

Balance freshness vs. load:

```yaml
# High frequency for critical services
- job_name: 'pihole'
  scrape_interval: 15s

# Lower frequency for system metrics
- job_name: 'node-exporter'
  scrape_interval: 30s
```

### Retention Policies

Configure data retention:

```yaml
# Prometheus command line args
--storage.tsdb.retention.time=30d  # Keep 30 days
--storage.tsdb.retention.size=10GB # Or 10GB max
```

### Resource Usage

Typical resource consumption:
- Prometheus: 200-500 MB RAM, 1-5 GB disk
- Grafana: 100-200 MB RAM
- Exporters: 20-50 MB RAM each

Total overhead: ~500 MB RAM, 5-10 GB disk

## Integration with Security Pi

### Metrics Federation

Share DNS metrics with Security Pi's Prometheus:

**On Security Pi Prometheus config:**
```yaml
scrape_configs:
  - job_name: 'dns-pi-federation'
    honor_labels: true
    metrics_path: '/federate'
    params:
      'match[]':
        - '{job=~"pihole.*"}'
        - '{job=~"unbound.*"}'
    static_configs:
      - targets:
          - '192.168.8.250:9090'  # DNS Pi Prometheus
```

### Shared Grafana Dashboards

Access DNS dashboards from Security Pi:

1. Add DNS Pi Prometheus as datasource in Security Pi Grafana
2. Import DNS dashboards
3. Create unified security dashboard combining DNS + IDS metrics

### Unified Alerting

Route all alerts through Security Pi Alertmanager:

```yaml
# DNS Pi Prometheus config
alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - '192.168.8.100:9093'  # Security Pi Alertmanager
```

## Troubleshooting

### Exporters Not Showing Metrics

**Check exporter is running:**
```bash
docker ps | grep exporter
docker logs pihole-exporter-primary
```

**Verify metrics endpoint:**
```bash
curl http://localhost:9617/metrics
```

**Check firewall:**
```bash
sudo iptables -L | grep 9617
```

### Prometheus Not Scraping Targets

**Check Prometheus targets page:**
http://192.168.8.250:9090/targets

**Common issues:**
- Network connectivity (ping exporter IP)
- Wrong port in config
- Exporter not running

**Fix:**
```bash
# Restart Prometheus
docker restart prometheus

# Reload config without restart
curl -X POST http://localhost:9090/-/reload
```

### Grafana Showing "No Data"

**Check datasource connection:**
1. Grafana → Configuration → Data Sources
2. Click Prometheus
3. Click "Test" button
4. Should show "Data source is working"

**Check query syntax:**
- Try query in Prometheus UI first
- Verify metric name exists: `probe_dns_lookup_time_seconds`

### High Prometheus Memory Usage

**Reduce retention:**
```bash
# Edit Prometheus command
--storage.tsdb.retention.time=15d  # Reduce from 30d
```

**Reduce scrape frequency:**
```yaml
global:
  scrape_interval: 30s  # Increase from 15s
```

## Advanced Topics

### Custom Metrics

Add custom metrics via pushgateway:

```bash
# Install pushgateway
docker run -d -p 9091:9091 prom/pushgateway

# Push custom metric
echo "dns_custom_metric 42" | curl --data-binary @- \
  http://localhost:9091/metrics/job/custom/instance/dns-pi-1
```

### Long-term Storage

For retention > 30 days, use Thanos or Cortex:

```yaml
# Thanos sidecar for long-term storage
thanos-sidecar:
  image: thanosio/thanos:latest
  command:
    - 'sidecar'
    - '--prometheus.url=http://prometheus:9090'
    - '--objstore.config-file=/etc/thanos/objstore.yml'
```

### Distributed Tracing

For request tracing across components (future):
- Jaeger or Zipkin
- OpenTelemetry instrumentation
- Trace DNS query path

## See Also

- [Health and HA Guide](health-and-ha.md) - Health checking details
- [Prometheus Documentation](https://prometheus.io/docs/) - Official docs
- [Grafana Documentation](https://grafana.com/docs/) - Dashboard creation
- [Orion Sentinel Integration](ORION_SENTINEL_INTEGRATION.md) - Security Pi integration
