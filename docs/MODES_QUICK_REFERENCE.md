# Standalone vs Integrated Mode - Quick Reference

This repository supports two deployment modes to suit different use cases.

## Quick Decision Guide

**Just want reliable DNS on your Raspberry Pi?**
→ Use **Standalone Mode** (default)

**Running the full Orion Sentinel ecosystem with CoreSrv?**
→ Use **Integrated Mode**

---

## Standalone Mode (Default)

### What You Get
- ✅ Pi-hole for network-wide ad blocking
- ✅ Unbound for recursive DNS with DNSSEC
- ✅ Keepalived for high availability (VIP failover)
- ✅ Fully functional without any external dependencies

### What You DON'T Need
- ❌ CoreSrv or external monitoring server
- ❌ Exporters (optional, can add for local metrics)
- ❌ Promtail (optional, can add for local logs)

### Quick Start

```bash
# Clone the repository
git clone https://github.com/orionsentinel/Orion-sentinel-ha-dns.git
cd Orion-sentinel-ha-dns

# Deploy core DNS services
cd stacks/dns
docker compose --profile single-pi-ha up -d

# That's it! Your DNS is running.
```

### Access Your Services
- Pi-hole Dashboard: http://your-pi-ip:8080/admin
- DNS Server: Use your-pi-ip or VIP as DNS server

---

## Integrated Mode (with CoreSrv)

### What You Get (Everything from Standalone, PLUS)
- 📊 Metrics scraped by CoreSrv Prometheus
- 📝 Logs forwarded to CoreSrv Loki
- 🎨 Unified dashboards in CoreSrv Grafana
- 🔗 Cross-stack correlation with security events

### Prerequisites
- ✅ CoreSrv running (Dell server with Loki, Grafana, Prometheus)
- ✅ Network connectivity between Pi and CoreSrv
- ✅ LOKI_URL environment variable configured

### Quick Start

```bash
# 1. Deploy core DNS services (same as Standalone)
cd stacks/dns
docker compose --profile single-pi-ha up -d

# 2. Deploy metrics exporters (optional but recommended)
cd ../monitoring
docker compose -f docker-compose.exporters.yml up -d

# 3. Deploy log shipping agent (optional but recommended)
cd ../agents/pi-dns

# Set your CoreSrv Loki URL
export LOKI_URL=http://192.168.8.100:3100  # Replace with your CoreSrv IP

# Deploy Promtail
docker compose up -d

# 4. Configure CoreSrv Prometheus to scrape metrics
# See docs/SPOG_INTEGRATION_GUIDE.md for details
```

### What Happens If CoreSrv Fails?
**Good news:** DNS continues to work perfectly! Core services are independent.

Only the observability layer is affected:
- ❌ Metrics won't be scraped (but exporters keep running)
- ❌ Logs won't be forwarded (but DNS keeps resolving)
- ✅ DNS resolution continues normally
- ✅ Ad blocking continues normally
- ✅ HA failover continues normally

---

## Comparison Table

| Feature | Standalone | Integrated |
|---------|-----------|------------|
| **DNS Resolution** | ✅ | ✅ |
| **Ad Blocking** | ✅ | ✅ |
| **High Availability** | ✅ | ✅ |
| **Local Web UI** | ✅ | ✅ |
| **External Dependencies** | ❌ None | ⚪ CoreSrv (optional) |
| **Centralized Metrics** | ❌ | ✅ |
| **Centralized Logs** | ❌ | ✅ |
| **Unified Dashboards** | ❌ | ✅ |
| **Cross-Stack Correlation** | ❌ | ✅ |

---

## Environment Variables

### Standalone Mode
No special environment variables required. Just set:
- `PIHOLE_PASSWORD` - Your Pi-hole admin password
- `DNS_VIP` - Virtual IP for HA (if using)

