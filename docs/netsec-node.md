# NetSec Node Documentation

This document covers the Network Security Monitoring (NetSec) node deployment using Suricata IDS, EveBox, and supporting services.

---

## 📖 Table of Contents

- [What Runs](#what-runs)
- [Ports Reference](#ports-reference)
- [Where Logs Live](#where-logs-live)
- [Checking Capture Health](#checking-capture-health)
- [Updating Rules Safely](#updating-rules-safely)
- [EveBox Admin Password](#evebox-admin-password)
- [Mirror Port Limitations](#mirror-port-limitations)
- [Troubleshooting](#troubleshooting)

---

## What Runs

The NetSec profile deploys the following services:

| Service | Image | Purpose |
|---------|-------|---------|
| **suricata** | `jasonish/suricata:7.0.6` | Network IDS/IPS, packet analysis |
| **evebox** | `jasonish/evebox:0.18.2` | Suricata alert management UI |
| **netsec_node_exporter** | `prom/node-exporter:v1.8.2` | System metrics for Prometheus |
| **cadvisor** | `gcr.io/cadvisor/cadvisor:v0.49.1` | Container metrics |
| **netsec_promtail** | `grafana/promtail:3.0.0` | Log shipping to Loki |

### Deployment Profiles

- **`netsec`**: Suricata + node-exporter + cadvisor + promtail (no EveBox)
- **`netsec-plus-evebox`**: All services including EveBox UI

Deploy with:
```bash
# Full stack with EveBox
docker compose --profile netsec-plus-evebox up -d

# Core services only (no EveBox)
docker compose --profile netsec up -d
```

---

## Ports Reference

| Service | Host Port | Container Port | Protocol |
|---------|-----------|----------------|----------|
| node-exporter | 19100 | 9100 | HTTP/metrics |
| cadvisor | 18080 | 8080 | HTTP/metrics |
| evebox | 5636 | 5636 | HTTP/UI |

**Note:** These ports are intentionally non-standard to avoid conflicts with other services:
- Standard node-exporter uses 9100 → we use 19100
- Standard cadvisor uses 8080 → we use 18080
- EveBox uses its standard port 5636

Suricata runs in `network_mode: host` and doesn't expose ports - it captures on the specified interface.

---

## Where Logs Live

All Suricata data persists under `/mnt/orion-nvme-netsec/suricata/`:

```
/mnt/orion-nvme-netsec/suricata/
├── etc/                    # Configuration
│   ├── suricata.yaml       # Main Suricata config
│   ├── update.yaml         # suricata-update config
│   ├── disable.conf        # Disabled rules
│   └── threshold.config    # Rate limiting/suppression
├── lib/                    # Rules
│   └── rules/
│       └── suricata.rules  # Active ruleset
└── logs/                   # Logs
    ├── eve.json            # Primary JSON log (alerts, flows, etc.)
    ├── fast.log            # Human-readable alerts
    ├── stats.log           # Performance statistics
    └── suricata.log        # Main application log
```

### Log Rotation

Eve.json can grow large. Configure logrotate:

```bash
cat > /etc/logrotate.d/suricata << 'EOF'
/mnt/orion-nvme-netsec/suricata/logs/eve.json {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 640 root root
    postrotate
        docker exec suricata kill -USR2 1 2>/dev/null || true
    endscript
}
EOF
```

---

## Checking Capture Health

### Quick Health Check

Use the doctor script:
```bash
./scripts/doctor.sh
```

### Manual Checks

#### 1. Check Suricata is Running
```bash
docker ps | grep suricata
docker logs suricata --tail 50
```

#### 2. Check Interface Capture
Look for device lines in startup:
```bash
docker logs suricata 2>&1 | grep -E "(device|interface|af-packet)"
```

Expected output:
```
[PERF] eth1: currently in TPACKET_V3
```

#### 3. Check for Packet Drops
```bash
# Real-time stats
docker exec suricata suricatasc -c "iface-stat eth1"

# Or check stats.log
tail -f /mnt/orion-nvme-netsec/suricata/logs/stats.log | grep -E "(drop|kernel)"
```

Key metrics:
- `capture.kernel_drops` - packets dropped by kernel
- `decoder.pkts` - packets processed
- `detect.alert` - alerts generated

#### 4. Check Eve.json Growth
```bash
# File should be growing if traffic is flowing
ls -la /mnt/orion-nvme-netsec/suricata/logs/eve.json

# Watch for new entries
tail -f /mnt/orion-nvme-netsec/suricata/logs/eve.json | jq -c .
```

#### 5. Check for Errors
```bash
# Common startup errors
docker logs suricata 2>&1 | grep -iE "(error|warning|fail|fatal)"

# Specific issues to watch for:
# - "malformed" - config syntax errors
# - "no rules were loaded" - rule loading failed
# - "mmap" - memory mapping issues
# - "init socket" - interface access problems
# - "fanout" - AF_PACKET fanout errors (should not appear with our config)
```

---

## Updating Rules Safely

### Using suricata-update

The safest way to update rules:

```bash
# 1. Run suricata-update inside container
docker exec suricata suricata-update

# 2. Test the new rules (dry run)
docker exec suricata suricata -T -c /etc/suricata/suricata.yaml

# 3. If test passes, reload rules
docker exec suricata suricatasc -c reload-rules

# OR restart the container
docker restart suricata
```

### Scheduled Updates

Add to crontab for automatic updates:
```bash
# Update rules daily at 3 AM, restart if successful
0 3 * * * docker exec suricata suricata-update && docker restart suricata
```

### Modifying Disabled Rules

Edit `/mnt/orion-nvme-netsec/suricata/etc/disable.conf`:

```bash
# Add SIDs to disable (one per line)
echo "2100498" >> /mnt/orion-nvme-netsec/suricata/etc/disable.conf

# Re-run suricata-update to apply
docker exec suricata suricata-update
docker restart suricata
```

### Verifying Rule Load Status
```bash
# Count active rules
docker exec suricata suricatasc -c "ruleset-stats"

# Or check startup log
docker logs suricata 2>&1 | grep -E "rules (loaded|failed)"
```

---

## EveBox Admin Password

### Setting Up Authentication

By default, EveBox runs without authentication (`EVEBOX_AUTH_REQUIRED=false`).

To enable authentication:

1. **Set environment variable in `.env`:**
   ```bash
   EVEBOX_AUTH_REQUIRED=true
   ```

2. **Restart EveBox:**
   ```bash
   docker compose --profile netsec-plus-evebox up -d evebox
   ```

3. **Create admin user:**
   ```bash
   docker exec -it evebox evebox config set authentication.type username
   docker exec -it evebox evebox user add admin
   ```
   You'll be prompted to enter a password.

### Recovering/Resetting Password

If you forget the password:

1. **Check container logs** (password may be shown on first startup if auto-generated):
   ```bash
   docker logs evebox 2>&1 | grep -i password
   ```

2. **Reset password:**
   ```bash
   docker exec -it evebox evebox user passwd admin
   ```

3. **Or disable authentication temporarily:**
   ```bash
   # In .env
   EVEBOX_AUTH_REQUIRED=false
   
   # Restart
   docker compose --profile netsec-plus-evebox up -d evebox
   ```

### Accessing EveBox

Once running, access EveBox at:
```
http://<netsec-pi-ip>:5636
```

---

## Mirror Port Limitations

### Understanding Mirror Ports (SPAN)

Suricata captures traffic via a mirror/SPAN port on your switch. This has important limitations:

### What You CAN See

✅ **WAN-bound traffic** - Traffic going to/from the internet through your router
✅ **Inter-VLAN traffic** - If your switch mirrors inter-VLAN routing
✅ **Traffic to mirrored ports** - Only ports configured as mirror sources

### What You CANNOT See

❌ **East-West traffic** - Traffic between devices on the same switch that doesn't pass through the mirrored uplink
❌ **Encrypted payloads** - Suricata sees the encrypted traffic but can't inspect TLS/SSL content
❌ **Traffic on unmirrored switches** - Only the configured switch's traffic is visible

### Maximizing Coverage

1. **Mirror the router uplink** - Captures all internet-bound traffic
2. **Consider multiple mirror ports** - If you have multiple network segments
3. **Position strategically** - Place the mirror at your network choke point

### Mirror Port Configuration Example (Managed Switch)

For a typical managed switch (commands vary by vendor):

```
# Cisco example
monitor session 1 source interface Gi0/1
monitor session 1 destination interface Gi0/24

# UniFi example (via controller)
# Settings → Networks → Configure mirror port in switch settings
```

### Verifying Mirror is Working

```bash
# Check if Suricata sees traffic
docker exec suricata suricatasc -c "iface-stat eth1"

# Should show increasing packet counts
# If pkts = 0, mirror port may not be configured correctly
```

---

## Troubleshooting

### Common Issues

#### "malformed integer" Error
```
Error: malformed integer value
```
**Cause:** Buffer-size specified as string like "32mb" instead of integer.
**Fix:** Our config uses `buffer-size: 33554432` (integer bytes).

#### "no rules were loaded"
```
Warning: no rules loaded
```
**Cause:** suricata-update hasn't run or rules path is wrong.
**Fix:**
```bash
docker exec suricata suricata-update
docker restart suricata
```

#### "init socket failed"
```
Error: init socket failed
```
**Cause:** Interface doesn't exist or no permission.
**Fix:**
- Verify interface name: `ip link show`
- Check container has NET_ADMIN capability
- Ensure interface is up: `ip link set eth1 up`

#### "fanout not supported"
```
Error: AF_PACKET fanout not supported
```
**Cause:** Kernel doesn't support fanout or misconfigured cluster settings.
**Fix:** Our config intentionally omits cluster-id and cluster-type to avoid this.

#### Memory Issues (mmap errors)
```
Error: mmap failed
```
**Cause:** Not enough memory for ring buffers.
**Fix:** Reduce buffer-size in suricata.yaml or increase system memory.

### Performance Issues

#### High Packet Drops

1. **Check kernel drops:**
   ```bash
   docker exec suricata suricatasc -c "iface-stat eth1"
   ```

2. **Increase ring buffer:**
   Edit `/mnt/orion-nvme-netsec/suricata/etc/suricata.yaml`:
   ```yaml
   ring-size: 2048  # Increase from 1024
   ```

3. **Reduce max-pending-packets if memory constrained:**
   ```yaml
   max-pending-packets: 2048  # Decrease from 4096
   ```

#### Eve.json Too Large

1. **Enable log rotation** (see above)
2. **Filter out flow events:**
   ```yaml
   # In suricata.yaml outputs section
   - eve-log:
       types:
         - flow:
             enabled: no  # Disable flow logging
   ```

### Getting Help

1. **Check Suricata docs:** https://docs.suricata.io/
2. **EveBox docs:** https://evebox.org/docs/
3. **Review logs:** `docker logs suricata` and `docker logs evebox`
4. **Run doctor script:** `./scripts/doctor.sh`
