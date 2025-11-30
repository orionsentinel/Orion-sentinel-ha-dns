# Two Raspberry Pi High Availability Installation Guide

**Orion Sentinel DNS HA - Dual-Pi Setup with Automatic Failover**

This guide walks you through installing Orion DNS HA on two Raspberry Pis with full hardware redundancy and automatic failover.

---

## Quick Start (TL;DR)

For experienced users, here's the quick setup:

```bash
# On BOTH Pis:
git clone https://github.com/orionsentinel/Orion-sentinel-ha-dns.git
cd Orion-sentinel-ha-dns

# Copy the two-pi-ha environment template
cp env/.env.two-pi-ha.example .env

# Edit .env - set these values (same on both, EXCEPT HOST_IP and KEEPALIVED_PRIORITY):
#   PI1_IP=192.168.8.250
#   PI2_IP=192.168.8.251
#   VIP_ADDRESS=192.168.8.249
#   HOST_IP=<this Pi's IP>         # 192.168.8.250 on Pi1, 192.168.8.251 on Pi2
#   KEEPALIVED_PRIORITY=<priority> # 100 on Pi1 (MASTER), 90 on Pi2 (BACKUP)
#   VRRP_PASSWORD=<secure password>
#   PIHOLE_PASSWORD=<secure password>
#   Generate passwords with: openssl rand -base64 32

# Validate configuration
bash scripts/validate-env.sh
bash scripts/test-env-format.sh

# Deploy on Pi1:
cd stacks/dns && docker compose --profile two-pi-ha-pi1 up -d

# Deploy on Pi2:
cd stacks/dns && docker compose --profile two-pi-ha-pi2 up -d

# Verify (on both):
bash scripts/vip-health.sh
dig +short example.com @${VIP_ADDRESS}
```

---

## Overview

A two-Pi HA deployment provides:
- ✅ Hardware redundancy - DNS continues if one Pi fails
- ✅ Automatic failover - VIP moves to backup Pi within seconds
- ✅ Zero-downtime updates - Update one Pi while the other serves DNS
- ✅ Container-level redundancy - Multiple instances per Pi
- ✅ Production-grade reliability

**Deployment model:** `HighAvail_2Pi1P1U` (Recommended)
- 2 Raspberry Pis
- 1 Pi-hole per Pi
- 1 Unbound per Pi
- Shared Virtual IP (VIP)

---

## Prerequisites

### Hardware Requirements

- **2x Raspberry Pi 4** (4GB RAM recommended each)
- **2x MicroSD cards** (32GB or larger, Class 10)
- **2x Ethernet cables** (Wi-Fi not recommended for HA)
- **2x Power supplies** (official RPi power supply)
- **Network switch** with available ports

### Network Requirements

- **2 static IP addresses** for your Pis (one per Pi)
- **1 Virtual IP (VIP)** address not used by any device
- All three IPs must be on the same subnet
- Access to your router's admin interface

**Example IP scheme:**
- Pi #1 (MASTER): `192.168.1.100`
- Pi #2 (BACKUP): `192.168.1.101`
- VIP (shared): `192.168.1.200`

**Important:** The VIP should be outside your router's DHCP range to avoid conflicts.

---

## Installation Process

You need to set up both Pis. The process is similar but with different node roles.

---

## Pi #1 (MASTER Node) Setup

### 1. Clone the Repository

```bash
# On Pi #1
git clone https://github.com/orionsentinel/Orion-sentinel-ha-dns.git
cd Orion-sentinel-ha-dns
```

### 2. Run Initial Setup

```bash
bash scripts/install.sh
```

This will:
- Install Docker if needed
- Create network configuration
- Set up directories
- Prompt you to configure `.env`

### 3. Configure .env for MASTER

**Option A: Use the two-pi-ha template (Recommended)**

```bash
# Copy the two-pi-ha template
cp env/.env.two-pi-ha.example .env
nano .env
```

