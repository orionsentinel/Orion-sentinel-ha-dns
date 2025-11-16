# High Availability Setup: Two Pis with 1 Pi-hole + 1 Unbound per Pi

## Architecture Overview

This setup distributes services across **two physical Raspberry Pis** with **hardware-level redundancy**. This is the **RECOMMENDED** multi-node setup.

```
┌──────────────────────────────┐    ┌──────────────────────────────┐
│  Raspberry Pi #1             │    │  Raspberry Pi #2             │
│  Physical IP: 192.168.8.11   │    │  Physical IP: 192.168.8.12   │
│  ┌────────────────────────┐  │    │  ┌────────────────────────┐  │
│  │  Docker Host           │  │    │  │  Docker Host           │  │
│  │  ┌──────────────────┐  │  │    │  │  ┌──────────────────┐  │  │
│  │  │   Pi-hole        │  │  │    │  │  │   Pi-hole        │  │  │
│  │  │   Primary        │  │  │    │  │  │   Secondary      │  │  │
│  │  │   .251           │◄─┼──┼────┼──┼──┤   .252           │  │  │
│  │  │                  │  │  │    │  │  │                  │  │  │
│  │  └────────┬─────────┘  │  │    │  │  └────────┬─────────┘  │  │
│  │           │             │  │    │  │           │             │  │
│  │  ┌────────▼─────────┐  │  │    │  │  ┌────────▼─────────┐  │  │
│  │  │   Unbound        │  │  │    │  │  │   Unbound        │  │  │
│  │  │   Primary        │  │  │    │  │  │   Secondary      │  │  │
│  │  │   .253           │◄─┼──┼────┼──┼──┤   .254           │  │  │
│  │  └──────────────────┘  │  │    │  │  └──────────────────┘  │  │
│  │                        │  │    │  │                        │  │
│  │  ┌──────────────────┐  │  │    │  │  ┌──────────────────┐  │  │
│  │  │  Keepalived      │  │  │    │  │  │  Keepalived      │  │  │
│  │  │  MASTER          │◄─┼──┼────┼──┼─►│  BACKUP          │  │  │
│  │  │  Priority: 100   │  │  │    │  │  │  Priority: 90    │  │  │
│  │  └──────────────────┘  │  │    │  │  └──────────────────┘  │  │
│  └────────────────────────┘  │    │  └────────────────────────┘  │
│              │                │    │              │                │
└──────────────┼────────────────┘    └──────────────┼────────────────┘
               │                                    │
               └────────────┬───────────────────────┘
                            │
                            ▼
              Virtual IP (VIP): 192.168.8.255
             (Floats between Pi #1 and Pi #2)
```

## Features

- ✅ **Hardware-level HA**: Protects against complete node failure
- ✅ **Automatic failover**: VIP moves between Pis via VRRP (5-10 sec)
- ✅ **Configuration sync**: Gravity Sync keeps Pi-holes synchronized
- ✅ **1x Pi-hole per Pi**: Simplified, efficient resource usage
- ✅ **1x Unbound per Pi**: Clean, straightforward setup
- ✅ **Zero downtime updates**: Update one Pi while other handles traffic

## Pros and Cons

### ✅ Advantages
- True hardware redundancy
- Automatic failover on node failure
- Moderate complexity (easier than 2P2U)
- Efficient resource usage
- Production-ready
- Easy to manage and troubleshoot
- Best balance of features vs. complexity

### ⚠️ Considerations
- Requires two Raspberry Pis
- Slightly more complex than single-Pi setup
- No container-level redundancy on each node
- Requires network sync between nodes

## Network Configuration

### Node IP Addresses
- **Raspberry Pi #1**: 192.168.8.11 (MASTER)
- **Raspberry Pi #2**: 192.168.8.12 (BACKUP)

### Service IP Addresses
- **Pi-hole on Pi #1**: 192.168.8.251
- **Pi-hole on Pi #2**: 192.168.8.252
- **Unbound on Pi #1**: 192.168.8.253
- **Unbound on Pi #2**: 192.168.8.254
- **Virtual IP (VIP)**: 192.168.8.255

## How It Works

### Normal Operation
1. Pi #1 (MASTER) owns the VIP (192.168.8.255)
2. All DNS queries go to VIP → handled by Pi #1
3. Pi #2 (BACKUP) monitors via VRRP heartbeats
4. Gravity Sync syncs configurations Pi #1 → Pi #2 (hourly)

### Failover Scenario
1. Pi #1 fails (power, hardware, network)
2. Pi #2 detects missing heartbeats (3 seconds)
3. Pi #2 promotes itself to MASTER
4. VIP (192.168.8.255) moves to Pi #2
5. DNS continues working seamlessly via Pi #2
6. **Failover time: 5-10 seconds**

### Failback
1. Pi #1 recovers and starts services
2. Pi #1 reclaims MASTER role (higher priority)
3. VIP returns to Pi #1
4. Pi #2 returns to BACKUP state

## Deployment Instructions

### Prerequisites
- 2x Raspberry Pi 4/5 (4GB+ RAM each)
- Raspberry Pi OS (64-bit) on both
- Docker and Docker Compose installed on both
- Static IPs configured:
  - Pi #1: 192.168.8.11
  - Pi #2: 192.168.8.12
- SSH access between nodes

### Step-by-Step Deployment

#### 1. Prepare Both Nodes

On **both Pi #1 and Pi #2**:

```bash
# Install prerequisites
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io docker-compose git rsync

# Clone repository
cd /opt
sudo git clone https://github.com/yorgosroussakis/rpi-ha-dns-stack.git
cd rpi-ha-dns-stack/deployments/HighAvail_2Pi1P1U
```

