# Backup and Migration Guide

Comprehensive guide for backing up, restoring, and migrating Orion Sentinel DNS HA configurations.

## Overview

Regular backups protect against:
- Hardware failure (SD card corruption, Pi failure)
- Accidental configuration changes
- Failed upgrades
- Disaster scenarios

This guide covers:
- Automated and manual backups
- Configuration restoration
- Migration to new hardware
- Disaster recovery scenarios

## What Gets Backed Up

### Configuration Files
- `.env` - Environment variables and settings
- `docker-compose*.yml` - Stack definitions
- `keepalived.conf` - HA configuration
- `unbound.conf` - DNS resolver settings
- Security profiles - DNS filtering rules

### Pi-hole Data
- Gravity database - Blocklists and domains
- Custom DNS records - Local domain mappings
- DHCP leases (if using Pi-hole DHCP)
- Query history - Recent DNS queries
- Whitelist/Blacklist - Custom rules
- Group assignments - Client-specific filtering

### Monitoring Data
- Prometheus configuration - Scrape targets and rules
- Grafana dashboards - Visualization configs
- Alert rules - Notification triggers

### Not Backed Up
- Docker images - Can be re-downloaded
- Prometheus metrics data - Time-series data (too large)
- Log files - Can be archived separately if needed
- Temporary files

## Automated Backups

### Using the Backup Script

Run the automated backup script:

```bash
# Create a backup
bash scripts/backup-config.sh

# Backup is created in backups/ directory
ls -lh backups/
# dns-ha-backup-20231120_143022.tar.gz
# dns-ha-backup-20231120_143022.tar.gz.sha256
```

**What the script does:**
1. Creates timestamped backup directory
2. Copies all configuration files
3. Exports Pi-hole databases from containers
4. Backs up monitoring configurations
5. Creates compressed tar archive
6. Generates SHA256 checksum
7. Optionally cleans up old backups

### Scheduled Automatic Backups

Add to crontab for regular backups:

```bash
# Edit crontab
crontab -e

# Add weekly backup (Sundays at 2 AM)
0 2 * * 0 /opt/rpi-ha-dns-stack/scripts/backup-config.sh

# Or daily backups at 3 AM
0 3 * * * /opt/rpi-ha-dns-stack/scripts/backup-config.sh

# Keep only last 10 backups
# Set environment variable before running
0 3 * * * KEEP_BACKUPS=10 /opt/rpi-ha-dns-stack/scripts/backup-config.sh
```

### Backup to Remote Storage

For disaster recovery, store backups remotely:

**Option 1: rsync to NAS**
```bash
#!/bin/bash
# backup-to-nas.sh

# Run backup
bash /opt/rpi-ha-dns-stack/scripts/backup-config.sh

# Copy to NAS
rsync -avz /opt/rpi-ha-dns-stack/backups/ \
    user@nas.local:/backups/dns-ha/

# Keep only recent backups locally
find /opt/rpi-ha-dns-stack/backups/ -name "*.tar.gz" -mtime +7 -delete
```

**Option 2: Upload to cloud (rclone)**
```bash
#!/bin/bash
# backup-to-cloud.sh

# Run backup
bash /opt/rpi-ha-dns-stack/scripts/backup-config.sh

# Upload to cloud (configure rclone first)
LATEST_BACKUP=$(ls -t /opt/rpi-ha-dns-stack/backups/*.tar.gz | head -1)
rclone copy "$LATEST_BACKUP" remote:dns-ha-backups/
```

**Option 3: Git repository**
```bash
#!/bin/bash
# backup-to-git.sh

cd /opt/rpi-ha-dns-stack

# Create backup
bash scripts/backup-config.sh

# Commit to Git
git add backups/*.tar.gz
git commit -m "Automated backup $(date +%Y-%m-%d)"
git push origin main
```

## Manual Backups

### Quick Manual Backup

Before making major changes:

```bash
# Quick backup of critical files
cd /opt/rpi-ha-dns-stack
tar czf manual-backup-$(date +%Y%m%d).tar.gz \
    .env \
    stacks/dns/docker-compose.yml \
    stacks/dns/keepalived/*.conf \
    stacks/dns/unbound/*.conf
```

### Export Pi-hole Settings

Backup Pi-hole via admin interface:

1. Open Pi-hole admin: http://192.168.8.251/admin
2. Navigate to **Settings > Teleporter**
3. Click **Backup** button
4. Save the `.tar.gz` file locally
5. Repeat for secondary Pi-hole (192.168.8.252)

### Backup Docker Volumes

For complete data backup:

```bash
# Backup Pi-hole primary volume
docker run --rm \
    -v pihole_primary:/data \
    -v $(pwd)/backups:/backup \
    alpine tar czf /backup/pihole-primary-volume.tar.gz /data

# Backup Pi-hole secondary volume
docker run --rm \
    -v pihole_secondary:/data \
    -v $(pwd)/backups:/backup \
    alpine tar czf /backup/pihole-secondary-volume.tar.gz /data
```

