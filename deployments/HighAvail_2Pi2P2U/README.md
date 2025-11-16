# High Availability Setup: Two Pis with 2 Pi-hole + 2 Unbound per Pi

## Architecture Overview

This setup provides **maximum redundancy** by running **2 Pi-hole + 2 Unbound** on **each of two physical Raspberry Pis**. This is the **ADVANCED** multi-node setup.

```
┌──────────────────────────────┐    ┌──────────────────────────────┐
│  Raspberry Pi #1             │    │  Raspberry Pi #2             │
│  Physical IP: 192.168.8.11   │    │  Physical IP: 192.168.8.12   │
│  ┌────────────────────────┐  │    │  ┌────────────────────────┐  │
│  │  Docker Host           │  │    │  │  Docker Host           │  │
│  │                        │  │    │  │                        │  │
│  │  ┌────────┐ ┌────────┐ │  │    │  │  ┌────────┐ ┌────────┐ │  │
│  │  │Pi-hole │ │Pi-hole │ │  │    │  │  │Pi-hole │ │Pi-hole │ │  │
│  │  │  P-1   │ │  P-2   │ │◄─┼────┼──┼─►│  S-1   │ │  S-2   │ │  │
│  │  │  .251  │ │  .252  │ │  │    │  │  │  .255  │ │  .256  │ │  │
│  │  └───┬────┘ └───┬────┘ │  │    │  │  └───┬────┘ └───┬────┘ │  │
│  │      │          │       │  │    │  │      │          │       │  │
│  │  ┌───▼────┐ ┌───▼────┐ │  │    │  │  ┌───▼────┐ ┌───▼────┐ │  │
│  │  │Unbound │ │Unbound │ │  │    │  │  │Unbound │ │Unbound │ │  │
│  │  │  P-1   │ │  P-2   │ │  │    │  │  │  S-1   │ │  S-2   │ │  │
│  │  │  .253  │ │  .254  │ │  │    │  │  │  .257  │ │  .258  │ │  │
│  │  └────────┘ └────────┘ │  │    │  │  └────────┘ └────────┘ │  │
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
              Virtual IP (VIP): 192.168.8.259
             (Floats between Pi #1 and Pi #2)
```

## Features

- ✅ **Triple redundancy**: Container-level + Node-level + Hardware-level
- ✅ **Maximum availability**: Services continue even with multiple failures
- ✅ **2x Pi-hole per Pi**: Container-level redundancy on each node
- ✅ **2x Unbound per Pi**: Container-level redundancy on each node
- ✅ **Automatic failover**: Both container-level and node-level
- ✅ **Zero downtime**: Survives multiple concurrent failures

## Pros and Cons

### ✅ Advantages
- Maximum redundancy at all levels
- Survives multiple concurrent failures
- Can lose one Pi-hole on each node and still work
- True mission-critical setup
- Best for high-uptime requirements

### ⚠️ Considerations
- Requires two powerful Raspberry Pis (8GB RAM recommended)
- Higher complexity to manage
- Higher resource usage on each Pi
- More configuration to sync
- Overkill for most home/small office setups

## Network Configuration

### Node IP Addresses
- **Raspberry Pi #1**: 192.168.8.11 (MASTER)
- **Raspberry Pi #2**: 192.168.8.12 (BACKUP)

### Service IP Addresses (Pi #1)
- **Pi-hole Primary-1**: 192.168.8.251
- **Pi-hole Primary-2**: 192.168.8.252
- **Unbound Primary-1**: 192.168.8.253
- **Unbound Primary-2**: 192.168.8.254

### Service IP Addresses (Pi #2)
- **Pi-hole Secondary-1**: 192.168.8.255
- **Pi-hole Secondary-2**: 192.168.8.256
- **Unbound Secondary-1**: 192.168.8.257
- **Unbound Secondary-2**: 192.168.8.258

### Shared
- **Virtual IP (VIP)**: 192.168.8.259

## How It Works

### Three Levels of Redundancy

**Level 1: Container-level (per node)**
- If one Pi-hole crashes on Pi #1 → other Pi-hole on Pi #1 handles queries
- Local Keepalived manages container-level failover

**Level 2: Node-level**
- If entire Pi #1 fails → Pi #2 takes over via VIP failover
- VRRP manages node-level failover

**Level 3: Combined**
- Can survive Pi-hole crash on Pi #1 AND entire Pi #2 failure
- Multiple failure points before complete outage

### Normal Operation
1. Pi #1 (MASTER) owns the VIP
2. Local Keepalived on Pi #1 routes to healthy Pi-hole containers
3. Pi #2 (BACKUP) monitors via VRRP
4. All 4 Pi-holes sync configurations

### Failure Scenarios

**Scenario 1: Container Crash**
```
Pi-hole P-1 crashes on Pi #1
→ Local Keepalived routes to Pi-hole P-2
→ Service continues on Pi #1
→ No VIP movement needed
→ Recovery time: <5 seconds
```

**Scenario 2: Node Failure**
```
Entire Pi #1 fails
→ Pi #2 detects missing VRRP heartbeats
→ Pi #2 becomes MASTER, claims VIP
→ Service continues on Pi #2
→ Recovery time: 5-10 seconds
```

**Scenario 3: Multiple Failures**
```
Pi-hole P-1 crashes on Pi #1 AND Pi #2 goes down
→ Pi #1 routes to Pi-hole P-2 locally
→ Service continues on Pi #1
→ Can survive complex failure scenarios
```

## Deployment Instructions

### Prerequisites
- 2x Raspberry Pi 4/5 (8GB RAM each - RECOMMENDED)
- Raspberry Pi OS (64-bit) on both
- Docker and Docker Compose installed on both
- Static IPs configured:
  - Pi #1: 192.168.8.11
  - Pi #2: 192.168.8.12
