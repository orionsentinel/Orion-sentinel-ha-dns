# Complete Automation Guide - Zero-Touch Operation

## Overview

This deployment includes **complete automation** for all maintenance tasks. Once deployed, the system runs autonomously with **zero manual intervention required**.

## ✅ What's Automated

### 1. Blocklist Updates (Daily)
- **Service:** `pihole-auto-update`
- **Frequency:** Every 24 hours (configurable)
- **What it does:**
  - Updates gravity database with latest blocklists
  - Verifies domain counts
  - Logs all updates
  - **Automatically restarts if it fails**

### 2. Configuration Sync (Every 5 minutes)
- **Service:** `pihole-sync`
- **Frequency:** Every 5 minutes (configurable)
- **What it does:**
  - Syncs Pi-hole configurations between instances
  - Syncs custom DNS records
  - Syncs CNAME records
  - Syncs FTL configuration
  - **Automatically restarts if it fails**

### 3. Automated Backups (Daily)
- **Service:** `pihole-auto-backup`
- **Frequency:** Every 24 hours (configurable)
- **What it does:**
  - Creates timestamped backups of all Pi-hole data
  - Backs up gravity database
  - Backs up configurations
  - Rotates old backups (keeps 30 days)
  - **Automatically restarts if it fails**

### 4. Health Monitoring & Auto-Recovery (Every 60 seconds)
- **Service:** `health-monitor`
- **Frequency:** Continuous monitoring
- **What it does:**
  - Monitors all containers for health issues
  - Runs functional DNS tests
  - Automatically restarts failed containers
  - Tracks restart attempts (max 3 per cooldown period)
  - Sends alerts (if webhook configured)
  - **Self-healing system - requires no intervention**

## 🚀 One-Time Setup

### Step 1: Deploy Your Stack

```bash
# Navigate to your deployment directory
cd deployments/HighAvail_2Pi1P1U/node1  # or your chosen deployment

# Deploy
docker compose up -d
```

### Step 2: Wait for Initialization (60 seconds)

The system will:
1. Start all containers
2. Wait for Pi-hole to be ready
3. Automatically configure optimal blocklists
4. Automatically add essential whitelists
5. Start all automation services

### Step 3: Verify Automation (Optional)

```bash
# Check all automation services are running
docker ps | grep -E "auto-update|auto-backup|health-monitor|sync"

# Should show 4 automation containers running
```

**That's it!** Everything else happens automatically.

## 📊 Monitoring (Optional)

### View Real-Time Logs

```bash
# Auto-update logs
docker logs -f pihole-auto-update

# Auto-backup logs
docker logs -f pihole-auto-backup

# Health monitor (shows dashboard every 10 minutes)
docker logs -f health-monitor

# Configuration sync logs
docker logs -f pihole-sync
```

### Check Backup Status

```bash
# List all backups
ls -lh ./backups/

# View latest backup info
tar -tzf ./backups/pihole_primary_*.tar.gz | head -20
```

### Check Health Status

The health monitor automatically displays a dashboard every 10 minutes showing:
- ✓ Healthy containers (green)
- ⚠ Unhealthy containers (yellow)
- ✗ Stopped containers (red)
- Restart attempt counts

## 🔧 Configuration Options

All automation services can be configured via environment variables in `.env`:

```bash
# Blocklist update interval (seconds)
UPDATE_INTERVAL=86400  # 24 hours (default)
# Options: 43200 (12h), 86400 (24h), 172800 (48h)

# Backup interval (seconds)
BACKUP_INTERVAL=86400  # 24 hours (default)

# Backup retention (days)
RETENTION_DAYS=30  # Keep 30 days of backups (default)

# Configuration sync interval (seconds)
SYNC_INTERVAL=300  # 5 minutes (default)

# Health check interval (seconds)
HEALTH_CHECK_INTERVAL=60  # 1 minute (default)

# Max restart attempts before giving up
MAX_RESTART_ATTEMPTS=3  # Default

# Cooldown between restart attempts (seconds)
RESTART_COOLDOWN=300  # 5 minutes (default)

# Test domain for functional tests
TEST_DOMAIN=google.com  # Default
```

**Apply changes:**
```bash
# Edit .env file
nano .env

# Restart affected services
docker compose up -d
```

## 🎯 What Happens Automatically

### Daily at 2 AM (approximately)

1. **Blocklist Update** runs
   - Downloads latest blocklists
   - Updates gravity database
   - Logs: "Update cycle complete: X succeeded, Y failed"

2. **Backup** runs
   - Creates compressed backup
   - Rotates old backups
   - Logs: "Backup completed: X succeeded, Y failed"

### Every 5 Minutes

3. **Configuration Sync** runs
   - Syncs Pi-hole settings between instances
   - Ensures consistency
   - Logs: "Sync completed!"

### Every 60 Seconds

4. **Health Monitor** checks
   - Tests DNS resolution
   - Verifies Pi-hole status
   - Checks database integrity
   - Auto-restarts failed containers
   - Logs any issues detected

### On Container Failure

5. **Auto-Recovery** triggers
   - Health monitor detects failure
   - Waits for cooldown period (if previous restart)
   - Restarts container
   - Verifies recovery with functional tests
   - Logs recovery status
   - Sends alert (if configured)

## 🛡️ Failure Scenarios & Responses

### Scenario 1: Blocklist Update Fails

**What happens:**
1. Health monitor detects update service stopped
2. Automatically restarts `pihole-auto-update` container
3. Next scheduled update runs normally
4. No manual intervention needed

### Scenario 2: Pi-hole Container Crashes

