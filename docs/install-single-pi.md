# Single Pi Installation Guide

**Orion Sentinel DNS HA - Single Node Mode**

This guide covers installing the DNS HA stack on a single Raspberry Pi without high availability failover.

---

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Installation Steps](#installation-steps)
- [Configuration](#configuration)
- [Verification](#verification)
- [Router Configuration](#router-configuration)
- [Next Steps](#next-steps)

---

## Overview

**Single-node mode** runs all DNS services (Pi-hole + Unbound + Keepalived) on one Raspberry Pi:

- **Redundancy Level**: Container-level only (dual Pi-hole and Unbound containers)
- **VIP**: Set to same as Pi's IP (no actual VIP failover)
- **Best For**: Home labs, testing, single Pi setups
- **Hardware Required**: 1x Raspberry Pi (4GB+ RAM recommended)

**Architecture:**
```
[Raspberry Pi]
├── Pi-hole Primary   (192.168.8.251)
├── Pi-hole Secondary (192.168.8.252)
├── Unbound Primary   (192.168.8.253)
├── Unbound Secondary (192.168.8.254)
└── Keepalived        (VIP = Pi's IP)
```

---

## Prerequisites

### Hardware Requirements
- Raspberry Pi 4 or 5 (4GB+ RAM recommended)
- 16GB+ microSD card (or SSD for better performance)
- Stable power supply (3A+)
- Ethernet connection recommended (WiFi supported but not ideal)

### Software Requirements
- Raspberry Pi OS (Debian-based)
- Static IP configured for the Pi
- Internet connectivity
- SSH access enabled (for remote setup)

### Network Requirements
- Static IP address for your Pi (e.g., 192.168.8.250)
- Access to your router to change DNS settings
- Note your network details:
  - Pi's IP: `192.168.8.250` (example)
  - Network interface: Usually `eth0` for Ethernet
  - Subnet: Usually `192.168.1.0/24` or `192.168.8.0/24`
  - Gateway: Your router's IP (e.g., `192.168.8.1`)

---

## Installation Steps

### Step 1: Clone the Repository

SSH into your Raspberry Pi and clone the repository:

```bash
cd ~
git clone https://github.com/yorgosroussakis/Orion-sentinel-ha-dns.git
cd Orion-sentinel-ha-dns
```

### Step 2: Run the Installation Script

Run the guided installation script:

```bash
bash scripts/install.sh
```

The script will:
1. ✅ Check system prerequisites (Docker, disk space, memory)
2. ✅ Install Docker if needed
3. ✅ Copy `.env.example` to `.env`
4. ✅ Prompt you for configuration
5. ✅ Create necessary networks and directories
6. ✅ Deploy the stack

### Step 3: Interactive Configuration

When prompted, provide the following information:

**Pi's LAN IP:**
```
Enter your Pi's LAN IP address [default: 192.168.8.250]: 
```
- Press ENTER to accept the detected IP or enter your Pi's static IP

**Deployment Mode:**
```
Choose deployment mode:
  1) Single-node mode (no VIP failover)
  2) Two-node HA mode (VIP + MASTER/BACKUP)
Enter choice [1 or 2]: 1
```
- Choose **1** for single-node mode

**Network Interface:**
```
Enter network interface [default: eth0]: 
```
- Press ENTER for `eth0` or enter your interface name (check with `ip addr`)

**Pi-hole Password:**
```
Enter Pi-hole web admin password: 
```
- Enter a strong password (or generate with `openssl rand -base64 32`)

The script will automatically set:
- `DNS_VIP` = Your Pi's IP (e.g., 192.168.8.250)
- `NODE_ROLE` = `MASTER` (single node acts as master)

### Step 4: Wait for Deployment

The script will:
- Create Docker networks
- Pull container images
- Start all services
- Verify basic functionality

This may take 5-10 minutes depending on your internet speed.

---

## Configuration

### Environment File

Your configuration is stored in `.env`:

```bash
# View configuration
cat .env

# Edit if needed
nano .env
```

**Key settings for single-node mode:**
```env
# Your Pi's IP
HOST_IP=192.168.8.250

# DNS container IPs (on macvlan network)
PRIMARY_DNS_IP=192.168.8.251
SECONDARY_DNS_IP=192.168.8.252
UNBOUND_PRIMARY_IP=192.168.8.253
UNBOUND_SECONDARY_IP=192.168.8.254

# VIP = Pi's IP (no failover)
VIP_ADDRESS=192.168.8.250

# Network settings
NETWORK_INTERFACE=eth0
SUBNET=192.168.8.0/24
GATEWAY=192.168.8.1

# Passwords (REQUIRED - change defaults!)
PIHOLE_PASSWORD=your_secure_password_here
GRAFANA_ADMIN_PASSWORD=your_secure_password_here
VRRP_PASSWORD=your_secure_password_here
```

### Generate Secure Passwords

Before deployment, generate strong passwords:

```bash
# Generate and update in .env
echo "PIHOLE_PASSWORD=$(openssl rand -base64 32)"
echo "GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 32)"
echo "VRRP_PASSWORD=$(openssl rand -base64 20)"
```

---

## Verification

### Check Running Containers

```bash
docker ps

# Should see:
# - pihole_primary
# - pihole_secondary
# - unbound_primary
# - unbound_secondary
# - keepalived
# - prometheus
# - grafana
# - and others...
```

### Test DNS Resolution

```bash
# Test DNS on VIP (your Pi's IP)
dig @192.168.8.250 google.com

# Test on Pi-hole primary
dig @192.168.8.251 google.com

# Should get valid DNS responses
```

### Check Pi-hole Web Interface

Open in your browser:
- Primary: `http://192.168.8.251/admin`
- Secondary: `http://192.168.8.252/admin`
- Via VIP: `http://192.168.8.250/admin`

Login with the password you set during installation.

### Check Grafana Dashboard

Open in your browser:
- `http://192.168.8.250:3000`

Login:
- Username: `admin`
- Password: From your `.env` file (`GRAFANA_ADMIN_PASSWORD`)

---

## Router Configuration

### Point Your Router to Use Pi-hole

1. Log into your router's admin panel (usually `http://192.168.8.1`)
2. Navigate to LAN/DHCP settings
3. Set DNS servers:
   - **Primary DNS**: `192.168.8.250` (your Pi's IP/VIP)
   - **Secondary DNS**: Leave blank or set to `1.1.1.1` as fallback
4. Save and reboot your router

### Alternative: Manual Client Configuration

If you can't change router DNS, configure clients manually:

**Windows:**
```
Control Panel → Network Connections → Ethernet Properties
→ IPv4 Properties → Use the following DNS servers
Primary: 192.168.8.250
```

**macOS:**
```
System Preferences → Network → Advanced → DNS
Add: 192.168.8.250
```

**Linux:**
```bash
# Edit /etc/resolv.conf
nameserver 192.168.8.250
```

---

## Next Steps

### Apply DNS Security Profile

Choose a security profile for your DNS filtering:

```bash
# Standard (recommended for most users)
python3 scripts/apply-profile.py --profile standard

# Family (adds adult content filtering)
python3 scripts/apply-profile.py --profile family

# Paranoid (maximum privacy/security)
python3 scripts/apply-profile.py --profile paranoid
```

See [docs/profiles.md](profiles.md) for profile details.

### Enable Monitoring

Access monitoring dashboards:
- **Grafana**: `http://192.168.8.250:3000`
- **Prometheus**: `http://192.168.8.250:9090`

### Setup Automated Backups

Schedule weekly backups:

```bash
# Edit crontab
crontab -e

# Add weekly backup (Sundays at 2 AM)
0 2 * * 0 /home/pi/Orion-sentinel-ha-dns/scripts/backup-config.sh
```

### Read Operational Documentation

- [Operations Guide](operations.md) - Backup, restore, upgrade
- [Troubleshooting](../TROUBLESHOOTING.md) - Common issues
- [Profiles Guide](profiles.md) - DNS filtering profiles

---

## Upgrading to Two-Pi HA

If you later acquire a second Pi, you can upgrade to full HA:

1. Set up the second Pi with the same repository
2. Change `NODE_ROLE` to `MASTER` on Pi #1 and `BACKUP` on Pi #2
3. Choose a different VIP (e.g., `192.168.8.255`)
4. Redeploy both Pis

See [docs/install-two-pi-ha.md](install-two-pi-ha.md) for details.

---

## Support

For issues or questions:
1. Check the [Troubleshooting Guide](../TROUBLESHOOTING.md)
2. Review [QUICKSTART.md](../QUICKSTART.md)
3. Open an issue on [GitHub](https://github.com/yorgosroussakis/Orion-sentinel-ha-dns/issues)
