# Installation Steps - Quick Reference

**Last Updated**: November 23, 2025  
**Version**: 2.4.0

---

## ⚡ Quick Installation (Most Users)

```bash
# 1. Clone repository
git clone https://github.com/orionsentinel/Orion-sentinel-ha-dns.git
cd Orion-sentinel-ha-dns

# 2. Verify system is ready
bash scripts/verify-installation.sh

# 3. Run installation
bash install.sh

# 4. Open web wizard
# Navigate to: http://<your-pi-ip>:5555
```

**That's it!** The web wizard will guide you through the rest.

---

## 📋 Prerequisites Checklist

Before you begin, ensure you have:

### Hardware
- [ ] Raspberry Pi 4/5 (4GB+ RAM recommended)
- [ ] 32GB+ SD card or SSD
- [ ] Stable 3A+ power supply
- [ ] Ethernet connection (recommended)

### Network Planning
- [ ] Static IP address assigned to your Pi
- [ ] Available IP addresses for:
  - Primary DNS (e.g., 192.168.8.251)
  - Secondary DNS (e.g., 192.168.8.252)
  - VIP (e.g., 192.168.8.255)
- [ ] Know your network's subnet and gateway

### Software (Auto-installed if missing)
- [ ] Raspberry Pi OS (64-bit) or Linux
- [ ] Docker (20.10+)
- [ ] Docker Compose (v2.0+)

---

## 🎯 Installation Methods

### Option 1: Automated Web Setup (Easiest)

**Best for**: First-time users, beginners

```bash
git clone https://github.com/orionsentinel/Orion-sentinel-ha-dns.git
cd Orion-sentinel-ha-dns
bash install.sh
```

Then visit: `http://<your-pi-ip>:5555`

**Time**: ~10-15 minutes

---

### Option 2: Interactive CLI Setup (Power Users)

**Best for**: Users comfortable with terminal

```bash
git clone https://github.com/orionsentinel/Orion-sentinel-ha-dns.git
cd Orion-sentinel-ha-dns
bash scripts/install.sh
```

Follow the prompts to configure your installation.

**Time**: ~15-20 minutes

---

### Option 3: Manual Configuration (Advanced)

**Best for**: Advanced users wanting full control

```bash
# 1. Clone
git clone https://github.com/orionsentinel/Orion-sentinel-ha-dns.git
cd Orion-sentinel-ha-dns

# 2. Configure
cp .env.example .env
nano .env  # Edit all settings

# 3. Install
bash scripts/install.sh

# 4. Deploy
cd stacks/dns
docker compose --profile single-pi-ha up -d
```

**Time**: ~20-30 minutes

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
