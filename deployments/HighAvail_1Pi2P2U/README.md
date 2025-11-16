# High Availability Setup: Single Pi with 2 Pi-hole + 2 Unbound

## Architecture Overview

This is the **current/default** setup that runs on a **single Raspberry Pi** with container-level redundancy.

```
┌─────────────────────────────────────────────────────────────┐
│  Raspberry Pi (192.168.8.250)                                │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Docker Host                                          │   │
│  │  ┌────────────┐  ┌────────────┐                      │   │
│  │  │ Pi-hole    │  │ Pi-hole    │                      │   │
│  │  │ Primary    │  │ Secondary  │                      │   │
│  │  │ .251       │  │ .252       │                      │   │
│  │  └─────┬──────┘  └─────┬──────┘                      │   │
│  │        │               │                              │   │
│  │  ┌─────▼──────┐  ┌─────▼──────┐                      │   │
│  │  │ Unbound    │  │ Unbound    │                      │   │
│  │  │ Primary    │  │ Secondary  │                      │   │
│  │  │ .253       │  │ .254       │                      │   │
│  │  └────────────┘  └────────────┘                      │   │
│  │                                                       │   │
│  │  ┌──────────────┐                                    │   │
│  │  │ Keepalived   │                                    │   │
│  │  │ VIP: .255    │                                    │   │
│  │  └──────────────┘                                    │   │
│  │                                                       │   │
│  │  All on macvlan network                              │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Features

- ✅ **Container-level HA**: If one Pi-hole fails, Keepalived routes to the other
- ✅ **2x Pi-hole instances**: Primary and Secondary
- ✅ **2x Unbound instances**: Primary and Secondary
- ✅ **Keepalived VIP**: Single IP for clients (192.168.8.255)
- ✅ **Local sync**: pihole-sync container keeps Pi-holes synchronized
- ⚠️  **Single point of failure**: Entire Pi is a single point of failure

## Pros and Cons

### ✅ Advantages
- Simple setup (one physical device)
- Lower cost (1 Raspberry Pi)
- Container-level redundancy
- Quick failover (<5 seconds between containers)
- Easy to manage

### ❌ Disadvantages
- No protection against hardware failure
- No protection against SD card failure
- No protection against power supply failure
- If the Pi goes down, DNS is completely offline

## Network Configuration

- **Raspberry Pi Host**: 192.168.8.250
- **Pi-hole Primary**: 192.168.8.251
- **Pi-hole Secondary**: 192.168.8.252
- **Unbound Primary**: 192.168.8.253
- **Unbound Secondary**: 192.168.8.254
- **Keepalived VIP**: 192.168.8.255

## Deployment Instructions

### Prerequisites
- 1x Raspberry Pi 4/5 (4GB+ RAM)
- Raspberry Pi OS (64-bit)
- Docker and Docker Compose installed
- Static IP configured (192.168.8.250)

### Quick Start

1. **Copy environment file**:
   ```bash
   cp .env.example .env
   nano .env  # Edit with your settings
   ```

2. **Create Docker network**:
   ```bash
   sudo docker network create \
     -d macvlan \
     --subnet=192.168.8.0/24 \
     --gateway=192.168.8.1 \
     -o parent=eth0 \
     dns_net
   ```

3. **Deploy the stack**:
   ```bash
   docker compose up -d
   ```

4. **Verify services**:
   ```bash
   docker compose ps
   ```

### Testing

From another device on your network:

```bash
# Test DNS via VIP
dig google.com @192.168.8.255

# Test each Pi-hole
dig google.com @192.168.8.251
dig google.com @192.168.8.252

# Test failover
docker stop pihole_primary
# Wait 10 seconds
dig google.com @192.168.8.255  # Should still work via secondary
docker start pihole_primary
```

## When to Use This Setup

Choose this setup if:
- ✅ You have only one Raspberry Pi
- ✅ You want container-level redundancy
- ✅ You prefer simple setup and management
- ✅ You're okay with hardware being a single point of failure
- ✅ This is for a lab/testing environment

## Migration Path

If you later want hardware-level redundancy:
- Deploy a second Raspberry Pi
- Migrate to **HighAvail_2Pi1P1U** or **HighAvail_2Pi2P2U**
- See those deployment guides for migration instructions

## Files in This Deployment

- `docker-compose.yml` - Main service definitions
- `.env.example` - Environment configuration template
- `README.md` - This file
- `keepalived/` - Keepalived configuration for local VIP
- `pihole-sync.sh` - Script to sync Pi-hole configurations

## Support

For issues or questions about this deployment option:
1. Check container logs: `docker compose logs`
2. Review main repository documentation
3. Open an issue on GitHub
