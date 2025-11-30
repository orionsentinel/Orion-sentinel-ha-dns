# Orion Sentinel DNS HA 🌐
## RPi HA DNS Stack - Privacy & High Availability

A production-ready, high-availability DNS stack for Raspberry Pi, part of the **Orion Sentinel** ecosystem.

> **Orion Sentinel** is a two-Pi home lab security platform:
> - **Orion Sentinel DNS HA** (this repo) - DNS privacy and high availability layer
> - **Orion Sentinel NSM AI** (separate repo) - Network security monitoring with AI detection

## 🚀 Getting Started - Choose Your Path

### For First-Time Users (Easy Setup)

**Want a simple, guided setup?** Use the **First-Run Web Wizard**:

1. Clone the repo and run install script:
   ```bash
   git clone https://github.com/yorgosroussakis/Orion-sentinel-ha-dns.git
   cd Orion-sentinel-ha-dns
   # Optional: Verify your system is ready
   bash scripts/verify-installation.sh
   # Run the installer
   bash install.sh
   ```

2. Visit the web wizard at `http://<your-pi-ip>:5555`

3. Follow the 3-step wizard:
   - Choose single-node or HA mode
   - Configure network settings
   - Select DNS security profile (Family / Standard / Paranoid)

4. Deploy and you're done!

📖 **[Installation Steps Quick Reference](INSTALLATION_STEPS.md)** - Step-by-step installation guide ⭐ NEW  
📖 **[First-Run Wizard Guide](docs/first-run-wizard.md)** - Complete wizard documentation

### For Power Users (Manual Setup)

**Prefer command-line control?** Use the guided CLI or manual configuration:

- **Single Pi Setup:** [Install Guide for Single Pi](docs/install-single-pi.md)
- **Two Pi HA Setup:** [Install Guide for Two-Pi HA](docs/install-two-pi-ha.md)

These guides walk you through:
- Manual `.env` configuration
- Network setup
- Docker deployment
- Profile application

---

## 📚 Documentation Quick Links

### Getting Started
- **[⚡ INSTALLATION_STEPS.md](INSTALLATION_STEPS.md)** - Quick reference for installation steps ⭐ NEW
- **[📖 INSTALL.md](INSTALL.md)** - Comprehensive installation guide ⭐ NEW
- **[✅ TEST_RESULTS.md](TEST_RESULTS.md)** - Installation verification test results ⭐ NEW
- **[🎯 Deployment Modes](docs/MODES_QUICK_REFERENCE.md)** - Standalone vs Integrated mode guide
- **[🧙 First-Run Web Wizard](docs/first-run-wizard.md)** - Guided web-based setup
- **[📖 Single-Pi Installation](docs/install-single-pi.md)** - Step-by-step single node setup
- **[📖 Two-Pi HA Installation](docs/install-two-pi-ha.md)** - Step-by-step dual node HA setup
- **[🚀 QUICKSTART.md](QUICKSTART.md)** - One-page guide to get started fast
- **[📖 INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md)** - Detailed installation instructions

