# Orion Sentinel DNS HA

**High-availability DNS with Pi-hole + Unbound + Keepalived**

Two-node VRRP failover for ad-blocking, privacy-focused DNS on Raspberry Pi.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│              Client Devices (DNS queries)                │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
            VIP: 192.168.8.250/24 (eth1)
                  Managed by VRRP
                         │
        ┌────────────────┴────────────────┐
        │                                 │
        ▼                                 ▼
┌──────────────────┐            ┌──────────────────┐
│   Node A (Pri)   │            │   Node B (Sec)   │
│  192.168.8.249   │◄──────────►│  192.168.8.243   │
│                  │   Unicast  │                  │
│  Priority: 200   │   VRRP     │  Priority: 150   │
│  Role: MASTER    │            │  Role: BACKUP    │
└──────────────────┘            └──────────────────┘
        │                                 │
        ▼                                 ▼
  ┌─────────────┐                  ┌─────────────┐
  │  Pi-hole +  │                  │  Pi-hole +  │
  │  Unbound    │                  │  Unbound    │
  └─────────────┘                  └─────────────┘
```

**Key Components:**

- **Pi-hole + Unbound**: Single container from `ghcr.io/mpgirro/docker-pihole-unbound`
  - Pi-hole for ad/tracker blocking
  - Unbound for local recursive DNS (DNSSEC-validated, privacy-first)
- **Keepalived**: VRRP daemon for automatic VIP failover
- **VIP**: `192.168.8.250/24` floats between nodes on `eth1`
- **Health Checks**: DNS resolution monitored every 5 seconds

---

## Quick Start

### Single-Node Setup

Perfect for testing or simple home use:

```bash
# 1. Clone repository
git clone https://github.com/orionsentinel/Orion-sentinel-ha-dns.git
cd Orion-sentinel-ha-dns

# 2. Configure environment
cp .env.example .env
nano .env  # Set WEBPASSWORD and adjust network settings

# 3. Start services
docker compose --profile single-node up -d

# 4. Test DNS
dig @localhost github.com

# 5. Access Pi-hole admin
# Open http://<your-ip>/admin
```

### Two-Node HA Setup

For production high-availability:

#### Node A (Primary)

```bash
# 1. Clone repository
git clone https://github.com/orionsentinel/Orion-sentinel-ha-dns.git
cd Orion-sentinel-ha-dns

# 2. Configure as primary
cp .env.primary.example .env
nano .env  # Set WEBPASSWORD and VRRP_PASSWORD

# 3. Start services
docker compose --profile two-node-ha-primary up -d

# 4. Verify VIP assigned
ip addr show eth1 | grep 192.168.8.250
```

#### Node B (Secondary)

```bash
# 1. Clone repository
git clone https://github.com/orionsentinel/Orion-sentinel-ha-dns.git
cd Orion-sentinel-ha-dns

# 2. Configure as secondary
cp .env.secondary.example .env
nano .env  # Set WEBPASSWORD and VRRP_PASSWORD (must match primary!)

# 3. Start services
docker compose --profile two-node-ha-backup up -d

# 4. Verify VRRP communication
docker logs keepalived
```

#### Testing Failover

```bash
# On any client machine
dig @192.168.8.250 github.com  # Should work

# Stop primary node's Pi-hole
# On Node A:
docker stop pihole_unbound

# VIP should move to Node B within ~15 seconds
# On Node B:
ip addr show eth1 | grep 192.168.8.250

# DNS should still work
dig @192.168.8.250 github.com  # Still resolves!
```

---

## Operations

### Using Make Commands

```bash
# Show all available commands
make help

# Start core services (auto-detects single/two-node mode from .env)
make up-core

# Start with monitoring exporters
make up-all

# Stop all services
make down

# View logs
make logs

# Run health check
make health-check

# Create backup
make backup

# Sync Pi-hole config from primary to secondary
make sync  # Run on primary node

