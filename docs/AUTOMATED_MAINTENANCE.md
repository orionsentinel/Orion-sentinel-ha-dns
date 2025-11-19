# Automated Maintenance Setup Guide

## Overview

The RPi HA DNS Stack includes automated health checks and maintenance tasks that run weekly. This guide explains how to set up and manage these automated tasks.

## Quick Setup

### Automatic Setup (During Installation)

When you run the installation script (`bash scripts/setup.sh`), you'll be prompted to set up automated maintenance. Simply answer "Y" when asked:

```
Set up automated cron jobs? (Y/n): Y
```

The setup script will automatically:
- Configure weekly health checks
- Configure weekly maintenance tasks
- Set up log directories
- Configure log rotation
- Make a backup of your existing crontab

### Manual Setup (Post-Installation)

If you skipped the automated setup or want to reconfigure:

```bash
sudo bash scripts/setup-cron.sh
```

This script:
1. Backs up your existing crontab
2. Adds cron jobs for health checks and maintenance
3. Creates log directories with proper permissions
4. Sets up log rotation
5. Makes scripts executable

## What Gets Automated

### Weekly Health Check (Sundays at 2 AM)

**Script**: `scripts/health-check.sh`

**What it does**:
- Tests DNS resolution (VIP and both Pi-holes)
- Checks service health (all containers)
- Verifies HA status (Keepalived, VIP location)
- Monitors disk space usage
- Monitors memory usage
- Checks container health status
- Validates Prometheus metrics endpoint

**Log location**: `/var/log/rpi-dns/health-check.log`

### Weekly Maintenance (Sundays at 3 AM)

**Script**: `scripts/weekly-maintenance.sh`

**What it does**:
- Updates container images (pulls latest)
- Cleans old logs (>30 days)
- Checks disk space and cleans if needed
- Backs up configuration files (.env, docker-compose.yml)
- Generates health report
- Cleans Docker system (removes unused images/containers)
- Removes old backups (>90 days)

**Log location**: `/var/log/rpi-dns/maintenance.log`

## Viewing Scheduled Tasks

```bash
# View all cron jobs
crontab -l

# View only RPi DNS Stack jobs
crontab -l | grep -A 2 "RPi HA DNS Stack"
```

## Viewing Logs

```bash
# View health check log
tail -f /var/log/rpi-dns/health-check.log

# View maintenance log
tail -f /var/log/rpi-dns/maintenance.log

# View last 50 lines of health check
tail -50 /var/log/rpi-dns/health-check.log

# View last week's maintenance runs
grep "Weekly Maintenance" /var/log/rpi-dns/maintenance.log
```

## Running Tasks Manually

You can run these tasks manually at any time:

```bash
# Run health check now
bash scripts/health-check.sh

# Run maintenance now
bash scripts/weekly-maintenance.sh

# View output in real-time
bash scripts/health-check.sh 2>&1 | tee health-check-manual.log
```

## Customizing the Schedule

### Edit Cron Schedule

```bash
# Edit crontab
crontab -e

# Default schedule:
0 2 * * 0  # Sundays at 2:00 AM (health check)
0 3 * * 0  # Sundays at 3:00 AM (maintenance)
```

### Common Schedule Patterns

```bash
# Daily at 2 AM
0 2 * * *

# Every Monday at 3 AM
0 3 * * 1

# First day of month at 4 AM
0 4 1 * *

# Every 6 hours
0 */6 * * *

# Twice per week (Tuesday and Friday at 2 AM)
0 2 * * 2,5
```

### Cron Format Explained

```
┌─── minute (0 - 59)
│ ┌─── hour (0 - 23)
│ │ ┌─── day of month (1 - 31)
│ │ │ ┌─── month (1 - 12)
│ │ │ │ ┌─── day of week (0 - 7, Sunday=0 or 7)
│ │ │ │ │
* * * * * command to execute
```

## Disabling Automation

### Temporarily Disable

```bash
# Comment out the cron jobs
crontab -e

# Add # at the beginning of each line:
# 0 2 * * 0 /opt/rpi-ha-dns-stack/scripts/health-check.sh...
# 0 3 * * 0 /opt/rpi-ha-dns-stack/scripts/weekly-maintenance.sh...
```

### Permanently Remove

```bash
# Edit crontab
crontab -e

# Delete the RPi HA DNS Stack section entirely
```