## Restoration

### Full Restore from Backup

Restore complete configuration:

```bash
# Copy backup file to target system
scp backups/dns-ha-backup-20231120_143022.tar.gz \
    pi@new-pi:/tmp/

# SSH to target system
ssh pi@new-pi

# Run restore script
cd /opt/rpi-ha-dns-stack
bash scripts/restore-config.sh /tmp/dns-ha-backup-20231120_143022.tar.gz

# Review what will be restored
bash scripts/restore-config.sh /tmp/dns-ha-backup-20231120_143022.tar.gz --dry-run

# Restore everything
bash scripts/restore-config.sh /tmp/dns-ha-backup-20231120_143022.tar.gz

# Restart services
docker compose down
docker compose up -d
```

### Selective Restore

Restore only specific components:

```bash
# Skip Pi-hole data restoration
bash scripts/restore-config.sh backup.tar.gz --skip-pihole

# Skip docker-compose files
bash scripts/restore-config.sh backup.tar.gz --skip-compose

# Restore to running containers
# Pi-hole data will be restored to running containers
bash scripts/restore-config.sh backup.tar.gz
```

### Restore Pi-hole Only

If you only need to restore Pi-hole data:

```bash
# Extract backup
tar xzf dns-ha-backup-20231120_143022.tar.gz

# Find Pi-hole backup
cd dns-ha-backup-20231120_143022/pihole/

# Restore to container
docker cp primary-config.tar.gz pihole_primary:/tmp/
docker exec pihole_primary tar xzf /tmp/primary-config.tar.gz -C /
docker exec pihole_primary pihole -g

# Restart container
docker restart pihole_primary
```

## Migration Scenarios

### Migrate to New SD Card

**Scenario**: SD card is failing, need to migrate to new card

**Steps:**

1. **Prepare new SD card**
   ```bash
   # Flash Raspberry Pi OS to new SD card
   # Use Raspberry Pi Imager or dd command
   ```

2. **Install Docker on new system**
   ```bash
   curl -fsSL https://get.docker.com | sh
   sudo usermod -aG docker $USER
   ```

3. **Clone repository**
   ```bash
   git clone https://github.com/yourusername/rpi-ha-dns-stack.git
   cd rpi-ha-dns-stack
   ```

4. **Copy backup from old system**
   ```bash
   # From new system
   scp pi@old-pi:/opt/rpi-ha-dns-stack/backups/latest.tar.gz ./backups/
   ```

5. **Restore configuration**
   ```bash
   bash scripts/restore-config.sh backups/latest.tar.gz
   ```

6. **Update IP addresses if needed**
   ```bash
   # Edit .env if Pi IP changed
   nano .env
   # Update HOST_IP, network settings, etc.
   ```

7. **Deploy stack**
   ```bash
   docker compose up -d
   ```

8. **Verify operation**
   ```bash
   docker ps
   dig @192.168.8.255 google.com
   ```

### Migrate to New Raspberry Pi

**Scenario**: Upgrading from Pi 4 to Pi 5, or replacing failed Pi

**Steps:**

1. **Create backup on old Pi**
   ```bash
   bash scripts/backup-config.sh
   ```

2. **Setup new Pi** (as above)

3. **Transfer backup**
   ```bash
   # Copy via network
   scp pi@old-pi:/opt/rpi-ha-dns-stack/backups/latest.tar.gz ./

   # Or use USB stick
   # Copy to USB on old Pi, then copy from USB to new Pi
   ```

4. **Restore and deploy**
   ```bash
   bash scripts/restore-config.sh latest.tar.gz
   docker compose up -d
   ```

5. **Update Keepalived VIP if needed**
   - If using multi-Pi HA, update `keepalived.conf` priority
   - Ensure new Pi has correct role (MASTER/BACKUP)

6. **Test failover**
   ```bash
   # Simulate failure of other node
   # Verify VIP moves to new Pi
   ```

### Migrate to Different Network

**Scenario**: Moving DNS stack to different network or IP range

**Steps:**

1. **Create backup** (as usual)

2. **Restore on new network**

3. **Update all IP addresses in `.env`**
   ```bash
   nano .env
   
   # Update these variables:
   HOST_IP=192.168.1.250           # New network
   PIHOLE_PRIMARY_IP=192.168.1.251
   PIHOLE_SECONDARY_IP=192.168.1.252
   UNBOUND_PRIMARY_IP=192.168.1.253
   UNBOUND_SECONDARY_IP=192.168.1.254
   VIP_ADDRESS=192.168.1.255
   SUBNET=192.168.1.0/24
   GATEWAY=192.168.1.1
   ```

