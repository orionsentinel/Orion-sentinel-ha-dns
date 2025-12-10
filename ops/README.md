# Orion DNS HA - Operational Scripts

This directory contains host-level operational scripts for the Orion DNS HA stack.
These scripts run **outside** of containers at the host (systemd) level.

## Scripts

### `orion-dns-health.sh`

**Auto-heal script** that monitors DNS health and automatically restarts containers on failure.

- Uses the same `check_dns.sh` that keepalived uses internally
- Tracks consecutive failures before taking action (default threshold: 2)
- Restarts `pihole_unbound` container on repeated DNS failures
- Starts `keepalived` if not running

**Usage:**
```bash
# Run manually
./ops/orion-dns-health.sh

# With custom threshold
HEALTH_FAIL_THRESHOLD=3 ./ops/orion-dns-health.sh
```

**Environment Variables:**
| Variable | Default | Description |
|----------|---------|-------------|
| `REPO_DIR` | `/opt/orion-dns-ha` | Path to repository |
| `PIHOLE_CONTAINER_NAME` | `pihole_unbound` | Pi-hole container name |
| `KEEPALIVED_CONTAINER_NAME` | `keepalived` | Keepalived container name |
| `HEALTH_FAIL_THRESHOLD` | `2` | Consecutive failures before restart |
| `CHECK_DNS_FQDN` | `github.com` | Domain to check for DNS resolution |

### `orion-dns-backup.sh`

**Backup script** that creates timestamped compressed backups with retention.

**What gets backed up:**
- `compose.yml`
- `.env*` files
- `pihole/etc-pihole/` (gravity DB, settings)
- `pihole/etc-dnsmasq.d/` (dnsmasq configs)
- `keepalived/config/` (keepalived.conf, scripts)

**Usage:**
```bash
# Run backup
./ops/orion-dns-backup.sh

# With custom retention
BACKUP_RETENTION_DAYS=30 ./ops/orion-dns-backup.sh
```

**Environment Variables:**
| Variable | Default | Description |
|----------|---------|-------------|
| `REPO_DIR` | `/opt/orion-dns-ha` | Path to repository |
| `BACKUP_RETENTION_DAYS` | `14` | Days to keep old backups |

**Output:**
- Backups are stored in `${REPO_DIR}/backups/`
- Format: `dns-ha-backup-<hostname>-YYYYMMDD-HHMMSS.tgz`

### `orion-dns-restore.sh`

**Restore script** that restores configuration from backup tarballs.

**Usage:**
```bash
# List available backups
./ops/orion-dns-restore.sh --list

# Preview restore (dry-run)
./ops/orion-dns-restore.sh --dry-run backups/dns-ha-backup-pi1-20240115-031500.tgz

# Restore from backup
./ops/orion-dns-restore.sh backups/dns-ha-backup-pi1-20240115-031500.tgz
```

**Restore Process:**
1. Stops the DNS stack (`docker compose down`)
2. Extracts backup over existing files
3. Starts the DNS stack (`docker compose up -d`)

## Installation with systemd

See the `systemd/` directory for unit files that run these scripts automatically:

```bash
# Copy unit files
sudo cp systemd/orion-dns-ha-health.* /etc/systemd/system/
sudo cp systemd/orion-dns-ha-backup.* /etc/systemd/system/

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable --now orion-dns-ha-health.timer
sudo systemctl enable --now orion-dns-ha-backup.timer

# Verify
sudo systemctl list-timers --all | grep orion
```

## State Files

The health script maintains state in `${REPO_DIR}/run/`:
- `health.failcount` - Tracks consecutive DNS check failures

This directory is created automatically and can be safely deleted to reset state.