- SSH access between nodes
- Adequate cooling (more services = more heat)

### Step-by-Step Deployment

[Similar deployment steps as 2Pi1P1U, but with more containers]

#### 1. Prepare Both Nodes

On **both Pi #1 and Pi #2**:

```bash
# Install prerequisites
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io docker-compose git rsync

# Clone repository
cd /opt
sudo git clone https://github.com/yorgosroussakis/rpi-ha-dns-stack.git
cd rpi-ha-dns-stack/deployments/HighAvail_2Pi2P2U
```

#### 2. Configure SSH Keys

[Same as 2Pi1P1U]

#### 3. Configure Environment

On **Pi #1**:
```bash
cp node1/.env.example node1/.env
nano node1/.env
# Verify settings
```

On **Pi #2**:
```bash
cp node2/.env.example node2/.env
nano node2/.env
# Verify settings
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

#### 6. Verify Automatic Synchronization

Synchronization is handled automatically by the built-in pihole-sync.sh script (Pi-hole v6 compatible).

The sync containers on each node automatically synchronize configuration between all 4 Pi-hole instances. No manual configuration is required.

To verify sync is working:
```bash
# Check sync container logs on any node
docker logs pihole-sync

# Test by making a change on one Pi-hole instance
# and verifying it appears on the others
```

### Verification

[Similar verification steps as 2Pi1P1U]

## When to Use This Setup

Choose this setup if:
- ✅ You have two powerful Raspberry Pis (8GB RAM each)
- ✅ You need **maximum** uptime and redundancy
- ✅ Your DNS is **mission-critical** to operations
- ✅ You can handle high complexity
- ✅ You need to survive multiple concurrent failures
- ✅ Budget allows for powerful hardware

**Do NOT use this setup if:**
- ❌ You have limited resources (use 2Pi1P1U instead)
- ❌ You want simple management (use 2Pi1P1U or 1Pi2P2U)
- ❌ This is for home/lab use (use 2Pi1P1U)
- ❌ Your Pis have only 4GB RAM (use 2Pi1P1U)

## Comparison with Other Options

| Feature | 1Pi2P2U | 2Pi1P1U | 2Pi2P2U (This) |
|---------|---------|---------|----------------|
| Raspberry Pis | 1 | 2 | 2 |
| Pi-hole per Pi | 2 | 1 | 2 |
| Unbound per Pi | 2 | 1 | 2 |
| Hardware HA | ❌ | ✅ | ✅ |
| Container HA per node | ✅ | ❌ | ✅ |
| Complexity | Low | Medium | **High** |
| RAM Required | 4GB | 4GB | **8GB** |
| Resource Usage | Medium | Medium | **High** |
| Failover Layers | 1 | 1 | **3** |
| Best For | Lab | Production | **Mission Critical** |

## Resource Usage

### Per Node (Estimated)
- **CPU**: 20-30% average, 60% peak
- **RAM**: 3-4GB with all services
- **Disk**: 10-15GB
- **Network**: Moderate (sync traffic between 4 Pi-holes)

### Cooling Requirements
- Active cooling (fan) **strongly recommended**
- Heat sinks on CPU and RAM
- Monitor temperatures regularly

## Files in This Deployment

```
HighAvail_2Pi2P2U/
├── README.md                    # This file
├── node1/                       # Pi #1 (Primary) configuration
│   ├── docker-compose.yml       # 2 Pi-hole + 2 Unbound + Keepalived
│   ├── .env.example
│   └── keepalived/
│       ├── Dockerfile
│       ├── keepalived.conf
│       └── scripts...
└── node2/                       # Pi #2 (Secondary) configuration
    ├── docker-compose.yml       # 2 Pi-hole + 2 Unbound + Keepalived
    ├── .env.example
    └── keepalived/
        ├── Dockerfile
        ├── keepalived.conf
        └── scripts...
```

## Maintenance

### Regular Tasks
- **Weekly**: Review all container logs
- **Weekly**: Check resource usage (CPU, RAM, disk)
- **Biweekly**: Test container-level failover
- **Monthly**: Test node-level failover
- **Monthly**: Update Docker images (one node at a time)
- **Quarterly**: Full system backup

### Monitoring
- Set up alerts for high CPU/RAM usage
- Monitor sync status between all 4 Pi-holes
- Watch for split-brain scenarios
- Track failover frequency

## Troubleshooting

### High Resource Usage
- Check if all containers are necessary
- Consider downgrading to 2Pi1P1U
- Reduce logging verbosity
- Increase swap space

### Complex Sync Issues
- Sync 4 Pi-holes is more complex
- May need custom sync scripts
- Consider syncing pairs: P-1↔S-1, P-2↔S-2
- Monitor sync conflicts

### Container Conflicts
- Ensure unique IPs for all 8 containers
- Check port conflicts
- Verify resource limits aren't too restrictive

## Migration Path

### From 1Pi2P2U
1. Deploy Pi #2 with 2P2U setup
2. Configure VRRP between nodes
3. Test failover
4. Optionally simplify Pi #1 to match

### From 2Pi1P1U
1. Add second Pi-hole + Unbound to each node
2. Update Keepalived configs for local failover
3. Configure sync for all 4 Pi-holes
4. Test multi-level failover

## Support

For issues or questions:
1. Check logs on all containers: `docker compose logs`
2. Review resource usage: `docker stats`
3. See MULTI_NODE_HA_DESIGN.md for detailed architecture
4. Consider if 2Pi1P1U might be more appropriate
5. Open an issue on GitHub

---

**This is an ADVANCED setup. Most users should use HighAvail_2Pi1P1U instead.**
