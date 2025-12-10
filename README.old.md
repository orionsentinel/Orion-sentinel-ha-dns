# Orion Sentinel DNS HA 🌐

**High-availability DNS stack for Raspberry Pi with ad-blocking, privacy protection, and automatic failover.**

Part of the [Orion Sentinel](docs/ORION_SENTINEL_ARCHITECTURE.md) home lab security platform.

---

## 🆕 NEW: Production-Ready Structure

**Simplified setup for maximum reliability and minimal maintenance!**

### 🚀 Quick Start (Production Setup)

```bash
# 1. Clone repository
git clone https://github.com/orionsentinel/Orion-sentinel-ha-dns.git
cd Orion-sentinel-ha-dns

# 2. Bootstrap your Pi(s)
sudo ./scripts/bootstrap-node.sh --node=pi1 --ip=192.168.8.250

# 3. Configure environment
cp .env.production.example .env
nano .env  # Set passwords and IPs

# 4. Deploy!
make up-core
```

**That's it!** See [QUICKSTART.production.md](QUICKSTART.production.md) for detailed two-Pi HA setup.

### DNS HA Overview (PR1)

- Node A (primary): `192.168.8.249`
- Node B (secondary): `192.168.8.243`
- Floating VIP: `192.168.8.250/24` on `eth1` managed by `keepalived`
- `pihole_unbound` runs Pi-hole + Unbound (DNSSEC, DoT-ready, optional Redis), `keepalived` handles VRRP failover.

Run modes:
- Single node: `docker compose --profile single-node up -d`
- Primary (MASTER): `NODE_ROLE=MASTER KEEPALIVED_PRIORITY=200 NODE_IP=192.168.8.249 docker compose --profile two-node-ha-primary up -d`
- Secondary (BACKUP): `NODE_ROLE=BACKUP KEEPALIVED_PRIORITY=150 NODE_IP=192.168.8.243 PEER_IP=192.168.8.249 docker compose --profile two-node-ha-backup up -d`

Basic checks:
- DNS: `dig @192.168.8.250 github.com +short`
- Failover: stop Pi-hole on the primary and confirm DNS still answers on `192.168.8.250`.

Troubleshooting:
- No response on port 53: ensure `network_mode: host` is used and `DNSMASQ_LISTENING=all` is set.
- VIP not assigned: verify `NETWORK_INTERFACE=eth1`, `USE_UNICAST_VRRP=true`, and `PEER_IP` is set on both nodes.
- Keepalived restart loop: check `/etc/keepalived/keepalived.conf` for syntax errors; auth_pass must be plain text (no `${}` or `\n` literals).

### 📊 Observability (PR2)

The keepalived notify scripts can push VRRP state metrics to a Prometheus Pushgateway.

**Configuration:**

Set these environment variables in your `.env` file or pass them to Docker Compose:

```env
PROM_PUSHGATEWAY_URL=http://pushgateway.example.com:9091
PROM_JOB_NAME=orion_dns_ha
PROM_INSTANCE_LABEL=node-a
```

**Metric:**

- **`keepalived_vrrp_state`** - gauge indicating VRRP state
  - Value `1` = MASTER
  - Value `0` = BACKUP
  - Value `-1` = FAULT
- **Labels:** `job`, `instance`, `router_id`, `name`, `type`, `state`

If `PROM_PUSHGATEWAY_URL` is empty (the default), no metrics are pushed and the scripts only log to `/var/log/keepalived-notify.log`.

### 🔧 Operations (PR3)

Host-level operational tooling for autostart, auto-healing, and backups.

#### Autostart via systemd

Example systemd units are in [`systemd/`](systemd/) for managing the stack on boot:

```bash
# On PRIMARY node
sudo cp systemd/orion-dns-ha-primary.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now orion-dns-ha-primary.service

# On BACKUP node
sudo cp systemd/orion-dns-ha-backup-node.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now orion-dns-ha-backup-node.service
```

These services call `docker compose --profile <profile> up -d` on start and `down` on stop.

#### Auto-Healing

The health timer runs every minute, executes the same `check_dns.sh` used by keepalived, and restarts containers on repeated failures:

```bash
# Install on BOTH nodes
sudo cp systemd/orion-dns-ha-health.* /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now orion-dns-ha-health.timer
```

