# Installation Steps - Quick Reference

> **📌 This page redirects to the main installation guide.**

For installation instructions, please see:

- **[GETTING_STARTED.md](GETTING_STARTED.md)** — Quick start guide (recommended)
- **[INSTALL.md](INSTALL.md)** — Comprehensive installation reference

---

## ⚡ Quick Installation

```bash
git clone https://github.com/orionsentinel/Orion-sentinel-ha-dns.git
cd Orion-sentinel-ha-dns
bash install.sh
```

Then open `http://<your-pi-ip>:5555` and follow the wizard.

---

## Installation Methods

| Method | Command | Best For |
|--------|---------|----------|
| **Web Wizard** | `bash install.sh` | Everyone (recommended) |
| **CLI Interactive** | `bash scripts/cli-install.sh` | Terminal users |
| **Manual** | Edit `.env` + `docker compose up` | Advanced users |

See **[INSTALL.md](INSTALL.md)** for detailed instructions on each method.

---

## 🔧 Configuration Quick Guide

### Essential Settings (in .env file)

```bash
# Your Pi's Network Settings
HOST_IP=192.168.8.250           # Your Pi's IP
NETWORK_INTERFACE=eth0          # Usually eth0
SUBNET=192.168.8.0/24          # Your network subnet
GATEWAY=192.168.8.1            # Your router IP

# DNS Service IPs
PRIMARY_DNS_IP=192.168.8.251    # Primary Pi-hole
SECONDARY_DNS_IP=192.168.8.252  # Secondary Pi-hole
VIP_ADDRESS=192.168.8.255       # Virtual IP (for HA)

# Security (CHANGE THESE!)
PIHOLE_PASSWORD=<your_strong_password>
GRAFANA_ADMIN_PASSWORD=<your_strong_password>
VRRP_PASSWORD=<your_strong_password>

# Timezone
TZ=Europe/Amsterdam             # Your timezone
```

**Generate secure passwords**:
```bash
openssl rand -base64 32
```

---

## 🚀 Post-Installation Steps

### 1. Access Services

After installation completes:

| Service | URL | Default Login |
|---------|-----|---------------|
| Pi-hole (Primary) | http://192.168.8.251/admin | Password from .env |
| Pi-hole (Secondary) | http://192.168.8.252/admin | Password from .env |
| Grafana | http://192.168.8.250:3000 | admin / (password from .env) |
| Prometheus | http://192.168.8.250:9090 | N/A |

### 2. Configure Router DNS

Set your router's DNS servers to:
- **Primary**: 192.168.8.255 (VIP - recommended)
- **Secondary**: 192.168.8.251 (Primary Pi-hole)

### 3. Apply Security Profile

Choose a DNS filtering level:

```bash
# Family-friendly (blocks ads + adult content)
bash scripts/apply-profile.py family

# Standard (blocks ads only)
bash scripts/apply-profile.py standard

# Paranoid (maximum blocking)
bash scripts/apply-profile.py paranoid
```

### 4. Verify Everything Works

```bash
# Check services are running
docker ps

# Test DNS resolution
dig @192.168.8.255 google.com

# Check from another device
ping 192.168.8.255
nslookup google.com 192.168.8.255
```

---

## ✅ Verification Commands

### Before Installation
```bash
# Verify system is ready
bash scripts/verify-installation.sh
```

### After Installation
```bash
# Check all containers
docker ps

# View logs
docker logs pihole_primary
docker logs unbound_primary

# Test DNS
dig @192.168.8.255 google.com

# Check VIP status
ip addr show | grep 192.168.8.255
```

---

## 🐛 Quick Troubleshooting

### Docker Permission Issues
```bash
sudo usermod -aG docker $USER
newgrp docker
# Or log out and back in
```

### Services Won't Start
```bash
# Check logs
docker compose -f stacks/dns/docker-compose.yml logs

# Restart
docker compose -f stacks/dns/docker-compose.yml restart
```

### DNS Not Resolving
```bash
# Check Pi-hole
docker exec pihole_primary pihole status

# Check Unbound
docker logs unbound_primary

# Test from container
docker exec pihole_primary dig @127.0.0.1 google.com
```

### Can't Access from Pi Itself
This is **normal** with macvlan networks. Access services from another device on your network.

---

## 📚 Additional Resources

- **Full Installation Guide**: [INSTALL.md](INSTALL.md)
- **Quick Start**: [QUICKSTART.md](QUICKSTART.md)
- **Troubleshooting**: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **User Guide**: [USER_GUIDE.md](USER_GUIDE.md)
- **Test Results**: [TEST_RESULTS.md](TEST_RESULTS.md)

---

## 🎓 Installation Workflow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. VERIFY PREREQUISITES                                     │
│    bash scripts/verify-installation.sh                      │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. CHOOSE INSTALLATION METHOD                               │
│    • Web UI:  bash install.sh                               │
│    • CLI:     bash scripts/install.sh                       │
│    • Manual:  Edit .env and deploy                          │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. CONFIGURE SETTINGS                                       │
│    • Network IPs and interface                              │
│    • Passwords (IMPORTANT!)                                 │
│    • Timezone                                               │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. DEPLOY SERVICES                                          │
│    Docker containers will start automatically                │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. POST-INSTALLATION                                        │
│    • Access web interfaces                                  │
│    • Configure router DNS                                   │
│    • Apply security profile                                 │
│    • Verify with tests                                      │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔐 Security Checklist

Before going live:

- [ ] Changed all default passwords
- [ ] Used strong passwords (20+ characters)
- [ ] Configured firewall rules
- [ ] Limited access to admin interfaces
- [ ] Set up automated backups
- [ ] Enabled monitoring (optional)
- [ ] Reviewed security guide

---

## ⏱️ Expected Time

- **Pre-check**: 2 minutes
- **Installation**: 10-15 minutes
- **Configuration**: 5-10 minutes
- **Verification**: 5 minutes
- **Total**: ~25-35 minutes

---

## 💡 Pro Tips

1. **Use the Web UI** if you're new - it's the easiest method
2. **Test verification script first** - catches issues early
3. **Save your .env file** - backup for future reference
4. **Use screen/tmux** - prevents SSH disconnection issues
5. **Reserve IPs in router** - prevents IP conflicts
6. **Monitor temperature** - especially important for RPi
7. **Set up cooling** - heatsink or fan recommended

---

## 🆘 Getting Help

**Before asking for help**:
1. Run verification script
2. Check TEST_RESULTS.md
3. Review TROUBLESHOOTING.md
4. Check container logs

**For support**:
- GitHub Issues: https://github.com/orionsentinel/Orion-sentinel-ha-dns/issues
- Check existing documentation
- Include verification script output

---

**Ready to Install?**

```bash
bash scripts/verify-installation.sh && bash install.sh
```

Good luck! 🚀
