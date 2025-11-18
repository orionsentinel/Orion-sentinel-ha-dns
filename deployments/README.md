# High Availability DNS Deployment Options

This directory contains **four complete deployment options** for high availability DNS setups on Raspberry Pi, including a **VPN Edition** for remote access!

## 🌟 NEW: Interactive Setup Wizard

**Recommended for all users!** Run the interactive setup wizard to get guided through the entire process:

```bash
cd /path/to/rpi-ha-dns-stack
bash scripts/interactive-setup.sh
```

The wizard will:
1. Check all prerequisites (Docker, RAM, disk space, etc.)
2. Survey your hardware (number of Pis, available RAM)
3. Recommend the best deployment option for your setup
4. Guide you through configuration (network, passwords, etc.)
5. Create all necessary .env files automatically
6. Show you exactly what commands to run next

**No need to read further if you use the wizard!** It does all the decision-making for you.

---

## Manual Selection Guide

If you prefer to choose manually, here's the breakdown:

## Quick Decision Guide

```
How many Raspberry Pis do you have?
│
├─ 1 Pi ──→ Do you need remote VPN access?
│           │
│           ├─ Yes ──→ Use HighAvail_1Pi2P2U_VPN ⭐ VPN EDITION
│           │          (HA DNS + WireGuard VPN with QR codes)
│           │
│           └─ No  ──→ Use HighAvail_1Pi2P2U
│                      (Container-level HA only)
│
└─ 2 Pis ──→ What level of redundancy do you need?
             │
             ├─ Balanced ──→ Use HighAvail_2Pi1P1U ⭐ RECOMMENDED
             │               (1 Pi-hole + 1 Unbound per Pi)
             │
             └─ Maximum ──→ Use HighAvail_2Pi2P2U
                             (2 Pi-hole + 2 Unbound per Pi)
```

## Deployment Options

### HighAvail_1Pi2P2U_VPN - Single Pi with VPN ⭐ VPN EDITION

**Architecture:** 1 Raspberry Pi with 2 Pi-hole + 2 Unbound + WireGuard VPN

```
                  Internet
                     ↓
          Router (Port 51820 UDP)
                     ↓
┌────────────────────────────────────┐
│  Raspberry Pi + WireGuard VPN      │
│  ├── WireGuard Server (QR codes!) │
│  ├── WireGuard-UI (Web interface) │
│  ├── Pi-hole Primary               │
│  ├── Pi-hole Secondary             │
│  ├── Unbound Primary               │
│  ├── Unbound Secondary             │
│  └── Keepalived VIP (192.168.8.255)│
└────────────────────────────────────┘
         ↓
   VPN Clients (phones, laptops)
   All use VIP for HA DNS!
```

**Best For:**
- Remote access to home network
- Ad-blocking on all devices everywhere
- Secure access to home services (media servers, NAS)
- Testing VPN before scaling to 2-Pi

**Pros:**
- ✅ Simple setup (one device)
- ✅ Low cost (1 Raspberry Pi)
- ✅ **VPN with QR codes for instant setup**
- ✅ **Ad-blocking everywhere via Pi-hole**
- ✅ **HA DNS with automatic failover**
- ✅ Container-level redundancy
- ✅ Access home services remotely

**Cons:**
- ❌ Single point of failure (hardware)
- ❌ VPN speed limited by home upload
- ❌ No protection against power failure

**Requirements:**
- 1x Raspberry Pi 4/5 (4GB+ RAM recommended)
- Static IP configuration
- **Public IP or DDNS hostname (e.g., myhome.duckdns.org)**
- **Router with port forwarding (UDP 51820)**

**Unique Features:**
- 📱 **QR codes** for instant mobile setup
- 🌐 **Web UI** for managing VPN peers
- 🛡️ **Integrates with HA VIP** (192.168.8.255)
- 🚀 **Split or full tunnel** options
- ✅ **Same UX as WireHole** but with HA DNS backend!

**[Go to HighAvail_1Pi2P2U_VPN →](./HighAvail_1Pi2P2U_VPN/)**

---

### HighAvail_1Pi2P2U - Single Pi, Dual Services

**Architecture:** 1 Raspberry Pi with 2 Pi-hole + 2 Unbound

```
┌─────────────────────────────┐
│  Raspberry Pi               │
│  ├── Pi-hole Primary        │
│  ├── Pi-hole Secondary      │
│  ├── Unbound Primary        │
│  ├── Unbound Secondary      │
│  └── Keepalived (local VIP) │
└─────────────────────────────┘
```

