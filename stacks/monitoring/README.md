# DNS HA Monitoring Stack

Observability components for Orion Sentinel DNS HA.

## Overview

This directory contains **optional** monitoring exporters and configurations for comprehensive DNS stack observability.

**These components work in both Standalone and Integrated modes:**
- **Standalone mode**: Exporters run locally, metrics accessible via HTTP endpoints
- **Integrated mode**: Same as standalone, plus CoreSrv Prometheus scrapes the metrics

**Important:** Core DNS services (Pi-hole, Unbound, Keepalived) do NOT depend on these exporters. They will continue to function normally even if exporters are not deployed or fail to start.

## Deployment Modes

### Standalone Mode

Exporters expose metrics locally for manual inspection or local Prometheus:

```bash
# Deploy exporters
docker compose -f docker-compose.exporters.yml up -d

# Access metrics directly
curl http://localhost:9100/metrics  # Node metrics
curl http://localhost:9617/metrics  # Pi-hole primary metrics
curl http://localhost:9115/metrics  # Blackbox exporter
```

**Use cases:**
- Monitor DNS stack health locally
- Troubleshoot performance issues
- Run local Prometheus/Grafana instance
- No external dependencies

### Integrated Mode (with CoreSrv)

Same deployment, but CoreSrv's Prometheus scrapes these metrics:

```bash
# 1. Deploy exporters (same as standalone)
docker compose -f docker-compose.exporters.yml up -d

# 2. Configure CoreSrv Prometheus to scrape these endpoints
# See docs/SPOG_INTEGRATION_GUIDE.md for Prometheus configuration

# 3. Access unified dashboards on CoreSrv Grafana
# http://coresrv-ip:3000
```

**Benefits:**
- Centralized metrics across all Pis
- Unified dashboards in CoreSrv Grafana
- Long-term metrics retention
- Cross-stack correlation (DNS + Security)

## Components

### Metrics Exporters

Located in `docker-compose.exporters.yml`:

- **node-exporter**: System metrics (CPU, RAM, disk, network)
- **pihole-exporter-primary**: Pi-hole primary instance metrics
- **pihole-exporter-secondary**: Pi-hole secondary instance metrics
- **blackbox-exporter**: DNS latency probes
- **cadvisor**: Container resource metrics

Optional (requires configuration):
- **unbound-exporter**: Unbound DNS resolver metrics
- **prometheus**: Metrics storage (if not using observability stack)

### Configuration Files

- `prometheus/prometheus.yml`: Prometheus scrape configuration
- `prometheus/alerts/dns-alerts.yml`: Alert rules for DNS services
- `grafana/provisioning/`: Auto-provisioning configs
- `grafana/dashboards/`: Pre-built dashboards
- `blackbox/blackbox.yml`: DNS probe configuration

## Quick Start

### Deploy Exporters

```bash
cd /opt/rpi-ha-dns-stack

# Start all exporters
docker compose -f stacks/monitoring/docker-compose.exporters.yml up -d

# Verify exporters are running
docker ps | grep exporter

# Check metrics endpoints
curl http://localhost:9100/metrics  # Node exporter
curl http://localhost:9617/metrics  # Pi-hole exporter primary
curl http://localhost:9115/probe?target=google.com&module=dns_google  # Blackbox
```

### Access Monitoring

If using the main observability stack:

- **Prometheus**: http://192.168.8.250:9090
- **Grafana**: http://192.168.8.250:3000
  - Username: `admin`
  - Password: From `.env` file
- **Alertmanager**: http://192.168.8.250:9093

### Import Dashboard

1. Open Grafana: http://192.168.8.250:3000
2. Navigate to **Dashboards** → **Import**
3. Upload `grafana/dashboards/dns-ha-overview.json`
4. Select Prometheus datasource
5. Click **Import**

## Metrics Collected

### DNS Metrics (Pi-hole)

```promql
pihole_domains_being_blocked      # Total domains on blocklists
pihole_dns_queries_today          # Total DNS queries today
pihole_ads_blocked_today          # Blocked queries today
pihole_ads_percentage_today       # Block percentage
```

### DNS Latency (Blackbox)

```promql
probe_dns_lookup_time_seconds     # DNS resolution time
probe_success                     # Whether DNS query succeeded
```

### System Metrics (Node Exporter)

```promql
node_cpu_seconds_total            # CPU usage
node_memory_MemAvailable_bytes    # Available memory
node_filesystem_avail_bytes       # Disk space
node_network_receive_bytes_total  # Network RX
```

### Container Metrics (cAdvisor)

