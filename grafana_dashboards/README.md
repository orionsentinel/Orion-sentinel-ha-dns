# Grafana Dashboards for Orion Sentinel HA DNS

This directory contains pre-configured Grafana dashboards for monitoring your HA DNS stack.

## Available Dashboards

### DNS HA Overview
**File:** `dns-ha-overview.json`

Comprehensive dashboard showing:
- DNS query rates and latency
- Pi-hole blocking statistics
- Unbound cache performance
- Keepalived VIP status
- System resource usage (CPU, memory, disk)
- Container health status
- HA failover events

**Data Sources Required:**
- Prometheus (scraping node_exporter, pihole_exporter, unbound_exporter)

### System Metrics
**File:** `system-metrics.json` (coming soon)

Detailed system-level metrics:
- CPU usage per core
- Memory breakdown
- Disk I/O
- Network traffic
- Temperature (Raspberry Pi)

## Installation

### Method 1: Manual Import

1. **Access Grafana:**
   ```
   http://<your-grafana-ip>:3000
   ```
   Default credentials: admin / <GRAFANA_ADMIN_PASSWORD from .env>

2. **Import Dashboard:**
   - Click **+** (Create) → **Import**
   - Click **Upload JSON file**
   - Select dashboard JSON file from this directory
   - Select your Prometheus data source
   - Click **Import**

### Method 2: Auto-Provisioning

If you have Grafana deployed with provisioning enabled:

1. **Copy dashboards to Grafana provisioning directory:**
   ```bash
   cp grafana_dashboards/*.json /path/to/grafana/provisioning/dashboards/
   ```

2. **Restart Grafana:**
   ```bash
   docker restart grafana
   ```

## Data Source Configuration

### Prometheus Setup

The dashboards expect a Prometheus data source with:

**URL:** `http://prometheus:9090` (if Prometheus is in same Docker network)

**Scrape targets configured:**
```yaml
scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['<HOST_IP>:9100']
  
  - job_name: 'pihole'
    static_configs:
      - targets: ['<HOST_IP>:9617']
  
  - job_name: 'unbound'
    static_configs:
      - targets: ['<HOST_IP>:9167']
```

### Enable Exporters

If you haven't enabled monitoring exporters yet:

```bash
# Edit .env
DEPLOY_MONITORING=true

# Deploy exporters
make up-exporters

# Verify exporters are running
curl http://<HOST_IP>:9100/metrics  # Node exporter
curl http://<HOST_IP>:9617/metrics  # Pi-hole exporter
curl http://<HOST_IP>:9167/metrics  # Unbound exporter
```

## Dashboard Customization

### Variables

Dashboards use these variables:
- `$node` - Node name (auto-populated from Prometheus labels)
- `$interval` - Time interval for aggregations
- `$datasource` - Prometheus data source

### Panels

Each dashboard is organized into rows:
1. **Overview** - High-level metrics and alerts
2. **DNS Performance** - Query rates, latency, cache hits
3. **Pi-hole Stats** - Blocking effectiveness, query types
4. **System Health** - CPU, memory, disk, network
5. **HA Status** - Keepalived VIP assignment, failover history

### Alerts

Some panels include alert thresholds:
- DNS query latency > 500ms
- Pi-hole service down
- Unbound service down
- Memory usage > 90%
- Disk usage > 85%

Configure alert notifications in Grafana settings.

## Creating Custom Dashboards

### Using Existing Panels

1. Open an existing dashboard
2. Click panel title → **Edit**
3. Copy the panel JSON
4. Paste into your custom dashboard

### Query Examples

**DNS query rate:**
```promql
rate(pihole_queries_forwarded[5m])
```

**Unbound cache hit ratio:**
```promql
rate(unbound_cache_hits_total[5m]) / rate(unbound_queries_total[5m]) * 100
```

**System CPU usage:**
```promql
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

**Container memory:**
```promql
container_memory_usage_bytes{name=~"pihole.*|unbound.*|keepalived"}
```

## Dashboard Updates

Dashboards in this repository are updated periodically. To get the latest version:

```bash
cd /path/to/orion-sentinel-ha-dns
git pull origin main
```

Then re-import the dashboard in Grafana.

## Troubleshooting

### Dashboard shows "No data"

**Check Prometheus targets:**
```bash
# Access Prometheus UI
http://<prometheus-ip>:9090/targets

# Verify all targets are "UP"
```

**Verify exporters:**
```bash
# Check if exporters are running
docker ps | grep exporter

# Test metrics endpoints
curl http://<HOST_IP>:9100/metrics
curl http://<HOST_IP>:9617/metrics
curl http://<HOST_IP>:9167/metrics
```

**Check Grafana data source:**
- Go to Configuration → Data Sources
- Select Prometheus
- Click "Test" button
- Should show "Data source is working"

### Panels show errors

**"Metric not found":**
- Exporter may not be running
- Prometheus may not be scraping the target
- Check Prometheus logs: `docker logs prometheus`

**"Timeout":**
- Prometheus may be overloaded
- Increase timeout in Grafana data source settings
- Consider reducing dashboard time range

## Contributing

Have a useful dashboard? Submit a PR with:
1. Dashboard JSON file
2. Screenshot
3. Description of panels and use case
4. Required data sources

## Links

- **Grafana Documentation:** https://grafana.com/docs/
- **Prometheus Query Language:** https://prometheus.io/docs/prometheus/latest/querying/basics/
- **Node Exporter Metrics:** https://github.com/prometheus/node_exporter
- **Pi-hole Exporter:** https://github.com/eko/pihole-exporter
- **Unbound Exporter:** https://github.com/svaloumas/unbound_exporter

---

**Need Help?**
- Check main README.md for deployment guide
- See TROUBLESHOOTING.md for common issues
- Open an issue on GitHub
