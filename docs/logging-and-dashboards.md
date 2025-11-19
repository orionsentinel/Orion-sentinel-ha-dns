# Logging and Dashboards - Orion Sentinel

**Complete guide to Grafana dashboards, Loki logging, and observability for the Orion Sentinel security platform**

---

## Overview

The Orion Sentinel NSM (Network Security Monitoring) stack provides comprehensive logging and visualization for:

- **Suricata IDS alerts** – Network intrusion detection events
- **DNS queries** – Pi-hole and Unbound logs from the DNS Pi
- **AI anomaly detection** – Device behavior and domain risk scoring
- **Threat intelligence** – IOCs, matches, and community intel digests

All logs are centralized in **Loki** and visualized through pre-configured **Grafana dashboards**.

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                    Orion Sentinel Logging Stack                  │
└──────────────────────────────────────────────────────────────────┘

┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Suricata      │────▶│                 │     │                 │
│   (IDS Alerts)  │     │                 │     │                 │
└─────────────────┘     │                 │     │                 │
                        │                 │     │                 │
┌─────────────────┐     │    Promtail     │────▶│      Loki       │
│   Pi-hole       │────▶│  (Log Shipper)  │     │  (Log Storage)  │
│   (DNS Logs)    │     │                 │     │                 │
└─────────────────┘     │                 │     │                 │
                        │                 │     │                 │
┌─────────────────┐     │                 │     │                 │
│   AI Service    │────▶│                 │     │                 │
│   (Anomalies)   │     └─────────────────┘     └────────┬────────┘
└─────────────────┘                                       │
                                                          │
┌─────────────────┐                                       │
│  Threat Intel   │                                       │
│  (IOCs/Matches) │───────────────────────────────────────┘
└─────────────────┘                                       │
                                                          ▼
                                               ┌─────────────────────┐
                                               │      Grafana        │
                                               │   (Dashboards)      │
                                               └─────────────────────┘
```

---

## Directory Structure

```
stacks/nsm/
├── docker-compose.yml                    # NSM stack services
├── grafana-provisioning/
│   ├── datasources/
│   │   └── orion-loki.yml               # Loki datasource config
│   └── dashboards/
│       ├── orion-sentinel.yml           # Dashboard provider config
│       ├── orion-sentinel-overview.json # Main security dashboard
│       └── orion-sentinel-threat-intel.json # Threat intel dashboard
├── loki/
│   └── loki-config.yaml                 # Loki configuration (to be created)
├── promtail/
│   └── promtail-config.yaml             # Promtail configuration (to be created)
├── suricata/
│   ├── etc/                             # Suricata configuration
│   ├── logs/                            # Suricata log output
│   └── rules/                           # Suricata IDS rules
└── ai-service/
    ├── Dockerfile                       # AI service container
    ├── models/                          # ML models
    └── config/                          # AI service config
```

---

## Grafana Provisioning

### How It Works

Grafana automatically loads datasources and dashboards on startup using **provisioning files**:

1. **Datasources** (`grafana-provisioning/datasources/orion-loki.yml`)
   - Defines connection to Loki
   - Uses environment variable `${LOKI_URL}` for flexibility
   - Default: `http://loki:3100` (Docker internal URL)

2. **Dashboard Provider** (`grafana-provisioning/dashboards/orion-sentinel.yml`)
   - Points to directory containing dashboard JSON files
   - Creates "Security" folder in Grafana UI
   - Dashboards are editable but not deletable

3. **Dashboard JSON Files**
   - Pre-configured panels and queries
   - Automatically imported on Grafana startup
   - Located in `/var/lib/grafana/dashboards/orion-sentinel` (inside container)

### Changing the Loki URL

To use a different Loki instance:

**Option 1: Environment Variable (Recommended)**

Edit `.env` or set in your environment:

```bash
export LOKI_URL=http://192.168.8.100:3100
```

Then restart Grafana:

```bash
cd stacks/nsm
docker compose restart grafana
```

**Option 2: Edit Provisioning File**