#### 2. Configure SSH Keys (for sync)

On **Pi #1**:
```bash
# Generate SSH key
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""

# Copy to Pi #2
ssh-copy-id pi@192.168.8.12

# Test connection
ssh pi@192.168.8.12 "echo 'SSH works'"
```

#### 3. Configure Environment

On **Pi #1**:
```bash
cp node1/.env.example node1/.env
nano node1/.env
# Set NODE_ROLE=primary, NODE_IP=192.168.8.11, PEER_IP=192.168.8.12
```

On **Pi #2**:
```bash
cp node2/.env.example node2/.env
nano node2/.env
# Set NODE_ROLE=secondary, NODE_IP=192.168.8.12, PEER_IP=192.168.8.11
```

#### 4. Create Docker Networks

On **both nodes**:
```bash
sudo docker network create \
  -d macvlan \
  --subnet=192.168.8.0/24 \
  --gateway=192.168.8.1 \
  -o parent=eth0 \
  dns_net
```

#### 5. Deploy Services

On **Pi #1**:
```bash
cd node1
docker compose up -d
```

On **Pi #2**:
```bash
cd node2
docker compose up -d
```

#### 6. Verify Automatic Sync

This deployment uses custom Pi-hole v6 sync scripts instead of Gravity Sync (which doesn't support v6).

Synchronization is handled automatically by the built-in pihole-sync.sh containers. The sync configuration is set up during deployment and runs automatically in the background.

To verify sync is working:
```bash
# On Pi #1, check sync container logs
docker logs pihole-sync

# Check that changes made on Pi #1 appear on Pi #2
# Example: Add a domain to the blocklist on Pi #1's web interface
# Then check Pi #2's web interface to see if it appears there
```

### Verification

#### Check VIP Assignment

On **Pi #1**:
```bash
ip addr show eth0 | grep 192.168.8.255
# Should show VIP assigned
```

On **Pi #2**:
```bash
ip addr show eth0 | grep 192.168.8.255
# Should NOT show VIP (unless Pi #1 is down)
```

#### Check Keepalived Status

```bash
# On both nodes
docker logs keepalived | tail -20
# Pi #1 should show "Entering MASTER STATE"
# Pi #2 should show "Entering BACKUP STATE"
```

#### Test DNS Resolution

From another device on your network:
```bash
# Test via VIP
dig google.com @192.168.8.255

# Test each Pi-hole
dig google.com @192.168.8.251
dig google.com @192.168.8.252
```

#### Test Failover

```bash
# On Pi #1, stop keepalived
docker stop keepalived

# Wait 10 seconds, then check Pi #2
ssh pi@192.168.8.12 "ip addr show eth0 | grep 192.168.8.255"
# VIP should now be on Pi #2

# Test DNS still works
dig google.com @192.168.8.255

# Restart keepalived on Pi #1
docker start keepalived
# VIP should return to Pi #1 after ~10 seconds
```

## When to Use This Setup

Choose this setup if:
- ✅ You have two Raspberry Pis available
- ✅ You want hardware-level redundancy
- ✅ You need automatic failover on node failure
- ✅ You prefer moderate complexity
- ✅ You want best balance of features/complexity
- ✅ Each Pi has 4GB+ RAM
- ✅ **This is the RECOMMENDED option for most users**

## Comparison with Other Options

| Feature | 1Pi2P2U | 2Pi1P1U (This) | 2Pi2P2U |
|---------|---------|----------------|---------|
| Raspberry Pis | 1 | 2 | 2 |
| Pi-hole per Pi | 2 | 1 | 2 |
| Hardware HA | ❌ | ✅ | ✅ |
| Complexity | Low | Medium | High |
| Resource Usage | Medium | Medium | High |
| Best For | Lab/Testing | Production | Mission Critical |

## Files in This Deployment

```
HighAvail_2Pi1P1U/
├── README.md                    # This file
├── node1/                       # Pi #1 (Primary) configuration
│   ├── docker-compose.yml
│   ├── .env.example
│   └── keepalived/
│       ├── Dockerfile
│       ├── keepalived.conf
│       ├── check_dns.sh
│       └── notify_*.sh
└── node2/                       # Pi #2 (Secondary) configuration
    ├── docker-compose.yml
    ├── .env.example
    └── keepalived/
        ├── Dockerfile
        ├── keepalived.conf
        ├── check_dns.sh
        └── notify_*.sh
```

## Maintenance

### Regular Tasks
- **Weekly**: Review keepalived logs for unexpected failovers
- **Monthly**: Test failover manually
- **Monthly**: Update Docker images
- **Quarterly**: Full system backup

### Updates
```bash
# On each Pi, one at a time:
cd /opt/rpi-ha-dns-stack/deployments/HighAvail_2Pi1P1U/node[1|2]
docker compose pull
docker compose up -d
# Wait for services to stabilize, then update the other node
```

## Troubleshooting

### VIP Not Showing
- Check VRRP traffic: `tcpdump -i eth0 -nn vrrp`
- Verify network connectivity between nodes
- Check firewall rules

### Split Brain (Both MASTER)
- Check network connectivity: `ping <peer_ip>`
- Verify VRRP configuration matches
- Check virtual_router_id is same on both

### Sync Not Working
- Test SSH: `ssh pi@<peer_ip>`
- Check Gravity Sync logs: `sudo gravity-sync log`
- Run manual sync: `sudo gravity-sync push -f`

## Support

For issues or questions:
1. Check logs: `docker compose logs`
2. Review main repository documentation
3. See MULTI_NODE_HA_DESIGN.md for detailed architecture
4. Open an issue on GitHub
