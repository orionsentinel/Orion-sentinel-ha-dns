# Backup Stack

Automated daily backups for all critical data.

## What Gets Backed Up

- Pi-hole primary configuration and databases
- Pi-hole secondary configuration and databases
- Prometheus metrics data
- Grafana dashboards and data

## Configuration

Copy `.env.example` to `.env` and adjust settings:

```bash
cp .env.example .env
nano .env
```

### Environment Variables

- `TZ`: Timezone for backup timestamps (default: UTC)
- `BACKUP_RETENTION_DAYS`: How many days to keep old backups (default: 7)

## Deployment

```bash
cd /opt/rpi-ha-dns-stack/stacks/backup
cp .env.example .env
docker compose up -d
```

## Backup Schedule

- Backups run automatically every 24 hours
- Backup files are stored in `./backups/` directory
- Old backups are automatically deleted after retention period

## Backup Format

Backup files are named: `backup-YYYYMMDD-HHMMSS.tar.gz`

Example: `backup-20251115-120000.tar.gz`

## Manual Backup

To trigger a manual backup:

```bash
docker exec backup sh -c "tar czf /backups/manual-$(date +%Y%m%d-%H%M%S).tar.gz /pihole1 /pihole2 /prometheus /grafana"
```

## Restore from Backup

```bash
# Stop services
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
