# Enhanced Backup Stack

Comprehensive automated backup solution for all critical stack data with restore capability.

## Features

✅ **Complete Coverage**: All critical data backed up
✅ **Automated Schedule**: Runs daily at 2 AM (customizable)
✅ **Smart Retention**: Automatic cleanup of old backups
✅ **Metadata Tracking**: Detailed backup information
✅ **Easy Restore**: Interactive restore utility
✅ **Compression**: Space-efficient tar.gz format
✅ **Docker Integration**: Direct container data access
✅ **Logging**: Comprehensive backup logs

## What Gets Backed Up

### DNS Services
- **Pi-hole Primary**: Configuration, gravity database, custom lists, teleporter exports
- **Pi-hole Secondary**: Configuration, gravity database, custom lists, teleporter exports
- **Unbound 1 & 2**: Configuration files and settings

### Observability
- **Prometheus**: Metrics data and snapshots
- **Grafana**: Dashboards, data sources, settings, users

### Management Services
- **Portainer**: Stacks, environments, settings
- **Uptime Kuma**: Monitors, status pages, notifications
- **Netdata**: Configuration files

### Configuration Files
- All stack docker-compose.yml files
- Environment variables (.env files)
- Provisioning configurations
- Homepage dashboard configs

## Quick Start

### 1. Deploy Backup Service

```bash
cd /opt/rpi-ha-dns-stack/stacks/backup
cp .env.example .env
nano .env  # Adjust settings if needed
docker compose up -d
```

### 2. Verify Backup Service

```bash
docker logs backup-service
```

## Configuration

### Environment Variables

```bash
# Timezone for backup timestamps
TZ=UTC

# How many days to keep old backups (default: 7)
BACKUP_RETENTION_DAYS=7

# Cron schedule for automated backups (default: daily at 2 AM)
# Format: minute hour day month weekday
BACKUP_SCHEDULE=0 2 * * *
```

### Custom Backup Schedule Examples

```bash
# Every 6 hours
BACKUP_SCHEDULE=0 */6 * * *

# Daily at 3 AM
BACKUP_SCHEDULE=0 3 * * *

# Twice daily (6 AM and 6 PM)
BACKUP_SCHEDULE=0 6,18 * * *

# Weekly on Sunday at 2 AM
BACKUP_SCHEDULE=0 2 * * 0
```

## Manual Operations

### Manual Backup

Trigger a manual backup immediately:

```bash
# Run backup script directly
bash /opt/rpi-ha-dns-stack/scripts/automated-backup.sh
```

### List Backups

```bash
ls -lh /opt/rpi-ha-dns-stack/backups/stack_backup_*.tar.gz
```

### View Backup Info

```bash
tar xzf /opt/rpi-ha-dns-stack/backups/stack_backup_YYYYMMDD_HHMMSS.tar.gz \
  stack_backup_YYYYMMDD_HHMMSS/BACKUP_INFO.txt -O
```

### Restore from Backup

Interactive restore utility:

```bash
bash /opt/rpi-ha-dns-stack/scripts/restore-backup.sh
```

The restore script will:
1. List all available backups
2. Let you select which backup to restore
3. Show backup information
4. Confirm before proceeding
5. Stop all services
6. Restore data
7. Restart services

**⚠️ Warning**: Restore will overwrite existing data. Make sure you have a current backup before restoring!

## Backup File Structure

```
stack_backup_YYYYMMDD_HHMMSS/
├── BACKUP_INFO.txt           # Backup metadata
├── configs/                  # Configuration files
│   ├── .env
│   ├── dns/
│   │   ├── unbound/
│   │   └── docker-compose.yml
│   ├── observability/
│   │   ├── grafana/
│   │   ├── prometheus/
│   │   └── docker-compose.yml
│   └── management/
│       ├── homepage/
│       └── docker-compose.yml
├── pihole/
│   ├── primary/
│   │   ├── etc/data.tar.gz
│   │   └── dnsmasq/data.tar.gz
│   ├── secondary/
│   │   ├── etc/data.tar.gz
│   │   └── dnsmasq/data.tar.gz
│   ├── pihole_primary_teleporter.tar.gz
│   └── pihole_secondary_teleporter.tar.gz
├── grafana/data.tar.gz
├── prometheus/
│   ├── data.tar.gz
│   └── snapshot.json
├── unbound/
│   ├── unbound1/unbound.conf
│   └── unbound2/unbound.conf
└── management/
    ├── portainer/data.tar.gz
    ├── uptime-kuma/data.tar.gz
    └── netdata.conf
```

## Monitoring Backups

### Check Backup Service Status

```bash
docker ps -f name=backup-service
docker logs backup-service --tail 50
```

