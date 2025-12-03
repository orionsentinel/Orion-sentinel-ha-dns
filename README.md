# Orion Sentinel DNS HA 🌐

**High-availability DNS stack for Raspberry Pi with ad-blocking, privacy protection, and automatic failover.**

Part of the [Orion Sentinel](docs/ORION_SENTINEL_ARCHITECTURE.md) home lab security platform.

---

## ⚡ Quick Start

### Getting Started
- **[📖 SIMPLE_INSTALLATION_GUIDE.md](SIMPLE_INSTALLATION_GUIDE.md)** - Easy step-by-step installation guide ⭐ **START HERE**
- **[⚡ INSTALLATION_STEPS.md](INSTALLATION_STEPS.md)** - Quick reference for installation steps
- **[📖 INSTALL.md](INSTALL.md)** - Comprehensive installation guide with advanced options
- **[✅ TEST_RESULTS.md](TEST_RESULTS.md)** - Installation verification test results
- **[🎯 Deployment Modes](docs/MODES_QUICK_REFERENCE.md)** - Standalone vs Integrated mode guide
- **[🧙 First-Run Web Wizard](wizard/README.md)** - Guided web-based setup (port 5555)
- **[📖 Single-Pi Installation](docs/install-single-pi.md)** - Step-by-step single node setup
- **[📖 Two-Pi HA Installation](docs/install-two-pi-ha.md)** - Step-by-step dual node HA setup
- **[🚀 QUICKSTART.md](QUICKSTART.md)** - One-page guide to get started fast
- **[📖 INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md)** - Detailed installation instructions

### ⚠️ Pi-hole DNS Configuration (CRITICAL)
- **[🔒 Pi-hole DNS Configuration Guide](docs/PIHOLE_CONFIGURATION.md)** - **MUST READ** - Privacy-first DNS policy ⭐ NEW

> **Privacy Policy:** This project **ONLY** supports Unbound (local recursive resolver) as Pi-hole upstreams.
> Public DNS providers (Google, Cloudflare, OpenDNS, Quad9) are **NOT supported** for privacy reasons.
> See the [Pi-hole DNS Configuration Guide](docs/PIHOLE_CONFIGURATION.md) for details.

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
- **Privacy Hardening**: Hide identity/version, query randomization, large query protection
- **Serve Expired**: Faster perceived response times during cache refresh

**Enable/Disable:**
```bash
git clone https://github.com/orionsentinel/Orion-sentinel-ha-dns.git
cd Orion-sentinel-ha-dns
bash install.sh
```

Then open `http://<your-pi-ip>:5555` and follow the wizard.

**📖 [Getting Started Guide](GETTING_STARTED.md)** — Detailed setup instructions

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🛡️ **Ad Blocking** | Network-wide ad/tracker blocking via Pi-hole |
| 🔒 **Privacy** | Recursive DNS with DNSSEC via Unbound |
| ⚡ **High Availability** | Automatic failover with Keepalived VIP |
| 📊 **Monitoring** | Built-in Grafana dashboards and alerts |
| 🔧 **Self-Healing** | Automatic failure detection and recovery |
| 💾 **Automated Backups** | Scheduled backups with off-site replication |
| 🔐 **Encrypted DNS** | DoH/DoT gateway for devices |
| 🌐 **Remote Access** | VPN, Tailscale, and Cloudflare options |

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  Your Network Devices                        │
└────────────────────────────┬────────────────────────────────┘
                             │ DNS Queries
                             ▼
┌─────────────────────────────────────────────────────────────┐
│              Keepalived VIP (Automatic Failover)             │
└────────────────────────────┬────────────────────────────────┘
              ┌──────────────┴──────────────┐
              ▼                             ▼
┌──────────────────────┐          ┌──────────────────────┐
│     Pi-hole #1       │          │     Pi-hole #2       │
│     Ad Blocking      │          │     Ad Blocking      │
└──────────┬───────────┘          └──────────┬───────────┘
           │                                 │
           ▼                                 ▼
