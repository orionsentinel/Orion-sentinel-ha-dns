# Orion Sentinel – NSM & AI Security (orion-sentinel-nsm-ai)

**Passive network security monitoring and AI anomaly detection for home/lab networks**

This repository contains the **Security & Monitoring** component of Orion Sentinel. It runs on a Raspberry Pi 5 with an AI Hat and provides passive network security monitoring, AI-powered anomaly detection, and threat intelligence correlation. Together with [orion-sentinel-dns-ha](https://github.com/yorgosroussakis/rpi-ha-dns-stack) (DNS & Privacy on Pi #1), it forms a complete two-node home defense platform.

---

## Features

- **Suricata IDS** – Network intrusion detection on mirrored LAN traffic (passive monitoring, no inline routing)
- **Loki + Promtail** – Centralized log storage and collection for all security events
- **Grafana Dashboards** – Pre-configured visualizations for alerts, DNS queries, device behavior, and anomalies
- **Threat Intelligence** – Automated ingestion and correlation from feeds (abuse.ch, AlienVault OTX, CISA KEV, etc.)
- **AI Anomaly Detection** – Device behavior analysis and domain risk scoring using machine learning
- **Pi-hole Integration** – Optional API integration to automatically add high-risk domains to DNS blocklists
- **SOAR-lite Automation** – Lightweight security orchestration and automated response (future/ongoing)

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                        Home Network                              │
│                                                                  │
│  ┌──────────────┐                                               │
│  │   Router     │  NAT, Firewall, DHCP                          │
│  │              │  DNS → Pi #1 (VIP)                            │
│  └──────┬───────┘  Port Mirror → Pi #2 eth0                     │
│         │                                                        │
│    ┌────▼──────────────┐                ┌─────────────────────┐│
│    │ Switch (Managed)  │                │                     ││
│    │ Port Mirroring    │                │                     ││
│    └────┬──────┬───────┘                │                     ││
│         │      │                        │                     ││
│         │      └───────────────┐        │                     ││
│         │                      │        │                     ││
│  ┌──────▼────────────┐  ┌──────▼────────▼──────────────────┐ │
│  │  Pi #1: DNS Pi    │  │  Pi #2: Security Pi (THIS REPO) │ │
│  │  192.168.x.251    │  │  192.168.x.100 + Mirror Port    │ │
│  │                   │  │                                  │ │
│  │  ┌─────────────┐  │  │  ┌──────────────────────────┐  │ │
│  │  │ Pi-hole     │──┼──┼─▶│ Loki (Log Storage)       │  │ │
│  │  │ (DNS+Block) │  │API │  │ - Suricata alerts       │  │ │
│  │  └─────────────┘  │  │  │ - DNS logs (from Pi #1) │  │ │
│  │                   │Logs │ - AI anomalies          │  │ │
│  │  ┌─────────────┐  │──┼─▶│ - Threat intel          │  │ │
│  │  │ Unbound     │  │  │  └────────┬─────────────────┘  │ │
│  │  │ (Recursive) │  │  │           │                    │ │
│  │  └─────────────┘  │  │  ┌────────▼─────────────────┐  │ │
│  │                   │  │  │ Grafana (Dashboards)     │  │ │
│  │  orion-sentinel-  │  │  │ - Security Overview      │  │ │
│  │  dns-ha repo      │  │  │ - Threat Intelligence    │  │ │
│  └───────────────────┘  │  └──────────────────────────┘  │ │
│                         │                                  │ │
│                         │  ┌──────────────────────────┐  │ │
│                         │  │ Suricata IDS             │  │ │
│                         │  │ (Passive on mirror port) │  │ │
│                         │  └──────────┬───────────────┘  │ │
│                         │             │                   │ │
│                         │  ┌──────────▼───────────────┐  │ │
│                         │  │ AI Service               │  │ │
│                         │  │ - Device anomaly detect  │  │ │
│                         │  │ - Domain risk scoring    │  │ │
│                         │  │ - Auto-blocking via API  │  │ │
│                         │  └──────────────────────────┘  │ │
│                         │                                  │ │
│                         │  orion-sentinel-nsm-ai repo      │ │
│                         └──────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘

Legend:
─────► Log/data flow
◄───── API calls (block domains)
```

---

## Repo Layout

```
orion-sentinel-nsm-ai/
├── docs/
│   ├── ORION_SENTINEL_ARCHITECTURE.md    # Overall two-Pi architecture
│   ├── ORION_SENTINEL_INTEGRATION.md     # Integration with DNS Pi
│   ├── logging-and-dashboards.md         # Grafana dashboards guide
│   └── ai-stack-setup.md                 # AI service setup (future)
│
├── stacks/
│   ├── nsm/                              # Network Security Monitoring stack
│   │   ├── docker-compose.yml            # Suricata, Loki, Grafana, Promtail
│   │   ├── loki/                         # Loki configuration
│   │   ├── promtail/                     # Log collection config
│   │   ├── grafana-provisioning/         # Auto-loaded dashboards
│   │   ├── suricata/                     # Suricata IDS config
│   │   └── README.md                     # This file
│   │
│   └── ai/                                # AI & Threat Intel stack (future)
│       ├── docker-compose.yml             # AI service, threat intel
│       ├── threat-intel/                  # IOC feeds and correlation
│       ├── ai-service/                    # ML models and scoring
│       └── soar/                          # Automation and response
│
└── README.md                              # Main repository README
```

---

## Quick Start (High-Level)

### 1. Prepare Pi #2 (Security Pi)

- **Hardware:** Raspberry Pi 5 (8GB RAM) with AI Hat
- **OS:** Raspberry Pi OS (64-bit) or Ubuntu Server
- **Network:** Static IP address (e.g., 192.168.8.100)
- **Software:** Docker and Docker Compose installed

```bash
# Install Docker (if not already installed)
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo apt install docker-compose-plugin
```

### 2. Configure Port Mirroring

Configure your managed switch to mirror all LAN traffic to the port connected to Pi #2:

- **Source ports:** All LAN ports
- **Destination port:** Port connected to Pi #2 (e.g., port 8)
- **Direction:** Both ingress and egress
- **Mode:** Passive monitoring (read-only)

This allows Suricata to see all network traffic without being inline.

### 3. Clone Repository and Configure

```bash
# Clone this repository
git clone https://github.com/yorgosroussakis/orion-sentinel-nsm-ai.git
cd orion-sentinel-nsm-ai/stacks/nsm

# Copy and edit environment variables
cp .env.example .env
nano .env  # Set NSM_IFACE, GRAFANA_ADMIN_PASSWORD, etc.
```

**Key environment variables:**

```bash
# Network interface receiving mirrored traffic
NSM_IFACE=eth0  # Or the interface connected to your switch mirror port

# Grafana admin credentials
GRAFANA_ADMIN_PASSWORD=your-secure-password

# Optional: Pi-hole API for auto-blocking (from DNS Pi)
PIHOLE_API_URL=http://192.168.8.251/admin/api.php
PIHOLE_API_TOKEN=your-api-token
```

### 4. Start NSM Stack

```bash
# Start Loki, Grafana, Promtail, Suricata
docker compose up -d

# Check all services are running
docker compose ps

# View logs
docker compose logs -f
```

### 5. Access Grafana Dashboards

1. Open browser: `http://<pi2-ip>:3000` (e.g., `http://192.168.8.100:3000`)
2. Login with credentials from `.env`
3. Navigate to **Dashboards** → **Security** folder
4. Open **Orion Sentinel – Security Overview**

You should see panels for Suricata alerts, DNS queries (once integrated), AI anomalies, and threat intel.

### 6. (Optional) Start AI Stack

Once you have ML models trained and Pi-hole API configured:

```bash
cd ../ai
docker compose up -d
```

See `docs/ai-stack-setup.md` for AI service configuration (future documentation).

---

## Components (NSM Stack)

This section describes the services in `stacks/nsm/` (Network Security Monitoring stack).

### Loki (Port 3100)

Centralized log storage with:
- 30-day log retention
- Automatic log compaction
- Optimized for Raspberry Pi performance

**Configuration:** `loki/loki-config.yaml`

**Log Streams:**
- Suricata IDS alerts and events
- DNS queries from Pi #1 (Pi-hole, Unbound)
- AI service output (device anomalies, domain risk)
- Threat intelligence (IOCs, matches, digests)

### Promtail (Port 9080)

Collects logs from:
- Suricata EVE JSON logs (`/var/log/suricata/eve.json`)
- AI service output (`/var/log/ai-service/`)
- Threat intelligence feeds (`/var/log/threat-intel/`)
- Docker containers (optional)

**Configuration:** `promtail/promtail-config.yaml`

Ships all logs to Loki for storage and querying.

### Grafana (Port 3000)

Pre-configured with:
- Loki datasource (auto-provisioned)
- Security Overview dashboard (20 panels)
- Threat Intelligence dashboard (15 panels)

**Provisioning:** `grafana-provisioning/`

Dashboards auto-load on startup. See `docs/logging-and-dashboards.md` for full panel descriptions and LogQL query examples.

### Suricata (Network Mode: Host)

Network IDS running in **passive mode**:
- Monitors mirrored network traffic (port mirroring required)
- Generates alerts for suspicious activity (malware, exploits, C2, etc.)
- Logs to EVE JSON format for easy parsing

**Configuration:** `suricata/etc/` (to be created)  
**Logs:** `suricata/logs/eve.json`

**Status:** Service configured, needs IDS rules and interface tuning.

### AI Service (Future - stacks/ai/)

Machine learning service for:
- **Device behavior anomaly detection:** Identifies unusual patterns in network activity per device
- **Domain risk scoring:** ML-based classification of queried domains as benign/suspicious/malicious
- **Automated threat response:** Calls Pi-hole API to block high-risk domains

**Status:** Placeholder service in `stacks/nsm/docker-compose.yml`. Full implementation in `stacks/ai/` directory (future work).

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

## Working with orion-sentinel-dns-ha

This repository (orion-sentinel-nsm-ai) handles **Security & Monitoring** on Pi #2. The DNS & Privacy layer runs on Pi #1 using the [orion-sentinel-dns-ha](https://github.com/yorgosroussakis/rpi-ha-dns-stack) repository.

### What Lives Where

| Component | Repository | Pi | Purpose |
|-----------|------------|-----|---------|
| **DNS & Privacy** | [orion-sentinel-dns-ha](https://github.com/yorgosroussakis/rpi-ha-dns-stack) | Pi #1 | Pi-hole, Unbound, Keepalived VIP, DNS query logging |
| **Security & Monitoring** | **orion-sentinel-nsm-ai** (this repo) | Pi #2 | Suricata IDS, Loki, Grafana, AI, Threat Intel |

### Integration Points

**1. DNS Logs → Security Pi**

DNS query logs from Pi #1 (Pi-hole and Unbound) are shipped to Loki on Pi #2 via Promtail:

- Install Promtail on Pi #1 (see `docs/ORION_SENTINEL_INTEGRATION.md`)
- Configure to send logs to `http://<pi2-ip>:3100/loki/api/v1/push`
- Logs appear in Grafana dashboards under DNS Activity panels

**2. Pi-hole API ← Security Pi**

The AI service on Pi #2 can automatically block high-risk domains by calling Pi-hole's API on Pi #1:

- Get API token from Pi-hole UI: Settings → API → Show API token
- Set `PIHOLE_API_URL` and `PIHOLE_API_TOKEN` in `.env`
- AI service blocks domains with risk score > threshold

**3. Together They Form a Two-Node Home Defense Platform**

```
┌───────────────────────────────────────────────────┐
│          Orion Sentinel Platform                  │
├───────────────────────────────────────────────────┤
│                                                   │
│  Pi #1 (DNS Pi)              Pi #2 (Security Pi) │
│  ┌──────────────┐            ┌──────────────┐   │
│  │ DNS Privacy  │───Logs────▶│ NSM + AI     │   │
│  │ & Blocking   │◀───Block───│ Monitoring   │   │
│  └──────────────┘    API     └──────────────┘   │
│                                                   │
│  • Ad blocking               • IDS alerts        │
│  • Recursive DNS             • Anomaly detect    │
│  • High availability         • Threat intel      │
│  • Query logging             • Auto-response     │
└───────────────────────────────────────────────────┘
```

**Benefits of Two-Node Design:**

- **Separation of concerns:** DNS on Pi #1, security on Pi #2
- **Performance:** Each Pi dedicated to its role
- **Resilience:** DNS stays up even if security monitoring is down
- **Scalability:** Add more security nodes or DNS nodes independently

---

## Status / Roadmap

### ✅ Completed

- **NSM Foundation:** Loki + Promtail + Grafana stack configured
- **Dashboards:** Security Overview and Threat Intelligence dashboards with 35 panels
- **Suricata Placeholder:** Docker service ready, needs rules and configuration
- **Documentation:** Architecture, integration, and dashboard guides

### 🚧 In Progress

- **Threat Intel Module:** IOC feeds (abuse.ch, OTX, CISA KEV), correlation engine
- **AI Anomaly Detection:** Device behavior models, domain risk scoring
- **Suricata Configuration:** IDS rules, interface tuning, alert optimization

### 📅 Future / Ongoing

- **SOAR-lite Automation:** Automated response playbooks, webhook integration
- **Advanced ML Models:** Transformer-based models for behavior analysis
- **Real-time Packet Capture:** On-demand PCAP for investigations
- **Multi-site Support:** VPN mesh for distributed monitoring

**Note:** This is a home/lab security project. Features are implemented as needed and contributions are welcome!

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

## Next Steps After Deployment

Once the NSM stack is running:

1. **Configure Suricata IDS:**
   - Download and install IDS rules (e.g., Emerging Threats, Snort rules)
   - Tune `suricata.yaml` for your network interface and traffic volume
   - Test alert generation with EICAR or other test patterns

2. **Integrate DNS Pi (Pi #1):**
   - Install Promtail on DNS Pi to ship Pi-hole and Unbound logs
   - Configure to send to `http://<pi2-ip>:3100/loki/api/v1/push`
   - Verify DNS query logs appear in Grafana dashboards
   - See `docs/ORION_SENTINEL_INTEGRATION.md` for detailed steps

3. **Implement AI Service (stacks/ai/):**
   - Train ML models for device behavior baselines
   - Implement domain risk scoring algorithm
   - Configure Pi-hole API integration for auto-blocking
   - See `docs/ai-stack-setup.md` (future documentation)

4. **Set Up Threat Intelligence:**
   - Configure IOC feed sources (abuse.ch, OTX, CISA KEV, etc.)
   - Implement correlation engine to match IOCs with your logs
   - Add IOC and match streams to Loki
   - Monitor via Threat Intelligence dashboard

5. **Enable Alerting:**
   - Configure Grafana alert rules (high alert rate, critical anomalies, etc.)
   - Set up notification channels (email, Slack, Signal, etc.)
   - Define escalation policies and on-call schedules

6. **Harden and Optimize:**
   - Review security settings and credentials
   - Tune resource limits based on actual usage
   - Set up automated backups for Grafana dashboards and Loki data
   - Document your customizations

---

## Documentation

Full documentation is available in the `docs/` directory:

- **`ORION_SENTINEL_ARCHITECTURE.md`** – Overall two-Pi architecture and data flows
- **`ORION_SENTINEL_INTEGRATION.md`** – Integrating DNS Pi logs with Security Pi
- **`logging-and-dashboards.md`** – Complete Grafana dashboard guide with LogQL examples
- **`ai-stack-setup.md`** – AI service configuration (future)

---

## Support and Contributing

**For issues or questions:**
1. Check the troubleshooting sections in this README and `docs/logging-and-dashboards.md`
2. Review Docker logs: `docker compose logs <service>`
3. Open an issue in the GitHub repository

**Contributions welcome!** This is an open-source home/lab security project. If you've implemented features (AI models, threat intel feeds, SOAR playbooks, etc.), consider contributing back.

---

**Repository:** [orion-sentinel-nsm-ai](https://github.com/yorgosroussakis/orion-sentinel-nsm-ai)  
**Companion Repo:** [orion-sentinel-dns-ha](https://github.com/yorgosroussakis/rpi-ha-dns-stack) (DNS & Privacy on Pi #1)  
**Status:** Foundation ready (Loki, Grafana, Promtail, Suricata placeholder)  
**Next:** Suricata rules, AI service, threat intel feeds
