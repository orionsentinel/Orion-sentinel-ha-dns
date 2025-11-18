# Deployment Options Comparison Chart

## Visual Architecture Comparison

### HighAvail_1Pi2P2U (Starter)
```
┌─────────────────────────────┐
│  Raspberry Pi               │
│  ├── Pi-hole Primary   ✓    │
│  ├── Pi-hole Secondary ✓    │
│  ├── Unbound Primary   ✓    │
│  ├── Unbound Secondary ✓    │
│  └── Keepalived VIP    ✓    │
│                             │
│  VPN Gateway?          ✗    │
│  Remote Access?        ✗    │
└─────────────────────────────┘
```
**Use Case**: Testing, learning, home lab  
**Setup Time**: 10 minutes  
**Cost**: 1x Raspberry Pi  

---

### HighAvail_1Pi2P2U_VPN (VPN Edition) ⭐
```
                Internet
                   ↓
    Router Port Forward (51820/UDP)
                   ↓
┌──────────────────────────────────┐
│  Raspberry Pi                    │
│  ├── WireGuard VPN Server  ✓ 🆕│
│  ├── WireGuard-UI (QR)     ✓ 🆕│
│  ├── Pi-hole Primary       ✓    │
│  ├── Pi-hole Secondary     ✓    │
│  ├── Unbound Primary       ✓    │
│  ├── Unbound Secondary     ✓    │
│  └── Keepalived VIP        ✓    │
│      (192.168.8.255)            │
└──────────────────┬───────────────┘
                   ↓
         VPN Clients (phones, laptops)
         Use VIP for HA DNS!
```
**Use Case**: Remote access + ad-blocking everywhere  
**Setup Time**: 10-15 minutes  
**Cost**: 1x Raspberry Pi + Public IP/DDNS  
**Special**: QR codes for instant mobile setup!  

---

### HighAvail_2Pi1P1U (Production) ⭐
```
┌──────────────────┐    ┌──────────────────┐
│  Raspberry Pi #1 │    │  Raspberry Pi #2 │
│  ├── Pi-hole  ✓  │    │  ├── Pi-hole  ✓  │
│  └── Unbound  ✓  │    │  └── Unbound  ✓  │
└────────┬─────────┘    └─────────┬────────┘
         │                        │
         └────────┬───────────────┘
                  ↓
         Keepalived VIP (192.168.8.255)
         Floats between Pi #1 and #2!
```
**Use Case**: Production, always-on networks  
**Setup Time**: 30 minutes  
**Cost**: 2x Raspberry Pis  
**Special**: True hardware redundancy  

---

### HighAvail_2Pi2P2U (Maximum)
```
┌──────────────────┐    ┌──────────────────┐
│  Raspberry Pi #1 │    │  Raspberry Pi #2 │
│  ├── Pi-hole A ✓ │    │  ├── Pi-hole C ✓ │
│  ├── Pi-hole B ✓ │    │  ├── Pi-hole D ✓ │
│  ├── Unbound A ✓ │    │  ├── Unbound C ✓ │
│  └── Unbound B ✓ │    │  └── Unbound D ✓ │
└────────┬─────────┘    └─────────┬────────┘
         │                        │
         └────────┬───────────────┘
                  ↓
         Keepalived VIP (192.168.8.255)
         Maximum redundancy!
```
**Use Case**: Mission-critical, small office  
**Setup Time**: 45 minutes  
**Cost**: 2x Raspberry Pis  
**Special**: Survives multiple failures  

---

## Feature Matrix

| Feature | Starter | VPN Edition | Production | Maximum |
|---------|---------|-------------|------------|---------|
| **Hardware** |
| Raspberry Pis | 1 | 1 | 2 | 2 |
| Hardware Redundancy | ❌ | ❌ | ✅ | ✅ |
| **DNS Services** |
| Pi-hole Instances | 2 | 2 | 2 | 4 |
| Unbound Instances | 2 | 2 | 2 | 4 |
| Keepalived VIP | ✅ | ✅ | ✅ | ✅ |
| Auto Failover | Container | Container | Hardware | Hardware |
| **VPN Features** |
| WireGuard VPN | ❌ | ✅ | ❌* | ❌* |
| WireGuard-UI | ❌ | ✅ | ❌* | ❌* |
| QR Codes | ❌ | ✅ | ❌* | ❌* |
| Remote Access | ❌ | ✅ | ❌* | ❌* |
| **Capabilities** |
| Ad-Blocking | ✅ | ✅ | ✅ | ✅ |
| Recursive DNS | ✅ | ✅ | ✅ | ✅ |
| Self-Healing | ✅ | ✅ | ✅ | ✅ |
| Observability | Optional | Optional | Optional | Optional |
| **Metrics** |
| Setup Time | 10 min | 15 min | 30 min | 45 min |
| Setup Complexity | Low | Low | Medium | High |
| Ongoing Maintenance | Low | Low | Medium | Medium |
| Resource Usage | ~600MB | ~700MB | ~600MB/Pi | ~1GB/Pi |
| **Best For** |
| Use Case | Testing | Home + Remote | Always-On | Critical |
| User Skill Level | Beginner | Beginner | Intermediate | Advanced |
| Uptime Target | 99% | 99% | 99.9% | 99.95% |

*VPN can be added to 2-Pi deployments by deploying VPN stack separately

---

## Cost Comparison

### Initial Hardware

| Option | Hardware | Cost (USD) |
|--------|----------|------------|
| Starter | 1x RPi 4 (4GB) | $55 |
| VPN Edition | 1x RPi 4 (4GB) | $55 |
| Production | 2x RPi 4 (4GB) | $110 |
| Maximum | 2x RPi 4 (8GB) | $150 |

