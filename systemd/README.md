# Orion DNS HA - systemd Unit Files

This directory contains example systemd unit files for managing the Orion DNS HA stack.
Copy these files to `/etc/systemd/system/` on your Raspberry Pi nodes.

## Stack Management Units

### Primary Node Setup

On the **PRIMARY** node (higher VRRP priority, default MASTER):

```bash
sudo cp systemd/orion-dns-ha-primary.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now orion-dns-ha-primary.service
```

### Backup Node Setup

On the **BACKUP** node (lower VRRP priority):

```bash
sudo cp systemd/orion-dns-ha-backup-node.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now orion-dns-ha-backup-node.service
```

> **Important:** Only install ONE stack service per node (either primary or backup).

## Health Check Timer

Runs DNS health checks every minute and auto-heals on failures.

**Install on BOTH nodes:**

```bash
sudo cp systemd/orion-dns-ha-health.service /etc/systemd/system/
sudo cp systemd/orion-dns-ha-health.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now orion-dns-ha-health.timer
```

**Verify:**
```bash
sudo systemctl status orion-dns-ha-health.timer
sudo journalctl -u orion-dns-ha-health.service -f
```

## Backup Timer

Creates daily backups at 03:15 AM with automatic retention.

**Install on BOTH nodes:**

```bash
sudo cp systemd/orion-dns-ha-backup.service /etc/systemd/system/
sudo cp systemd/orion-dns-ha-backup.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now orion-dns-ha-backup.timer
```

**Verify:**
```bash
sudo systemctl status orion-dns-ha-backup.timer
sudo systemctl list-timers --all | grep orion
```

**Manual backup:**
```bash
sudo systemctl start orion-dns-ha-backup.service
```

## Unit Files Summary

| File | Purpose | Install On |
|------|---------|------------|
| `orion-dns-ha-primary.service` | Start/stop stack (primary profile) | Primary node |
| `orion-dns-ha-backup-node.service` | Start/stop stack (backup profile) | Backup node |
| `orion-dns-ha-health.service` | DNS health check (oneshot) | Both nodes |
| `orion-dns-ha-health.timer` | Triggers health check every minute | Both nodes |
| `orion-dns-ha-backup.service` | Backup configuration (oneshot) | Both nodes |
| `orion-dns-ha-backup.timer` | Triggers backup daily at 03:15 | Both nodes |

## Configuration Override

All services support environment overrides via `/etc/default/orion-dns-ha`:

```bash
# /etc/default/orion-dns-ha
REPO_DIR=/opt/orion-dns-ha
HEALTH_FAIL_THRESHOLD=3
BACKUP_RETENTION_DAYS=30
```

## Checking Status

```bash
# View all Orion timers
sudo systemctl list-timers --all | grep orion

# Check health timer status
sudo systemctl status orion-dns-ha-health.timer

# Check backup timer status  
sudo systemctl status orion-dns-ha-backup.timer

# View recent health check logs
sudo journalctl -u orion-dns-ha-health.service --since "1 hour ago"

# View recent backup logs
sudo journalctl -u orion-dns-ha-backup.service --since "1 day ago"

# Check stack service status
sudo systemctl status orion-dns-ha-primary.service  # on primary node
# OR
sudo systemctl status orion-dns-ha-backup-node.service  # on backup node
```

## Troubleshooting

### Timer not running

```bash
# Verify timer is enabled
sudo systemctl is-enabled orion-dns-ha-health.timer

# Check timer status
sudo systemctl status orion-dns-ha-health.timer

# Manually trigger the service
sudo systemctl start orion-dns-ha-health.service
```

### Service failing

```bash
# View detailed logs
sudo journalctl -u orion-dns-ha-health.service -xe

# Check script permissions
ls -la /opt/orion-dns-ha/ops/
```

### Stack not starting on boot

```bash
# Ensure docker is enabled
sudo systemctl enable docker.service

# Check systemd dependencies
sudo systemctl list-dependencies orion-dns-ha-primary.service
```