## Troubleshooting

### Cron Jobs Not Running

1. **Check if cron service is running**:
   ```bash
   sudo systemctl status cron
   ```

2. **Check crontab is installed**:
   ```bash
   crontab -l
   ```

3. **Check script permissions**:
   ```bash
   ls -l scripts/health-check.sh scripts/weekly-maintenance.sh
   # Both should be executable (x flag)
   ```

4. **Check log files for errors**:
   ```bash
   tail -100 /var/log/rpi-dns/health-check.log
   tail -100 /var/log/rpi-dns/maintenance.log
   ```

5. **Check cron log**:
   ```bash
   grep CRON /var/log/syslog | tail -20
   ```

### Scripts Fail to Execute

1. **Check paths in crontab**:
   ```bash
   crontab -l
   # Verify paths are absolute and correct
   ```

2. **Test script manually**:
   ```bash
   bash scripts/health-check.sh
   # Fix any errors that appear
   ```

3. **Check file permissions**:
   ```bash
   chmod +x scripts/health-check.sh
   chmod +x scripts/weekly-maintenance.sh
   ```

### No Logs Generated

1. **Check log directory exists**:
   ```bash
   ls -ld /var/log/rpi-dns/
   ```

2. **Create if missing**:
   ```bash
   sudo mkdir -p /var/log/rpi-dns
   sudo chown $USER:$USER /var/log/rpi-dns
   ```

3. **Check disk space**:
   ```bash
   df -h /var/log
   ```

## Log Rotation

Log rotation is automatically configured at `/etc/logrotate.d/rpi-dns`:

```
/var/log/rpi-dns/*.log {
    weekly
    rotate 12
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}
```

This keeps 12 weeks (3 months) of compressed logs.

## Email Notifications (Optional)

To receive email notifications from cron jobs:

1. **Install mail utilities**:
   ```bash
   sudo apt-get install mailutils
   ```

2. **Configure in crontab**:
   ```bash
   crontab -e
   
   # Add at top:
   MAILTO=your-email@example.com
   
   # Cron will email any output
   ```

3. **Or use a custom notification script**:
   ```bash
   # In crontab:
   0 2 * * 0 /path/to/script.sh && mail -s "Health Check Success" you@example.com
   ```

## Best Practices

1. **Monitor Initially**: Check logs weekly for the first month to ensure everything works
2. **Review Reports**: Monthly review of health reports in `/opt/rpi-dns-backups/reports/`
3. **Test Manually**: Run scripts manually after any configuration changes
4. **Keep Backups**: The script backs up crontab automatically, but keep your own backup too
5. **Adjust Schedule**: If your Pi is busy at 2-3 AM, change the schedule to off-peak hours

## Advanced Configuration

### Running as Different User

```bash
# Edit root's crontab
sudo crontab -e

# Or edit specific user's crontab
sudo crontab -u username -e
```

### Multiple Schedules

```bash
# Health check twice per week
0 2 * * 0,3 /opt/rpi-ha-dns-stack/scripts/health-check.sh

# Maintenance weekly
0 3 * * 0 /opt/rpi-ha-dns-stack/scripts/weekly-maintenance.sh

# Quick health check daily (without full report)
0 6 * * * /opt/rpi-ha-dns-stack/scripts/health-check.sh --quick
```

## Uninstalling

To completely remove cron automation:

```bash
# Remove cron jobs
crontab -e
# Delete the RPi HA DNS Stack section

# Remove log directory
sudo rm -rf /var/log/rpi-dns

# Remove logrotate config
sudo rm /etc/logrotate.d/rpi-dns

# Restore from backup if needed
crontab < ~/.crontab.backup.YYYYMMDD_HHMMSS
```

## Support

If you encounter issues:
1. Check the logs: `/var/log/rpi-dns/`
2. Run scripts manually to identify errors
3. Check cron service: `sudo systemctl status cron`
4. Review [TROUBLESHOOTING.md](../TROUBLESHOOTING.md)
5. Open an issue on GitHub

---

**Related Documentation**:
- [OPERATIONAL_RUNBOOK.md](../OPERATIONAL_RUNBOOK.md) - Day-to-day operations
- [DISASTER_RECOVERY.md](../DISASTER_RECOVERY.md) - Recovery procedures
- [README.md](../README.md) - Main documentation