### View Backup Log

```bash
tail -f /opt/rpi-ha-dns-stack/backups/backup.log
```

### Backup Statistics

```bash
# Total backups
ls -1 /opt/rpi-ha-dns-stack/backups/stack_backup_*.tar.gz | wc -l

# Total backup size
du -sh /opt/rpi-ha-dns-stack/backups/

# Latest backup
ls -lt /opt/rpi-ha-dns-stack/backups/stack_backup_*.tar.gz | head -1
```

## Troubleshooting

### Backup Service Won't Start

```bash
# Check logs
docker logs backup-service

# Verify permissions
ls -ld /opt/rpi-ha-dns-stack/backups/

# Ensure directory exists
mkdir -p /opt/rpi-ha-dns-stack/backups/
```

### Backup Too Large

- Reduce `BACKUP_RETENTION_DAYS` to keep fewer backups
- Prometheus data grows over time - consider reducing retention in Prometheus config
- Manually clean old backups:
  ```bash
  find /opt/rpi-ha-dns-stack/backups/ -name "stack_backup_*.tar.gz" -mtime +30 -delete
  ```

### Restore Failed

- Ensure all containers are stopped before restore
- Check available disk space
- Verify backup file integrity:
  ```bash
  tar tzf /path/to/backup.tar.gz > /dev/null
  ```

## Best Practices

1. **Off-Site Backups**: Periodically copy backups to external storage:
   ```bash
   rsync -avz /opt/rpi-ha-dns-stack/backups/ user@remote:/backups/
   ```

2. **Test Restores**: Regularly test restore procedure in non-production environment

3. **Monitor Backup Size**: Set up alerts if backup size grows unexpectedly

4. **Backup Before Updates**: Always trigger manual backup before major updates:
   ```bash
   bash /opt/rpi-ha-dns-stack/scripts/automated-backup.sh
   ```

5. **Document Changes**: Keep notes of configuration changes for context during restores

## Integration with Management Stack

If you have Uptime Kuma deployed, add backup monitoring:

1. **HTTP Monitor**: Check backup service health
   - URL: `http://backup-service:8080/health` (requires health endpoint)
   - Interval: 1 hour

2. **File Monitor**: Alert on stale backups
   - Check backup file timestamp
   - Alert if no backup in 25+ hours

## Backup Retention Strategy

### Recommended Retention Policies

| Use Case | Retention Days | Backup Frequency |
|----------|----------------|------------------|
| Home Lab | 7 | Daily |
| Small Business | 14 | Daily |
| Production | 30 | Twice Daily |
| Compliance | 90+ | Daily + Off-site |

### Grandfather-Father-Son (GFS) Strategy

For advanced users, implement GFS rotation:

```bash
# Daily: Keep 7 days
# Weekly: Keep 4 weeks (every Sunday)
# Monthly: Keep 12 months (first of month)

# Script to implement GFS (add to cron)
# See ADVANCED_BACKUP_STRATEGIES.md for full implementation
```

## Security Considerations

- Backup files contain **sensitive data** (passwords, API keys)
- Secure backup directory permissions:
  ```bash
  chmod 700 /opt/rpi-ha-dns-stack/backups/
  ```
- Consider encrypting backups for off-site storage:
  ```bash
  gpg --symmetric --cipher-algo AES256 backup.tar.gz
  ```
- Never commit backups to version control

## Support

For issues or questions:
- Check logs: `/opt/rpi-ha-dns-stack/backups/backup.log`
- GitHub Issues: [Report a problem](https://github.com/yorgosroussakis/rpi-ha-dns-stack/issues)
- Documentation: See VERSIONS.md for troubleshooting guide
cd /opt/rpi-ha-dns-stack/stacks/dns
docker compose down
cd /opt/rpi-ha-dns-stack/stacks/observability
docker compose down

# Extract backup
cd /opt/rpi-ha-dns-stack/stacks/backup
tar xzf backups/backup-YYYYMMDD-HHMMSS.tar.gz -C /

# Restart services
cd /opt/rpi-ha-dns-stack/stacks/dns
docker compose up -d
cd /opt/rpi-ha-dns-stack/stacks/observability
docker compose up -d
```

## Monitoring

Check backup logs:

```bash
docker logs backup
docker logs backup --tail 50
```

List backups:

```bash
ls -lh /opt/rpi-ha-dns-stack/stacks/backup/backups/
```

## Storage Requirements

Typical backup sizes:
- Pi-hole config: ~10-50 MB
- Prometheus (30 days): ~1-5 GB
- Grafana: ~10-100 MB

Total: ~1-6 GB per backup

With 7-day retention: ~7-42 GB storage needed