Edit `grafana-provisioning/datasources/orion-loki.yml`:

```yaml
datasources:
  - name: Loki
    type: loki
    url: http://192.168.8.100:3100  # Change this
```

Then restart Grafana.

---

## Dashboards

### 1. Orion Sentinel – Security Overview

**File:** `orion-sentinel-overview.json`

**Purpose:** Main dashboard showing real-time security posture across all components.

**Panels:**

#### Suricata IDS Alerts
- **Alerts Over Time (by Severity)** – Time series chart showing critical/high/medium/low alerts
  - *Question answered:* "Are we currently under attack?"
  - Query: `sum by (alert_severity) (count_over_time({service="suricata", event_type="alert"} | json [5m]))`

- **Top Alert Signatures** – Bar chart of most-triggered IDS rules
  - *Question answered:* "What are the most common threats?"
  - Query: `topk(10, sum by (alert_signature) (count_over_time({service="suricata", event_type="alert"} | json [$__range])))`

- **Top Talkers (Source IPs)** – Table of most active source IPs
  - *Question answered:* "Which devices are generating the most traffic?"
  - Query: `topk(15, sum by (src_ip) (count_over_time({service="suricata"} | json | src_ip != "" [24h])))`

- **Recent Critical Alerts** – Live table of high/critical severity alerts
  - *Question answered:* "What just happened?"

#### DNS Activity
- **Top Queried Domains** – Most frequently queried domains (last 24h)
  - *Question answered:* "What are users accessing most?"
  - Query: `topk(20, sum by (query) (count_over_time({service="pihole"} | json | query != "" [24h])))`

- **Top DNS Clients** – Devices making the most DNS queries
  - *Question answered:* "Which devices are most active?"
  - Query: `topk(15, sum by (client_ip) (count_over_time({service="pihole"} | json | client_ip != "" [24h])))`

#### AI Anomaly Detection
- **Top Suspicious Devices** – Devices with highest anomaly scores
  - *Question answered:* "Which devices are behaving abnormally?"
  - Query: `topk(10, max by (device_ip) (max_over_time({service="ai-device-anomaly"} | json | unwrap anomaly_score [24h])))`

- **Device Anomaly Scores Over Time** – Time series of anomaly scores per device
  - *Question answered:* "How is device behavior trending?"

- **High-Risk Domains** – Domains with elevated risk scores from AI analysis
  - *Question answered:* "What domains should we be concerned about?"
  - Query: `{service="ai-domain-risk"} | json | risk_score > 0.6`

#### Threat Intelligence
- **Recent Threat Intel IOCs** – Latest indicators of compromise from feeds
  - *Question answered:* "What new threats have been identified?"
  - Query: `{stream="intel_iocs"} | json`

- **Threat Intel Matches** – IOCs that matched activity in our environment
  - *Question answered:* "Are we seeing known threats?"
  - Query: `{stream="intel_match"} | json`

- **Community Intel Digest** – Aggregated threat intelligence summary (markdown panel)
  - *Question answered:* "What's happening in the threat landscape?"

#### System Health
- **Suricata Alert Rate** – Alerts per hour (stat panel with thresholds)
- **DNS Queries** – Total queries in last hour
- **AI Anomalies Detected** – Count of high-score anomalies

**Default Time Range:** Last 24 hours  
**Refresh Rate:** 30 seconds  
**Best For:** NOC/SOC monitoring, incident response

---

### 2. Orion Sentinel – Threat Intelligence

**File:** `orion-sentinel-threat-intel.json`

**Purpose:** Detailed view of threat intelligence feeds, IOCs, and correlation.

**Panels:**

#### IOC Overview
- **IOC Ingestion Timeline** – Time series of IOCs ingested by source
  - *Question answered:* "Which intel sources are most active?"

- **IOCs by Type** – Pie chart of IP addresses, domains, URLs, hashes, etc.
  - *Question answered:* "What types of threats are we tracking?"

- **All Threat Intel IOCs** – Filterable table with all IOCs
  - Columns: IOC Value, Type, Source, Confidence, First Seen, Last Seen, Tags
  - *Question answered:* "What are all the known bad indicators?"

