# Multi-Node HA Documentation Index

## 🚀 **NEW: Two-Pi HA Quick Start** ⭐

**Want to get started quickly?** Jump straight to:
→ **[Two-Pi HA Quick Start Guide](MULTI_NODE_QUICKSTART.md#-two-pi-ha-quick-start-30-minutes)**

This 30-minute guide walks you through deploying true high availability DNS across two Raspberry Pis with automatic failover.

---

Welcome! This index helps you navigate the complete multi-node High Availability DNS setup documentation.

## 🚀 Start Here

**New to multi-node HA?** Start with the Quick Start:
- **[MULTI_NODE_QUICKSTART.md](MULTI_NODE_QUICKSTART.md)** - Overview and quick reference

**Want to understand the architecture?** Read the comparison:
- **[ARCHITECTURE_COMPARISON.md](ARCHITECTURE_COMPARISON.md)** - Visual diagrams and comparisons

## 📚 Complete Documentation

### 1. Design & Architecture
**[MULTI_NODE_HA_DESIGN.md](MULTI_NODE_HA_DESIGN.md)** - 25KB comprehensive guide
- Complete architecture designs (Option A & B)
- Network topology and IP addressing
- Keepalived configuration details
- Synchronization strategies
- Security considerations
- Performance tuning
- FAQ and troubleshooting

### 2. Visual Comparison
**[ARCHITECTURE_COMPARISON.md](ARCHITECTURE_COMPARISON.md)** - 20KB visual guide
- Side-by-side topology diagrams
- Current vs. proposed architectures
- Failure scenario analysis
- Resource usage comparison
- Decision tree
- Migration path from single-node

### 3. Deployment Guide
**[MULTI_NODE_DEPLOYMENT_CHECKLIST.md](MULTI_NODE_DEPLOYMENT_CHECKLIST.md)** - 12KB checklist
- Pre-deployment requirements
- Step-by-step deployment instructions
- Verification procedures
- Testing scenarios
- Troubleshooting guide
- Maintenance tasks
- Emergency procedures

### 4. Quick Reference
**[MULTI_NODE_QUICKSTART.md](MULTI_NODE_QUICKSTART.md)** - 12KB quick guide
- Quick start instructions
- Architecture overview
- How it works
- Key concepts explained
- Testing procedures
- When to use which option
- Resource requirements

## ⚙️ Configuration Files

### Environment Configuration
- **[.env.multinode.example](.env.multinode.example)** - Complete environment template
  - Network configuration
  - Node identification
  - Keepalived settings
  - Sync configuration
  - Resource limits

### Keepalived Configurations
Located in `stacks/dns/keepalived/`:
- **[keepalived-multinode-primary.conf](stacks/dns/keepalived/keepalived-multinode-primary.conf)** - Primary node config
- **[keepalived-multinode-secondary.conf](stacks/dns/keepalived/keepalived-multinode-secondary.conf)** - Secondary node config

### Health Check & Notification Scripts
Located in `stacks/dns/keepalived/`:
- **[check_dns.sh](stacks/dns/keepalived/check_dns.sh)** - DNS health check script
- **[notify_master.sh](stacks/dns/keepalived/notify_master.sh)** - MASTER state notification
- **[notify_backup.sh](stacks/dns/keepalived/notify_backup.sh)** - BACKUP state notification
- **[notify_fault.sh](stacks/dns/keepalived/notify_fault.sh)** - Fault detection notification

## 🔧 Deployment Tools

- **[scripts/deploy-multinode.sh](scripts/deploy-multinode.sh)** - Automated deployment script
  - Prerequisite validation
  - Node role detection
  - Network setup
  - Service deployment
  - Health checks
  - Post-deployment guidance

## 🎯 Quick Navigation by Task

### I want to understand the options
1. Read [ARCHITECTURE_COMPARISON.md](ARCHITECTURE_COMPARISON.md)
2. Review decision tree and comparison tables
3. Decide: Option A (Simplified) or Option B (Full)

### I want to see how it works
1. Read [MULTI_NODE_QUICKSTART.md](MULTI_NODE_QUICKSTART.md)
2. Review "How Multi-Node HA Works" section
3. Check failure scenario examples

### I want to deploy it
1. Start with [MULTI_NODE_DEPLOYMENT_CHECKLIST.md](MULTI_NODE_DEPLOYMENT_CHECKLIST.md)
2. Complete pre-deployment checklist
3. Follow step-by-step instructions
4. Use `deploy-multinode.sh` script
5. Run verification tests

### I want detailed architecture info
1. Read [MULTI_NODE_HA_DESIGN.md](MULTI_NODE_HA_DESIGN.md)
2. Focus on your chosen option (A or B)
3. Review network configuration section
4. Study synchronization strategy

### I need troubleshooting help
1. Check [MULTI_NODE_DEPLOYMENT_CHECKLIST.md](MULTI_NODE_DEPLOYMENT_CHECKLIST.md) troubleshooting section
2. Review common issues in [MULTI_NODE_HA_DESIGN.md](MULTI_NODE_HA_DESIGN.md)
3. Check [MULTI_NODE_QUICKSTART.md](MULTI_NODE_QUICKSTART.md) for quick fixes

## 📊 Architecture Options Summary

### Option A: Simplified (RECOMMENDED) ⭐
```
Pi #1: 1 Pi-hole + 1 Unbound + Keepalived MASTER
Pi #2: 1 Pi-hole + 1 Unbound + Keepalived BACKUP
VIP: 192.168.8.255 (floats between nodes)
```
**Best for:** Most users, home networks, small offices  
**Complexity:** Medium  
**Resource Usage:** Moderate

### Option B: Full Redundancy
```
Pi #1: 2 Pi-hole + 2 Unbound + Keepalived MASTER
Pi #2: 2 Pi-hole + 2 Unbound + Keepalived BACKUP
VIP: 192.168.8.255 (floats between nodes)
```
**Best for:** Mission-critical, maximum uptime required  
**Complexity:** High  
**Resource Usage:** High

## 🔍 Key Concepts

### Virtual IP (VIP)
Shared IP address (192.168.8.255) that automatically moves between nodes during failover.

### VRRP (Virtual Router Redundancy Protocol)
Industry-standard protocol for automatic IP failover between nodes.

### Keepalived
Software that implements VRRP, manages VIP, and monitors service health.

### Gravity Sync
Tool for synchronizing Pi-hole configurations between nodes.

### Failover Time
Typical: 5-10 seconds for automatic failover to backup node.

## 📈 Implementation Steps (Quick Overview)

1. **Prepare** (30 min)
   - Get two Raspberry Pis
   - Install OS on both
   - Set static IPs

2. **Configure** (30 min)
   - Copy .env.multinode.example to .env
   - Set node-specific variables
   - Configure SSH keys

3. **Deploy** (30 min)
   - Run deploy-multinode.sh on each node
   - Verify services start
   - Check VIP assignment

4. **Sync** (30 min)
   - Install Gravity Sync on primary
   - Configure sync settings
   - Test initial sync

5. **Test** (30 min)
   - Test DNS resolution
   - Test failover (stop primary)
   - Test failback (start primary)
   - Verify sync works

**Total Time:** 2-3 hours for Option A

## ❓ Decision Help

### Choose Option A if:
- ✅ You have two Raspberry Pis available
- ✅ You want hardware-level redundancy
- ✅ You're okay with medium complexity
- ✅ Your Pis have 4GB+ RAM
- ✅ You want best balance of features/complexity

### Choose Option B if:
- ✅ You need maximum redundancy
- ✅ Your environment is mission-critical
- ✅ Your Pis have 8GB RAM
- ✅ You can handle high complexity
- ✅ You need both container AND hardware redundancy

### Stay with Single-Node if:
- ✅ You only have one Raspberry Pi
- ✅ Container-level HA is sufficient
- ✅ You prefer simple setup
- ✅ Budget is limited
- ✅ Lab/testing environment only

## 🆘 Getting Help

### Common Questions
Check the FAQ sections in:
- [MULTI_NODE_HA_DESIGN.md](MULTI_NODE_HA_DESIGN.md#troubleshooting)
- [MULTI_NODE_DEPLOYMENT_CHECKLIST.md](MULTI_NODE_DEPLOYMENT_CHECKLIST.md#troubleshooting-guide)

### Troubleshooting
1. Review troubleshooting sections in guides
2. Check container logs: `docker logs keepalived`
3. Verify network connectivity
4. Test health check scripts manually

### Further Reading
- [Keepalived Documentation](https://www.keepalived.org/)
- [VRRP RFC 5798](https://tools.ietf.org/html/rfc5798)
- [Gravity Sync Guide](https://github.com/vmstan/gravity-sync)
- [Pi-hole Documentation](https://docs.pi-hole.net/)

## 📝 Notes

- **All configurations are production-ready** - Based on industry best practices
- **No changes to existing code** - All new functionality is in separate files
- **Backward compatible** - Single-node setup continues to work
- **Comprehensive testing** - Includes extensive test procedures
- **Well documented** - 73KB+ of detailed documentation

## 🎉 Ready to Start?

1. **Read** → [MULTI_NODE_QUICKSTART.md](MULTI_NODE_QUICKSTART.md)
2. **Understand** → [ARCHITECTURE_COMPARISON.md](ARCHITECTURE_COMPARISON.md)
3. **Deploy** → [MULTI_NODE_DEPLOYMENT_CHECKLIST.md](MULTI_NODE_DEPLOYMENT_CHECKLIST.md)
4. **Reference** → [MULTI_NODE_HA_DESIGN.md](MULTI_NODE_HA_DESIGN.md)

---

**Documentation Version:** 1.0  
**Status:** Complete - Ready for Implementation  
**Estimated Reading Time:** 2-3 hours for full documentation  
**Estimated Implementation Time:** 2-4 hours for Option A