### Operations & Maintenance
- **[📋 OPERATIONAL_RUNBOOK.md](OPERATIONAL_RUNBOOK.md)** - Day-to-day operations guide ⭐ NEW
- **[🔧 TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Fix common issues
- **[🚨 DISASTER_RECOVERY.md](DISASTER_RECOVERY.md)** - Recovery procedures ⭐ NEW
- **[📝 CHANGELOG.md](CHANGELOG.md)** - Track all changes ⭐ NEW
- **[👤 USER_GUIDE.md](USER_GUIDE.md)** - How to use and maintain the stack
- **[⚙️ Operations Guide](docs/operations.md)** - Backup, restore, and upgrade procedures ⭐ NEW
- **[🔒 Hardening Guide](docs/hardening.md)** - Security best practices and deployment hardening ⭐ NEW

### Phase 2 Features (Production Enhancements) ⭐ NEW
- **[🏥 Health & HA Guide](docs/health-and-ha.md)** - Health checking and failover
- **[🛡️ Security Profiles](docs/profiles.md)** - DNS filtering configurations
- **[💾 Backup & Migration](docs/backup-and-migration.md)** - Disaster recovery
- **[📊 Observability Guide](docs/observability.md)** - Monitoring and metrics

### Phase 3 Features (Resilience & Automation) 🆕
- **[🔗 Stack Integration Guide](docs/STACK_INTEGRATION.md)** - Multi-node sync, backup automation, and self-healing 🆕
- **[🔄 Multi-Node Sync](scripts/multi-node-sync.sh)** - Automated configuration sync between nodes 🆕
- **[💾 Automated Sync Backup](scripts/automated-sync-backup.sh)** - Backup with off-site replication 🆕
- **[🔧 Self-Healing Service](scripts/self-heal.sh)** - Automatic failure detection and recovery 🆕
- **[✅ Pre-Flight Check](scripts/pre-flight-check.sh)** - System validation before deployment 🆕

### 🔗 Orion Sentinel Integration
- **[🛡️ NSM/AI Integration Guide](docs/ORION_SENTINEL_INTEGRATION.md)** - Connect with Network Security Monitoring & AI ⭐ NEW
- **[🏗️ Orion Sentinel Architecture](docs/ORION_SENTINEL_ARCHITECTURE.md)** - Complete two-Pi ecosystem overview ⭐ NEW
- **[🖥️ Single Pane of Glass (SPoG) Integration](docs/SPOG_INTEGRATION_GUIDE.md)** - Centralized observability on Dell CoreSrv ⭐ NEW
- **[⚡ SPoG Quick Reference](docs/SPOG_QUICK_REFERENCE.md)** - Quick setup guide for SPoG mode ⭐ NEW

---

## 🛡️ Orion Sentinel Ecosystem

This repository is the **DNS & Privacy layer** of the Orion Sentinel platform:

```
┌─────────────────────────────────────────────────────────┐
│                  Orion Sentinel                         │
│          Home Lab Security Platform                     │
└─────────────────────────────────────────────────────────┘

     Pi #1 (DNS Pi)              Pi #2 (Security Pi)
┌──────────────────────┐    ┌──────────────────────────┐
│ Orion Sentinel       │    │ Orion Sentinel NSM AI    │
│ DNS HA (THIS REPO)   │◄──►│ (Separate Repository)    │
│                      │    │                          │
│ • Pi-hole            │    │ • Suricata IDS           │
│ • Unbound            │    │ • Loki + Grafana         │
│ • Keepalived VIP     │    │ • AI Anomaly Detection   │
│ • DNS Logs ────────►│    │ • Domain Risk Scoring    │
│ • Pi-hole API ◄──────│────│ • Automated Blocking     │
└──────────────────────┘    └──────────────────────────┘
```

**What this repo provides:**
- 🔒 **Privacy**: Network-wide ad/tracker blocking via Pi-hole
- 🌐 **DNS**: DNSSEC-validated recursive resolution via Unbound
- ⚡ **High Availability**: Automatic failover with Keepalived VIP
- 📊 **Observability**: Built-in monitoring and dashboards
- 🔄 **Smart Upgrades**: Automated update management (v2.4.0)
- 🏥 **Health Checking**: Comprehensive service health validation ⭐ NEW
- 🛡️ **Security Profiles**: Pre-configured DNS filtering levels ⭐ NEW
- 💾 **Backup & Restore**: Automated configuration backups ⭐ NEW
- 🔗 **Multi-Node Sync**: Automatic configuration sync between nodes 🆕
- 🔧 **Self-Healing**: Automatic failure detection and recovery 🆕
- 📤 **Off-Site Backup**: Remote backup to NAS/cloud storage 🆕
- 🧠 **Smart DNS Prefetch**: Enhanced caching with prefetch and privacy hardening 🆕
- 🔐 **Encrypted DNS Gateway**: DoH/DoT terminator for dumb devices 🆕

**Integration with NSM/AI Pi:**
- Exposes DNS logs for security analysis
- Provides Pi-hole API for blocking risky domains
- Shared observability stack (optional)

See [docs/ORION_SENTINEL_INTEGRATION.md](docs/ORION_SENTINEL_INTEGRATION.md) for integration details.

---

## 🧠 Smart DNS (Unbound Prefetch + Hardened Config)

Enable smarter DNS resolution with prefetching and enhanced privacy hardening.

**Features:**
- **Prefetching**: Proactively refreshes popular DNS records before they expire
- **Enhanced Caching**: Larger caches (up to 448MB) with optimized TTL settings
- **QNAME Minimisation**: Only sends minimum necessary query name for enhanced privacy
- **DNSSEC Hardening**: Strengthened DNSSEC validation and anti-stripping protection
- **Serve Expired**: Faster perceived response times during cache refresh

**Enable/Disable:**
```bash
# In your .env file:
UNBOUND_SMART_PREFETCH=1  # Enable (0 = disabled, default)
```

**Memory Usage:**
- Maximum cache utilization: ~448MB
- Suitable for Raspberry Pi 4/5 with 2-8GB RAM

**What Gets Tuned:**
| Setting | Default | Smart Prefetch |
|---------|---------|----------------|
| `msg-cache-size` | 50MB | 128MB |
| `rrset-cache-size` | 100MB | 256MB |
| `key-cache-size` | - | 64MB |
| `cache-min-ttl` | 3600s | 60s |
| `serve-expired-ttl` | 86400s | 180s |
| `qname-minimisation-strict` | no | yes |

**Note:** DNSSEC validation and existing privacy settings remain active and are only strengthened.

---

## 🎯 Deployment Modes

This repository is designed to be **fully functional as a standalone HA DNS appliance**, and can optionally integrate with CoreSrv for centralized monitoring and logging.

📖 **[Quick Reference Guide](docs/MODES_QUICK_REFERENCE.md)** - Complete standalone vs integrated mode comparison

### Standalone Mode (Default) ⭐

**Perfect for users who just want a reliable DNS solution on their Raspberry Pi.**

**Required Components:**
- ✅ **Pi-hole** - Network-wide ad blocking
- ✅ **Unbound** - Recursive DNS with DNSSEC validation
- ✅ **Keepalived** - High availability with automatic failover

**Optional Components:**
- 📊 **Exporters** (node, pihole, unbound) - Local metrics collection
- 📝 **Promtail** - Local log aggregation

**Deployment:**
```bash
# Deploy core DNS services only
cd stacks/dns
docker compose --profile single-pi-ha up -d

# Optionally add local monitoring
cd ../monitoring
docker compose -f docker-compose.exporters.yml up -d
```

**Key Features:**
- Works completely standalone without any external dependencies
- All DNS services start and run independently
- Monitoring/logging components are entirely optional
- Perfect for home users who want privacy and HA DNS

---

### Integrated Mode (with CoreSrv)

**For advanced users running the full Orion Sentinel ecosystem with centralized observability.**

**Everything from Standalone Mode, PLUS:**
- 📊 **Metrics Federation** - Pi-hole, Unbound, and Node metrics scraped by CoreSrv Prometheus
- 📝 **Log Shipping** - DNS logs forwarded to CoreSrv Loki via Promtail
- 🎨 **Unified Dashboards** - Centralized visualization in CoreSrv Grafana
- 🔗 **Cross-Stack Integration** - Correlate DNS data with security events from NSM Pi

**Deployment:**
```bash
# 1. Deploy core DNS services
cd stacks/dns
docker compose --profile single-pi-ha up -d

# 2. Deploy exporters for metrics
cd ../monitoring
docker compose -f docker-compose.exporters.yml up -d

# 3. Configure and deploy Promtail for log shipping
cd ../agents/pi-dns

# Set CoreSrv IP in environment or config
export LOKI_URL=http://192.168.8.100:3100  # Your CoreSrv IP
# OR edit promtail-config.example.yml and save as promtail-config.yml

docker compose up -d
```

**Environment Variables:**
- `CORESRV_IP` - IP address of your CoreSrv instance (default: 192.168.8.100)
- `LOKI_URL` - Loki endpoint for log shipping (default: http://192.168.8.100:3100)

**Key Points:**
- ✅ Core DNS services **never depend** on CoreSrv - they start even if exporters/Promtail fail
- ✅ Exporters expose metrics locally on standard ports (9100, 9617, etc.)
- ✅ CoreSrv's Prometheus scrapes these metrics over the network
- ✅ Promtail ships logs to CoreSrv's Loki only when `LOKI_URL` is configured
- ✅ If CoreSrv is unavailable, DNS continues to work normally

**Documentation:**
- 📖 **[SPoG Integration Guide](docs/SPOG_INTEGRATION_GUIDE.md)** - Complete CoreSrv setup
- 📖 **[SPoG Quick Reference](docs/SPOG_QUICK_REFERENCE.md)** - Quick start guide
- 📖 **[Observability Guide](docs/observability.md)** - Monitoring configuration

---

### Comparison

| Feature | Standalone Mode | Integrated Mode |
|---------|----------------|-----------------|
| **DNS Services** | ✅ Pi-hole, Unbound, Keepalived | ✅ Same |
| **High Availability** | ✅ Automatic failover | ✅ Same |
| **Local Web UI** | ✅ Pi-hole dashboard | ✅ Same |
| **Metrics Export** | ⚪ Optional (local only) | ✅ Scraped by CoreSrv |
| **Log Shipping** | ⚪ Optional (local only) | ✅ Sent to CoreSrv Loki |
| **Centralized Dashboards** | ❌ Not available | ✅ CoreSrv Grafana |
| **Cross-Stack Correlation** | ❌ Not available | ✅ DNS + Security events |
| **External Dependencies** | ❌ None | ⚪ CoreSrv (optional) |

**Bottom Line:**
- **Standalone Mode**: This repo is a complete, production-ready HA DNS solution that works perfectly on its own.
- **Integrated Mode**: When connected to CoreSrv, it becomes a smart sensor in the larger Orion Sentinel security platform, while maintaining full independence.

---

## 🆕 Phase 2 Features - Production-Ready Enhancements

### 🏥 Advanced Health Checking

Comprehensive health monitoring ensures system reliability:

- **Automated Health Checks**: Python-based health checker validates all DNS services
- **Docker Integration**: Built-in healthcheck directives for container monitoring
- **HTTP Endpoints**: Optional REST API for external monitoring (`/health`, `/ready`, `/live`)
- **Keepalived Integration**: Health status influences HA failover decisions

```bash
# Run health check
python3 health/health_checker.py

# Get JSON status
python3 health/health_checker.py --format json
```

📖 **[Health & HA Guide](docs/health-and-ha.md)** - Complete health checking documentation

### 🛡️ DNS Security Profiles

Three pre-configured security levels for different needs:

| Profile | Description | Use Case |
|---------|-------------|----------|
| **Standard** | Balanced ad + malware blocking | General home/office use |
| **Family** | Adds adult content filtering | Families with children |
| **Paranoid** | Maximum privacy + tracking blockers | Privacy-focused users |

```bash
# Apply a security profile
python3 scripts/apply-profile.py --profile standard

# Dry-run to preview changes
python3 scripts/apply-profile.py --profile family --dry-run
```

📖 **[Security Profiles Guide](docs/profiles.md)** - Profile details and customization

### 💾 Backup & Disaster Recovery

Automated configuration backups for peace of mind:

- **Automated Backups**: Script backs up all configs, Pi-hole data, and settings
- **Checksum Verification**: SHA256 checksums ensure backup integrity
- **Selective Restoration**: Restore everything or specific components
- **Migration Support**: Easy migration to new hardware or SD cards

```bash
# Create backup
bash scripts/backup-config.sh

# Restore from backup
bash scripts/restore-config.sh backups/dns-ha-backup-*.tar.gz

# Schedule weekly backups
0 2 * * 0 /opt/rpi-ha-dns-stack/scripts/backup-config.sh
```

📖 **[Backup & Migration Guide](docs/backup-and-migration.md)** - Complete backup documentation

### 📊 Enhanced Observability

Production-grade monitoring and metrics:

- **Metrics Exporters**: Node, Pi-hole, Unbound, Blackbox, cAdvisor
- **Prometheus Integration**: Time-series metrics with 30-day retention
- **Grafana Dashboards**: Pre-built DNS HA Overview dashboard
- **Alert Rules**: Critical alerts for service failures and performance issues
- **DNS Latency Monitoring**: Track DNS resolution performance

**Key Metrics:**
- DNS query rates and latency
- Pi-hole blocking effectiveness
- System resource usage
- HA failover events
- Container health status

```bash
# Deploy monitoring exporters
docker compose -f stacks/monitoring/docker-compose.exporters.yml up -d

# Access dashboards
# Prometheus: http://192.168.8.250:9090
# Grafana: http://192.168.8.250:3000
```

📖 **[Observability Guide](docs/observability.md)** - Monitoring setup and metrics

### 🔗 NSM/AI Integration

Enhanced integration with Orion Sentinel Security Pi:

- **Log Shipping**: Promtail agent for forwarding DNS logs to Loki
- **Pi-hole API**: Documented endpoints for automated threat blocking
- **Metrics Federation**: Share DNS metrics with Security Pi Prometheus
- **Unified Dashboards**: Combined DNS + security visualization

```bash
# Deploy log shipping agent
docker compose -f stacks/agents/dns-log-agent/docker-compose.yml up -d

# Logs sent to Security Pi's Loki at http://192.168.8.100:3100
```

📖 **[NSM/AI Integration](docs/ORION_SENTINEL_INTEGRATION.md)** - Security Pi integration details

### 🔗 Multi-Node Sync & Automation (Phase 3) 🆕

Automated synchronization and self-healing for multi-node deployments:

- **Configuration Sync**: Automatic Pi-hole, Unbound, and profile sync between nodes
- **Backup Replication**: Local backups with automatic replication to peer and off-site storage
- **Self-Healing**: Circuit breaker pattern with automatic failure recovery
- **Pre-Flight Validation**: Comprehensive system checks before deployment

```bash
# Setup multi-node sync
bash scripts/multi-node-sync.sh --setup

# Run sync daemon
bash scripts/multi-node-sync.sh --daemon &

# Run self-healing service
bash scripts/self-heal.sh --daemon &

# Pre-flight check before deployment
bash scripts/pre-flight-check.sh --fix

# Automated backup with sync
bash scripts/automated-sync-backup.sh --all
```

📖 **[Stack Integration Guide](docs/STACK_INTEGRATION.md)** - Complete multi-node setup and automation

---

## 🆕 Choose Your Deployment Option!

This repository now supports **FOUR complete deployment options** for different High Availability scenarios, including a **VPN Edition**!

### **[📂 View All Deployment Options →](deployments/)**

| Option | Description | Best For |
|--------|-------------|----------|
| **[HighAvail_1Pi2P2U](deployments/HighAvail_1Pi2P2U/)** | 1 Pi with 2 Pi-hole + 2 Unbound | Home labs, Testing |
| **[HighAvail_1Pi2P2U_VPN](deployments/HighAvail_1Pi2P2U_VPN/)** 🆕 ⭐ | 1 Pi with HA DNS + **WireGuard VPN** | **Remote Access + Ad-blocking** |
| **[HighAvail_2Pi1P1U](deployments/HighAvail_2Pi1P1U/)** ⭐ | 2 Pis with 1 Pi-hole + 1 Unbound each | **Production** (RECOMMENDED) |
| **[HighAvail_2Pi2P2U](deployments/HighAvail_2Pi2P2U/)** | 2 Pis with 2 Pi-hole + 2 Unbound each | Mission-Critical |

Each deployment option includes complete docker-compose files, configurations, and detailed instructions.

**🆕 VPN Edition Features:**
- 📱 QR codes for instant mobile setup
- 🌐 Web UI for managing VPN peers  
- 🛡️ Integrated with HA VIP (192.168.8.255)
- 🚀 Remote access to all home services
- ✅ Ad-blocking everywhere!

**Architecture Documentation:**
- **[📑 Documentation Index](MULTI_NODE_INDEX.md)** - Navigation guide
- **[🚀 Quick Start](MULTI_NODE_QUICKSTART.md)** - Overview
- **[📐 Architecture Design](MULTI_NODE_HA_DESIGN.md)** - Detailed design
- **[🎨 Visual Comparison](ARCHITECTURE_COMPARISON.md)** - Diagrams

## Network Configuration 🛠️
- **Host (Raspberry Pi) IP:** 192.168.8.250 (eth0)
- **Primary DNS:** 192.168.8.251 (pihole_primary)
- **Secondary DNS:** 192.168.8.252 (pihole_secondary)
- **Primary Unbound:** 192.168.8.253 (unbound_primary)
- **Secondary Unbound:** 192.168.8.254 (unbound_secondary)
- **Keepalived VIP:** 192.168.8.255

## Stack Includes:
- Dual Pi-hole v6 instances with Unbound recursive DNS.
- Keepalived for HA failover.
- Gravity Sync for Pi-hole synchronization.
- AI-Watchdog for self-healing with Signal notifications.
- Prometheus + Grafana + Alertmanager + Loki for observability.
- Signal webhook bridge for notifications via self-hosted signal-cli-rest-api.
- **🆕 WireGuard VPN for secure remote access to home services.**
- **🆕 Nginx Proxy Manager for exposing services with SSL support.**
- **🆕 Single Sign-On (SSO) with Authelia for centralized authentication.**
- Docker + Portainer setup.

## ASCII Network Diagram 🖥️
```plaintext
[192.168.8.250] <- Raspberry Pi Host
     |         |
     |         |
[192.168.8.251] [192.168.8.252]
 Pi-hole 1     Pi-hole 2
     |         |
     |         |
[192.168.8.253] [192.168.8.254]
 Unbound 1    Unbound 2
     |         |
     |         |
[192.168.8.255] <- Keepalived VIP

```

---

## 🚀 DNS Stack Deployment Modes

The DNS stack supports **three flexible deployment modes** using Docker Compose profiles. Choose the mode that fits your infrastructure and availability requirements.

### Mode A: Single-Pi HA (`single-pi-ha`)

**One Raspberry Pi running all services with local redundancy**

- **Services**: Both primary and secondary Pi-hole + Unbound instances
- **High Availability**: Keepalived manages VIP for service failover
- **Use Case**: Simple setup with container-level redundancy on one host
- **Deployment**:
  ```bash
  # Copy and configure the environment file
  cp env/.env.single-pi-ha.example env/.env
  # Edit env/.env with your settings (VIP, passwords, etc.)
  
  # Deploy all services on one Pi
  cd stacks/dns
  docker compose --profile single-pi-ha up -d
  ```

**Services Running**: `pihole_primary`, `pihole_secondary`, `unbound_primary`, `unbound_secondary`, `keepalived`, `pihole-sync`

**Access DNS via**: `${DNS_VIP}` (e.g., 192.168.8.249)

---

### Mode B: Two-Pi Simple (`two-pi-simple`)

**Two Raspberry Pis, active-passive, no automatic failover**

- **Services**: Primary services only on Pi1 (no secondary services)
- **High Availability**: Manual failover required
- **Use Case**: Simple two-Pi setup where Pi2 is passive/standby
- **Deployment**:
  ```bash
  # Copy and configure the environment file
  cp env/.env.two-pi-simple.example env/.env
  # Edit env/.env with your settings
  
  # On Pi1 only - deploy primary services
  cd stacks/dns
  docker compose --profile two-pi-simple up -d
  ```

**Services Running on Pi1**: `pihole_primary`, `unbound_primary`

**Services Running on Pi2**: None (Pi2 is standby)

**Access DNS via**: Pi1's IP address (e.g., 192.168.8.11)

---

### Mode C: Two-Pi HA (`two-pi-ha`)

**Two Raspberry Pis with full high availability and automatic failover**

- **Services**: Primary services on Pi1, secondary services on Pi2
- **High Availability**: Keepalived manages floating VIP between both Pis
- **Use Case**: Production setup with hardware-level redundancy
- **Deployment**:
  ```bash
  # Copy and configure the environment file (same on both Pis)
  cp env/.env.two-pi-ha.example env/.env
  # Edit env/.env with your settings (both Pi IPs, VIP, passwords, etc.)
  
  # On Pi1 - deploy primary services
  cd stacks/dns
  docker compose --profile two-pi-ha-pi1 up -d
  
  # On Pi2 - deploy secondary services
  cd stacks/dns
  docker compose --profile two-pi-ha-pi2 up -d
  ```

**Services Running on Pi1**: `pihole_primary`, `unbound_primary`, `keepalived`, `pihole-sync`

**Services Running on Pi2**: `pihole_secondary`, `unbound_secondary`, `keepalived`

**Access DNS via**: `${DNS_VIP}` (e.g., 192.168.8.249) - automatically fails over between Pis

---

### Service-to-Mode-to-Host Mapping

| Service | single-pi-ha | two-pi-simple | two-pi-ha (Pi1) | two-pi-ha (Pi2) |
|---------|--------------|---------------|-----------------|-----------------|
| `pihole_primary` | ✅ Pi1 | ✅ Pi1 | ✅ Pi1 | ❌ |
| `pihole_secondary` | ✅ Pi1 | ❌ | ❌ | ✅ Pi2 |
| `unbound_primary` | ✅ Pi1 | ✅ Pi1 | ✅ Pi1 | ❌ |
| `unbound_secondary` | ✅ Pi1 | ❌ | ❌ | ✅ Pi2 |
| `keepalived` | ✅ Pi1 | ❌ | ✅ Pi1 | ✅ Pi2 |
| `pihole-sync` | ✅ Pi1 | ❌ | ❌ | ❌ |

**Note on Pi-hole Sync**: 
- In `single-pi-ha` mode, pihole-sync runs locally to sync between containers on the same host
- In `two-pi-ha` mode, use external sync tools like [Gravity Sync](https://github.com/vmstan/gravity-sync) to sync Pi-hole configurations across hosts

**Profile Usage:**
- **Mode A (single-pi-ha)**: `docker compose --profile single-pi-ha up -d`
- **Mode B (two-pi-simple)**: `docker compose --profile two-pi-simple up -d`
- **Mode C (two-pi-ha)**: 
  - On Pi1: `docker compose --profile two-pi-ha-pi1 up -d`
  - On Pi2: `docker compose --profile two-pi-ha-pi2 up -d`

### Key Design Decisions

1. **Service Name Resolution**: Services communicate using DNS names (e.g., `unbound_primary#5335`) instead of hard-coded IP addresses
2. **Dynamic IP Assignment**: Docker automatically assigns IPs - no manual IP configuration needed
3. **Profile-Based Control**: Profiles determine which services run in each mode
4. **Environment-Based Configuration**: Each mode has its own `.env.*.example` file with relevant variables

---

## Deployment Options 🎯

This repository provides **three complete deployment configurations**:

### HighAvail_1Pi2P2U - Single Pi Setup
- **Architecture:** 1 Pi with 2 Pi-hole + 2 Unbound
- **Redundancy:** Container-level only
- **Best for:** Home labs, testing, single Pi setups
- **Hardware:** 1x Raspberry Pi (4GB+ RAM)
- **[View Details →](deployments/HighAvail_1Pi2P2U/)**

### HighAvail_2Pi1P1U - Simplified Two-Pi Setup ⭐ RECOMMENDED
- **Architecture:** 2 Pis with 1 Pi-hole + 1 Unbound each
- **Redundancy:** Hardware + Node-level
- **Best for:** Production home networks, small offices
- **Hardware:** 2x Raspberry Pi (4GB+ RAM each)
- **[View Details →](deployments/HighAvail_2Pi1P1U/)**

### HighAvail_2Pi2P2U - Full Redundancy Two-Pi Setup
- **Architecture:** 2 Pis with 2 Pi-hole + 2 Unbound each
- **Redundancy:** Container + Hardware + Node-level (triple)
- **Best for:** Mission-critical environments
- **Hardware:** 2x Raspberry Pi (8GB RAM recommended)
- **[View Details →](deployments/HighAvail_2Pi2P2U/)**

**Quick Decision:** Have 2 Pis? → Use **HighAvail_2Pi1P1U** ⭐  
**[See Full Comparison →](deployments/)**

## Features List 📝
- High availability through Keepalived.
- Enhanced security and performance using Unbound.
- Real-time observability with Prometheus and Grafana.
- Automated sync of DNS records with Gravity Sync.
- Self-healing through AI-Watchdog.
- **🆕 Multi-node deployment for true hardware redundancy.**
- **🆕 Automated multi-node configuration sync** - Keep primary and secondary in sync automatically.
- **🆕 Off-site backup replication** - Backup to peer nodes, NAS, and cloud storage.
- **🆕 Circuit breaker pattern** - Prevent cascading failures with intelligent retry logic.
- **🆕 Pre-flight validation** - Comprehensive system checks before deployment.
- **🆕 Self-healing service** - Automatic detection and recovery from failures.

## 🔧 Operational Excellence

**Automation & Monitoring Scripts** ⭐ NEW

We provide production-ready scripts for operational maturity:

### Health Monitoring
```bash
# Run weekly health checks
bash scripts/health-check.sh
```
**Checks**: DNS resolution, service health, HA status, disk/memory usage, container health

### Weekly Maintenance
```bash
# Automated maintenance tasks
bash scripts/weekly-maintenance.sh
```
**Performs**: Container updates, log cleanup, disk space management, configuration backups, health reports

### Setup Automation

**Automatic Setup (Recommended)** ⭐
```bash
# Cron jobs are automatically configured during installation
# The setup script will prompt you to enable automated tasks
```

**Manual Setup**
```bash
# Run the cron setup script
sudo bash scripts/setup-cron.sh

# This automatically configures:
# - Weekly health check (Sundays at 2 AM)
# - Weekly maintenance (Sundays at 3 AM)
# - Log rotation
# - Creates /var/log/rpi-dns/ directory
```

**Alternative: Manual crontab editing**
```bash
# Add to crontab for automation
sudo crontab -e

# Weekly health check (Sundays at 2 AM)
0 2 * * 0 /opt/rpi-ha-dns-stack/scripts/health-check.sh >> /var/log/rpi-dns/health-check.log 2>&1

# Weekly maintenance (Sundays at 3 AM)
0 3 * * 0 /opt/rpi-ha-dns-stack/scripts/weekly-maintenance.sh >> /var/log/rpi-dns/maintenance.log 2>&1
```

### Documentation
- **[OPERATIONAL_RUNBOOK.md](OPERATIONAL_RUNBOOK.md)** - Common issues and solutions
- **[DISASTER_RECOVERY.md](DISASTER_RECOVERY.md)** - Recovery procedures and RTO/RPO
- **[CHANGELOG.md](CHANGELOG.md)** - Track all configuration changes

**Philosophy**: Mature systems are boring. They just work. Focus on reliability over features.


## Quick Start Instructions 🚀

### 🚀 One-Line Installation (Recommended for Raspberry Pi)

**The easiest way to get started - just one command!**

```bash
curl -fsSL https://raw.githubusercontent.com/yorgosroussakis/rpi-ha-dns-stack/main/install.sh | bash
```

This installer will:
- ✅ Check system compatibility
- ✅ Install Docker and Docker Compose automatically
- ✅ Clone the repository
- ✅ Launch the web setup wizard

**Then follow the web wizard at:** `http://<your-pi-ip>:5555`

---

### 🌟 Web Setup UI (Modern & User-Friendly) ✨

**Graphical web interface for easy setup!** No terminal knowledge needed.

The Web Setup UI provides:
- ✅ Modern, responsive web interface
- ✅ 8-step guided wizard (Prerequisites → Hardware → Deployment → Node Role → Network → Security → Notifications → Summary)
- ✅ Automatic prerequisites checking (Docker, RAM, disk space)
- ✅ Hardware survey with detailed system information
- ✅ **NEW:** Node role selection for multi-Pi deployments (Primary/Secondary)
- ✅ Visual deployment option selection
- ✅ Form-based network and security configuration
- ✅ Real-time validation and feedback
- ✅ Configuration summary and deployment instructions
- ✅ Access from any device on your network

**Manual Installation:**
```bash
git clone https://github.com/yorgosroussakis/rpi-ha-dns-stack.git
cd rpi-ha-dns-stack
bash scripts/launch-setup-ui.sh
```

**Then open your browser at:** `http://localhost:5555` or `http://<your-pi-ip>:5555`

**That's it!** Follow the step-by-step wizard in your browser - no terminal knowledge required!

---

### 🔐 Security Best Practices

**Before deploying**, generate secure passwords:

```bash
# Generate and save these passwords securely
echo "PIHOLE_PASSWORD=$(openssl rand -base64 32)"
echo "GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 32)"
echo "VRRP_PASSWORD=$(openssl rand -base64 20)"
```

**After configuring your .env file**, validate it:

```bash
# Validate environment configuration
bash scripts/validate-env.sh

# Test .env file format
bash scripts/test-env-format.sh
```

Both validation scripts must pass before deployment to ensure:
- All required variables are set
- No default/weak passwords remain
- Proper file formatting

---

### Alternative: Terminal-Based Setup

#### 🆕 Option 1: CLI Installer (NEW - Recommended for Power Users) ✨

**NEW:** Full-featured command-line installer with interactive and non-interactive modes!

```bash
git clone https://github.com/yorgosroussakis/rpi-ha-dns-stack.git
cd rpi-ha-dns-stack

# Interactive mode (guided prompts)
bash scripts/cli-install.sh

# Non-interactive mode (for automation)
bash scripts/cli-install.sh --mode single-pi-ha --host-ip 192.168.1.100 --non-interactive

# Dry-run to preview changes
bash scripts/cli-install.sh --mode single-pi-ha --dry-run

# See all options
bash scripts/cli-install.sh --help
```

Features:
- ✅ Interactive AND non-interactive modes
- ✅ All deployment modes (single-pi-ha, two-pi-simple, two-pi-ha)
- ✅ Dry-run capability to preview changes
- ✅ Full automation support for CI/CD
- ✅ Comprehensive --help documentation
- ✅ Generate config only with `--generate-config`

#### Option 2: Easy Installer

Robust installer with proper error handling and recovery:

```bash
git clone https://github.com/yorgosroussakis/rpi-ha-dns-stack.git
cd rpi-ha-dns-stack
bash scripts/easy-install.sh
```

Features:
- ✅ Comprehensive prerequisite checks
- ✅ Safe error handling (won't cause unexpected reboots)
- ✅ Automatic recovery from failures
- ✅ Choose between Web UI or Terminal setup
- ✅ Verbose mode for debugging: `bash scripts/easy-install.sh --verbose`
- ✅ Help available: `bash scripts/easy-install.sh --help`

#### Option 3: Interactive Terminal Wizard

If you prefer a terminal-based interactive wizard:
```bash
git clone https://github.com/yorgosroussakis/rpi-ha-dns-stack.git
cd rpi-ha-dns-stack
bash scripts/interactive-setup.sh
```

#### Option 4: Guided Terminal Setup

For a simpler guided terminal setup:
```bash
git clone https://github.com/yorgosroussakis/rpi-ha-dns-stack.git
cd rpi-ha-dns-stack
bash scripts/setup.sh
```

#### Option 5: Manual Setup
1. Clone the repository:
   ```bash
   git clone https://github.com/yorgosroussakis/rpi-ha-dns-stack.git
   cd rpi-ha-dns-stack
   ```
2. Set up Signal notifications (optional but recommended):
   - Follow the detailed guide in [SIGNAL_INTEGRATION_GUIDE.md](SIGNAL_INTEGRATION_GUIDE.md)
   - Quick start: Register a phone number with signal-cli-rest-api
   - Copy `.env.example` to `.env` and update:
     - `SIGNAL_NUMBER`: Your phone number registered with Signal (e.g., +1234567890)
     - `SIGNAL_RECIPIENTS`: Recipient phone numbers (comma-separated)

3. Deploy the stack:
   ```bash
   bash scripts/install.sh
   ```

## Updating the Stack 🔄

### 🆕 Smart Upgrade System (Recommended) ✨

**NEW in v2.4.0:** Intelligent upgrade management with safety checks and rollback capability!

```bash
cd rpi-ha-dns-stack

# Interactive mode (easiest)
bash scripts/smart-upgrade.sh -i

# Or check for updates first
bash scripts/smart-upgrade.sh -c

# Or perform full upgrade
bash scripts/smart-upgrade.sh -u
```

**Smart Upgrade Features:**
- ✅ Pre-upgrade health checks (disk, Docker, network)
- ✅ Automatic backup creation before upgrade
- ✅ Selective upgrades (all stacks or individual)
- ✅ Post-upgrade verification (health, DNS tests)
- ✅ Detailed upgrade logging
- ✅ One-click rollback capability
- ✅ Update report generation

### Standard Update Method

For traditional updates:
```bash
cd rpi-ha-dns-stack
bash scripts/update.sh
```

The standard update script will:
- Backup your current configuration
- Pull latest changes from git
- Rebuild updated containers
- Restart services with zero downtime
- Preserve your `.env` and override files

### Automated Update Checks

Enable daily update checks to stay informed:
```bash
# Check for available updates
bash scripts/check-updates.sh

# View update report
cat update-report.md

# Setup automated daily checks (optional)
(crontab -l 2>/dev/null; echo "0 3 * * * $(pwd)/scripts/check-updates.sh") | crontab -
```

## Service Access URLs 🌐
- **🆕 Web Setup UI:** [http://192.168.8.250:5555](http://192.168.8.250:5555) - Installation & Configuration Interface
- **Pi-hole Primary Dashboard:** [http://192.168.8.251/admin](http://192.168.8.251/admin)
- **Pi-hole Secondary Dashboard:** [http://192.168.8.252/admin](http://192.168.8.252/admin)
- **Metrics Dashboard (Grafana):** [http://192.168.8.250:3000](http://192.168.8.250:3000)
- **Prometheus:** [http://192.168.8.250:9090](http://192.168.8.250:9090)
- **Alertmanager:** [http://192.168.8.250:9093](http://192.168.8.250:9093)
- **Signal CLI REST API:** [http://192.168.8.250:8081](http://192.168.8.250:8081)
- **Signal Webhook Bridge:** [http://192.168.8.250:8080/health](http://192.168.8.250:8080/health)

### VPN & Remote Access URLs (Optional Stack)
- **🆕 WireGuard-UI:** [http://192.168.8.250:5000](http://192.168.8.250:5000) - VPN Peer Management
- **🆕 Nginx Proxy Manager:** [http://192.168.8.250:81](http://192.168.8.250:81) - Reverse Proxy Configuration

### SSO URLs (Optional Stack) 🔐
- **🆕 Authelia Portal:** [http://192.168.8.250:9091](http://192.168.8.250:9091) - Single Sign-On Authentication
- **🆕 OAuth2 Proxy:** [http://192.168.8.250:4180](http://192.168.8.250:4180) - Service Proxy Gateway

## Signal Notifications 📱
The stack uses [signal-cli-rest-api](https://github.com/bbernhard/signal-cli-rest-api) for self-hosted Signal notifications:
- **Container restart notifications** from AI-Watchdog
- **Prometheus alerts** via Alertmanager
- **Test notifications** via API endpoint
- **End-to-end encrypted** using Signal protocol
- **No third-party dependencies** - fully self-hosted

For detailed setup instructions, see [SIGNAL_INTEGRATION_GUIDE.md](SIGNAL_INTEGRATION_GUIDE.md)

To test Signal notifications:
```bash
curl -X POST http://192.168.8.250:8080/test \
  -H "Content-Type: application/json" \
  -d '{"message": "Test from RPi HA DNS Stack"}'
```

## Health Check Commands ✅
- Check Pi-hole status:
  ```bash
  pihole status
  ```
- Check Unbound status:
  ```bash
  systemctl status unbound
  ```

## Troubleshooting 🔧

### Installation Issues

If you experience issues during installation (SSH disconnects, system reboots, errors):

1. **Use the Easy Installer** (recommended):
   ```bash
   bash scripts/easy-install.sh --verbose
   ```

2. **Common Issues & Solutions**:
   - **SSH Disconnects**: Use `screen` or `tmux` before installation
   - **System Reboots**: Check power supply (need 3A+), monitor temperature
   - **Docker Errors**: Run `sudo usermod -aG docker $USER && newgrp docker`
   - **Permission Errors**: Ensure you own the repo directory
   - **DNS Unreachable**: Network may be misconfigured - run `bash scripts/fix-dns-network.sh`

3. **Get Help**:
   - See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed solutions
   - Check [QUICKSTART.md](QUICKSTART.md) for quick reference
   - Report issues at: https://github.com/yorgosroussakis/rpi-ha-dns-stack/issues

### DNS Not Working?

If DNS containers are unreachable ("host unreachable" errors):

```bash
# Quick diagnosis
bash scripts/validate-network.sh

# Automated fix
bash scripts/fix-dns-network.sh
```

This typically happens when the network was created with the wrong type (bridge instead of macvlan).
See [TROUBLESHOOTING.md](TROUBLESHOOTING.md#issue-dns-containers-unreachable---host-unreachable-errors) for details.

### Quick Recovery

If installation fails:
```bash
# Check logs
cat install.log

# Resume installation
bash scripts/easy-install.sh

# Full reset (if needed)
docker compose down -v
docker system prune -af
rm -f .install_state .env
bash scripts/easy-install.sh
```

## Configuration Details ⚙️
- [Pi-hole Configuration](https://docs.pi-hole.net/)  
- [Unbound Configuration](https://nlnetlabs.nl/projects/unbound/about/)  
- [Keepalived Documentation](https://www.keepalived.org/)  
- [Prometheus Documentation](https://prometheus.io/docs/introduction/overview/)  

## 🔒 Remote Access (Optional - Super Easy!)

Need to access your home services remotely? We offer **THREE** user-friendly options - choose the easiest for your users!

### 🎯 Choose Your Solution

| Solution | User Ease | Setup | Best For |
|----------|-----------|-------|----------|
| **Tailscale** ⭐⭐⭐⭐⭐ | Install app & sign in | 5 min | EASIEST - Recommended! |
| **Cloudflare Tunnel** ⭐⭐⭐⭐⭐ | Just click a link | 15 min | Web services only (no app!) |
| **WireGuard** ⭐⭐ | Manual config files | 30 min | Advanced users |

### Option 1: Tailscale (RECOMMENDED - Easiest!)

**For End Users:** "Install Tailscale app, sign in with Google, done!"

**Setup:**
```bash
# 1. Get auth key from https://login.tailscale.com/admin/settings/keys
# 2. Add to .env:
TAILSCALE_AUTH_KEY=tskey-auth-xxxxxxxxx

# 3. Deploy:
docker compose -f stacks/remote-access/docker-compose.yml --profile tailscale up -d
```

**User Experience:**
- ✅ No configuration files
- ✅ No port forwarding needed
- ✅ Works with router VPN (Proton, etc.)
- ✅ Sign in with Google/Microsoft/GitHub
- ✅ Automatic access to all services

### Option 2: Cloudflare Tunnel (Web Services - No App Needed!)

**For End Users:** "Click this link: https://jellyfin.yourdomain.com"

**Setup:**
```bash
# 1. Need a domain name ($10/year)
# 2. Create tunnel in Cloudflare dashboard
# 3. Add to .env:
CLOUDFLARE_TUNNEL_TOKEN=your-token

# 4. Deploy:
docker compose -f stacks/remote-access/docker-compose.yml --profile cloudflare up -d
```

**User Experience:**
- ✅ No app installation
- ✅ No VPN needed
- ✅ Professional URLs (jellyfin.yourdomain.com)
- ✅ Free SSL certificates
- ✅ Works on any device with browser

### Option 3: WireGuard (Advanced)

Traditional VPN for power users. See **[stacks/vpn/README.md](stacks/vpn/README.md)** for details.

### Comparison

**Tailscale vs WireGuard:**
```
WireGuard User: "What do I do with this config file?"
Tailscale User: "I installed the app and signed in with Google. It just works!"
```

**Cloudflare vs Everything:**
```
You: "Access at https://jellyfin.yourdomain.com"
User: *clicks link* "That's it? Amazing!"
```

### Full Documentation

See **[stacks/remote-access/README.md](stacks/remote-access/README.md)** for:
- Detailed setup guides for all three options
- End user instructions
- Troubleshooting
- Which option to choose

### Why These Are Better

**The Problem with Traditional VPN:**
- ❌ Users struggle with config files
- ❌ Requires port forwarding
- ❌ Conflicts with router VPNs
- ❌ Complex troubleshooting

**With Tailscale/Cloudflare:**
- ✅ Users just "install & sign in" or "click a link"
- ✅ No port forwarding needed
- ✅ Works everywhere automatically
- ✅ Happy users! 🎉


## 🔐 Single Sign-On (SSO) - Optional but Powerful!

**Centralized Authentication with Authelia**

Tired of managing separate passwords for Pi-hole, Grafana, and WireGuard-UI? Enable SSO for:
- 🔑 **One Login for All Services** - Log in once, access everything
- 🛡️ **Two-Factor Authentication** - TOTP (Google Authenticator) and WebAuthn (YubiKey, TouchID)
- 👥 **User Management** - Add/remove users from one place
- 🚨 **Brute Force Protection** - Automatic rate limiting and banning
- 📊 **Session Control** - Manage active sessions, force logout
- 🔒 **Fine-grained Access Control** - Configure per-service permissions

### Quick SSO Setup

**Option 1: Use the Web Setup Wizard** (Easiest)

1. Launch the setup wizard:
   ```bash
   bash scripts/launch-setup-ui.sh
   ```

2. Follow the wizard to Step 7 (SSO Configuration)
3. Enable SSO and configure admin user
4. Complete the wizard and deploy

**Option 2: Manual Setup**

```bash
# 1. Generate secrets
cd stacks/sso
bash generate-secrets.sh

# 2. Update .env file
# Add the generated secrets to your .env file

# 3. Deploy SSO stack
docker compose up -d

# 4. Access Authelia portal
# http://192.168.8.250:9091
```

### Integrated Services

| Service | Integration | Access |
|---------|------------|---------|
| **Grafana** | Native OAuth2 | Click "Sign in with Authelia" |
| **Pi-hole** | OAuth2 Proxy | http://192.168.8.250:4180 |
| **WireGuard-UI** | External Auth | Auto-redirect to Authelia |
| **Nginx Proxy Manager** | OAuth2 Proxy | Protected endpoints |

### SSO Features

- **Password Policy**: Minimum 12 characters (configurable)
- **Session Duration**: 1 hour active, 5 minutes inactivity (configurable)
- **Remember Me**: 30 days (optional)
- **2FA Methods**: 
  - TOTP (Google Authenticator, Authy, 1Password, etc.)
  - WebAuthn (YubiKey, TouchID, Windows Hello, Android fingerprint)
- **User Groups**: `admins` (full access) and `users` (limited access)

### Documentation

- **[SSO Setup Guide](stacks/sso/README.md)** - Complete SSO documentation
- **[SSO Integration Guide](SSO_INTEGRATION_GUIDE.md)** - Integrate services with SSO
- **[Security Best Practices](SECURITY_GUIDE.md)** - Secure your SSO deployment

### Example: Grafana with SSO

Before SSO:
```
1. Navigate to http://192.168.8.250:3000
2. Enter username: admin
3. Enter password: your_grafana_password
4. Access Grafana
```

After SSO:
```
1. Navigate to http://192.168.8.250:3000
2. Click "Sign in with Authelia"
3. Enter your Authelia credentials (used for ALL services)
4. Complete 2FA (optional but recommended)
5. Access Grafana automatically
```

**Bonus**: Same login works for Pi-hole, WireGuard-UI, and any other integrated service!

### Why Use SSO?

**Security Benefits:**
- 🔐 One strong password to remember (instead of many)
- 🛡️ Mandatory 2FA for all services
- 🚨 Centralized brute force protection
- 📝 Audit trail of all authentication attempts
- ⏱️ Automatic session expiration

**Convenience Benefits:**
- 🎯 Single login for everything
- 💾 "Remember me" option
- 📱 Mobile-friendly authentication
- 🔄 Easy password reset
- 👥 Team member management

**For Home Users**: SSO might be overkill if you're the only user. But if you have family members or want maximum security, it's awesome!

**For Small Teams**: SSO is perfect for managing access for multiple users without creating separate accounts on each service.


## Conclusion 🏁
This README provides all necessary information to configure and run a high-availability DNS stack using Raspberry Pi 5. Enjoy a reliable and powerful DNS solution!