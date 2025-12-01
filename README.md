# Orion Sentinel DNS HA 🌐

**High-availability DNS stack for Raspberry Pi with ad-blocking, privacy protection, and automatic failover.**

Part of the [Orion Sentinel](docs/ORION_SENTINEL_ARCHITECTURE.md) home lab security platform.

---

## ⚡ Quick Start

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

### Getting Started
| Document | Description |
|----------|-------------|
| **[GETTING_STARTED.md](GETTING_STARTED.md)** | Quick start guide — **start here** |
| **[INSTALL.md](INSTALL.md)** | Comprehensive installation reference |
| **[docs/install-single-pi.md](docs/install-single-pi.md)** | Single Raspberry Pi setup |
| **[docs/install-two-pi-ha.md](docs/install-two-pi-ha.md)** | Two-Pi high availability setup |

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