#### Environment Correlation
- **Intel Matches Timeline** – Time series of matches by IOC type
  - *Question answered:* "How often are we matching known threats?"

- **Matches by Source** – Bar gauge showing which intel sources are catching threats
  - *Question answered:* "Which intel feeds are most valuable?"

- **All Intel Matches** – Detailed table of all correlations
  - Columns: Match Time, IOC Value, Type, Source, Device IP, Service, Confidence
  - *Question answered:* "What threats have we actually seen?"

#### Community Intel
- **Latest Community Digest** – Full markdown rendering of aggregated intel summary
  - *Question answered:* "What should we be watching for?"

#### Statistics
- **Total IOCs (Last 7 Days)** – Count of all tracked indicators
- **Total Matches (Last 24h)** – Matches found in environment
- **Unique Threat Sources** – Number of different intel feeds
- **Match Rate** – Matches per minute

**Default Time Range:** Last 7 days  
**Refresh Rate:** 1 minute  
**Variables:** Filter by intel source or IOC type  
**Best For:** Threat hunting, intel feed evaluation

---

## Log Streams and Labels

### Expected Loki Streams

The dashboards expect logs with these **label combinations**:

#### 1. Suricata Logs
```
{service="suricata", pi="pi2-security", event_type="alert"}
{service="suricata", pi="pi2-security", event_type="flow"}
```

**JSON fields:** `timestamp`, `src_ip`, `dest_ip`, `proto`, `alert.signature`, `alert.severity`, `alert.category`

#### 2. Pi-hole DNS Logs
```
{service="pihole", pi="pi1-dns"}
```

**JSON fields:** `timestamp`, `client_ip`, `query`, `type`, `status`, `reply`

#### 3. Unbound DNS Logs
```
{service="unbound", pi="pi1-dns"}
```

**Log format:** Text logs with domain queries and results

#### 4. AI Device Anomaly Logs
```
{service="ai-device-anomaly", pi="pi2-security"}
```

**JSON fields:** `device_ip`, `window_start`, `window_end`, `anomaly_score`, `features`

#### 5. AI Domain Risk Logs
```
{service="ai-domain-risk", pi="pi2-security"}
```

**JSON fields:** `domain`, `risk_score`, `first_seen`, `last_seen`, `features`

#### 6. Threat Intel IOCs
```
{stream="intel_iocs", source="<feed_name>", ioc_type="<type>", pi="pi2-security"}
```

**JSON fields:** `value`, `type`, `source`, `confidence`, `tags`, `first_seen`, `last_seen`

#### 7. Threat Intel Matches
```
{stream="intel_match", source="<feed_name>", ioc_type="<type>", service="<service>", pi="pi2-security"}
```

**JSON fields:** `ioc_value`, `ioc_type`, `source`, `device_ip`, `match_time`, `log_ref`, `confidence`

#### 8. Community Intel Digest
```
{stream="community_intel_digest", pi="pi2-security"}
```

**JSON fields:** `time_range`, `sources`, `keywords`, `summary_markdown`, `summary_text`

---

## Customizing Panels

### Editing Queries

All panels use **LogQL** (Loki Query Language):

**Basic Examples:**

```logql
# Get all Suricata alerts
{service="suricata", event_type="alert"}

# Filter by severity
{service="suricata", event_type="alert"} | json | alert_severity="critical"

# Count over time
sum(count_over_time({service="suricata"} [5m]))

# Group by field
sum by (alert_signature) (count_over_time({service="suricata"} [1h]))

# Extract numeric values
{service="ai-device-anomaly"} | json | unwrap anomaly_score

# Regex filtering
{service="pihole"} |~ ".*malware.*"
```

**Advanced Examples:**

```logql
# Top N with label filtering
topk(10, sum by (src_ip) (count_over_time({service="suricata", alert_severity="high"} [24h])))

# Multiple services
{service=~"suricata|pihole"} | json

# Line formatting for tables
{stream="intel_match"} | json | line_format "{{.match_time}} | {{.ioc_value}} | {{.device_ip}}"

# Conditional filtering
{service="ai-domain-risk"} | json | risk_score > 0.7
```