### Ongoing Costs

| Option | Power/Year | DDNS (optional) | Total/Year |
|--------|------------|-----------------|------------|
| Starter | ~$15 | $0 | $15 |
| VPN Edition | ~$15 | $0-25 | $15-40 |
| Production | ~$30 | $0 | $30 |
| Maximum | ~$30 | $0 | $30 |

---

## Recommended Migration Path

### Path 1: Budget-Conscious
```
Start → HighAvail_1Pi2P2U (Starter)
          ↓ (Add VPN when needed)
      HighAvail_1Pi2P2U_VPN
          ↓ (Buy 2nd Pi when ready)
      HighAvail_2Pi1P1U (Production)
```

### Path 2: VPN-First
```
Start → HighAvail_1Pi2P2U_VPN (with VPN)
          ↓ (Scale to 2-Pi)
      HighAvail_2Pi1P1U + Add VPN stack
          ↓ (Maximum redundancy)
      HighAvail_2Pi2P2U + Add VPN stack
```

### Path 3: Enterprise
```
Start → HighAvail_2Pi1P1U (Production)
          ↓ (Add VPN)
      HighAvail_2Pi1P1U + VPN stack
          ↓ (Maximum redundancy)
      HighAvail_2Pi2P2U + VPN stack
```

---

## Quick Decision Tree

```
Do you have 2 Raspberry Pis?
│
├─ Yes ──→ Use HighAvail_2Pi1P1U (Production)
│          Add VPN later if needed
│
└─ No (1 Pi) ──→ Do you need remote access?
               │
               ├─ Yes ──→ HighAvail_1Pi2P2U_VPN ⭐
               │          (VPN Edition - RECOMMENDED!)
               │
               └─ No ──→ HighAvail_1Pi2P2U
                         (Starter - Add VPN later)
```

---

## VPN Edition: Why It's Special

### What Makes VPN Edition Unique

1. **WireHole UX with HA Backend**
   - Simple setup like WireHole
   - Automatic failover unlike WireHole
   - QR codes for phones
   - Web UI for management

2. **Perfect First Step**
   - Start with 1 Pi
   - Get full HA benefits
   - Add VPN immediately
   - Scale to 2-Pi later

3. **Best Value**
   - Same hardware as Starter
   - Adds remote access
   - Adds ad-blocking everywhere
   - Only +5 minutes setup

### VPN Edition vs Starter

```
Both cost the same (1x Raspberry Pi)
Both have same HA DNS (2 Pi-hole, 2 Unbound)
Both have Keepalived VIP
Both have self-healing

VPN Edition adds:
+ WireGuard VPN server
+ WireGuard-UI with QR codes
+ Remote access to all home services
+ Ad-blocking on all devices everywhere
+ Only +$0-25/year for DDNS (optional)
+ Only +5 minutes setup time

Recommendation: Just use VPN Edition!
```

---

## Integration Examples

### Example 1: VPN Edition + Media Server

```
Internet
   ↓
Router:51820 → WireGuard VPN
                    ↓
              VIP (192.168.8.255)
                    ↓
              Pi-hole (ad-blocking)
                    ↓
         Access home services:
         • Jellyfin (192.168.8.100:8096)
         • Pi-hole Admin (192.168.8.251/admin)
         • Grafana (192.168.8.250:3000)
```

### Example 2: Production + VPN Stack

```
         Internet
            ↓
   Router:51820 → WireGuard (on Pi #1)
                       ↓
                VIP (192.168.8.255)
            ┌───────────┴───────────┐
            ↓                       ↓
     Pi #1 (healthy)          Pi #2 (standby)
     • Pi-hole                • Pi-hole
     • Unbound                • Unbound
     
Hardware Redundancy + VPN Access!
```

---

## Performance Comparison

### DNS Query Latency

| Deployment | Cold Query | Cached Query | Failover Time |
|------------|------------|--------------|---------------|
| Starter | ~50ms | ~2ms | <5 sec |
| VPN Edition | ~50ms | ~2ms | <5 sec |
| Production | ~50ms | ~2ms | <2 sec |
| Maximum | ~50ms | ~2ms | <2 sec |

### VPN Performance

| Metric | VPN Edition | Production + VPN |
|--------|-------------|------------------|
| Latency | +10-20ms | +10-20ms |
| Throughput | Limited by home upload | Limited by home upload |
| Reliability | 99% (1 Pi) | 99.9% (2 Pi) |
| Failover | DNS only | DNS + VPN gateway |

---

## Summary Recommendation

### For Most Users: **VPN Edition** ⭐

**Why:**
- Same cost as Starter (1 Raspberry Pi)
- Same HA benefits (automatic DNS failover)
- Adds remote access for free
- QR codes make setup trivial
- Can scale to 2-Pi later

**When NOT to use:**
- Don't need remote access ever
- Have 2 Pis from the start (use Production)
- Don't have public IP/DDNS

### Upgrade Path

```
Start:      VPN Edition (1 Pi)
Scale:      Add 2nd Pi → Production + VPN
Maximize:   Both Pis full services
```

**Bottom Line**: VPN Edition is the best starting point for 95% of users! 🚀

---

## Quick Links

- [VPN Edition Deployment →](deployments/HighAvail_1Pi2P2U_VPN/)
- [VPN Quick Start Guide →](stacks/vpn/README_VPN_QUICKSTART.md)
- [All Deployment Options →](deployments/README.md)
- [Main Documentation →](README.md)