**What happens:**
1. Health monitor detects DNS resolution failure
2. Automatically restarts Pi-hole container (attempt 1/3)
3. Waits 10 seconds for stabilization
4. Runs functional tests to verify recovery
5. If healthy: resets restart counter
6. If still unhealthy: waits 5 minutes, then retry (attempt 2/3)
7. Logs all actions

### Scenario 3: Database Corruption

**What happens:**
1. Health monitor detects database integrity failure
2. Restarts affected Pi-hole
3. If sync is running: secondary's database is synced
4. If both corrupted: restore from latest backup
5. Automatic recovery or logged for review

### Scenario 4: Network Partition (Multi-Node)

**What happens:**
1. Keepalived detects peer node unreachable
2. BACKUP node promotes to MASTER
3. VIP moves to healthy node
4. DNS continues working
5. When network recovers: original MASTER reclaims VIP
6. All automatic, no intervention needed

### Scenario 5: Multiple Concurrent Failures

**What happens:**
1. Health monitor processes each failure sequentially
2. Restarts containers one at a time
3. Respects cooldown periods
4. Max 3 restart attempts per container
5. After max attempts: logs critical alert
6. Sends webhook notification (if configured)

## 📈 Success Metrics

**The system is working correctly when:**

✅ All 4 automation containers are running:
```bash
$ docker ps | grep -E "auto-update|auto-backup|health-monitor|sync" | wc -l
4
```

✅ Daily backups are being created:
```bash
$ ls -1 ./backups/*.tar.gz | wc -l
30  # Or however many days of retention
```

✅ Blocklists are up-to-date:
```bash
$ docker logs pihole-auto-update | tail -5
[2024-11-16 02:00:15] Update cycle complete: 2 succeeded, 0 failed
```

✅ No restart loops:
```bash
$ docker logs health-monitor | grep "restart" | tail -10
# Should show isolated restarts, not continuous loops
```

✅ DNS resolution works:
```bash
$ dig @192.168.8.255 google.com +short
# Returns IP addresses
```

## 🔔 Alert Configuration (Optional)

To receive notifications when containers fail:

1. **Set up webhook** (Slack, Discord, etc.)

2. **Configure in `.env`:**
```bash
ALERT_WEBHOOK=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

3. **Restart health monitor:**
```bash
docker compose up -d health-monitor
```

**You'll receive alerts for:**
- Container failures
- Automatic restarts
- Max restart attempts reached
- Recovery successes

## 📝 Log Locations

All logs are stored in `./logs/` directory:

```
./logs/
├── pihole-auto-update.log     # Update logs
├── pihole-auto-backup.log     # Backup logs (not created yet, uses stdout)
└── health-monitor.log         # Health check logs (not created yet, uses stdout)
```

**View logs:**
```bash
# Real-time
docker logs -f pihole-auto-update
docker logs -f pihole-auto-backup
docker logs -f health-monitor

# Historical
docker logs --since 24h pihole-auto-update
docker logs --tail 100 health-monitor
```

## 🎓 Understanding the Automation

### Why These Intervals?

| Service | Interval | Reason |
|---------|----------|--------|
| Updates | 24 hours | Blocklists don't change more frequently |
| Backups | 24 hours | Daily snapshots sufficient for recovery |
| Sync | 5 minutes | Quick propagation of manual changes |
| Health | 60 seconds | Fast failure detection, low overhead |

### Resource Usage

All automation services are lightweight:

| Service | RAM | CPU | Impact |
|---------|-----|-----|--------|
| pihole-auto-update | ~30MB | <1% | Minimal (sleeps most of time) |
| pihole-auto-backup | ~30MB | <1% | Minimal (sleeps most of time) |
| pihole-sync | ~30MB | <1% | Minimal (sleeps most of time) |
| health-monitor | ~50MB | <2% | Very low (efficient checks) |

**Total overhead: ~140MB RAM, <5% CPU**

## ❓ FAQ

**Q: Do I need to run any commands after deployment?**  
A: No. Everything is automatic. Just deploy and forget.

**Q: How do I know if automation is working?**  
A: Check logs or look for daily backups in `./backups/` directory.

**Q: Can I disable a specific automation?**  
A: Yes. Stop the container: `docker stop pihole-auto-update` (or whichever service).

**Q: What if I want manual control?**  
A: You can always trigger manually:
```bash
# Manual update
docker exec pihole-auto-update bash /auto-update.sh --once

# Manual backup
docker exec pihole-auto-backup bash /auto-backup.sh --once

# Manual sync
docker exec pihole-sync bash /sync.sh --once
```

**Q: How do I restore from backup?**  
A: See BACKUP_RESTORATION.md for detailed steps.

**Q: Can I change intervals?**  
A: Yes. Edit `.env`, then `docker compose up -d` to apply.

**Q: What if max restart attempts are reached?**  
A: Check logs to diagnose issue, fix root cause, then restart container manually to reset counter.

**Q: Do I need to update blocklists manually?**  
A: No. They update automatically every 24 hours.

**Q: Do I need to backup manually?**  
A: No. Backups happen automatically every 24 hours.

**Q: Do I need to sync configurations?**  
A: No. Sync happens automatically every 5 minutes.

## 🎉 Summary

**You only need to:**
1. Deploy once: `docker compose up -d`
2. Optionally monitor: `docker logs -f health-monitor`

**Everything else is automatic:**
- ✅ Updates run daily
- ✅ Backups run daily
- ✅ Sync runs every 5 minutes
- ✅ Health checks run every minute
- ✅ Failed containers restart automatically
- ✅ Functional tests verify everything works
- ✅ Old backups are cleaned up automatically

**Truly zero-touch operation!** 🚀