- Tracks consecutive DNS failures (default threshold: 2)
- Restarts `pihole_unbound` when threshold is reached
- Starts `keepalived` if not running
- Logs to journald: `journalctl -u orion-dns-ha-health.service`

#### Backups

Daily compressed backups with automatic retention:

```bash
# Install on BOTH nodes
sudo cp systemd/orion-dns-ha-backup.* /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now orion-dns-ha-backup.timer
```

**What gets backed up:**
- `compose.yml` and `.env*` files
- `pihole/etc-pihole/` (gravity, settings)
- `pihole/etc-dnsmasq.d/` (dnsmasq configs)
- `keepalived/config/` (keepalived.conf, scripts)

**Backup location:** `backups/dns-ha-backup-<hostname>-YYYYMMDD-HHMMSS.tgz`

**Retention:** Backups older than 14 days are automatically deleted (configurable via `BACKUP_RETENTION_DAYS`).

**Restore:**
```bash
# Stop the stack, extract backup, start the stack
./ops/orion-dns-restore.sh backups/dns-ha-backup-pi1-20240115-031500.tgz

# Preview restore without making changes
./ops/orion-dns-restore.sh --dry-run backups/dns-ha-backup-pi1-20240115-031500.tgz

# List available backups
./ops/orion-dns-restore.sh --list
```

See [`ops/README.md`](ops/README.md) and [`systemd/README.md`](systemd/README.md) for full details.

### 🌐 NextDNS Mode (Optional)

By default, Unbound performs **fully local recursive DNS resolution** — queries go directly to authoritative DNS servers without any third-party forwarder.

If you want DNS over TLS (DoT) forwarding to NextDNS:

1. Edit `unbound/nextdns-forward.conf`
2. Uncomment the `forward-zone` block
3. Replace `<your-id>` with your NextDNS configuration ID (from https://my.nextdns.io)
4. Restart the stack: `docker compose --profile <your-profile> restart pihole_unbound`

**Example enabled config:**
```conf
server:
    tls-cert-bundle: "/etc/ssl/certs/ca-certificates.crt"

forward-zone:
    name: "."
    forward-tls-upstream: yes
    forward-addr: 45.90.28.0@853#abc123.dns.nextdns.io
    forward-addr: 45.90.30.0@853#abc123.dns.nextdns.io
```

To disable NextDNS and return to local recursive resolution, comment out the `forward-zone` block or delete the file.

### 📖 Production Documentation

- **[🚀 QUICKSTART.production.md](QUICKSTART.production.md)** - Get running in 10 minutes ⭐ **START HERE**
- **[📖 README.production.md](README.production.md)** - Complete production guide
- **[🔄 docs/migration.md](docs/migration.md)** - Migrate from old structure
- **[📋 PLAN.md](PLAN.md)** - Refactoring plan and design decisions

### Key Features

✅ **Single `compose.yml`** at root - no more multiple deployment folders  
✅ **`Makefile`** for all operations - `make up-core`, `make health-check`, etc.  
✅ **Template-based config** - works for both Pi1 and Pi2 with just env vars  
✅ **Bootstrap script** - automated first-time setup  
✅ **Profile-based** - deploy only what you need (`dns-core`, `exporters`, etc.)

---

## 🔧 Legacy Installation

**The following methods still work but are being phased out:**

### Quick Installation (Web Wizard)
```bash
git clone https://github.com/orionsentinel/Orion-sentinel-ha-dns.git
cd Orion-sentinel-ha-dns
bash install.sh
```
Then open `http://<your-pi-ip>:5555` in your browser and follow the web wizard.

### Documentation (Legacy)
- **[📖 SIMPLE_INSTALLATION_GUIDE.md](SIMPLE_INSTALLATION_GUIDE.md)** - Complete step-by-step guide
- **[🚀 QUICKSTART.md](QUICKSTART.md)** - One-page quick reference

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
- **[🔄 Update Guide](docs/update.md)** - How to update images and configurations ⭐ NEW

### Backup & Restore
- **[💾 Backup Scripts](backup/README.md)** - Automated volume backups ⭐ NEW
  - `sudo ./backup/backup-volumes.sh` - Backup all critical volumes
  - `sudo ./backup/restore-volume.sh <backup-file>` - Restore from backup
  - Weekly backups recommended: `0 2 * * 0 /path/to/backup/backup-volumes.sh`

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