# Show deployment info
make info
```

### Pi-hole Configuration Sync

Synchronize Pi-hole configuration from primary to secondary:

```bash
# On primary node, sync to secondary
PEER_IP=192.168.8.243 ./ops/pihole-sync.sh

# Or use Make
make sync
```

**What gets synced:**
- Gravity database (blocklists, adlists, groups)
- Pi-hole settings
- Custom DNS records
- Whitelist/blacklist entries

**Prerequisites:**
- SSH key-based authentication between nodes
- `rsync` installed on both nodes

### Backups

Automated daily backups with 7-day retention:

```bash
# Manual backup
./ops/orion-dns-backup.sh

# Or via Make
make backup

# List backups
ls -lh backups/

# Restore from backup
./ops/orion-dns-restore.sh backups/dns-ha-backup-<hostname>-<timestamp>.tgz
```

**What gets backed up:**
- `compose.yml` and `.env` files
- `pihole/etc-pihole/` (gravity, settings)
- `pihole/etc-dnsmasq.d/` (dnsmasq configs)
- `keepalived/config/` (keepalived.conf, scripts)

### Health Monitoring

Automatic health checks with container restart on failures:

```bash
# Manual health check
./ops/orion-dns-health.sh

# Install systemd timer for automated checks (every minute)
make install-systemd-primary  # On primary node
make install-systemd-secondary  # On secondary node

sudo systemctl enable --now orion-dns-ha-health.timer
```

---

## DNS Configuration

### Fully Local DNS (Default)

By default, Unbound performs **fully local recursive DNS resolution**:

- Queries go directly to authoritative DNS servers (root hints)
- No third-party DNS providers involved
- Maximum privacy and control
- DNSSEC validation enabled

### NextDNS for DNS over TLS (Optional)

If you want encrypted DNS forwarding to NextDNS:

1. Edit `unbound/nextdns-forward.conf`
2. Uncomment the `forward-zone` block
3. Replace `<your-id>` with your NextDNS configuration ID
4. Restart: `docker compose restart pihole_unbound`

**Example:**
```conf
server:
    tls-cert-bundle: "/etc/ssl/certs/ca-certificates.crt"

forward-zone:
    name: "."
    forward-tls-upstream: yes
    forward-addr: 45.90.28.0@853#abc123.dns.nextdns.io
    forward-addr: 45.90.30.0@853#abc123.dns.nextdns.io
```

To disable and return to local recursion, comment out the `forward-zone` block.

---

## Monitoring Integration

### Exporters Profile

Enable Prometheus exporters and log shipping to Loki/Grafana:

```bash
# Start with exporters
docker compose --profile two-node-ha-primary --profile exporters up -d

# Or via Make
make up-all
```

**Exporters:**
- **Node Exporter** (`:9100`) - System metrics (CPU, memory, disk, network)
- **Pi-hole Exporter** (`:9617`) - DNS query metrics, blocking stats
- **Promtail** (`:9080`) - Ships logs to Loki

**Configuration:**
Set `LOKI_URL` in `.env` to point to your Loki instance (default: `http://192.168.8.100:3100`).

### Prometheus Pushgateway (Optional)

Keepalived state transitions can push metrics to Prometheus Pushgateway:

```bash
# In .env file
PROM_PUSHGATEWAY_URL=http://pushgateway.example.com:9091
PROM_JOB_NAME=orion_dns_ha
PROM_INSTANCE_LABEL=node-primary
```

**Metric:** `keepalived_vrrp_state`
- `1` = MASTER
- `0` = BACKUP
- `-1` = FAULT

---

## Systemd Integration

### Autostart on Boot

**Primary Node:**
```bash
sudo make install-systemd-primary

# Enable services
sudo systemctl enable --now orion-dns-ha-primary.service
sudo systemctl enable --now orion-dns-ha-health.timer
sudo systemctl enable --now orion-dns-ha-backup.timer
sudo systemctl enable --now orion-dns-ha-sync.timer
```