┌──────────────────────┐          ┌──────────────────────┐
│     Unbound #1       │          │     Unbound #2       │
│   DNSSEC + Privacy   │          │   DNSSEC + Privacy   │
└──────────────────────┘          └──────────────────────┘
```

---

## 📚 Documentation

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

### 📋 Pre-configured Blocklists

Out of the box, Pi-hole is configured with high-quality, curated blocklists:

| List | Description | Domains |
|------|-------------|---------|
| **Hagezi Pro++** | Comprehensive ad/tracker/malware blocking | ~3M |
| **OISD Big** | Balanced blocking with low false positives | ~1.9M |
| **Hagezi Threat Intelligence** | Malware, phishing, threat intel | ~500K |
| **Hagezi Multi** | Multi-purpose filtering (family+ profiles) | ~1M |

**Blocklist Profile Environment Variable:**
```bash
# In .env file or at runtime
PIHOLE_BLOCKLIST_PROFILE=standard  # standard (default), family, or paranoid
```

**Pre-configured Streaming Whitelist:**
Disney+, Netflix, Amazon Prime, Hulu, HBO Max, Apple TV+, Spotify, YouTube

📖 **[USER_GUIDE.md](USER_GUIDE.md#blocklist-profiles--customization)** - Detailed blocklist documentation

### 💾 Backup & Disaster Recovery

Automated configuration backups for peace of mind:

- **Automated Backups**: Script backs up all configs, Pi-hole data, and settings
- **Checksum Verification**: SHA256 checksums ensure backup integrity
- **Selective Restoration**: Restore everything or specific components
- **Migration Support**: Easy migration to new hardware or SD cards

**What Gets Backed Up:**
- Environment configuration (`.env`)
- Docker Compose files
- Unbound configuration (including smart prefetch tuning)
- DoH/DoT Gateway configuration (Blocky config templates)
- Pi-hole configuration and databases
- DNS security profiles
- Prometheus configuration
- Grafana dashboards

**TLS Certificate Handling:**
TLS certificates for the DoH/DoT gateway are **NOT** backed up by default (security best practice). After restoring a backup:
```bash
# Regenerate TLS certificates
cd stacks/dns/blocky
bash generate-certs.sh dns.mylab.local
```

Alternatively, for production environments using Let's Encrypt or an internal CA, certificates can be re-issued automatically or restored from a secure secrets management system.

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

### Daily Operations
| Document | Description |
|----------|-------------|
| **[USER_GUIDE.md](USER_GUIDE.md)** | How to use and maintain the stack |
| **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** | Common issues and solutions |
| **[OPERATIONAL_RUNBOOK.md](OPERATIONAL_RUNBOOK.md)** | Day-to-day operations |

### Advanced Topics
| Document | Description |
|----------|-------------|
| **[ADVANCED_FEATURES.md](ADVANCED_FEATURES.md)** | VPN, SSO, DoH/DoT gateway |
| **[SECURITY_GUIDE.md](SECURITY_GUIDE.md)** | Security hardening |
| **[DISASTER_RECOVERY.md](DISASTER_RECOVERY.md)** | Backup and recovery procedures |

### Integration
| Document | Description |
|----------|-------------|
| **[docs/ORION_SENTINEL_INTEGRATION.md](docs/ORION_SENTINEL_INTEGRATION.md)** | NSM/AI integration |
| **[docs/SPOG_INTEGRATION_GUIDE.md](docs/SPOG_INTEGRATION_GUIDE.md)** | Centralized observability |

---

## 🎯 Deployment Options

| Option | Description | Best For |
|--------|-------------|----------|
| **Single-Pi HA** | One Pi, container redundancy | Home labs, testing |
| **Two-Pi HA** | Two Pis, hardware redundancy | Production |
| **VPN Edition** | HA DNS + WireGuard VPN | Remote access |

See **[deployments/](deployments/)** for detailed configurations.

---

## 🛡️ DNS Security Profiles

Apply pre-configured filtering levels:

```bash
python3 scripts/apply-profile.py --profile <profile>
```

| Profile | Description |
|---------|-------------|
| **Standard** | Balanced ad/tracker blocking |
| **Family** | + Adult content filtering |
| **Paranoid** | Maximum privacy protection |

---

## 🔗 Orion Sentinel Ecosystem

```
┌──────────────────────┐    ┌──────────────────────────┐
│ Orion Sentinel       │    │ Orion Sentinel NSM AI    │
│ DNS HA (THIS REPO)   │◄──►│ (Separate Repository)    │
│                      │    │                          │
│ • Pi-hole            │    │ • Suricata IDS           │
│ • Unbound            │    │ • Loki + Grafana         │
│ • Keepalived VIP     │    │ • AI Anomaly Detection   │
└──────────────────────┘    └──────────────────────────┘
```

---

## 🔧 Quick Commands

```bash
# Check service status
docker ps

# Test DNS resolution
dig @<your-ip> google.com

# Health check
bash scripts/health-check.sh

# Apply security profile
python3 scripts/apply-profile.py --profile standard

# Backup configuration
bash scripts/backup-config.sh

# Update stack
bash scripts/smart-upgrade.sh -i
```

---

## 📋 Requirements

**Hardware:**
- Raspberry Pi 4/5 (4GB+ RAM)
- 32GB+ SD card or SSD
- Ethernet connection
- 3A+ power supply

**Software:**
- Raspberry Pi OS (64-bit) or Ubuntu
- Docker 20.10+ (auto-installed)

---

## 🆘 Getting Help

- 📖 **[Full Documentation](docs/)**
- 🐛 **[GitHub Issues](https://github.com/orionsentinel/Orion-sentinel-ha-dns/issues)**
- 📝 **[CHANGELOG.md](CHANGELOG.md)** — What's new

---

## 📜 License

This project is open source. See the repository for license details.

---

**Ready to start?** Run `bash install.sh` and follow the wizard! 🚀
