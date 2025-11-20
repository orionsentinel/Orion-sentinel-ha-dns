# Two Pi High Availability Installation Guide

**Orion Sentinel DNS HA - Two-Node HA Mode**

This guide covers installing the DNS HA stack on two Raspberry Pis with automatic failover using Keepalived VIP.

---

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Architecture](#architecture)
- [Installation Steps](#installation-steps)
- [Configuration](#configuration)
- [Verification](#verification)
- [Router Configuration](#router-configuration)
- [Failover Testing](#failover-testing)
- [Troubleshooting](#troubleshooting)

---

## Overview

**Two-node HA mode** provides true high availability with automatic failover:

- **Redundancy Level**: Hardware + Node-level (true HA)
- **VIP**: Shared virtual IP that floats between nodes
- **Automatic Failover**: If primary fails, secondary takes over in ~3 seconds
- **Best For**: Production home networks, small offices
- **Hardware Required**: 2x Raspberry Pi (4GB+ RAM each)

**Benefits:**
- ✅ Zero downtime during Pi failures or upgrades
- ✅ Automatic failover (no manual intervention)
- ✅ Load distribution across two Pis
- ✅ Hardware redundancy protects against SD card failure

---

## Prerequisites

### Hardware Requirements
- 2x Raspberry Pi 4 or 5 (4GB+ RAM recommended)
- 2x 16GB+ microSD cards (or SSDs for better performance)
- 2x Stable power supplies (3A+ each)
- Ethernet cables (WiFi not recommended for HA)
- Network switch with available ports

### Software Requirements
- Raspberry Pi OS (Debian-based) on both Pis
- Static IPs configured for both Pis
- Internet connectivity on both Pis
- SSH access enabled on both Pis

### Network Requirements

**Plan your IP addresses:**

| Component | IP Address | Description |
|-----------|------------|-------------|
| Pi #1 (Primary) | `192.168.8.250` | MASTER node |
| Pi #2 (Secondary) | `192.168.8.100` | BACKUP node |
| VIP | `192.168.8.255` | Floating virtual IP |
| Pi-hole Primary | `192.168.8.251` | On Pi #1 |
| Pi-hole Secondary | `192.168.8.252` | On Pi #2 |
| Unbound Primary | `192.168.8.253` | On Pi #1 |
| Unbound Secondary | `192.168.8.254` | On Pi #2 |

**Network settings you'll need:**
- Network interface: Usually `eth0` for Ethernet
- Subnet: Usually `192.168.1.0/24` or `192.168.8.0/24`
- Gateway: Your router's IP (e.g., `192.168.8.1`)

---

## Architecture

### How Two-Node HA Works

```
                    [Router: 192.168.8.1]
                            |
                    DNS: 192.168.8.255 (VIP)
                            |
        ┌──────────────────┴──────────────────┐
        |                                     |
   [Pi #1 - MASTER]                    [Pi #2 - BACKUP]
   192.168.8.250                       192.168.8.100
        |                                     |
   ┌────┴────┐                          ┌────┴────┐
   │ Pi-hole │ 251                      │ Pi-hole │ 252
   │ Unbound │ 253                      │ Unbound │ 254
   │Keepalived│ ← VIP Owner             │Keepalived│ ← VIP Backup
   └─────────┘                          └─────────┘
```

**Normal Operation:**
- VIP (`192.168.8.255`) is on Pi #1 (MASTER)
- All DNS queries go to Pi #1
- Pi #2 is running and ready

**During Failover:**
- Pi #1 fails or goes offline
- Pi #2 detects failure within ~3 seconds
- VIP automatically moves to Pi #2 (BACKUP)
- DNS queries now go to Pi #2
- Users experience no interruption

---

## Installation Steps

### Step 1: Prepare Both Pis

**On both Raspberry Pis**, assign static IPs:

**Pi #1 (Primary):**
```bash
# Edit dhcpcd.conf
sudo nano /etc/dhcpcd.conf

# Add at the end:
interface eth0
static ip_address=192.168.8.250/24
static routers=192.168.8.1
static domain_name_servers=8.8.8.8 1.1.1.1

# Reboot
sudo reboot
```

**Pi #2 (Secondary):**
```bash
# Edit dhcpcd.conf
sudo nano /etc/dhcpcd.conf

# Add at the end:
interface eth0
static ip_address=192.168.8.100/24
static routers=192.168.8.1
static domain_name_servers=8.8.8.8 1.1.1.1

# Reboot
sudo reboot
```

### Step 2: Clone Repository on Both Pis

**On both Pis:**
```bash
cd ~
git clone https://github.com/yorgosroussakis/Orion-sentinel-ha-dns.git
cd Orion-sentinel-ha-dns
```

### Step 3: Install on Pi #1 (MASTER)

SSH into Pi #1 and run the installation script:

```bash
bash scripts/install.sh
```

**When prompted, provide:**

1. **Pi's LAN IP**: Accept default `192.168.8.250` or enter Pi #1's IP
2. **Deployment Mode**: Choose `2` (Two-node HA mode)
3. **VIP Address**: Enter `192.168.8.255` (or your chosen VIP)
4. **Node Role**: Choose `MASTER`
5. **Network Interface**: Accept default `eth0`
6. **Pi-hole Password**: Enter a strong password

The script will configure Pi #1 as the MASTER node with the VIP.

### Step 4: Install on Pi #2 (BACKUP)

SSH into Pi #2 and run the installation script:

```bash
bash scripts/install.sh
```

**When prompted, provide:**

1. **Pi's LAN IP**: Accept default `192.168.8.100` or enter Pi #2's IP
2. **Deployment Mode**: Choose `2` (Two-node HA mode)
3. **VIP Address**: Enter `192.168.8.255` (MUST match Pi #1's VIP)
4. **Node Role**: Choose `BACKUP`
5. **Network Interface**: Accept default `eth0`
6. **Pi-hole Password**: Use the SAME password as Pi #1

The script will configure Pi #2 as the BACKUP node.

**Important:** Both Pis must have:
- ✅ Same VIP address
- ✅ Same VRRP password
- ✅ Same network interface name
- ✅ Different node roles (MASTER vs BACKUP)
- ✅ Same Pi-hole password (for sync)

---

## Configuration

### Environment File (.env)

**Pi #1 (MASTER):**
```env
# Pi #1's IP
HOST_IP=192.168.8.250

# DNS container IPs
PRIMARY_DNS_IP=192.168.8.251
SECONDARY_DNS_IP=192.168.8.252
UNBOUND_PRIMARY_IP=192.168.8.253
UNBOUND_SECONDARY_IP=192.168.8.254

# VIP (shared between both Pis)
VIP_ADDRESS=192.168.8.255

# Network settings
NETWORK_INTERFACE=eth0
SUBNET=192.168.8.0/24
GATEWAY=192.168.8.1

# Node role
NODE_ROLE=MASTER

# Passwords (MUST be same on both Pis)
PIHOLE_PASSWORD=your_secure_password_here
VRRP_PASSWORD=your_secure_password_here
```

**Pi #2 (BACKUP):**
```env
# Pi #2's IP (DIFFERENT from Pi #1)
HOST_IP=192.168.8.100

# DNS container IPs (SAME as Pi #1)
PRIMARY_DNS_IP=192.168.8.251
SECONDARY_DNS_IP=192.168.8.252
UNBOUND_PRIMARY_IP=192.168.8.253
UNBOUND_SECONDARY_IP=192.168.8.254

# VIP (SAME as Pi #1)
VIP_ADDRESS=192.168.8.255

# Network settings (SAME as Pi #1)
NETWORK_INTERFACE=eth0
SUBNET=192.168.8.0/24
GATEWAY=192.168.8.1

# Node role (DIFFERENT from Pi #1)
NODE_ROLE=BACKUP

# Passwords (MUST be SAME as Pi #1)
PIHOLE_PASSWORD=your_secure_password_here
VRRP_PASSWORD=your_secure_password_here
```

---

## Verification

### Check Services on Both Pis

**On Pi #1:**
```bash
# Check containers
docker ps

# Should see pihole, unbound, keepalived running
```

**On Pi #2:**
```bash
# Check containers
docker ps

# Should see pihole, unbound, keepalived running
```

### Verify VIP Ownership

**On Pi #1 (should own VIP):**
```bash
ip addr show eth0 | grep 192.168.8.255

# Should see the VIP address listed
```

**On Pi #2 (should NOT own VIP initially):**
```bash
ip addr show eth0 | grep 192.168.8.255

# Should NOT see the VIP (it's on Pi #1)
```

### Test DNS via VIP

```bash
# From your computer (not the Pis)
dig @192.168.8.255 google.com

# Should get valid DNS response from whichever Pi owns the VIP
```

### Check Keepalived Logs

**On both Pis:**
```bash
docker logs keepalived

# Pi #1 should show: Entering MASTER STATE
# Pi #2 should show: Entering BACKUP STATE
```

---

## Router Configuration

### Point Router DNS to VIP

1. Log into your router's admin panel (e.g., `http://192.168.8.1`)
2. Navigate to LAN/DHCP settings
3. Set DNS servers:
   - **Primary DNS**: `192.168.8.255` (the VIP)
   - **Secondary DNS**: Leave blank or `1.1.1.1` as fallback
4. Save and reboot your router

**Why use the VIP?**
- The VIP automatically points to whichever Pi is active
- If Pi #1 fails, VIP moves to Pi #2 → no DNS outage
- Clients don't need reconfiguration

---

## Failover Testing

### Test Automatic Failover

**Simulate Pi #1 failure:**

1. Note current VIP owner:
   ```bash
   # On Pi #1
   ip addr show eth0 | grep 192.168.8.255
   # VIP should be present
   ```

2. Stop Keepalived on Pi #1:
   ```bash
   # On Pi #1
   docker stop keepalived
   ```

3. Wait ~3 seconds, then check Pi #2:
   ```bash
   # On Pi #2
   ip addr show eth0 | grep 192.168.8.255
   # VIP should now be present (failover occurred)
   ```

4. Test DNS still works:
   ```bash
   dig @192.168.8.255 google.com
   # Should still resolve (now via Pi #2)
   ```

5. Restart Keepalived on Pi #1:
   ```bash
   # On Pi #1
   docker start keepalived
   
   # VIP should return to Pi #1 (MASTER takes priority)
   ```

**Expected behavior:**
- Failover: ~3 seconds
- DNS queries: Continue working during failover
- VIP returns to MASTER when it recovers

---

## Troubleshooting

### VIP not appearing on Pi #1

**Check Keepalived status:**
```bash
docker logs keepalived

# Should see: "Entering MASTER STATE"
```

**Check interface name:**
```bash
ip addr

# Verify NETWORK_INTERFACE in .env matches actual interface
```

**Check VRRP password:**
```bash
# Must be identical on both Pis
grep VRRP_PASSWORD .env
```

### Failover not working

**Verify both Pis can communicate:**
```bash
# From Pi #1, ping Pi #2
ping 192.168.8.100

# From Pi #2, ping Pi #1
ping 192.168.8.250
```

**Check Keepalived VRRP packets:**
```bash
# On both Pis
sudo tcpdump -i eth0 vrrp

# Should see VRRP advertisements
```

### DNS queries fail via VIP

**Check which Pi owns VIP:**
```bash
# On both Pis
ip addr show eth0 | grep 192.168.8.255
```

**Test direct DNS on each Pi-hole:**
```bash
dig @192.168.8.251 google.com  # Pi #1's Pi-hole
dig @192.168.8.252 google.com  # Pi #2's Pi-hole
```

**Check Pi-hole container health:**
```bash
docker ps | grep pihole
docker logs pihole_primary
```

### Pi-hole sync issues

**Manual sync from Pi #1 to Pi #2:**
```bash
# On Pi #1
bash stacks/dns/pihole-sync.sh
```

**Check gravity-sync logs:**
```bash
docker logs pihole-sync
```

---

## Maintenance

### Upgrading Both Pis

Always upgrade one Pi at a time to maintain availability:

**Step 1: Upgrade Pi #2 (BACKUP) first:**
```bash
# On Pi #2
bash scripts/upgrade.sh

# Wait for completion and verify
docker ps
```

**Step 2: Verify Pi #2 is healthy:**
```bash
# Test DNS on Pi #2
dig @192.168.8.252 google.com
```

**Step 3: Upgrade Pi #1 (MASTER):**
```bash
# On Pi #1
bash scripts/upgrade.sh

# VIP will failover to Pi #2 during restart
# Then return to Pi #1 when ready
```

### Scheduled Backups

**On Pi #1 (MASTER) only:**
```bash
# Edit crontab
crontab -e

# Add weekly backup
0 2 * * 0 /home/pi/Orion-sentinel-ha-dns/scripts/backup-config.sh
```

Backups only need to run on one Pi since configuration should be identical.

---

## Next Steps

### Apply DNS Security Profile

On Pi #1, apply a profile (will sync to Pi #2):
```bash
python3 scripts/apply-profile.py --profile standard
```

### Enable Monitoring

Access dashboards:
- **Grafana**: `http://192.168.8.250:3000` (Pi #1) or `http://192.168.8.100:3000` (Pi #2)
- **Prometheus**: `http://192.168.8.250:9090`

### Read Operational Documentation

- [Operations Guide](operations.md) - Backup, restore, upgrade procedures
- [Troubleshooting](../TROUBLESHOOTING.md) - Common issues and solutions
- [Disaster Recovery](../DISASTER_RECOVERY.md) - Recovery procedures

---

## Support

For issues or questions:
1. Check the [Troubleshooting Guide](../TROUBLESHOOTING.md)
2. Review [MULTI_NODE_QUICKSTART.md](../MULTI_NODE_QUICKSTART.md)
3. Open an issue on [GitHub](https://github.com/yorgosroussakis/Orion-sentinel-ha-dns/issues)