Edit the following values for Pi1:

```bash
# Network configuration
SUBNET=192.168.8.0/24
GATEWAY=192.168.8.1
NETWORK_INTERFACE=eth0

# IP addresses
PI1_IP=192.168.8.250
PI2_IP=192.168.8.251
VIP_ADDRESS=192.168.8.249

# This Pi's specific settings (DIFFERENT on each Pi)
HOST_IP=192.168.8.250           # Pi1's IP
KEEPALIVED_PRIORITY=100         # Higher = MASTER

# For validation script compatibility
PRIMARY_DNS_IP=192.168.8.250
SECONDARY_DNS_IP=192.168.8.251

# Passwords (MUST be same on both Pis!)
# Generate with: openssl rand -base64 32
PIHOLE_PASSWORD=your-secure-password
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=your-secure-password
VRRP_PASSWORD=your-secure-vrrp-password
```

**Option B: Use Web Wizard**

```bash
# Start the wizard
docker compose -f stacks/dns/docker-compose.yml --profile wizard up -d dns-wizard

# Access at http://192.168.8.250:8080

# In the wizard:
# - Select "High Availability (HA)" mode
# - Pi IP: 192.168.8.250
# - VIP: 192.168.8.249
# - Node Role: MASTER
# - Interface: eth0
# - Set passwords
```

### 4. Validate Configuration

```bash
# Validate environment variables
bash scripts/validate-env.sh

# Check .env file format
bash scripts/test-env-format.sh
```

Both scripts should pass before deploying.

### 5. Deploy Stack on Pi #1

```bash
cd stacks/dns
docker compose --profile two-pi-ha-pi1 up -d
```

### 6. Verify Pi #1 is Running

```bash
# Check containers
docker ps

# Verify VIP is on Pi #1
ip addr show eth0 | grep 192.168.8.249

# Should show the VIP on eth0 as a secondary address

# Run the health check
bash scripts/vip-health.sh

# Test DNS resolution
dig +short example.com @192.168.8.249  # Via VIP
dig +short example.com @192.168.8.250  # Via HOST_IP
```

---

## Pi #2 (BACKUP Node) Setup

### 1. Clone the Repository

```bash
# On Pi #2
git clone https://github.com/orionsentinel/Orion-sentinel-ha-dns.git
cd Orion-sentinel-ha-dns
```

### 2. Run Initial Setup

```bash
bash scripts/install.sh
```

### 3. Configure .env for BACKUP

**Option A: Copy from Pi1 and modify (Recommended)**

The easiest approach is to copy your working .env from Pi1 and change only the Pi2-specific values:

```bash
# Copy .env from Pi1 (via scp or manually)
scp pi@192.168.8.250:~/Orion-sentinel-ha-dns/.env .env
nano .env
```

Change ONLY these values for Pi2:

```bash
# These are the ONLY values that differ between Pi1 and Pi2:
HOST_IP=192.168.8.251           # Pi2's IP (was 192.168.8.250)
KEEPALIVED_PRIORITY=90          # Lower than Pi1 (was 100)
```

**Option B: Fresh configuration**

```bash
cp env/.env.two-pi-ha.example .env
nano .env
```

Edit the following values for Pi2:

```bash
# Network configuration (SAME as Pi1)
SUBNET=192.168.8.0/24
GATEWAY=192.168.8.1
NETWORK_INTERFACE=eth0

# IP addresses (SAME as Pi1)
PI1_IP=192.168.8.250
PI2_IP=192.168.8.251
VIP_ADDRESS=192.168.8.249

# This Pi's specific settings (DIFFERENT from Pi1)
HOST_IP=192.168.8.251           # Pi2's IP
KEEPALIVED_PRIORITY=90          # Lower = BACKUP

# For validation script compatibility
PRIMARY_DNS_IP=192.168.8.250
SECONDARY_DNS_IP=192.168.8.251

# Passwords (MUST be SAME as Pi1!)
PIHOLE_PASSWORD=<same-as-pi1>
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=<same-as-pi1>
VRRP_PASSWORD=<same-as-pi1>     # CRITICAL: Must match Pi1!
```

