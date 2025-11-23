# Log Shipping Agents (Optional)

This directory contains **optional** log shipping agents for **Integrated mode** only.

## Overview

These agents use Promtail to forward DNS logs to a centralized Loki instance:
- On a Security Pi running Orion Sentinel NSM AI
- On a Dell CoreSrv running the Single Pane of Glass (SPoG) stack

**These components are NOT required for DNS functionality.**

## Agents Available

### 1. `pi-dns/` - Primary Log Agent (Recommended)

Ships logs to Dell CoreSrv Loki in SPoG deployments.

**Features:**
- Comprehensive log collection (Pi-hole, Unbound, Keepalived, Docker containers, system logs)
- Advanced log parsing and labeling
- Efficient batching and retry logic
- Resource-optimized for Raspberry Pi

**When to use:**
- You have a Dell CoreSrv running Loki
- You want centralized logging across multiple Pis
- Part of the full Orion Sentinel SPoG setup

**Deployment:**
```bash
cd stacks/agents/pi-dns

# Set your CoreSrv Loki URL
export LOKI_URL=http://192.168.8.100:3100  # Replace with your CoreSrv IP

# Deploy
docker compose up -d
```

### 2. `dns-log-agent/` - Simple Log Agent

Ships logs to a Security Pi running Orion Sentinel NSM AI.

**When to use:**
- You have a separate NSM/Security Pi with Loki
- You want DNS logs for security analysis
- Simpler two-Pi setup (DNS Pi + Security Pi)

**Deployment:**
```bash
cd stacks/agents/dns-log-agent

# Set your Loki URL (Security Pi)
export LOKI_URL=http://192.168.8.100:3100  # Replace with your Security Pi IP

# Deploy
docker compose up -d
```

### 3. `pi-netsec/` - Network Security Agent

For the Security/NSM Pi to ship its own logs. Not relevant for DNS Pi deployments.

## Configuration

All agents use environment variables for configuration:

| Variable | Description | Default |
|----------|-------------|---------|
| `LOKI_URL` | Full Loki endpoint URL | `http://192.168.8.100:3100` |
| `CORESRV_IP` | CoreSrv IP (alternative to LOKI_URL) | `192.168.8.100` |

**Methods to set variables:**

1. **Environment variable (temporary):**
   ```bash
   export LOKI_URL=http://your-ip:3100
   docker compose up -d
   ```

2. **Using .env file (recommended):**
   ```bash
   echo "LOKI_URL=http://your-ip:3100" > .env
   docker compose up -d
   ```

3. **Edit promtail config directly:**
   ```bash
   cp promtail-config.example.yml promtail-config.yml
   # Edit the clients URL in promtail-config.yml
   docker compose up -d
   ```

## Important Notes

### ✅ DNS Services Are Independent

**Core DNS services (Pi-hole, Unbound, Keepalived) do NOT depend on these agents.**

- DNS will continue to work perfectly even if:
  - These agents are not deployed
  - Promtail fails to start
  - Loki/CoreSrv is unreachable
  - Network connectivity to CoreSrv is lost

### 🎯 Deployment Modes

| Mode | Log Agents Needed? |
|------|-------------------|
| **Standalone** | ❌ No - DNS works without them |
| **Integrated** | ✅ Optional - Adds centralized logging |

### 📊 What Gets Shipped

When deployed, these agents forward:
- **Pi-hole logs**: DNS queries, blocks, FTL logs
- **Unbound logs**: DNS resolution, DNSSEC validation
- **Keepalived logs**: VIP failover events
- **Docker logs**: Container stdout/stderr
- **System logs**: Syslog entries for correlation

### 🔍 Troubleshooting

**Agent won't start:**
- Check that `LOKI_URL` is set correctly
- Verify network connectivity to Loki: `curl http://your-loki-ip:3100/ready`
- Check Promtail logs: `docker compose logs promtail`

**Logs not appearing in Loki:**
- Verify Loki is receiving data: Check Loki logs
- Ensure firewall allows traffic to port 3100
- Check Promtail metrics: `curl http://localhost:9080/metrics`

**DNS still works even though agent failed:**
- ✅ This is expected behavior!
- Core DNS services are independent
- Fix the agent when convenient

## Documentation

- **[SPoG Integration Guide](../../docs/SPOG_INTEGRATION_GUIDE.md)** - Complete CoreSrv setup
- **[SPoG Quick Reference](../../docs/SPOG_QUICK_REFERENCE.md)** - Quick start
- **[Observability Guide](../../docs/observability.md)** - Monitoring and logging

## Quick Decision Matrix

**Choose based on your setup:**

- **Just want DNS on my Pi?** → Skip this entirely, use Standalone mode
- **Have Dell CoreSrv (SPoG)?** → Use `pi-dns/` agent
- **Have Security Pi with Loki?** → Use `dns-log-agent/`
- **No centralized logging?** → Skip this, DNS works without it

**Remember:** This is the **Integrated mode** feature. The DNS stack is fully functional without any of these agents!
