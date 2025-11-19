# Orion Sentinel Architecture

**Complete Overview of the Two-Pi Security Platform**

---

## Executive Summary

**Orion Sentinel** is a home/lab security platform built on two Raspberry Pis working together to provide privacy-focused DNS, network security monitoring, and AI-powered threat detection.

### The Two Repositories

| Repository | Focus | Hardware | Key Technologies |
|------------|-------|----------|------------------|
| **orion-sentinel-dns-ha**<br>(THIS REPO) | DNS & Privacy<br>High Availability | Pi #1 (+ optional Pi #2 for HA) | Pi-hole, Unbound, Keepalived |
| **orion-sentinel-nsm-ai**<br>(Separate repo) | Network Security<br>AI Detection | Pi #2 (Raspberry Pi 5 + AI Hat) | Suricata, Loki, Grafana, AI models |

---

## Physical Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                        Home Network                              │
│                                                                  │
│  ┌──────────────┐                                               │
│  │   Router     │  NAT, Firewall, DHCP, VPN                     │
│  │  (GL.iNet)   │  DNS → 192.168.x.255 (VIP)                    │
│  │              │  Port Mirror → Pi #2 eth0                     │
│  └──────┬───────┘                                               │
│         │                                                        │
│         │                                                        │
│  ┌──────▼─────────────────┐      ┌────────────────────────┐   │
│  │  Pi #1: DNS Pi         │      │  Pi #2: Security Pi    │   │
│  │  192.168.x.251         │      │  192.168.x.252 + Mirror│   │
│  │                        │      │                        │   │
│  │  orion-sentinel-dns-ha │      │  orion-sentinel-nsm-ai │   │
│  │                        │      │                        │   │
│  │  ┌─────────────────┐   │ Logs │  ┌──────────────────┐  │   │
│  │  │ Pi-hole         │───┼─────►│  │ Loki             │  │   │
│  │  │ (Ad blocking)   │   │      │  │ (Log storage)    │  │   │
│  │  └────────┬────────┘   │      │  └────────┬─────────┘  │   │
│  │           │            │      │           │            │   │
│  │  ┌────────▼────────┐   │      │  ┌────────▼─────────┐  │   │
│  │  │ Unbound         │   │      │  │ Grafana          │  │   │
│  │  │ (Recursive DNS) │   │      │  │ (Dashboards)     │  │   │
│  │  └─────────────────┘   │      │  └──────────────────┘  │   │
│  │                        │      │                        │   │
│  │  ┌─────────────────┐   │      │  ┌──────────────────┐  │   │
│  │  │ Keepalived      │   │  API │  │ Suricata IDS     │  │   │
│  │  │ VIP: .255       │   │◄─────┤  │ (Passive mode)   │  │   │
│  │  └─────────────────┘   │Block │  └────────┬─────────┘  │   │
│  │                        │Domain│           │            │   │
│  │  ┌─────────────────┐   │      │  ┌────────▼─────────┐  │   │
│  │  │ Prometheus      │   │      │  │ AI Service       │  │   │
│  │  │ Grafana         │   │      │  │ (Anomaly detect) │  │   │
│  │  └─────────────────┘   │      │  └──────────────────┘  │   │
│  └────────────────────────┘      └────────────────────────┘   │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘

Legend:
─────►  Log shipping (Promtail to Loki)
◄─────  API calls (Block risky domains)
```

---

## Data Flows

### 1. DNS Query Flow (Normal Operation)

```
Client Device
    │
    │ DNS Query
    ▼
Router (configured with VIP as DNS)
    │
    │ Forward to VIP
    ▼
Keepalived VIP (192.168.x.255)
    │
    │ Routes to active Pi-hole
    ▼
