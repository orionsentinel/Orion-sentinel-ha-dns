# Keepalived Service Configuration for Two-Pi HA

## Overview
The Keepalived service in `stacks/dns/docker-compose.yml` is already fully configured for Two-Pi HA deployments. This document explains the configuration and how environment variables control its behavior.

## Docker Compose Service Definition

The Keepalived service is defined in `stacks/dns/docker-compose.yml`:

```yaml
keepalived:
  build: ./keepalived
  container_name: keepalived
  hostname: keepalived
  profiles:
    - single-pi-ha        # Single-node HA (container failover)
    - two-pi-ha-pi1       # Two-node HA - Primary (Pi1)
    - two-pi-ha-pi2       # Two-node HA - Secondary (Pi2)
  network_mode: host      # Required for VIP management
  cap_add:
    - NET_ADMIN          # Required to add/remove IPs
    - NET_BROADCAST      # Required for VRRP multicast
    - NET_RAW            # Required for VRRP protocol
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock:ro
  restart: unless-stopped
  environment:
    # Core Keepalived Settings
    - KEEPALIVED_ENABLED=${KEEPALIVED_ENABLED:-true}
    
    # VIP Configuration
    - VIP_ADDRESS=${VIP_ADDRESS}
    - HOST_IP=${HOST_IP}
    
    # VRRP Authentication
    - VRRP_PASSWORD=${VRRP_PASSWORD}
    
    # Network Configuration
    - NETWORK_INTERFACE=${NETWORK_INTERFACE:-eth0}
    - VIRTUAL_ROUTER_ID=${VIRTUAL_ROUTER_ID:-51}
    - KEEPALIVED_PRIORITY=${KEEPALIVED_PRIORITY:-100}
    - SUBNET=${SUBNET:-}
    
    # Peer Node Configuration (for unicast VRRP)
    - PI1_IP=${PI1_IP:-}
    - PI2_IP=${PI2_IP:-}
    - NODE_ROLE=${NODE_ROLE:-}
    - PI1_HOSTNAME=${PI1_HOSTNAME:-}
    - PI2_HOSTNAME=${PI2_HOSTNAME:-}
    
    # DNS Health Check Configuration
    - DNS_CHECK_IP=${DNS_CHECK_IP:-127.0.0.1}
    - DNS_CHECK_PORT=${DNS_CHECK_PORT:-53}
    
    # Signal Notifications (Optional)
    - SIGNAL_NUMBER=${SIGNAL_NUMBER:-}
    - NOTIFY_ON_FAILOVER=${NOTIFY_ON_FAILOVER:-true}
    - NOTIFY_ON_FAILBACK=${NOTIFY_ON_FAILBACK:-true}
  
  healthcheck:
    test: ["CMD", "pgrep", "keepalived"]
    interval: 30s
    timeout: 5s
    retries: 3
    start_period: 10s
  
  deploy:
    resources:
      limits:
        cpus: '0.25'
        memory: 128M
      reservations:
        cpus: '0.05'
        memory: 32M
```

## Environment Variable Reference

### Core Settings

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `KEEPALIVED_ENABLED` | No | `true` | Enable/disable Keepalived service |
| `VIP_ADDRESS` | **Yes** | - | The Virtual IP that floats between nodes |
| `HOST_IP` | **Yes** | - | This node's IP address |
| `VRRP_PASSWORD` | **Yes** | - | Authentication password for VRRP (must match on all nodes) |

### Network Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `NETWORK_INTERFACE` | No | `eth0` | Physical interface to assign VIP to |
| `VIRTUAL_ROUTER_ID` | No | `51` | VRRP router ID (1-255, must be same on all nodes) |
| `KEEPALIVED_PRIORITY` | No | `100` | VRRP priority (higher = preferred MASTER) |
| `SUBNET` | No | - | Network subnet (e.g., 192.168.8.0/24) |

### Two-Pi HA Specific

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `NODE_ROLE` | Recommended | - | `primary` or `secondary` for logging/metrics |
| `PI1_IP` | For unicast | - | IP address of Pi1 (primary node) |
| `PI2_IP` | For unicast | - | IP address of Pi2 (secondary node) |
| `PI1_HOSTNAME` | No | - | Hostname of Pi1 |
| `PI2_HOSTNAME` | No | - | Hostname of Pi2 |