### 4. Validate Configuration

```bash
bash scripts/validate-env.sh
bash scripts/test-env-format.sh
```

### 5. Deploy Stack on Pi #2

```bash
cd stacks/dns
docker compose --profile two-pi-ha-pi2 up -d
```

### 6. Verify Pi #2 is Running

```bash
# Check containers
docker ps

# VIP should NOT be on Pi #2 (it should be on Pi #1)
ip addr show eth0 | grep 192.168.8.249

# Should show nothing (VIP is on MASTER - Pi1)

# But DNS should still work via Pi2's own IP
dig +short example.com @192.168.8.251
```

---

## Post-Installation Verification

### Verify Complete Setup

Run the health check on both Pis:

```bash
# On both Pis
bash scripts/vip-health.sh
```

Expected output on Pi1 (MASTER):
```
[✓] VIP 192.168.8.249 is present on eth0
[✓] DNS via VIP works
[✓] DNS via HOST_IP works
[✓] Keepalived container is running
[✓] Pi-hole container is running
[✓] All health checks PASSED
```

Expected output on Pi2 (BACKUP):
```
[✗] VIP 192.168.8.249 is NOT present on eth0
    This node may be in BACKUP state...
[✓] DNS via HOST_IP works
[✓] Keepalived container is running
[✓] Pi-hole container is running
```