Pi-hole (on Pi #1)
    │
    ├─ Ad/Tracker? → Block & return NXDOMAIN
    │
    └─ Legitimate → Forward to Unbound
           │
           ▼
       Unbound (on Pi #1)
           │
           │ Recursive query to root servers
           │ DNSSEC validation
           ▼
       Internet DNS Root Servers
           │
           ▼
       Response back to client
```

### 2. DNS Log Flow (Security Monitoring)

```
Pi-hole (on Pi #1)
    │
    │ Query logs written to disk/DB
    ▼
Promtail (on Pi #1)
    │
    │ Tail logs, add labels
    │ (service=pihole, pi=pi1-dns)
    ▼
Loki HTTP endpoint (on Pi #2)
    │
    │ Store logs with labels
    ▼
AI Service (on Pi #2)
    │
    │ Read logs via Loki API
    │ Extract features (domain length, entropy, etc.)
    │ Run ML models
    ▼
Domain Risk Assessment
    │
    ├─ High Risk → Call Pi-hole API to block
    │                   │
    │                   ▼
    │              Pi-hole (on Pi #1)
    │              Add to custom blocklist
    │
    └─ Low Risk → Log to Loki, no action
```

### 3. Network Traffic Flow (IDS Monitoring)

```
Network Switch/Router
    │
    │ Port mirroring enabled
    ▼
Pi #2 eth0 (mirrored traffic)
    │
    │ Passive listening
    ▼
Suricata IDS (on Pi #2)
    │
    │ Packet analysis
    │ Protocol detection
    │ Alert generation
    ▼
eve.json logs
    │
    ▼
Promtail (on Pi #2)
    │
    │ Ship to Loki
    ▼
Loki + Grafana (on Pi #2)
    │
    │ Visualize alerts
    │ Dashboards
    ▼
AI Service (on Pi #2)
    │
    │ Correlate with DNS logs
    │ Device behavior analysis
    ▼
Anomaly Detection
```

---

## Component Responsibilities

### Pi #1: DNS Pi (orion-sentinel-dns-ha)

**Primary Role:** Provide fast, private, highly-available DNS for all network clients

**Services:**
- **Pi-hole**: Ad/tracker blocking, DNS query logging, Web UI
- **Unbound**: Recursive DNS resolver with DNSSEC
- **Keepalived**: VIP management for high availability
- **Prometheus**: Metrics collection
- **Grafana**: DNS analytics dashboards (optional)

**Exposed Interfaces:**
- DNS on VIP (UDP/TCP 53)
- Pi-hole Web UI (HTTP 80/443)
- Pi-hole API (HTTP for automation)
- Prometheus metrics (HTTP 9090)
- Log files for shipping

**Resource Requirements:**
- CPU: Low (recursive DNS caching helps)
- RAM: 2-4GB sufficient
- Storage: 16GB+ for logs
- Network: Gigabit Ethernet

### Pi #2: Security Pi (orion-sentinel-nsm-ai)

**Primary Role:** Monitor network traffic, detect anomalies, block threats

**Services:**
- **Suricata**: IDS in passive mode on mirrored interface
- **Loki**: Centralized log storage (NSM + DNS logs)
- **Grafana**: Security dashboards and visualizations
- **Promtail**: Log collector and shipper
- **AI Service**: Python app for ML-based detection
- **Zeek** (optional): Rich protocol logging

**Exposed Interfaces:**
- Grafana dashboards (HTTP 3000)
- Loki HTTP API (for log queries)
- AI service API (optional, for status)

**Resource Requirements:**
- CPU: Medium-High (IDS + AI inference)
- RAM: 8GB recommended (Raspberry Pi 5)
- Storage: 64GB+ SSD (logs grow quickly)
- Network: Gigabit Ethernet + port mirroring
- AI Hat: ~13 TOPS for ML inference

---

## Integration Points

### 1. DNS Log Shipping

**From:** Pi #1 (DNS Pi)  
**To:** Pi #2 (Security Pi)  
**Method:** Promtail → Loki HTTP

**Setup on Pi #1:**
```yaml
# Add Promtail service to ship logs
services:
  promtail:
    image: grafana/promtail:latest
    volumes:
      - /var/lib/docker/volumes/pihole_primary/_data/pihole.log:/var/log/pihole.log:ro
      - ./promtail-config.yml:/etc/promtail/config.yml
    command: -config.file=/etc/promtail/config.yml
```

**Promtail Config:**
```yaml
clients:
  - url: http://<pi2-ip>:3100/loki/api/v1/push

scrape_configs:
  - job_name: pihole
    static_configs:
      - targets:
          - localhost
        labels:
          job: pihole
          pi: pi1-dns
          service: pihole
    pipeline_stages:
      - regex:
          expression: '^(?P<timestamp>\w+ \d+ \d+:\d+:\d+) (?P<message>.*)$'
```

### 2. Pi-hole API for Blocking

**From:** Pi #2 AI Service  
**To:** Pi #1 Pi-hole API  
**Method:** HTTP REST API

**Pi-hole API Endpoints:**
```
# Add domain to blocklist
POST http://<pi1-ip>/admin/api.php?list=black&add=<domain>&auth=<token>

# Remove domain from blocklist
POST http://<pi1-ip>/admin/api.php?list=black&sub=<domain>&auth=<token>

# Get API token from Pi-hole UI:
# Settings → API → Show API token
```

**Python Example (on Pi #2):**
```python
import requests

class PiHoleClient:
    def __init__(self, base_url: str, api_token: str):
        self.base_url = base_url
        self.api_token = api_token
    
    def block_domain(self, domain: str) -> bool:
        url = f"{self.base_url}/admin/api.php"
        params = {
            "list": "black",
            "add": domain,
            "auth": self.api_token
        }
        response = requests.post(url, params=params)
        return response.status_code == 200
```

### 3. Shared Observability (Optional)

**Option A:** Separate stacks (recommended for isolation)
- Pi #1 has its own Prometheus + Grafana for DNS metrics
- Pi #2 has its own stack for security metrics
- Both can be viewed independently

**Option B:** Centralized on Pi #2
- Pi #2 Prometheus scrapes Pi #1 exporters
- Single Grafana instance on Pi #2 shows everything
- Requires network connectivity and firewall rules

---

## Deployment Scenarios

### Scenario 1: Minimal Setup (Budget)

**Hardware:**
- 1x Raspberry Pi 4 (4GB) - DNS Pi
- 1x Raspberry Pi 5 (8GB) + AI Hat - Security Pi

**Configuration:**
- Pi #1: `HighAvail_1Pi2P2U` deployment (container redundancy only)
- Pi #2: Full NSM + AI stack
- No hardware-level HA (Pi #1 is single point of failure)

**Cost:** ~$200-250

### Scenario 2: Production HA (Recommended)

**Hardware:**
- 2x Raspberry Pi 5 (8GB) - DNS Pi #1 + backup
- 1x Raspberry Pi 5 (8GB) + AI Hat - Security Pi

**Configuration:**
- Pi #1 + #1b: `HighAvail_2Pi1P1U` with Keepalived VIP
- Pi #2: Full NSM + AI stack
- Hardware-level HA for DNS (sub-second failover)

**Cost:** ~$350-400

### Scenario 3: Enterprise-Grade

**Hardware:**
- 2x Raspberry Pi 5 (8GB) + SSD - DNS HA cluster
- 1x Raspberry Pi 5 (8GB) + AI Hat + SSD - Security Pi

**Configuration:**
- DNS: `HighAvail_2Pi2P2U` (triple redundancy)
- Security: Full stack with Zeek + Suricata
- Managed switch with VLAN support
- Redundant power supplies

**Cost:** ~$500-600

---

## Network Configuration

### IP Address Plan (Example: 192.168.8.0/24)

| Device/Service | IP Address | Purpose |
|----------------|------------|---------|
| Router | 192.168.8.1 | Gateway |
| Pi #1 Host | 192.168.8.250 | DNS Pi physical interface |
| Pi #1 Pi-hole Primary | 192.168.8.251 | Docker container |
| Pi #1 Pi-hole Secondary | 192.168.8.252 | Docker container (if using 1Pi2P2U) |
| Pi #1 Unbound Primary | 192.168.8.253 | Docker container |
| Pi #1 Unbound Secondary | 192.168.8.254 | Docker container (if using 1Pi2P2U) |
| **Keepalived VIP** | **192.168.8.255** | **Virtual IP for HA** |
| Pi #2 Host | 192.168.8.100 | Security Pi |
| Pi #2 Loki | 192.168.8.101 | Log storage (container) |
| Pi #2 Grafana | 192.168.8.102 | Dashboards (container) |

### Required Firewall Rules

**On Router:**
```
# Allow DNS queries to VIP
ALLOW UDP 53 from LAN to 192.168.8.255
ALLOW TCP 53 from LAN to 192.168.8.255

# Port mirroring
MIRROR all_traffic from LAN_switch to Pi2_port
```

**On Pi #1:**
```
# Allow Promtail to ship logs to Pi #2
ALLOW TCP 3100 from Pi1 to Pi2 (Loki)

# Allow Pi #2 to call Pi-hole API
ALLOW TCP 80 from Pi2 to Pi1 (Pi-hole API)
```

**On Pi #2:**
```
# Allow access to Grafana dashboards
ALLOW TCP 3000 from LAN to Pi2

# Promtail log ingestion
ALLOW TCP 3100 from Pi1 to Pi2
```

---

## Upgrade and Maintenance

### Upgrade Path

**This Repo (DNS Pi):**
```bash
cd ~/orion-sentinel-dns-ha
bash scripts/smart-upgrade.sh -u
```

**NSM/AI Repo (Security Pi):**
```bash
cd ~/orion-sentinel-nsm-ai
bash scripts/upgrade.sh
```

### Backup Strategy

**Pi #1 (DNS):**
- Automated backup via `scripts/automated-backup.sh`
- Backs up: Pi-hole config, Unbound config, Docker volumes
- Retention: 7 days (configurable)
- Restore: `scripts/restore-backup.sh`

**Pi #2 (Security):**
- Log rotation for Loki (retention: 30 days)
- AI model versioning (keep last 3 versions)
- Grafana dashboard export (weekly)
- Suricata rules backup (daily)

---

## Monitoring and Alerting

### Key Metrics to Monitor

**DNS Health (Pi #1):**
- Query response time
- Cache hit rate
- Blocked queries per hour
- Pi-hole service uptime
- Keepalived VIP status

**Security Events (Pi #2):**
- Suricata alert rate
- AI anomaly score trends
- Blocked domains per day
- Log ingestion rate
- Disk usage (logs grow fast!)

### Alert Thresholds

| Metric | Warning | Critical |
|--------|---------|----------|
| DNS query latency | >100ms | >500ms |
| Keepalived failover | 1/hour | 3/hour |
| Suricata alerts | >50/hour | >200/hour |
| AI anomalies | >5/hour | >20/hour |
| Disk usage (Pi #2) | >80% | >90% |
| Log ingestion lag | >5min | >15min |

---

## Security Considerations

### Network Segmentation

**Recommended VLAN Setup:**
- VLAN 10: Management (Pi access, SSH)
- VLAN 20: Client devices (use DNS VIP)
- VLAN 30: IoT devices (separate DNS if needed)
- VLAN 99: Monitoring (port mirror source)

### Access Control

**Pi #1 (DNS Pi):**
- Pi-hole web UI: Password protected
- SSH: Key-based auth only
- API token: Stored securely, rotated monthly

**Pi #2 (Security Pi):**
- Grafana: SSO with Authelia (optional)
- SSH: Key-based auth only
- Loki: Internal network only
- Suricata: Passive mode (no inline blocking)

### Data Privacy

**DNS Logs:**
- Contain sensitive data (user browsing history)
- Retained for 30 days maximum
- Access restricted to admin only
- Consider encryption at rest

**NSM Logs:**
- Packet metadata only (not full packets)
- Anonymize internal IPs in exports
- Comply with local privacy laws

---

## Troubleshooting

### DNS Resolution Fails

1. Check VIP status: `ip addr show` on Pi #1
2. Test Pi-hole directly: `dig @192.168.8.251 google.com`
3. Check Keepalived logs: `docker logs keepalived`
4. Verify Unbound: `docker logs unbound_primary`

### Logs Not Appearing in Loki

1. Check Promtail on Pi #1: `docker logs promtail`
2. Test Loki endpoint: `curl http://<pi2-ip>:3100/ready`
3. Verify network connectivity: `ping <pi2-ip>` from Pi #1
4. Check Loki logs: `docker logs loki`

### AI Service Not Blocking Domains

1. Verify AI service is running: `docker ps` on Pi #2
2. Check AI service logs: `docker logs orion-ai`
3. Test Pi-hole API: `curl http://<pi1-ip>/admin/api.php?auth=<token>`
4. Verify API token is valid in Pi-hole UI

---

## Future Enhancements

### Planned Features

**DNS Pi:**
- DoH (DNS-over-HTTPS) support
- Geographic DNS blocking
- Custom DNS response injection
- Multi-site VPN mesh

**Security Pi:**
- Zeek protocol analyzer integration
- Advanced ML models (transformers)
- Automated threat intelligence feeds
- Real-time packet capture on demand

---

## Summary

**Orion Sentinel** provides enterprise-grade security for home/lab networks using commodity Raspberry Pi hardware:

✅ **Privacy-first DNS** with ad-blocking  
✅ **High availability** with automatic failover  
✅ **Network security monitoring** with passive IDS  
✅ **AI-powered threat detection** for anomalies  
✅ **Automated blocking** of risky domains  
✅ **Full observability** with metrics and logs  
✅ **Production-ready** with backup and recovery

**Cost:** ~$200-400 depending on configuration  
**Complexity:** Moderate (good Docker/Linux skills needed)  
**Maintenance:** Low (mostly automated)

---

For detailed setup instructions:
- **DNS HA**: See main [README.md](../README.md) and [INSTALLATION_GUIDE.md](../INSTALLATION_GUIDE.md)
- **NSM/AI Integration**: See [ORION_SENTINEL_INTEGRATION.md](ORION_SENTINEL_INTEGRATION.md)