### Health Check Settings

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DNS_CHECK_IP` | No | `127.0.0.1` | IP to test DNS resolution against |
| `DNS_CHECK_PORT` | No | `53` | Port to test DNS on |

### Notification Settings

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `SIGNAL_NUMBER` | No | - | Signal phone number for notifications |
| `NOTIFY_ON_FAILOVER` | No | `true` | Send notification on failover to MASTER |
| `NOTIFY_ON_FAILBACK` | No | `true` | Send notification on return to BACKUP |

## How It Works

### 1. Network Mode: Host

```yaml
network_mode: host
```

Keepalived runs in **host network mode** because it needs to:
- Add/remove the VIP directly to the host's network interface
- Send/receive VRRP packets on the physical network
- Access the host's routing table

This means Keepalived sees the same network interfaces as the host Raspberry Pi.

### 2. Capabilities

```yaml
cap_add:
  - NET_ADMIN
  - NET_BROADCAST
  - NET_RAW
```

These Linux capabilities allow Keepalived to:
- **NET_ADMIN**: Add/remove IP addresses, manage routes
- **NET_BROADCAST**: Send multicast/broadcast packets for VRRP
- **NET_RAW**: Create raw sockets for VRRP protocol

### 3. VIP Management

The VIP is assigned using the `ip addr` command:

```bash
# When becoming MASTER
ip addr add ${VIP_ADDRESS}/32 dev ${NETWORK_INTERFACE}

# When becoming BACKUP
ip addr del ${VIP_ADDRESS}/32 dev ${NETWORK_INTERFACE}
```

This is handled automatically by Keepalived based on VRRP state.

### 4. Priority and State

Keepalived uses **VRRP priority** to determine which node should be MASTER:

- **Pi1 (Primary)**: `KEEPALIVED_PRIORITY=200` → Preferred MASTER
- **Pi2 (Secondary)**: `KEEPALIVED_PRIORITY=150` → BACKUP

When both nodes are healthy:
- Pi1 has higher priority → becomes MASTER → owns VIP
- Pi2 has lower priority → becomes BACKUP → does not have VIP

When Pi1 fails:
- Pi1 stops sending VRRP heartbeats
- Pi2 detects failure after ~3 seconds
- Pi2 transitions to MASTER → takes ownership of VIP
- DNS continues to work via VIP (now on Pi2)

When Pi1 recovers:
- Pi1 starts sending VRRP heartbeats again
- Pi1 has higher priority → reclaims MASTER
- Pi2 transitions back to BACKUP
- VIP moves back to Pi1

### 5. Unicast vs Multicast VRRP

**Multicast VRRP** (default):
- Uses multicast address 224.0.0.18
- Requires switch to support multicast
- Auto-discovers peers

**Unicast VRRP** (recommended):
- Sends VRRP packets directly between PI1_IP and PI2_IP
- Works on any network
- More reliable in home networks

Configured via `stacks/dns/keepalived/entrypoint.sh` based on `USE_UNICAST_VRRP` env var.

## Two-Pi HA Configuration Examples

### Example 1: Pi1 (Primary) .env

```bash
# This Node
NODE_ROLE=primary
HOST_IP=192.168.8.11
NODE_HOSTNAME=pi1-dns

# Peer Node
PEER_IP=192.168.8.12
PI1_IP=192.168.8.11
PI2_IP=192.168.8.12

# VIP
VIP_ADDRESS=192.168.8.249
NETWORK_INTERFACE=eth0

# Keepalived
KEEPALIVED_PRIORITY=200        # Higher = MASTER
VIRTUAL_ROUTER_ID=51
VRRP_PASSWORD=SecurePassword123!
USE_UNICAST_VRRP=true
```

**Docker Compose Profile**: `two-pi-ha-pi1`

**Expected Behavior**:
- Starts as MASTER (higher priority)
- Owns VIP (192.168.8.249 appears on eth0)
- Sends VRRP heartbeats to Pi2 (192.168.8.12)
- Checks local DNS health (127.0.0.1:53)

### Example 2: Pi2 (Secondary) .env

```bash
# This Node
NODE_ROLE=secondary
HOST_IP=192.168.8.12
NODE_HOSTNAME=pi2-dns

# Peer Node
PEER_IP=192.168.8.11
PI1_IP=192.168.8.11
PI2_IP=192.168.8.12

# VIP (SAME as Pi1!)
VIP_ADDRESS=192.168.8.249
NETWORK_INTERFACE=eth0