(The VIP not being present on Pi2 is expected - it's on Pi1!)

### Test DNS Resolution

From any device on your network:

```bash
# Test via VIP (should always work)
dig +short example.com @192.168.8.249

# Test via Pi1 directly
dig +short example.com @192.168.8.250

# Test via Pi2 directly
dig +short example.com @192.168.8.251
```

All three should return valid IP addresses.

---

## Testing Failover

### Test 1: Verify VIP Location

On Pi #1:
```bash
ip addr show eth0 | grep 192.168.8.249
# Should show: inet 192.168.8.249/24 scope global secondary eth0
```

On Pi #2:
```bash
ip addr show eth0 | grep 192.168.8.249
# Should show nothing (VIP is on Pi1)
```

### Test 2: Simulate Failover

```bash
# From any device, start continuous ping to VIP
ping 192.168.8.249

# On Pi #1, stop keepalived to trigger failover
docker stop keepalived

# Watch the ping - you should see 1-3 lost packets, then it continues
# VIP should move to Pi #2 within 2-5 seconds
```

Verify on Pi #2:
```bash
ip addr show eth0 | grep 192.168.8.249
# Should now show the VIP on Pi2!
```

### Test 3: Fail Back to Pi #1

```bash
# On Pi #1, restart keepalived
docker start keepalived

# Wait 5-10 seconds
# VIP should return to Pi #1 (higher priority)

ip addr show eth0 | grep 192.168.8.249
# Should show VIP back on Pi1
```

---

## Configure Your Router

**Critical:** Point your router's DNS to the VIP address.

1. Log into your router's admin interface
2. Find DNS/DHCP settings
3. Set **Primary DNS**: `192.168.8.249` (the VIP)
4. Set **Secondary DNS**: `192.168.8.249` (same VIP)
5. Save and reboot router if needed

**Why use the VIP for both primary and secondary?**
- The VIP automatically points to whichever Pi is active
- If you used individual Pi IPs, failover wouldn't work properly

---

## Accessing Services

### Pi-hole Admin Interfaces

- **Primary (via VIP):** `http://192.168.8.249/admin`
- **Pi #1 directly:** `http://192.168.8.250/admin`
- **Pi #2 directly:** `http://192.168.8.251/admin`

Login with the password set in `.env` (`PIHOLE_PASSWORD`).

### Grafana Dashboards

- **Pi #1:** `http://192.168.8.250:3000`
- **Pi #2:** `http://192.168.8.251:3000`

---

## High Availability Architecture

```
┌─────────────────────────────┐  ┌─────────────────────────────┐
│  Pi #1 (MASTER)             │  │  Pi #2 (BACKUP)             │
│  192.168.8.250              │  │  192.168.8.251              │
│                              │  │                              │
│  ┌────────────────────────┐ │  │  ┌────────────────────────┐ │
│  │     Keepalived         │ │  │  │     Keepalived         │ │
│  │  Priority: 100         │ │  │  │  Priority: 90          │ │
│  │  Role: MASTER          │◄─┼──┼─►│  Role: BACKUP          │ │
│  └────────────────────────┘ │  │  └────────────────────────┘ │
│                              │  │                              │
│  ┌───────────┐              │  │  ┌───────────┐              │
│  │ Pi-hole 1 │              │  │  │ Pi-hole 2 │              │
│  └─────┬─────┘              │  │  └─────┬─────┘              │
│        │                    │  │        │                    │
│  ┌─────▼──────┐             │  │  ┌─────▼──────┐             │
│  │ Unbound 1  │             │  │  │ Unbound 2  │             │
│  └────────────┘             │  │  └────────────┘             │
└──────────┬──────────────────┘  └──────────┬──────────────────┘
           │                                 │
           └────────────┬────────────────────┘
                        │
              ┌─────────▼─────────┐
              │   VIP (Floating)  │
              │  192.168.8.249    │
              └─────────┬─────────┘
                        │
                 ┌──────▼──────┐
                 │   Router    │
                 │  DHCP/DNS   │
                 └─────────────┘
                        │
                 ┌──────▼──────┐
                 │   Devices   │
                 └─────────────┘
```

**DNS Flow:** `Clients → VIP (192.168.8.249) → Pi-hole → Unbound → NextDNS DoT → Internet`

**Failover process:**
1. Keepalived on both Pis exchanges VRRP heartbeats (unicast)
2. If Pi #1 (MASTER) fails, Pi #2 detects missing heartbeats
3. Pi #2 (BACKUP) promotes itself to MASTER
4. VIP moves from Pi #1 to Pi #2 (gratuitous ARP)
5. DNS queries automatically route to Pi #2
6. When Pi #1 recovers, it reclaims the VIP (higher priority)

**Typical failover time:** 2-5 seconds

---

## Maintenance

### Backup Both Pis

```bash
# On Pi #1
bash scripts/backup-config.sh

# On Pi #2
bash scripts/backup-config.sh
```

Store backups somewhere safe (external drive, NAS, cloud).

### Upgrade One Pi at a Time (Zero Downtime)

```bash
# Upgrade Pi #2 first (BACKUP)
# On Pi #2:
docker stop keepalived  # Ensure VIP stays on Pi #1
bash scripts/upgrade.sh
docker start keepalived

# Wait a few minutes, verify Pi #2 is healthy

# Upgrade Pi #1 (MASTER)
# On Pi #1:
bash scripts/upgrade.sh
# VIP will briefly move to Pi #2, then return to Pi #1
```

### Monitor HA Status

```bash
# Quick health check
bash scripts/vip-health.sh

# Check Keepalived logs
docker logs keepalived

# Check which Pi has VIP
ip addr show eth0 | grep 192.168.8.249
```

### Sync Pi-hole Configuration

If Pi-hole configs drift:

```bash
# On Pi #1 (MASTER), export settings
docker exec pihole_primary pihole -a -t

# Copy the teleporter archive to Pi #2

# On Pi #2 (BACKUP), import settings
# (Or use Pi-hole web UI: Settings → Teleporter)
```

---

## Troubleshooting

### VIP Not Appearing

**Run the health check first:**
```bash
bash scripts/vip-health.sh
```

**Check Keepalived logs:**
```bash
docker logs keepalived
```

**Common issues:**

1. **VRRP_PASSWORD mismatch** - Must be identical on both Pis
2. **Invalid keepalived.conf** - Look for parse errors in logs like:
   - "Unknown keyword"
   - "Unexpected '{'"
   - "No VIP specified"
3. **Wrong NETWORK_INTERFACE** - Should be `eth0` for Raspberry Pi
4. **VIP is broadcast address** - Don't use .255, use .249 or similar
5. **Both Pis have same priority** - Pi1 should be 100, Pi2 should be 90

**Fix: Check if keepalived is generating config properly:**
```bash
# View the generated config
docker exec keepalived cat /etc/keepalived/keepalived.conf

# Look for correct values:
# - VIP address (should be your VIP_ADDRESS)
# - Interface (should be your NETWORK_INTERFACE)
# - Priority (should match your KEEPALIVED_PRIORITY)
```

### DNS Not Reachable

**Check if Pi-hole is listening on port 53:**
```bash
# On the host
sudo ss -uapn | grep ':53'

# Should show something listening on port 53
```

**Check if DNS works inside the container:**
```bash
docker exec pihole_primary dig +short example.com @127.0.0.1
```

**Common issues:**
1. Port 53 not exposed in docker-compose
2. Firewall blocking port 53
3. Another service using port 53 (like systemd-resolved)

**Fix systemd-resolved conflict:**
```bash
# Disable stub resolver
sudo sed -i 's/#DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
sudo systemctl restart systemd-resolved
```

### Failover Not Working

**Verify VRRP communication (unicast mode):**
```bash
# On both Pis, check if keepalived is communicating
docker logs keepalived | grep -E "(MASTER|BACKUP|Sending|Received)"
```

**Check if peer is reachable:**
```bash
# From Pi1, ping Pi2
ping 192.168.8.251

# From Pi2, ping Pi1
ping 192.168.8.250
```

**Check firewall:**
```bash
# VRRP uses IP protocol 112
sudo iptables -L -n | grep 112
```

### Pi-hole Configs Out of Sync

**Use Teleporter for manual sync:**
```bash
# On Pi #1, copy Pi-hole gravity database to Pi #2
docker cp pihole_primary:/etc/pihole/gravity.db /tmp/
scp /tmp/gravity.db pi@192.168.8.251:/tmp/

# On Pi #2
docker cp /tmp/gravity.db pihole_secondary:/etc/pihole/
docker exec pihole_secondary pihole restartdns reload-lists
```

---

## Best Practices

1. **Use identical .env files** except for:
   - `HOST_IP` (each Pi's own IP)
   - `KEEPALIVED_PRIORITY` (100 for Pi1, 90 for Pi2)

2. **Keep Pi-hole configs in sync**
   - Use pihole-sync container (single-pi-ha mode)
   - Or manually sync via Teleporter

3. **Update one Pi at a time**
   - Prevents total DNS outage
   - Test on BACKUP (Pi2) first

4. **Monitor both Pis**
   - Check logs regularly
   - Set up Grafana alerts

5. **Test failover regularly**
   - Monthly reboot of MASTER
   - Verify VIP moves and returns

6. **Keep backups current**
   - Weekly automated backups
   - Store offsite

---

## Next Steps

- **[Operations Guide](operations.md)** - Day-to-day management
- **[DNS Profiles Guide](profiles.md)** - Security profile details
- **[Disaster Recovery](../DISASTER_RECOVERY.md)** - Recovery procedures
- **[Troubleshooting Guide](../TROUBLESHOOTING.md)** - Common issues

---

**Questions or Issues?**

- Check [TROUBLESHOOTING.md](../TROUBLESHOOTING.md)
- Visit the [GitHub repository](https://github.com/yorgosroussakis/Orion-sentinel-ha-dns)
- Review the [Operational Runbook](../OPERATIONAL_RUNBOOK.md)