### Adding New Panels

1. Open Grafana UI: `http://<pi2-ip>:3000`
2. Navigate to the dashboard
3. Click "Add panel" → "Add a new panel"
4. Configure:
   - **Data source:** Loki
   - **Query:** Your LogQL expression
   - **Visualization:** Choose type (table, time series, stat, etc.)
   - **Panel options:** Title, description, legend
5. Click "Apply"
6. Save dashboard
7. Export JSON and save to `grafana-provisioning/dashboards/`

### Modifying Thresholds

Example: Change anomaly score warning threshold from 0.6 to 0.7:

Edit the dashboard JSON, find the panel, and modify:

```json
"thresholds": {
  "mode": "absolute",
  "steps": [
    {"value": null, "color": "green"},
    {"value": 0.7, "color": "yellow"},   // Changed from 0.6
    {"value": 0.8, "color": "red"}
  ]
}
```

---

## Deployment

### Starting the Stack

```bash
cd stacks/nsm
docker compose up -d
```

### Accessing Grafana

1. Open browser: `http://<pi2-ip>:3000`
2. Login:
   - Username: `admin` (or value of `GRAFANA_ADMIN_USER`)
   - Password: `changeme` (or value of `GRAFANA_ADMIN_PASSWORD`)
3. Navigate to **Dashboards** → **Security** folder
4. Open "Orion Sentinel – Security Overview"

### Verifying Loki

```bash
# Check Loki is running
curl http://localhost:3100/ready

# Query logs manually
curl -G -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={service="suricata"}' \
  | jq .

# Check label values
curl -s "http://localhost:3100/loki/api/v1/label/service/values" | jq .
```

---

## Troubleshooting

### No Data in Dashboards

**Symptoms:** Dashboards load but show "No data"

**Solutions:**

1. **Verify Loki is receiving logs:**
   ```bash
   # Check Promtail is shipping logs
   docker logs orion-promtail | grep -i "sent"
   
   # Query Loki directly
   curl "http://localhost:3100/loki/api/v1/label/service/values"
   # Should return: ["suricata", "pihole", ...]
   ```

2. **Check log file paths:**
   - Promtail must have access to log files
   - Verify volume mounts in `docker-compose.yml`
   - Check Promtail config: `stacks/nsm/promtail/promtail-config.yaml`

3. **Verify label names match:**
   - Dashboard queries use `{service="suricata"}`
   - Promtail config must add matching labels
   - Check Promtail config's `scrape_configs.static_configs.labels`

### Dashboard Panels Show Errors

**Symptoms:** "Error executing query" or "Failed to parse query"

**Solutions:**

1. **Check LogQL syntax:**
   - Use Grafana's "Explore" page to test queries
   - Ensure label names are quoted: `{service="suricata"}`
   - Check for typos in field names after `| json`

2. **Verify data source:**
   - Go to Configuration → Data sources → Loki
   - Click "Test" button
   - Should show "Data source is working"

3. **Check Loki logs:**
   ```bash
   docker logs orion-loki | grep -i "error"
   ```

### Slow Dashboard Performance

**Symptoms:** Dashboards take long to load or timeout

**Solutions:**

1. **Reduce time range:**
   - Use shorter time windows (e.g., 6h instead of 24h)
   - Increase refresh interval (5m instead of 30s)

2. **Optimize queries:**
   - Use `count_over_time` instead of raw log queries
   - Add more specific label filters
   - Limit results with `topk()` or `bottomk()`

3. **Increase Loki resources:**
   - Edit `docker-compose.yml`:
     ```yaml
     loki:
       deploy:
         resources:
           limits:
             memory: 2G  # Increase from 1G
     ```

### Dashboards Not Auto-Loading

**Symptoms:** Dashboards don't appear after Grafana restart

**Solutions:**