# Keepalived
KEEPALIVED_PRIORITY=150        # Lower = BACKUP
VIRTUAL_ROUTER_ID=51           # SAME as Pi1!
VRRP_PASSWORD=SecurePassword123!  # SAME as Pi1!
USE_UNICAST_VRRP=true
```

**Docker Compose Profile**: `two-pi-ha-pi2`

**Expected Behavior**:
- Starts as BACKUP (lower priority)
- Does NOT own VIP initially
- Sends VRRP heartbeats to Pi1 (192.168.8.11)
- Checks local DNS health (127.0.0.1:53)
- Takes over VIP if Pi1 fails

## Verification Commands

### Check VIP Ownership

On **each Pi**, run:
```bash
ip addr show eth0 | grep 192.168.8.249
```

**Expected**:
- **Pi1**: Shows VIP (if MASTER)
- **Pi2**: No output (if BACKUP)

### Check Keepalived State

```bash
docker logs keepalived | tail -20
```

Look for:
```
Entering MASTER STATE    # This node owns VIP
Entering BACKUP STATE    # This node does not own VIP
```

### Check VRRP Traffic

On **either Pi**:
```bash
sudo tcpdump -i eth0 vrrp -n
```

Should see VRRP advertisements every ~1 second.

### Test DNS via VIP

From **any device on network**:
```bash
dig google.com @192.168.8.249
nslookup google.com 192.168.8.249
```

Should resolve successfully whether VIP is on Pi1 or Pi2.

## Troubleshooting

### VIP Not Appearing

**Symptoms**: `ip addr show eth0` doesn't show VIP on any node

**Possible Causes**:
1. Keepalived container not running
2. Insufficient permissions (check cap_add)
3. VIP address misconfigured
4. VRRP traffic blocked

**Solutions**:
```bash
# Check container
docker ps | grep keepalived

# Check logs
docker logs keepalived

# Verify capabilities
docker inspect keepalived | grep -A5 CapAdd

# Test manually (as root on host)
ip addr add 192.168.8.249/32 dev eth0
ip addr del 192.168.8.249/32 dev eth0
```

### Both Nodes Claim MASTER (Split Brain)

**Symptoms**: Both Pi1 and Pi2 show VIP in `ip addr`

**Possible Causes**:
1. Network partition (Pis can't communicate)
2. Different VIRTUAL_ROUTER_ID on each node
3. Different VRRP_PASSWORD on each node

**Solutions**:
```bash
# Test network connectivity
ping <other-pi-ip>

# Verify VRRP traffic
sudo tcpdump -i eth0 vrrp

# Check .env on both nodes
grep VIRTUAL_ROUTER_ID .env
grep VRRP_PASSWORD .env
```

### Failover Not Happening

**Symptoms**: Pi1 stopped, but VIP doesn't move to Pi2

**Possible Causes**:
1. Pi2 Keepalived not running
2. VRRP traffic not reaching Pi2
3. Pi2 health check failing

**Solutions**:
```bash
# On Pi2, check Keepalived
docker ps | grep keepalived
docker logs keepalived

# Check health check
docker exec keepalived /check_dns.sh
```

## Advanced Configuration

### Custom Health Check Script

Keepalived can run custom scripts to check if this node is healthy. See `stacks/dns/keepalived/check_dns.sh`:

```bash
#!/bin/bash
# Check if local Pi-hole is responding
dig @${DNS_CHECK_IP:-127.0.0.1} google.com +short +timeout=2 > /dev/null 2>&1
exit $?
```

If the health check fails 3 times, Keepalived can:
- Lower its priority → cause failover
- Or transition to FAULT state → release VIP

### Notification Scripts

Keepalived can execute scripts on state changes:

- `notify_master.sh`: Executed when becoming MASTER
- `notify_backup.sh`: Executed when becoming BACKUP  
- `notify_fault.sh`: Executed when health check fails

These can send alerts via Signal, email, webhook, etc.

## Resources

- **VRRP RFC**: [RFC 5798](https://tools.ietf.org/html/rfc5798)
- **Keepalived Docs**: https://www.keepalived.org/
- **Linux Capabilities**: `man capabilities`

## Summary

The Keepalived service in `stacks/dns/docker-compose.yml` is **already fully configured** for Two-Pi HA:

✅ Configurable interface via `NETWORK_INTERFACE`  
✅ Has required capabilities (NET_ADMIN, NET_RAW, NET_BROADCAST)  
✅ Uses `KEEPALIVED_PRIORITY` to determine MASTER/BACKUP  
✅ Uses `NODE_ROLE` for logging and metrics  
✅ Supports unicast VRRP for home networks  
✅ Health checks local DNS service  
✅ Sends notifications on state changes  

**No code changes needed** — just configure environment variables in `.env` on each node!