**Secondary Node:**
```bash
sudo make install-systemd-secondary

# Enable services
sudo systemctl enable --now orion-dns-ha-backup-node.service
sudo systemctl enable --now orion-dns-ha-health.timer
sudo systemctl enable --now orion-dns-ha-backup.timer
```

### Timers

- **Health Timer**: Runs every minute, auto-restarts containers on DNS failures
- **Backup Timer**: Daily backups at 3 AM with 7-day retention (14 days default)
- **Sync Timer**: Hourly Pi-hole config sync from primary to secondary

---

## Testing and Troubleshooting

### Verify DNS Resolution

```bash
# Test against VIP
dig @192.168.8.250 github.com

# Test against specific node
dig @192.168.8.249 github.com  # Primary
dig @192.168.8.243 github.com  # Secondary
```

### Check VRRP Status

```bash
# View keepalived logs
docker logs keepalived

# Check VIP assignment
ip addr show eth1 | grep 192.168.8.250

# View VRRP state transitions
tail -f /var/log/keepalived-notify.log  # Inside keepalived container
docker exec keepalived tail -f /var/log/keepalived-notify.log
```

### Common Issues

#### No DNS response on VIP

**Symptoms:** `dig @192.168.8.250` times out

**Fixes:**
1. Verify VIP is assigned: `ip addr show eth1`
2. Check `network_mode: host` is set in `compose.yml`
3. Ensure `DNSMASQ_LISTENING=all` in `.env`
4. Verify firewall allows port 53 (UDP/TCP)

#### VIP not assigned

**Symptoms:** VIP doesn't appear on either node

**Fixes:**
1. Verify `NETWORK_INTERFACE=eth1` matches your interface name
2. Check `USE_UNICAST_VRRP=true` is set
3. Verify `PEER_IP` is set on both nodes
4. Ensure `VRRP_PASSWORD` matches on both nodes
5. Check keepalived logs: `docker logs keepalived`

#### Keepalived restart loop

**Symptoms:** keepalived container keeps restarting

**Fixes:**
1. Check keepalived.conf syntax: `docker exec keepalived cat /etc/keepalived/keepalived.conf`
2. Verify no raw `${VAR}` or `\n` literals in config (should be resolved by entrypoint.sh)
3. Check logs: `docker logs keepalived`

#### Failover not working

**Symptoms:** VIP stays on failed primary

**Fixes:**
1. Verify health check script works: `docker exec keepalived /etc/keepalived/check_dns.sh`
2. Check `CHECK_DNS_TARGET=127.0.0.1` is set
3. Verify `CHECK_DNS_FQDN` resolves: `docker exec keepalived dig @127.0.0.1 github.com`
4. Review keepalived logs for health check failures

---

## Documentation

- **[INSTALL.md](INSTALL.md)** - Comprehensive installation guide
- **[ops/README.md](ops/README.md)** - Operational scripts documentation
- **[systemd/README.md](systemd/README.md)** - Systemd integration guide

---

## Requirements

**Hardware:**
- Raspberry Pi 4/5 (4GB+ RAM recommended)
- 32GB+ SD card or USB SSD
- Ethernet connection (recommended for VRRP)

**Software:**
- Docker 20.10+
- Docker Compose V2 (plugin format)
- Linux kernel with VRRP support

**Network:**
- Two available IPs for nodes (e.g., 192.168.8.249, 192.168.8.243)
- One VIP for DNS service (e.g., 192.168.8.250)
- Multicast or unicast VRRP capability (unicast recommended)

---

## License

This project is open source. See the repository for license details.

---

## Contributing

Contributions welcome! Please open an issue or pull request.

**Project Goals:**
- Simplicity and reliability over complexity
- Privacy-first DNS (local recursion by default)
- Production-ready high availability
- Easy to deploy and maintain

---

**Ready to start?** See [INSTALL.md](INSTALL.md) for detailed installation instructions.
