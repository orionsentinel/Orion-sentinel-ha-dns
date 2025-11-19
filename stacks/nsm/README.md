# Orion Sentinel NSM Stack

**Network Security Monitoring with Suricata, Loki, Grafana, and AI-powered threat detection**

---

## Overview

This stack provides the **Security Pi (Pi #2)** component of the Orion Sentinel platform. It includes:

- **Loki** – Centralized log aggregation and storage
- **Promtail** – Log collection and shipping
- **Grafana** – Security dashboards and visualization
- **Suricata** – Network intrusion detection system (IDS)
- **AI Service** – Machine learning-based anomaly detection (placeholder)

---

## Quick Start

### Prerequisites

- Raspberry Pi 5 (8GB RAM recommended)
- Docker and Docker Compose installed
- Network port mirroring configured (for Suricata)
- DNS Pi (Pi #1) running and accessible

### 1. Configuration

Create a `.env` file:

```bash
cp .env.example .env
```

Edit `.env` and set:

```bash
# Grafana credentials
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=your-secure-password

# Pi-hole API (for AI service to block domains)
PIHOLE_API_URL=http://192.168.8.251/admin/api.php
PIHOLE_API_TOKEN=your-pihole-api-token

# Network interface to monitor (for Suricata)
MONITOR_INTERFACE=eth0

# Optional: Host IP for Grafana root URL
HOST_IP=192.168.8.100
```

### 2. Create Required Directories

```bash
mkdir -p suricata/{etc,logs,rules}
mkdir -p ai-service/{models,config}
```

### 3. Start the Stack

```bash
docker compose up -d
```

### 4. Verify Services

```bash
# Check all services are running
docker compose ps

# Check Loki is ready
curl http://localhost:3100/ready

# Check Grafana is ready
curl http://localhost:3000/api/health

# View logs
docker compose logs -f grafana
```

### 5. Access Grafana

1. Open browser: `http://<pi-ip>:3000`
2. Login with credentials from `.env`
3. Navigate to **Dashboards** → **Security** folder
4. Open **Orion Sentinel – Security Overview**

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  Orion Sentinel NSM Stack                │
│                    (Security Pi #2)                      │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐             │
│  │ Suricata │  │    AI    │  │  Threat  │             │
│  │   IDS    │  │ Service  │  │   Intel  │             │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘             │
│       │             │              │                    │
│       │  ┌──────────▼──────────────▼─────┐             │
│       └─▶│        Promtail               │             │
│          │     (Log Collector)           │             │
│          └──────────┬────────────────────┘             │
│                     │                                   │
│          ┌──────────▼────────────────────┐             │
│          │          Loki                 │             │
│          │     (Log Storage)             │             │
│          └──────────┬────────────────────┘             │
│                     │                                   │
│          ┌──────────▼────────────────────┐             │
│          │        Grafana                │             │
│          │     (Dashboards)              │             │
│          └───────────────────────────────┘             │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## Components

### Loki (Port 3100)

Centralized log storage with:
- 30-day log retention
- Automatic log compaction
- Optimized for Raspberry Pi performance

**Configuration:** `loki/loki-config.yaml`

### Promtail (Port 9080)

Collects logs from:
- Suricata EVE JSON logs
- AI service output
- Threat intelligence feeds
- Docker containers

**Configuration:** `promtail/promtail-config.yaml`

### Grafana (Port 3000)

Pre-configured with:
- Loki datasource
- Security Overview dashboard
- Threat Intelligence dashboard

**Provisioning:** `grafana-provisioning/`

### Suricata (Network Mode: Host)

Network IDS running in passive mode:
- Monitors mirrored network traffic
- Generates alerts for suspicious activity
- Logs to EVE JSON format

**Configuration:** `suricata/etc/` (to be created)  
**Logs:** `suricata/logs/`

### AI Service (Placeholder)

Machine learning service for:
- Device behavior anomaly detection
- Domain risk scoring
- Automated threat response

**Note:** This is a placeholder. Implement your AI service with:
- Python application
- Loki query integration
- Pi-hole API client
- ML models for scoring

---

## Dashboards

### 1. Orion Sentinel – Security Overview

Main SOC dashboard with:
- Suricata IDS alerts (time series, top signatures, top talkers)
- DNS activity (top domains, top clients)
- AI anomaly detection (suspicious devices, high-risk domains)
- Threat intelligence (recent IOCs, matches)
- System health metrics

**Best for:** 24/7 monitoring, incident response

### 2. Orion Sentinel – Threat Intelligence

Detailed threat intel dashboard with:
- IOC ingestion timeline
- IOCs by type and source
- Environment correlation (matches)
- Community intel digest
- Statistics and metrics

**Best for:** Threat hunting, intel feed evaluation

See `docs/logging-and-dashboards.md` for complete dashboard documentation.

---

## Integration with DNS Pi

To ship DNS logs from Pi #1 to this NSM stack:

1. **On DNS Pi (Pi #1):**

   Install Promtail to ship Pi-hole and Unbound logs.

   See `docs/ORION_SENTINEL_INTEGRATION.md` for step-by-step instructions.

2. **Configure Promtail to point to this Loki instance:**

   ```yaml
   clients:
     - url: http://<pi2-ip>:3100/loki/api/v1/push
   ```

3. **Verify logs arrive:**

   ```bash
   curl "http://localhost:3100/loki/api/v1/label/service/values"
   # Should include: pihole, unbound, suricata, ...
   ```

---

## Customization

### Adding Custom Log Sources

Edit `promtail/promtail-config.yaml`:

```yaml
scrape_configs:
  - job_name: my-custom-app
    static_configs:
      - targets:
          - localhost
        labels:
          job: custom
          service: my-app
          pi: pi2-security
          __path__: /var/log/my-app/*.log
    
    pipeline_stages:
      - json:
          expressions:
            timestamp: time
            message: msg
      
      - timestamp:
          source: timestamp
          format: RFC3339
```

Restart Promtail:

```bash
docker compose restart promtail
```

### Modifying Dashboards

1. Edit in Grafana UI
2. Export JSON: Dashboard settings → JSON Model
3. Save to `grafana-provisioning/dashboards/`
4. Restart Grafana to reload:

   ```bash
   docker compose restart grafana
   ```

### Adjusting Log Retention

Edit `loki/loki-config.yaml`:

```yaml
limits_config:
  retention_period: 1440h  # 60 days (change from 720h)

table_manager:
  retention_period: 1440h  # Match above
```

Restart Loki:

```bash
docker compose restart loki
```

---

## Monitoring and Maintenance

### Check Service Health

```bash
# All services
docker compose ps

# Specific service
docker compose logs -f loki
docker compose logs -f promtail
docker compose logs -f grafana

# Check Loki metrics
curl http://localhost:3100/metrics
```

### Disk Usage

Loki logs can grow large. Monitor disk usage:

```bash
# Check volume sizes
docker system df -v

# Check Loki data directory
du -sh ./loki-data
```

### Backup

```bash
# Backup Grafana dashboards
docker exec orion-grafana grafana-cli admin export \
  --output /tmp/backup.json

# Backup Loki data (stop Loki first)
docker compose stop loki
tar -czf loki-backup-$(date +%Y%m%d).tar.gz loki/
docker compose start loki
```

---

## Troubleshooting

### Loki Not Starting

**Check logs:**
```bash
docker compose logs loki
```

**Common issues:**
- Permission errors: Ensure Loki can write to `/loki` directory
- Port conflicts: Check if port 3100 is already in use
- Configuration errors: Validate YAML syntax in `loki-config.yaml`

### Promtail Not Shipping Logs

**Check Promtail logs:**
```bash
docker compose logs promtail | grep -i error
```

**Common issues:**
- Cannot reach Loki: Verify network connectivity
- Log file not found: Check `__path__` in `promtail-config.yaml`
- Permission denied: Ensure Promtail can read log files

### Grafana Shows No Data

**Verify Loki connection:**
```bash
curl "http://localhost:3100/loki/api/v1/label/service/values"
```

**Check Grafana datasource:**
1. Go to Configuration → Data sources → Loki
2. Click "Test"
3. Should show "Data source is working"

**Check dashboard queries:**
- Use Grafana "Explore" to test LogQL queries
- Verify label names match Promtail configuration

### Suricata Alerts Not Appearing

**Check Suricata is running:**
```bash
docker compose logs suricata
```

**Verify logs are being written:**
```bash
ls -la suricata/logs/
cat suricata/logs/eve.json | jq .
```

**Check Promtail is reading Suricata logs:**
```bash
docker compose logs promtail | grep suricata
```

---

## Security Considerations

### Network Isolation

This stack should run on an isolated network segment:
- Monitoring interface: Passive (receive-only)
- Management interface: Separate network for SSH/API access

### Credentials

- Change default Grafana password immediately
- Store Pi-hole API token securely (use environment variables)
- Rotate credentials regularly

### Resource Limits

Resource limits are configured in `docker-compose.yml`:
- Prevents any single service from consuming all RAM
- Adjust based on your Raspberry Pi model and workload

### Log Sanitization

Logs may contain sensitive data:
- Client IP addresses
- DNS queries (browsing history)
- Network traffic metadata

Configure appropriate retention and access controls.

---

## Performance Optimization

### For Raspberry Pi 4 (4GB RAM)

Reduce resource allocations in `docker-compose.yml`:

```yaml
loki:
  deploy:
    resources:
      limits:
        memory: 512M  # Down from 1G
```

Reduce Loki retention:

```yaml
# loki-config.yaml
limits_config:
  retention_period: 168h  # 7 days instead of 30
```

### For Raspberry Pi 5 (8GB RAM)

Current configuration is optimized for Pi 5.

Consider increasing if needed:
```yaml
loki:
  deploy:
    resources:
      limits:
        memory: 2G
```

---

## Next Steps

1. **Configure Suricata:**
   - Create `suricata/etc/suricata.yaml`
   - Download IDS rules
   - Configure interface monitoring

2. **Implement AI Service:**
   - Create Python application
   - Implement ML models
   - Integrate with Loki and Pi-hole

3. **Set Up Threat Intel:**
   - Configure threat feed sources
   - Implement IOC ingestion
   - Create correlation logic

4. **Enable Alerting:**
   - Configure Grafana alerts
   - Set up notification channels (email, Signal, etc.)
   - Define alert thresholds

5. **Integrate with DNS Pi:**
   - Install Promtail on Pi #1
   - Ship DNS logs to this Loki instance
   - Verify logs in Grafana dashboards

---

## Documentation

- **Complete Dashboard Guide:** `docs/logging-and-dashboards.md`
- **Orion Sentinel Architecture:** `docs/ORION_SENTINEL_ARCHITECTURE.md`
- **Integration Guide:** `docs/ORION_SENTINEL_INTEGRATION.md`

---

## Support

For issues or questions:
1. Check `docs/logging-and-dashboards.md` troubleshooting section
2. Review Docker logs: `docker compose logs`
3. Open an issue in the repository

---

**Status:** Ready for deployment (Loki, Grafana, Promtail configured)  
**TODO:** Suricata configuration, AI service implementation, threat intel feeds
