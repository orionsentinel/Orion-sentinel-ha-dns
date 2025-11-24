# Orion Sentinel DNS HA - Installation Guide

This guide provides comprehensive, step-by-step instructions to install the Orion Sentinel DNS HA stack.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Installation Methods](#installation-methods)
- [Post-Installation](#post-installation)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Hardware Requirements
- **Minimum**: Raspberry Pi 4, 4GB RAM, 32GB SD Card
- **Recommended**: Raspberry Pi 5, 8GB RAM, 64GB+ SSD (USB), Active cooling
- Stable 3A+ power supply
- Ethernet connection (recommended)

### Software Requirements
- **Operating System**: Raspberry Pi OS (64-bit) or any Linux distribution
- **Architecture**: ARM64 (aarch64), ARMv7l, or x86_64
- **Docker**: Version 20.10 or later
- **Docker Compose**: Version 2.0 or later (plugin format)

### Network Requirements
- Static IP address or DHCP reservation
- Available IP addresses for:
  - Primary DNS (e.g., 192.168.8.251)
  - Secondary DNS (e.g., 192.168.8.252)
  - VIP (Virtual IP for HA, e.g., 192.168.8.255)
- Subnet and gateway information

### Knowledge Requirements
- Basic Linux command-line skills
- Understanding of DNS concepts
- Docker basics (helpful but not required)

---

## Quick Start

For users who want to get started immediately:

```bash
# 1. Clone the repository
git clone https://github.com/orionsentinel/Orion-sentinel-ha-dns.git
cd Orion-sentinel-ha-dns

# 2. Run the installation script
bash install.sh
```

The script will:
- Check system requirements
- Install Docker and dependencies
- Launch the web-based setup wizard at `http://<your-pi-ip>:5555`

---

## Installation Methods

### Method 1: Web-Based Setup Wizard (Recommended)

**Best for**: New users who prefer a graphical interface

```bash
git clone https://github.com/orionsentinel/Orion-sentinel-ha-dns.git
cd Orion-sentinel-ha-dns
bash install.sh
```

Then open your browser to `http://<your-pi-ip>:5555` and follow the wizard.

**Features**:
- Guided step-by-step configuration
- Visual validation of settings
- Automated deployment
- No command-line knowledge required

---

### Method 2: Interactive CLI Setup

**Best for**: Users comfortable with terminal but want guidance

```bash
git clone https://github.com/orionsentinel/Orion-sentinel-ha-dns.git
cd Orion-sentinel-ha-dns
bash scripts/install.sh
```

**Features**:
- Interactive prompts for configuration
- Automatic validation
- Real-time feedback
- No need to edit files manually

---

### Method 3: Manual Configuration

**Best for**: Advanced users who want full control

#### Step 1: Clone Repository
```bash
git clone https://github.com/orionsentinel/Orion-sentinel-ha-dns.git
cd Orion-sentinel-ha-dns
```

#### Step 2: Create Configuration
```bash
# Copy the example environment file
cp .env.example .env

# Edit the configuration
nano .env
```

**Required Settings**:
```bash
# Network Configuration
HOST_IP=192.168.8.250           # Your Pi's IP address
PRIMARY_DNS_IP=192.168.8.251    # Primary Pi-hole IP
SECONDARY_DNS_IP=192.168.8.252  # Secondary Pi-hole IP
VIP_ADDRESS=192.168.8.255       # Virtual IP (for HA)
NETWORK_INTERFACE=eth0          # Network interface
SUBNET=192.168.8.0/24          # Your network subnet
GATEWAY=192.168.8.1            # Your network gateway

# Security (CHANGE THESE!)
PIHOLE_PASSWORD=your_secure_password_here
GRAFANA_ADMIN_PASSWORD=your_secure_password_here
VRRP_PASSWORD=your_secure_password_here

# Timezone
TZ=Europe/Amsterdam
```

#### Step 3: Install Dependencies
```bash
# Install Docker (if not already installed)
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER

# Install Docker Compose plugin
sudo apt-get update
sudo apt-get install -y docker-compose-plugin

# Log out and back in for group changes to take effect
```

#### Step 4: Deploy the Stack
```bash
# Run the installation script
bash scripts/install.sh

# Or deploy manually
cd stacks/dns
docker compose --profile single-pi-ha up -d
```

---

## Deployment Modes

### Single-Node HA Mode
All services run on one Pi with redundancy:
- 2x Pi-hole instances (primary + secondary)
- 2x Unbound instances
- Keepalived for VIP management

```bash
# Deploy single-node HA
cd stacks/dns
docker compose --profile single-pi-ha up -d
```

### Two-Pi HA Mode
Services distributed across two Pis for true high availability:

**Pi 1 (Primary)**:
```bash
cd stacks/dns
docker compose --profile two-pi-ha-pi1 up -d
```

**Pi 2 (Secondary)**:
```bash
cd stacks/dns
docker compose --profile two-pi-ha-pi2 up -d
```

---

## Post-Installation

### 1. Access Web Interfaces

After successful deployment:

- **Pi-hole Primary**: `http://192.168.8.251/admin`
- **Pi-hole Secondary**: `http://192.168.8.252/admin`
- **Grafana**: `http://192.168.8.250:3000`
- **Prometheus**: `http://192.168.8.250:9090`

Default credentials:
- Pi-hole: Password from `PIHOLE_PASSWORD` in `.env`
- Grafana: `admin` / password from `GRAFANA_ADMIN_PASSWORD` in `.env`

### 2. Configure Your Router/DHCP Server

Set DNS servers in your router to:
- **Primary**: `192.168.8.255` (VIP - recommended)
- **Secondary**: `192.168.8.251` (Primary Pi-hole)

Or configure individual devices to use these DNS servers.

### 3. Apply Security Profile

Choose and apply a DNS filtering profile:

```bash
# Family-friendly (blocks ads + adult content)
bash scripts/apply-profile.py family

# Standard (blocks ads only)
bash scripts/apply-profile.py standard

# Paranoid (maximum blocking)
bash scripts/apply-profile.py paranoid
```

---

## Verification

### Check Services are Running
```bash
# View all running containers
docker ps

# Should see:
# - pihole_primary
# - pihole_secondary (single-node HA mode)
# - unbound_primary
# - unbound_secondary (single-node HA mode)
# - keepalived
```

### Test DNS Resolution
```bash
# Test DNS query through VIP
dig @192.168.8.255 google.com

# Test DNS query through primary
dig @192.168.8.251 google.com

# Test that blocked domains are blocked
dig @192.168.8.255 ads.example.com
```

### Check Container Health
```bash
# View container health status
docker ps --format "table {{.Names}}\t{{.Status}}"

# View logs for specific service
docker logs pihole_primary
docker logs unbound_primary
```

### Verify Network Configuration
```bash
# Check VIP is active
ip addr show | grep 192.168.8.255

# Test connectivity from another device
ping 192.168.8.255
```

---

## Troubleshooting

### Docker Permission Errors
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Apply group changes
newgrp docker

# Or log out and back in
```

### Services Not Starting
```bash
# Check logs
docker compose -f stacks/dns/docker-compose.yml logs

# Restart services
docker compose -f stacks/dns/docker-compose.yml restart

# Check Docker daemon
sudo systemctl status docker
```

### Network Issues
```bash
# Verify network configuration
docker network ls
docker network inspect dns_net

# Recreate network if needed
docker network rm dns_net
bash scripts/install.sh
```

### Can't Access from Pi Itself
This is normal with macvlan networks. The Pi cannot access its own macvlan IPs.
- Access services from another device on the network
- Use `docker exec` to access containers directly from the Pi

### DNS Not Resolving
```bash
# Check Pi-hole is running
docker logs pihole_primary

# Check Unbound is running
docker logs unbound_primary

# Verify DNS configuration in Pi-hole
docker exec pihole_primary pihole status

# Test DNS from container
docker exec pihole_primary dig @127.0.0.1 google.com
```

### High CPU/Memory Usage
```bash
# Check resource usage
docker stats

# Reduce logging in Pi-hole web interface
# Add swap space
sudo dphys-swapfile swapoff
sudo nano /etc/dphys-swapfile  # Increase CONF_SWAPSIZE
sudo dphys-swapfile setup
sudo dphys-swapfile swapon
```

---

## Next Steps

### Set Up Monitoring (Optional)
```bash
# Deploy observability stack
cd stacks/observability
docker compose up -d

# Access Grafana at http://192.168.8.250:3000
```

### Enable Automated Backups
```bash
# Set up cron jobs for automatic backups
bash scripts/setup-cron.sh
```

### Configure Notifications (Optional)
Edit `.env` and add Signal notification settings:
```bash
SIGNAL_NUMBER=+1234567890
SIGNAL_RECIPIENTS=+1234567890
```

### Integrate with NSM/AI (Optional)
See [ORION_SENTINEL_INTEGRATION.md](docs/ORION_SENTINEL_INTEGRATION.md) for details on integrating with the Network Security Monitoring & AI component.

---

## Additional Resources

- **[README.md](README.md)** - Project overview and features
- **[QUICKSTART.md](QUICKSTART.md)** - One-page quick reference
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Comprehensive troubleshooting guide
- **[USER_GUIDE.md](USER_GUIDE.md)** - Daily operation and maintenance
- **[TESTING_GUIDE.md](TESTING_GUIDE.md)** - Validation and testing procedures

---

## Getting Help

- **Documentation**: Check the docs in this repository
- **Issues**: [GitHub Issues](https://github.com/orionsentinel/Orion-sentinel-ha-dns/issues)
- **Community**: See README for community links

---

## Security Notes

⚠️ **Important Security Practices**:

1. **Change all default passwords** in `.env` before deployment
2. **Use strong passwords** (20+ characters, random)
3. **Keep system updated**: `sudo apt update && sudo apt upgrade`
4. **Review firewall rules**: Limit access to admin interfaces
5. **Monitor logs regularly**: Check for suspicious activity

Generate secure passwords:
```bash
# Generate random password
openssl rand -base64 32
```

---

**Installation Date**: _____________  
**Version**: 2.4.0  
**Last Updated**: November 2025