**Best For:**
- Home labs and testing
- Single Raspberry Pi setups
- Learning and experimentation
- Budget-conscious deployments

**Pros:**
- ✅ Simple setup (one device)
- ✅ Low cost (1 Raspberry Pi)
- ✅ Container-level redundancy
- ✅ Quick failover (<5 seconds)

**Cons:**
- ❌ Single point of failure (hardware)
- ❌ No protection against power/SD card failure
- ❌ Complete outage if Pi fails

**Requirements:**
- 1x Raspberry Pi 4/5 (4GB+ RAM)
- Static IP configuration

**[Go to HighAvail_1Pi2P2U →](./HighAvail_1Pi2P2U/)**

---

### HighAvail_2Pi1P1U - Two Pis, Simplified ⭐ RECOMMENDED

**Architecture:** 2 Raspberry Pis with 1 Pi-hole + 1 Unbound each

```
┌─────────────────┐    ┌─────────────────┐
│  Raspberry Pi #1│    │  Raspberry Pi #2│
│  ├── Pi-hole    │    │  ├── Pi-hole    │
│  ├── Unbound    │    │  ├── Unbound    │
│  └── Keepalived │◄──►│  └── Keepalived │
│     MASTER      │VRRP│     BACKUP      │
└────────┬────────┘    └────────┬────────┘
         └────────┬──────────────┘
                  ▼
        VIP: 192.168.8.255
     (Floats between Pis)
```

**Best For:**
- Production home networks
- Small office deployments
- Users who want hardware redundancy
- **RECOMMENDED for most users**

**Pros:**
- ✅ True hardware redundancy
- ✅ Automatic failover (5-10 sec)
- ✅ Moderate complexity
- ✅ Efficient resource usage
- ✅ Best balance of features vs. complexity

**Cons:**
- ⚠️ Requires two Raspberry Pis
- ⚠️ Slightly more complex setup
- ⚠️ No container redundancy per node

**Requirements:**
- 2x Raspberry Pi 4/5 (4GB+ RAM each)
- Static IPs for both Pis
- SSH access between nodes

**[Go to HighAvail_2Pi1P1U →](./HighAvail_2Pi1P1U/)**

---

### HighAvail_2Pi2P2U - Two Pis, Maximum Redundancy

**Architecture:** 2 Raspberry Pis with 2 Pi-hole + 2 Unbound each

```
┌─────────────────────┐    ┌─────────────────────┐
│  Raspberry Pi #1    │    │  Raspberry Pi #2    │
│  ├── Pi-hole 1      │    │  ├── Pi-hole 1      │
│  ├── Pi-hole 2      │    │  ├── Pi-hole 2      │
│  ├── Unbound 1      │    │  ├── Unbound 1      │
│  ├── Unbound 2      │    │  ├── Unbound 2      │
│  └── Keepalived     │◄──►│  └── Keepalived     │
│     MASTER          │VRRP│     BACKUP          │
└──────────┬──────────┘    └──────────┬──────────┘
           └────────┬────────────────┘
                    ▼
          VIP: 192.168.8.259
       (Floats between Pis)
```

**Best For:**
- Mission-critical environments
- Maximum uptime requirements
- Complex failure scenarios
- Users with powerful hardware (8GB RAM)

**Pros:**
- ✅ Triple redundancy (container + node + hardware)
- ✅ Survives multiple concurrent failures
- ✅ Maximum availability
- ✅ Can lose one Pi-hole per node and still work

**Cons:**
- ⚠️ High complexity
- ⚠️ High resource usage (8GB RAM recommended)
- ⚠️ Overkill for most home setups
- ⚠️ More difficult to manage

**Requirements:**
- 2x Raspberry Pi 4/5 (8GB RAM each - RECOMMENDED)
- Static IPs for both Pis
- SSH access between nodes
- Active cooling recommended

**[Go to HighAvail_2Pi2P2U →](./HighAvail_2Pi2P2U/)**

---

## Comparison Matrix

| Feature | 1Pi2P2U | 2Pi1P1U | 2Pi2P2U |
|---------|---------|---------|---------|
| **Physical Pis** | 1 | 2 | 2 |
| **Pi-hole per Pi** | 2 | 1 | 2 |
| **Unbound per Pi** | 2 | 1 | 2 |
| **Hardware HA** | ❌ | ✅ | ✅ |
| **Container HA per Pi** | ✅ | ❌ | ✅ |
| **Setup Complexity** | Low | Medium | High |
| **RAM per Pi** | 4GB | 4GB | 8GB |
| **Cost** | $ | $$ | $$ |
| **Failover Time** | 5s | 10s | 5-10s |
| **Best For** | Lab/Test | **Production** | Critical |
| **Recommendation** | Home Lab | **⭐ Most Users** | Advanced |