### Integrated Mode
Additional optional variables:
- `LOKI_URL` - Loki endpoint (default: http://192.168.8.100:3100)
- `CORESRV_IP` - CoreSrv IP address (alternative to LOKI_URL)

**Setting variables:**

```bash
# Option 1: Environment variable (temporary)
export LOKI_URL=http://your-coresrv-ip:3100

# Option 2: .env file (recommended)
echo "LOKI_URL=http://your-coresrv-ip:3100" >> .env

# Option 3: Edit promtail config directly
cd stacks/agents/pi-dns
cp promtail-config.example.yml promtail-config.yml
# Edit the URL in promtail-config.yml
```

---

## File Organization

### Core DNS Services (Required)
```
stacks/dns/docker-compose.yml
  ├── Pi-hole (primary & secondary)
  ├── Unbound (primary & secondary)
  ├── Keepalived (VIP management)
  └── Pihole-sync (single-pi-ha mode)
```

### Monitoring Exporters (Optional)
```
stacks/monitoring/docker-compose.exporters.yml
  ├── node-exporter (system metrics)
  ├── pihole-exporter (Pi-hole metrics)
  ├── blackbox-exporter (DNS probes)
  └── cadvisor (container metrics)
```

### Log Shipping Agents (Optional)
```
stacks/agents/
  ├── pi-dns/docker-compose.yml (for CoreSrv)
  └── dns-log-agent/docker-compose.yml (for Security Pi)
```

---

## Troubleshooting

### Standalone Mode Issues

**DNS not resolving:**
```bash
# Check core services
cd stacks/dns
docker compose ps

# Check logs
docker compose logs pihole_primary
docker compose logs unbound_primary
```

### Integrated Mode Issues

**Metrics not appearing in Grafana:**
1. Check exporters are running: `docker ps | grep exporter`
2. Verify metrics endpoints: `curl http://localhost:9100/metrics`
3. Check CoreSrv Prometheus scrape config
4. Verify network connectivity to CoreSrv

**Logs not appearing in Loki:**
1. Check Promtail is running: `docker ps | grep promtail`
2. Check Promtail logs: `docker compose logs promtail`
3. Verify LOKI_URL is correct: `echo $LOKI_URL`
4. Test connectivity: `curl http://your-coresrv-ip:3100/ready`
5. Check firewall allows port 3100

**DNS still works even though monitoring failed:**
- ✅ This is expected! Core DNS is independent.
- Fix monitoring when convenient.
- DNS continues to function normally.

---

## Migration Between Modes

### From Standalone to Integrated

```bash
# No changes to core DNS needed!
# Just add exporters and log shipping:

cd stacks/monitoring
docker compose -f docker-compose.exporters.yml up -d

cd ../agents/pi-dns
export LOKI_URL=http://your-coresrv-ip:3100
docker compose up -d
```

### From Integrated to Standalone

```bash
# Just stop exporters and log shipping:

cd stacks/agents/pi-dns
docker compose down

cd ../../monitoring
docker compose -f docker-compose.exporters.yml down

# Core DNS continues running!
```

---

## Documentation Links

- **[Main README](../README.md)** - Complete project documentation
- **[SPoG Integration Guide](../docs/SPOG_INTEGRATION_GUIDE.md)** - Detailed CoreSrv setup
- **[SPoG Quick Reference](../docs/SPOG_QUICK_REFERENCE.md)** - Quick start guide
- **[Observability Guide](../docs/observability.md)** - Monitoring and metrics
- **[Agents README](../stacks/agents/README.md)** - Log shipping details
- **[Monitoring README](../stacks/monitoring/README.md)** - Exporters documentation

---

## Summary

**The Bottom Line:**
- This repo is a **complete, production-ready HA DNS solution** that works perfectly on its own.
- When you add CoreSrv, it becomes a **smart sensor** in the larger Orion Sentinel security platform.
- **Core DNS services never depend on monitoring/logging** - they're always independent.
- You can start with Standalone and upgrade to Integrated later (or vice versa).

**Choose your path:**
- **Home users, small labs**: Standalone mode is perfect
- **Full Orion Sentinel ecosystem**: Integrated mode gives you the complete picture
- **Not sure?** Start with Standalone, add Integrated later when needed
