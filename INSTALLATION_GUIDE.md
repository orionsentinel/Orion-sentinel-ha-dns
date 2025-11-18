# Complete Installation Guide 📦

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Hardware Requirements](#hardware-requirements)
3. [Quick Installation](#quick-installation)
4. [Detailed Installation](#detailed-installation)
5. [Post-Installation Configuration](#post-installation-configuration)
6. [Verification](#verification)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required
- ✅ Raspberry Pi 4/5 (ARM64)
- ✅ Raspberry Pi OS (64-bit) - Debian Bookworm or later
- ✅ Minimum 4GB RAM (8GB recommended)
- ✅ Minimum 32GB SD card (64GB+ recommended)
- ✅ Ethernet connection (Wi-Fi not recommended for DNS server)
- ✅ Static IP address configured on Raspberry Pi
- ✅ Internet connectivity
- ✅ Root/sudo access

### Software Requirements
- Docker 24.0+
- Docker Compose 2.20+
- Git
- curl, wget, nano/vim

---

## Hardware Requirements

### Minimum Specifications
| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | Raspberry Pi 4 (4 cores) | Raspberry Pi 5 (4 cores) |
| RAM | 4GB | 8GB |
| Storage | 32GB SD Card | 64GB+ SSD via USB |
| Network | 100Mbps Ethernet | 1Gbps Ethernet |
| Power | 3A USB-C | 3A+ USB-C with cooling |

### Estimated Resource Usage
- **CPU**: 10-20% average, 40% peak
- **RAM**: 2-3GB (with all features enabled)
- **Disk**: 10-20GB (depends on logs and analytics retention)
- **Network**: ~1-5 Mbps (varies with query volume)

---

## Quick Installation

### One-Command Setup (Easiest)

```bash
# Clone repository
git clone https://github.com/yorgosroussakis/rpi-ha-dns-stack.git
cd rpi-ha-dns-stack

# Run automated installer
sudo bash scripts/install.sh
```

The installer will:
1. Check system requirements
2. Install Docker and dependencies
3. Configure network settings
4. Create `.env` file with your inputs
5. Deploy all services
6. Run health checks

**Installation time**: 15-30 minutes

---

## Detailed Installation

### Step 1: Prepare Raspberry Pi

#### 1.1 Update System
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl wget vim net-tools dnsutils
```

#### 1.2 Set Static IP
Edit `/etc/dhcpcd.conf`:
```bash
sudo nano /etc/dhcpcd.conf
```

Add (adjust for your network):
```conf
interface eth0
static ip_address=192.168.8.226/24
static routers=192.168.8.1
static domain_name_servers=8.8.8.8 1.1.1.1
```

Reboot:
```bash
sudo reboot
```

#### 1.3 Configure Hostname (Optional)
```bash
sudo hostnamectl set-hostname rpi-dns-server
```

### Step 2: Install Docker

#### 2.1 Install Docker Engine
```bash
# Download and run Docker install script
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Logout and login for group changes to take effect
# Or run: newgrp docker
```

#### 2.2 Install Docker Compose
```bash
# Install Docker Compose plugin
sudo apt install -y docker-compose-plugin

# Verify installation
docker compose version
# Should show: Docker Compose version v2.x.x
```

#### 2.3 Enable Docker Service
```bash
sudo systemctl enable docker
sudo systemctl start docker
```

### Step 3: Clone Repository

```bash
cd /opt
sudo git clone https://github.com/yorgosroussakis/rpi-ha-dns-stack.git
sudo chown -R $USER:$USER rpi-ha-dns-stack
cd rpi-ha-dns-stack
```

### Step 4: Configure Environment

#### 4.1 Generate Secure Passwords

Before creating the `.env` file, generate secure passwords:

```bash
# Generate Pi-hole admin password
echo "PIHOLE_PASSWORD=$(openssl rand -base64 32)"

# Generate Grafana admin password
echo "GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 32)"

# Generate Keepalived VRRP password
echo "VRRP_PASSWORD=$(openssl rand -base64 20)"
```

**Save these passwords securely!** You'll need them to access your services.

#### 4.2 Create .env File
```bash
cp .env.example .env
nano .env
```

#### 4.3 Essential Configuration
Edit `.env` with your settings (paste the generated passwords from step 4.1):

```bash
# Network Configuration
SUBNET=192.168.8.0/24
GATEWAY=192.168.8.1
NETWORK_INTERFACE=eth0

# IP Addresses (adjust if needed)
HOST_IP=192.168.8.250
PRIMARY_DNS_IP=192.168.8.251
SECONDARY_DNS_IP=192.168.8.252
UNBOUND_PRIMARY_IP=192.168.8.253
UNBOUND_SECONDARY_IP=192.168.8.254
VIP_ADDRESS=192.168.8.255

# Timezone
TZ=Europe/London

# Pi-hole Configuration
# SECURITY: Generate a strong random password
# Example: openssl rand -base64 32
PIHOLE_PASSWORD=YourSecurePassword123!

# Grafana
GRAFANA_ADMIN_USER=admin
# SECURITY: Generate a strong random password
# Example: openssl rand -base64 32
GRAFANA_ADMIN_PASSWORD=YourGrafanaPassword123!

# Keepalived
# SECURITY: Generate a strong random password
# Example: openssl rand -base64 20
VRRP_PASSWORD=SecureVRRPPassword123!

# Signal Notifications (Optional - using signal-cli-rest-api)
SIGNAL_NUMBER=+1234567890
SIGNAL_RECIPIENTS=+1234567890
```

**Important Security Note**: 
- Replace ALL default passwords with secure ones before deployment!
- Generate strong passwords using: `openssl rand -base64 32`
- Never use the example passwords shown above in production

#### 4.4 Validate Configuration

Before proceeding, validate your `.env` file:

```bash
# Validate required variables and password security
bash scripts/validate-env.sh

# Test that the .env file can be sourced without errors
bash scripts/test-env-format.sh
```

Both scripts should report success. If you see errors, fix them before continuing.

### Step 5: Create Docker Network

#### 5.1 Create Macvlan Network
```bash
sudo docker network create \
  -d macvlan \
  --subnet=192.168.8.0/24 \
  --gateway=192.168.8.1 \
  -o parent=eth0 \
  dns_net
```

#### 5.2 Verify Network
```bash
sudo docker network inspect dns_net | grep -E 'Driver|Subnet|Gateway'
```

Expected output:
```
"Driver": "macvlan",
"Subnet": "192.168.8.0/24",
"Gateway": "192.168.8.1"
```

### Step 6: Deploy Services

#### 6.1 Deploy DNS Stack
```bash
cd /opt/rpi-ha-dns-stack/stacks/dns

# Build keepalived image
docker compose build keepalived

# Start all DNS services
docker compose up -d

# Check status
docker compose ps
```

Wait 60 seconds for containers to initialize.

#### 6.2 Configure Pi-hole
```bash
# Run Pi-hole setup script
sudo bash setup-pihole.sh
```

This configures:
- Blocklists (Hagezi Pro++, OISD Big)
- Whitelists (Disney+, streaming services)
- DNS forwarding to unbound
- Sync between primary and secondary

#### 6.3 Deploy Observability Stack
```bash
cd /opt/rpi-ha-dns-stack/stacks/observability
docker compose up -d
```

#### 6.4 Deploy Self-Healing Service
```bash
cd /opt/rpi-ha-dns-stack/stacks/self-healing
docker compose build
docker compose up -d
```

#### 6.5 Deploy Backup Service
```bash
cd /opt/rpi-ha-dns-stack/stacks/backup
cp .env.example .env
nano .env  # Configure backup retention
docker compose up -d
```

#### 6.6 Deploy Traffic Analytics (Optional)
```bash
cd /opt/rpi-ha-dns-stack/stacks/traffic-analytics
docker compose up -d
```

#### 6.7 Deploy Multi-Region Failover (Optional)
```bash
cd /opt/rpi-ha-dns-stack/stacks/dns
docker compose -f docker-compose.yml -f multi-region-failover.yml up -d
```

### Step 7: Configure AI Watchdog (Optional)

```bash
cd /opt/rpi-ha-dns-stack/stacks/ai-watchdog
docker compose build
docker compose up -d
```

---

## Post-Installation Configuration

### Configure Router

#### Set DNS Servers on Router
1. Access your router's admin interface (usually http://192.168.8.1)
2. Navigate to DHCP/DNS settings
3. Set DNS servers:
   - **Primary DNS**: 192.168.8.255 (VIP) or 192.168.8.251
   - **Secondary DNS**: 192.168.8.252
4. Save and reboot router
5. Renew DHCP leases on client devices

### Configure Individual Devices (Alternative)

For testing before router configuration:

**Windows**:
```
Control Panel → Network → Change Adapter Settings
→ Ethernet/Wi-Fi Properties → IPv4 Properties
→ Use the following DNS servers:
   Preferred: 192.168.8.255
   Alternate: 192.168.8.251
```

**macOS**:
```
System Preferences → Network → Advanced → DNS
→ Add: 192.168.8.255, 192.168.8.251
```

**Linux**:
```bash
# Edit /etc/resolv.conf
sudo nano /etc/resolv.conf

# Add:
nameserver 192.168.8.255
nameserver 192.168.8.251
```

**iOS/Android**:
```
Settings → Wi-Fi → Your Network → Configure DNS
→ Manual → Add: 192.168.8.255
```

---

## Verification

### Run Health Check
```bash
cd /opt/rpi-ha-dns-stack
bash scripts/health-check.sh
```

### Verify DNS Resolution
```bash
# From another device on your network:
dig google.com @192.168.8.255
nslookup google.com 192.168.8.255

# Should return IP address quickly
```

### Check Container Status
```bash
# DNS stack
cd /opt/rpi-ha-dns-stack/stacks/dns
docker compose ps

# All containers should show "Up (healthy)"
```

### Access Web Interfaces

| Service | URL | Default Login |
|---------|-----|---------------|
| **Unified Dashboard** | http://192.168.8.250/dashboard.html | N/A |
| **Pi-hole Primary** | http://192.168.8.251/admin | Password from .env |
| **Pi-hole Secondary** | http://192.168.8.252/admin | Password from .env |
| **Grafana** | http://192.168.8.250:3000 | admin / (password from .env) |
| **Prometheus** | http://192.168.8.250:9090 | N/A |
| **Alertmanager** | http://192.168.8.250:9093 | N/A |
| **Traffic Analytics** | http://192.168.8.250:3001 | admin / (grafana password) |

### Test DNS Features

#### Test Blocking
```bash
dig ads.google.com @192.168.8.255
# Should return 0.0.0.0 (blocked)
```

#### Test DNSSEC
```bash
dig dnssec-failed.org @192.168.8.253 +dnssec
# Should return SERVFAIL (validation failed)

dig cloudflare.com @192.168.8.253 +dnssec
# Should return valid response with DNSSEC signatures
```

#### Test Failover
```bash
# Stop primary
docker stop pihole_primary

# Wait 60 seconds
sleep 60

# Test DNS (should still work via secondary)
dig google.com @192.168.8.255

# Restart primary
docker start pihole_primary
```

### Check Metrics
```bash
# Self-healing metrics
curl http://192.168.8.250:8080/metrics

# Failover metrics
curl http://192.168.8.250:8081/metrics

# Traffic analytics
curl http://192.168.8.250:8082/metrics

# AI Watchdog metrics
curl http://192.168.8.250:5000/metrics
```

---

## Troubleshooting

### Common Issues

#### 1. Containers Not Starting
```bash
# Check logs
docker logs pihole_primary
docker logs unbound_primary

# Check resources
docker stats

# Restart services
cd /opt/rpi-ha-dns-stack/stacks/dns
docker compose restart
```

#### 2. DNS Not Resolving
```bash
# Check if containers are running
docker ps | grep -E 'pihole|unbound|keepalived'

# Test each component
dig @192.168.8.251 google.com  # Test primary Pi-hole
dig @192.168.8.253 google.com  # Test primary unbound
dig @192.168.8.255 google.com  # Test VIP

# Check Pi-hole logs
docker logs pihole_primary | tail -100
```

#### 3. Cannot Access from Host
This is **normal** with macvlan networks. The Raspberry Pi host cannot directly communicate with containers on the macvlan network. This is a Docker limitation, not a bug.

**Solutions**:
- Access services from another device on your network
- Use `docker exec` to access containers:
  ```bash
  docker exec -it pihole_primary bash
  ```

#### 4. Network Configuration Issues
```bash
# Recreate network
sudo docker network rm dns_net
sudo docker network create \
  -d macvlan \
  --subnet=192.168.8.0/24 \
  --gateway=192.168.8.1 \
  -o parent=eth0 \
  dns_net

# Restart DNS stack
cd /opt/rpi-ha-dns-stack/stacks/dns
docker compose down
docker compose up -d
```

#### 5. Performance Issues
```bash
# Check system resources
htop
df -h
free -h

# Check Docker resources
docker stats

# Optimize if needed:
# - Reduce analytics retention
# - Disable unused features
# - Increase swap space
```

### Getting Help

1. **Check logs**: Always check container logs first
   ```bash
   docker logs <container_name> --tail 100
   ```

2. **Run diagnostics**:
   ```bash
   bash /opt/rpi-ha-dns-stack/scripts/test-environment.sh
   ```

3. **Check documentation**:
   - [USER_GUIDE.md](USER_GUIDE.md)
   - [ADVANCED_FEATURES.md](ADVANCED_FEATURES.md)
   - [SECURITY_GUIDE.md](SECURITY_GUIDE.md)

4. **GitHub Issues**: https://github.com/yorgosroussakis/rpi-ha-dns-stack/issues

---

## Next Steps

After successful installation:

1. ✅ **Review User Guide**: See [USER_GUIDE.md](USER_GUIDE.md)
2. ✅ **Configure Backups**: Test backup/restore procedures
3. ✅ **Set Up Monitoring**: Configure Grafana dashboards
4. ✅ **Enable Notifications**: Configure Signal alerts (optional)
5. ✅ **Security Hardening**: Review [SECURITY_GUIDE.md](SECURITY_GUIDE.md)
6. ✅ **Performance Tuning**: Review [OPTIMIZATION_IMPLEMENTATION.md](OPTIMIZATION_IMPLEMENTATION.md)
7. ✅ **Advanced Features**: Enable as needed from [ADVANCED_FEATURES.md](ADVANCED_FEATURES.md)

---

## Installation Complete! 🎉

Your high-availability DNS stack is now running. All devices on your network using these DNS servers will benefit from:

- ✅ Ad/tracker blocking
- ✅ Malware protection
- ✅ DNS encryption (DoH)
- ✅ DNSSEC validation
- ✅ High availability (automatic failover)
- ✅ Self-healing capabilities
- ✅ Comprehensive monitoring
- ✅ Automated backups

**Enjoy your privacy-focused, high-performance DNS infrastructure!**