4. **Recreate Docker networks**
   ```bash
   # Remove old network
   docker network rm dns_net
   
   # Recreate with new subnet
   docker network create -d macvlan \
       --subnet=192.168.1.0/24 \
       --gateway=192.168.1.1 \
       --ip-range=192.168.1.250/29 \
       -o parent=eth0 dns_net
   ```

5. **Redeploy stack**
   ```bash
   docker compose down
   docker compose up -d
   ```

6. **Update router DNS settings** to point to new VIP

## Disaster Recovery

### Complete System Loss

**Scenario**: Pi destroyed, SD card unreadable, total loss

**Recovery (assuming you have remote backup):**

1. **Acquire new hardware**
2. **Flash new SD card with Raspberry Pi OS**
3. **Install Docker and Git**
4. **Clone repository**
5. **Download backup from remote storage**
   ```bash
   # From NAS
   rsync -avz user@nas.local:/backups/dns-ha/latest.tar.gz ./backups/
   
   # From cloud
   rclone copy remote:dns-ha-backups/latest.tar.gz ./backups/
   ```
6. **Restore and deploy**
7. **Update router to use new VIP**

**Expected downtime:** 30-60 minutes

### Corrupted Configuration

**Scenario**: Made bad changes, system not working

**Recovery:**

```bash
# Stop services
docker compose down

# Restore from latest backup
bash scripts/restore-config.sh backups/latest.tar.gz

# Restart services
docker compose up -d
```

### Failed Upgrade

**Scenario**: Upgrade script failed, system in inconsistent state

**Recovery:**

```bash
# The smart-upgrade script creates automatic backup
# Find the pre-upgrade backup
ls -lt backups/ | grep pre-upgrade

# Restore it
bash scripts/restore-config.sh backups/pre-upgrade-backup-*.tar.gz

# Redeploy
docker compose down
docker compose up -d
```

## Backup Verification

### Test Your Backups Regularly

Don't wait for disaster to find out backups are corrupt:

```bash
# Monthly backup verification
# 1. Extract to temporary location
mkdir /tmp/backup-test
tar xzf backups/latest.tar.gz -C /tmp/backup-test

# 2. Verify checksum
sha256sum -c backups/latest.tar.gz.sha256

# 3. Check contents
cat /tmp/backup-test/*/backup-info.txt

# 4. Verify critical files exist
test -f /tmp/backup-test/*/.env && echo "✅ .env present"
test -f /tmp/backup-test/*/pihole/primary-config.tar.gz && echo "✅ Pi-hole backup present"

# 5. Cleanup
rm -rf /tmp/backup-test
```

### Restore Test (Quarterly)

Full restore test in isolated environment:

1. Create test VM or use spare Pi
2. Restore from backup
3. Verify all services start
4. Test DNS resolution
5. Check dashboard access
6. Verify settings are correct

## Backup Best Practices

1. **Backup frequency**
   - Daily: If making frequent changes
   - Weekly: For stable setups
   - Before/after: Any major changes or upgrades

2. **Retention policy**
   - Keep last 10 local backups
   - Keep last 30 remote backups
   - Keep monthly backups for 1 year

3. **Storage locations**
   - Local: Fast recovery
   - NAS: Network disaster protection
   - Cloud: Site disaster protection
   - Multiple copies: Follow 3-2-1 rule

4. **Backup validation**
   - Verify checksums monthly
   - Test restore quarterly
   - Document restore procedures

5. **Security**
   - Encrypt sensitive backups
   - Restrict backup file permissions
   - Store credentials separately

## Backup Encryption (Optional)

For sensitive environments:

```bash
# Encrypt backup
gpg --symmetric --cipher-algo AES256 backups/latest.tar.gz

# Decrypt for restore
gpg --decrypt backups/latest.tar.gz.gpg > backups/latest.tar.gz
```

## Troubleshooting

### Backup Script Fails

**Error**: "Cannot backup Pi-hole container"

**Solution**: Ensure containers are running
```bash
docker ps | grep pihole
docker start pihole_primary pihole_secondary
```

### Restore Fails with Permission Errors

**Error**: "Permission denied"

**Solution**: Run with sudo or fix ownership
```bash
sudo bash scripts/restore-config.sh backup.tar.gz
# Or fix permissions
sudo chown -R $USER:$USER /opt/rpi-ha-dns-stack
```

### Backup File Corrupted

**Error**: Checksum verification fails

**Solution**: Use older backup
```bash
# List backups by date
ls -lt backups/

# Try previous backup
bash scripts/restore-config.sh backups/dns-ha-backup-PREVIOUS.tar.gz
```

## See Also

- [Health and HA Guide](health-and-ha.md) - Preventing failures
- [Smart Upgrade Guide](../SMART_UPGRADE_GUIDE.md) - Safe upgrades
- [Disaster Recovery](../DISASTER_RECOVERY.md) - Emergency procedures
- [Operational Runbook](../OPERATIONAL_RUNBOOK.md) - Day-to-day operations