## Network IP Allocation

### HighAvail_1Pi2P2U
- Host: 192.168.8.250
- Pi-hole Primary: 192.168.8.251
- Pi-hole Secondary: 192.168.8.252
- Unbound Primary: 192.168.8.253
- Unbound Secondary: 192.168.8.254
- VIP: 192.168.8.255

### HighAvail_2Pi1P1U
- Pi #1 Host: 192.168.8.11
- Pi #2 Host: 192.168.8.12
- Pi-hole on Pi #1: 192.168.8.251
- Pi-hole on Pi #2: 192.168.8.252
- Unbound on Pi #1: 192.168.8.253
- Unbound on Pi #2: 192.168.8.254
- VIP: 192.168.8.255

### HighAvail_2Pi2P2U
- Pi #1 Host: 192.168.8.11
- Pi #2 Host: 192.168.8.12
- Pi-holes on Pi #1: 192.168.8.251, 192.168.8.252
- Pi-holes on Pi #2: 192.168.8.255, 192.168.8.256
- Unbounds on Pi #1: 192.168.8.253, 192.168.8.254
- Unbounds on Pi #2: 192.168.8.257, 192.168.8.258
- VIP: 192.168.8.259

## How to Choose

### Choose HighAvail_1Pi2P2U if:
- ✅ You have only one Raspberry Pi
- ✅ You want container-level redundancy
- ✅ You prefer simple setup
- ✅ This is for lab/testing
- ✅ Budget is limited

### Choose HighAvail_2Pi1P1U if: ⭐
- ✅ You have two Raspberry Pis
- ✅ You want hardware redundancy
- ✅ You need production-level reliability
- ✅ You want balanced complexity
- ✅ **This is the recommended option**

### Choose HighAvail_2Pi2P2U if:
- ✅ You have two powerful Pis (8GB RAM)
- ✅ You need maximum redundancy
- ✅ Your DNS is mission-critical
- ✅ You can handle high complexity
- ✅ You need to survive multiple failures

## Migration Paths

### From 1Pi2P2U to 2Pi1P1U
1. Deploy second Pi with simplified setup
2. Configure VRRP between nodes
3. Test failover
4. Simplify first Pi if desired

### From 1Pi2P2U to 2Pi2P2U
1. Deploy second Pi with full redundancy
2. Configure VRRP between nodes
3. Keep first Pi as-is (already has 2P2U)

### From 2Pi1P1U to 2Pi2P2U
1. Add second Pi-hole + Unbound to each node
2. Update configurations
3. Configure local and inter-node sync

## Common Questions

**Q: Which option should I choose?**  
A: For most users, **HighAvail_2Pi1P1U** is the best choice. It provides hardware redundancy with reasonable complexity.

**Q: Can I mix and match?**  
A: Not recommended. Each deployment is designed as a complete, cohesive system.

**Q: What if I only have one Pi now but might get a second later?**  
A: Start with HighAvail_1Pi2P2U, then migrate to HighAvail_2Pi1P1U when you get the second Pi.

**Q: Do I need 8GB RAM for 2Pi2P2U?**  
A: Highly recommended. 4GB will work but may be tight under load.

**Q: Which gives the fastest failover?**  
A: 1Pi2P2U (5s) and 2Pi2P2U (5-10s) have fastest container-level failover. 2Pi1P1U has 10s node-level failover.

**Q: Which is easiest to manage?**  
A: HighAvail_1Pi2P2U is simplest, followed by HighAvail_2Pi1P1U, then HighAvail_2Pi2P2U.

## Getting Started

1. **Choose your deployment option** based on your needs and hardware
2. **Navigate to that directory** (click links above)
3. **Read the README.md** in that directory for detailed instructions
4. **Follow the deployment steps** specific to that option
5. **Test your setup** using the verification procedures

## Support

Each deployment option has its own detailed README with:
- Complete architecture diagrams
- Step-by-step deployment instructions
- Verification procedures
- Troubleshooting guides
- Maintenance tasks

For general questions:
- Review the main repository documentation
- Check the MULTI_NODE_HA_DESIGN.md for architecture details
- Open an issue on GitHub

---

**Remember:** The goal is high availability DNS. Choose the option that best fits your needs, hardware, and comfort level with complexity.

**Recommendation:** Start with **HighAvail_2Pi1P1U** if you have two Pis - it's the sweet spot for most users! ⭐