```promql
container_cpu_usage_seconds_total # Container CPU
container_memory_usage_bytes      # Container memory
container_network_transmit_bytes  # Container network TX
```

## Alert Rules

Pre-configured alerts in `prometheus/alerts/dns-alerts.yml`:

**Critical:**
- `AllPiHolesDown`: Complete DNS blocking failure
- `AllUnboundDown`: Complete DNS resolution failure
- `PiHoleDown`: Single Pi-hole instance down
- `UnboundDown`: Single Unbound instance down

**Warning:**
- `HighDNSFailureRate`: Many queries failing
- `HighDNSLatency`: Slow DNS responses (>1s)
- `HighCPUUsage`: CPU >85% for 10 minutes
- `HighMemoryUsage`: Memory >90% for 10 minutes
- `LowDiskSpace`: Disk <15% free

**Info:**
- `VIPFailover`: Keepalived failover occurred

## Customization

### Add Custom Scrape Target

Edit `prometheus/prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'custom-service'
    static_configs:
      - targets:
          - 'custom-service:9999'
        labels:
          service: 'custom'
```

Reload Prometheus config:
```bash
curl -X POST http://localhost:9090/-/reload
```

### Create Custom Dashboard

1. Design dashboard in Grafana UI
2. Export as JSON (Share → Export)
3. Save to `grafana/dashboards/custom-dashboard.json`
4. Dashboard will auto-load on Grafana restart

### Add Custom Alert

Edit `prometheus/alerts/dns-alerts.yml`:

```yaml
- alert: CustomAlert
  expr: custom_metric > 100
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Custom alert triggered"
```

Reload Prometheus:
```bash
docker restart prometheus
```

## Troubleshooting

### Exporter Not Showing Metrics

```bash
# Check container logs
docker logs pihole-exporter-primary

# Verify endpoint manually
curl http://localhost:9617/metrics

# Check network connectivity
docker exec pihole-exporter-primary ping pihole_primary
```

### Prometheus Not Scraping

1. Check targets page: http://localhost:9090/targets
2. Look for errors (red targets)
3. Common issues:
   - Container not running
   - Wrong port in config
   - Network issue

Fix and reload:
```bash
docker restart prometheus
curl -X POST http://localhost:9090/-/reload
```

### Grafana Dashboard Shows "No Data"

1. Verify Prometheus datasource: Configuration → Data Sources → Prometheus → Test
2. Check query in Prometheus first
3. Verify time range is correct
4. Check metric name exists: `pihole_dns_queries_today`

## Resource Usage

Typical resource consumption:

| Component | RAM | Disk | CPU |
|-----------|-----|------|-----|
| node-exporter | 20 MB | - | <1% |
| pihole-exporter | 30 MB | - | <1% |
| blackbox-exporter | 25 MB | - | <1% |
| cadvisor | 50 MB | - | 2-3% |
| prometheus | 200-500 MB | 5-10 GB | 2-5% |

**Total**: ~500 MB RAM, ~10 GB disk

On Raspberry Pi 4 (4GB+ RAM), this is acceptable overhead for production monitoring.

## Integration with Security Pi

### Metrics Federation

Share DNS metrics with Security Pi's Prometheus by adding this to Security Pi's config:

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
          - '192.168.8.250:9090'
```

### Unified Alerting

Route DNS alerts to Security Pi's Alertmanager:

```yaml
# prometheus.yml
alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - '192.168.8.100:9093'  # Security Pi
```

## Documentation

For complete monitoring documentation, see:
- **[docs/observability.md](../../docs/observability.md)** - Full observability guide
- **[docs/health-and-ha.md](../../docs/health-and-ha.md)** - Health checking
- **[Prometheus Docs](https://prometheus.io/docs/)** - Official documentation
- **[Grafana Docs](https://grafana.com/docs/)** - Dashboard creation

## Files

```
monitoring/
├── docker-compose.exporters.yml       # Exporter services
├── blackbox/
│   └── blackbox.yml                   # DNS probe config
├── prometheus/
│   ├── prometheus.yml                 # Scrape configuration
│   └── alerts/
│       └── dns-alerts.yml            # Alert rules
└── grafana/
    ├── dashboards/
    │   └── dns-ha-overview.json      # Pre-built dashboard
    └── provisioning/
        ├── datasources/
        │   └── prometheus.yml         # Prometheus datasource
        └── dashboards/
            └── dashboards.yml         # Dashboard provisioning
```

## See Also

- [Observability Guide](../../docs/observability.md)
- [Health & HA Guide](../../docs/health-and-ha.md)
- [Orion Sentinel Integration](../../docs/ORION_SENTINEL_INTEGRATION.md)