1. **Check provisioning mounts:**
   ```bash
   docker exec orion-grafana ls -la /etc/grafana/provisioning/dashboards
   # Should show orion-sentinel.yml
   
   docker exec orion-grafana ls -la /var/lib/grafana/dashboards/orion-sentinel
   # Should show *.json files
   ```

2. **Check Grafana logs:**
   ```bash
   docker logs orion-grafana | grep -i "provision"
   # Should show: "Provisioning dashboards from configuration"
   ```

3. **Verify YAML syntax:**
   ```bash
   # Check provisioning file syntax
   cat grafana-provisioning/dashboards/orion-sentinel.yml
   # Ensure proper YAML formatting
   ```

---

## Best Practices

### 1. Data Retention

Configure Loki retention to balance storage and investigation needs:

```yaml
# loki-config.yaml
limits_config:
  retention_period: 30d  # Keep logs for 30 days

table_manager:
  retention_deletes_enabled: true
  retention_period: 720h  # 30 days in hours
```

### 2. Alert Rules

Create Grafana alert rules for critical conditions:

- Suricata alert rate > 100/hour
- AI anomaly score > 0.9 for any device
- Threat intel matches detected
- Log ingestion lag > 5 minutes

### 3. Dashboard Organization

- **Security Overview:** For 24/7 NOC monitoring (keep on wall display)
- **Threat Intel:** For threat hunting and investigation
- Create additional dashboards for specific use cases (e.g., DNS deep-dive)

### 4. Query Optimization

- Use specific label filters: `{service="suricata", event_type="alert"}` instead of `{service="suricata"}`
- Limit time ranges for heavy queries
- Use aggregation (`sum`, `count_over_time`) instead of raw logs when possible
- Cache results by setting appropriate refresh intervals

### 5. Backup Dashboards

Periodically export dashboards as JSON:

```bash
# From Grafana UI: Dashboard settings → JSON Model → Copy
# Or use Grafana API:
curl -H "Authorization: Bearer <api-key>" \
  http://localhost:3000/api/dashboards/uid/orion-sentinel-overview \
  | jq . > backup-overview-$(date +%Y%m%d).json
```

---

## Integration with DNS Pi

To ship DNS logs from Pi #1 to the NSM stack on Pi #2:

1. **Install Promtail on DNS Pi** (Pi #1):
   - See `docs/ORION_SENTINEL_INTEGRATION.md` for detailed setup

2. **Configure Promtail to ship to Loki on Pi #2:**
   ```yaml
   clients:
     - url: http://<pi2-ip>:3100/loki/api/v1/push
   
   scrape_configs:
     - job_name: pihole
       static_configs:
         - labels:
             service: pihole
             pi: pi1-dns
   ```

3. **Verify logs arrive:**
   ```bash
   # On Pi #2
   curl "http://localhost:3100/loki/api/v1/label/pi/values"
   # Should include: pi1-dns, pi2-security
   ```

---

## Further Resources

- **Grafana Documentation:** https://grafana.com/docs/grafana/latest/
- **Loki Documentation:** https://grafana.com/docs/loki/latest/
- **LogQL Query Language:** https://grafana.com/docs/loki/latest/logql/
- **Orion Sentinel Architecture:** See `docs/ORION_SENTINEL_ARCHITECTURE.md`
- **NSM Integration Guide:** See `docs/ORION_SENTINEL_INTEGRATION.md`

---

## Summary

You now have:

✅ **Automated Grafana provisioning** for datasources and dashboards  
✅ **Pre-configured security dashboards** for Suricata, DNS, AI, and threat intel  
✅ **Centralized logging** with Loki for all security events  
✅ **Real-time visualization** of your home SOC environment  
✅ **Documentation** for customization and troubleshooting  

**Next Steps:**
1. Configure Loki and Promtail (create config files)
2. Start the NSM stack: `docker compose up -d`
3. Access Grafana and explore the dashboards
4. Customize panels based on your specific needs
5. Set up alerting for critical conditions

---

*For questions or issues, refer to the main repository documentation or open an issue.*
