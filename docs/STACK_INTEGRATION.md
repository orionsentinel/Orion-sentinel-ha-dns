# Stack Integration Guide

## Overview

This guide explains how Orion Sentinel DNS HA integrates with other components of the Orion Sentinel ecosystem and external services. The architecture is designed for maximum resilience, ease of installation, and seamless integration.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       Orion Sentinel Ecosystem                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                    DNS HA Stack (This Repo)                       │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │  │
│  │  │ Pi-hole Pri │  │ Pi-hole Sec │  │ Sync & Self-Heal        │  │  │
│  │  │   + Unbound │  │   + Unbound │  │ Services                │  │  │
│  │  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────────┘  │  │
│  │         │                 │                    │                 │  │
│  │         └────────┬────────┘                    │                 │  │
│  │                  ▼                             ▼                 │  │
│  │         ┌────────────────┐            ┌───────────────┐         │  │
│  │         │  Keepalived    │            │ Backup Sync   │         │  │
│  │         │  VIP Manager   │            │ (to peer/NAS) │         │  │
│  │         └────────┬───────┘            └───────────────┘         │  │
│  │                  │                                               │  │
│  └──────────────────┼───────────────────────────────────────────────┘  │
│                     │                                                   │
│        VIP: 192.168.8.255                                              │
│                     │                                                   │
│  ┌──────────────────┼───────────────────────────────────────────────┐  │
│  │                  ▼           NSM/AI Pi                            │  │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │  │
│  │  │ Suricata IDS    │  │ Loki + Grafana  │  │ AI Detection    │  │  │
│  │  │                 │  │ (receives DNS   │  │ (scores domains)│  │  │
│  │  │                 │  │  logs)          │  │                 │  │  │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘  │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                     CoreSrv (Optional)                            │  │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │  │
│  │  │ Prometheus      │  │ Grafana SPoG    │  │ Alertmanager    │  │  │
│  │  │ (metrics)       │  │ (dashboards)    │  │ (notifications) │  │  │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘  │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Integration Points

### 1. Multi-Node Synchronization

The DNS HA stack supports automatic synchronization between primary and secondary nodes.

#### Configuration

```bash
# In .env file
NODE_ROLE=primary          # or 'secondary'
PEER_IP=192.168.8.12       # IP of the peer node
SYNC_SSH_USER=pi
SYNC_INTERVAL=300          # Sync every 5 minutes
```

#### What Gets Synced

| Data | Direction | Frequency |
|------|-----------|-----------|
| Pi-hole gravity database | Primary → Secondary | Every 5 minutes |
| Custom DNS records | Primary → Secondary | Every 5 minutes |
| Whitelist/Blacklist | Primary → Secondary | Every 5 minutes |
| Unbound configuration | Bidirectional | On change |
| Security profiles | Primary → Secondary | On change |

#### Setup SSH for Sync

```bash
# On primary node
bash scripts/multi-node-sync.sh --setup

# This will:
# 1. Generate SSH key if needed
# 2. Copy public key to peer node
# 3. Test connectivity
```

#### Manual Sync Commands

```bash
# Push configuration to peer (from primary)
bash scripts/multi-node-sync.sh --push

# Pull configuration from peer (on secondary)
bash scripts/multi-node-sync.sh --pull

# Check sync status
bash scripts/multi-node-sync.sh --status

# Run as daemon
bash scripts/multi-node-sync.sh --daemon &
```

### 2. Automated Backup and Recovery

The stack includes comprehensive backup and sync capabilities.

#### Backup Configuration

```bash
# In .env file
BACKUP_DIR=/opt/rpi-ha-dns-stack/backups
BACKUP_RETENTION_DAYS=30
BACKUP_KEEP_COUNT=10
BACKUP_INTERVAL=86400      # Daily backups

# Off-site backup (optional)
OFFSITE_BACKUP_ENABLED=true
OFFSITE_TYPE=nas           # Options: nas, rclone, s3
NAS_HOST=nas.local
NAS_PATH=/backups/dns-ha
NAS_USER=backup
```

#### Backup Commands

```bash
# Create backup
bash scripts/automated-sync-backup.sh --backup

# Create backup and sync to peer
bash scripts/automated-sync-backup.sh --all

# Sync to off-site storage
bash scripts/automated-sync-backup.sh --offsite

# Verify backup integrity
bash scripts/automated-sync-backup.sh --verify

# Run as daemon for scheduled backups
bash scripts/automated-sync-backup.sh --daemon &
```

#### Backup Locations

| Location | Purpose | Retention |
|----------|---------|-----------|
| Local | Quick recovery | Last 10 backups |
| Peer Node | Hardware failure | Last 10 backups |
| NAS/Cloud | Site disaster | 30 days |

### 3. Self-Healing and Resilience

The self-healing service monitors all DNS services and automatically recovers from failures.

#### Configuration

```bash
# In .env file
HEALTH_CHECK_INTERVAL=60   # Check every minute
MAX_RESTART_ATTEMPTS=3     # Before circuit breaker trips
RESTART_COOLDOWN=300       # Seconds between restart attempts
CIRCUIT_BREAKER_TIMEOUT=300 # Seconds before circuit breaker resets
```

#### Circuit Breaker Pattern

The self-healing service implements a circuit breaker pattern to prevent cascading failures:

1. **Closed** (Normal): Service is healthy, failures are counted
2. **Open** (Tripped): Too many failures, no restart attempts
3. **Half-Open** (Recovery): After timeout, allow one restart attempt

```
┌──────────────────────────────────────────────────────────────┐
│                  Circuit Breaker States                       │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│   ┌─────────┐   Failure    ┌─────────┐   Timeout   ┌────────┐│
│   │         │ ──────────►  │         │ ──────────► │        ││
│   │ CLOSED  │              │  OPEN   │             │ HALF-  ││
│   │         │ ◄────────    │         │ ◄────────── │ OPEN   ││
│   └─────────┘   Success    └─────────┘   Failure   └────────┘│
│        ▲                                      │               │
│        │              Success                 │               │
│        └──────────────────────────────────────┘               │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

#### Self-Heal Commands

```bash
# Check service status
bash scripts/self-heal.sh --status

# Run single health check
bash scripts/self-heal.sh --once

# Restart specific service
bash scripts/self-heal.sh --restart pihole_primary

# Reset all circuit breakers
bash scripts/self-heal.sh --reset

# Run as daemon
bash scripts/self-heal.sh --daemon &
```

### 4. NSM/AI Integration

The DNS stack exposes logs and APIs for integration with the NSM/AI Pi.

#### Log Shipping to Loki

```bash
# In .env file
LOKI_URL=http://192.168.8.100:3100
```

Deploy Promtail agent:
```bash
docker compose -f stacks/agents/pi-dns/docker-compose.yml up -d
```

#### Pi-hole API for Blocking

The NSM/AI Pi can use the Pi-hole API to block suspicious domains:

```bash
# Block a domain
curl -X POST "http://192.168.8.251/admin/api.php?list=black&add=malicious.example.com"

# Unblock a domain
curl -X POST "http://192.168.8.251/admin/api.php?list=white&add=safe.example.com"
```

### 5. CoreSrv Integration (Single Pane of Glass)

For centralized monitoring, the stack exports metrics to CoreSrv.

#### Metrics Exporters

| Exporter | Port | Metrics |
|----------|------|---------|
| Node Exporter | 9100 | System metrics |
| Pi-hole Exporter | 9617 | DNS queries, blocking stats |
| Unbound Exporter | 9167 | Cache stats, query rates |

#### Prometheus Scrape Configuration

Add to CoreSrv's prometheus.yml:
```yaml
scrape_configs:
  - job_name: 'dns-pi-1'
    static_configs:
      - targets: ['192.168.8.250:9100', '192.168.8.250:9617', '192.168.8.250:9167']
  
  - job_name: 'dns-pi-2'
    static_configs:
      - targets: ['192.168.8.251:9100', '192.168.8.251:9617', '192.168.8.251:9167']
```

### 6. Pre-Flight Validation

Before deployment, validate the system is ready:

```bash
# Run comprehensive pre-flight check
bash scripts/pre-flight-check.sh

# Run with automatic fixes
bash scripts/pre-flight-check.sh --fix

# Quick check (skip optional tests)
bash scripts/pre-flight-check.sh --quick

# JSON output for automation
bash scripts/pre-flight-check.sh --json
```

#### Checks Performed

| Category | Checks |
|----------|--------|
| Operating System | Linux, architecture, Raspberry Pi detection |
| Resources | RAM, disk space, CPU cores |
| Docker | Installation, daemon status, permissions |
| Network | Interface, internet, DNS resolution |
| Ports | Required ports availability |
| Configuration | .env file, docker-compose validity |
| Multi-Node | Peer connectivity, SSH setup |
| Security | Root user, firewall, SSH configuration |

## Deployment Profiles

### Single Node HA

Deploy all services on one Raspberry Pi:

```bash
cd stacks/dns
docker compose --profile single-pi-ha up -d
docker compose -f docker-compose.sync.yml --profile heal up -d
```

### Two Node HA

#### Primary Node (Pi1)

```bash
cd stacks/dns
docker compose --profile two-pi-ha-pi1 up -d
docker compose -f docker-compose.sync.yml --profile two-pi-ha-pi1 up -d
```

#### Secondary Node (Pi2)

```bash
cd stacks/dns
docker compose --profile two-pi-ha-pi2 up -d
docker compose -f docker-compose.sync.yml --profile two-pi-ha-pi2 up -d
```

## Environment Variables Reference

### Node Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `NODE_ROLE` | Node role: primary or secondary | primary |
| `NODE_IP` | IP address of this node | auto-detected |
| `PEER_IP` | IP address of peer node | - |

### Sync Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `SYNC_INTERVAL` | Seconds between syncs | 300 |
| `SYNC_SSH_USER` | SSH username for peer | pi |
| `SYNC_SSH_KEY` | Path to SSH private key | ~/.ssh/id_rsa |
| `SYNC_SSH_PORT` | SSH port | 22 |
| `REMOTE_REPO_PATH` | Repo path on peer | /opt/rpi-ha-dns-stack |

### Backup Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `BACKUP_DIR` | Local backup directory | ./backups |
| `BACKUP_RETENTION_DAYS` | Days to keep backups | 30 |
| `BACKUP_KEEP_COUNT` | Minimum backups to keep | 10 |
| `BACKUP_INTERVAL` | Seconds between backups | 86400 |

### Off-Site Backup

| Variable | Description | Default |
|----------|-------------|---------|
| `OFFSITE_BACKUP_ENABLED` | Enable off-site backup | false |
| `OFFSITE_TYPE` | Type: nas, rclone, s3 | - |
| `NAS_HOST` | NAS hostname/IP | - |
| `NAS_PATH` | NAS backup path | - |
| `NAS_USER` | NAS SSH user | - |
| `RCLONE_REMOTE` | rclone remote path | - |

### Self-Healing

| Variable | Description | Default |
|----------|-------------|---------|
| `HEALTH_CHECK_INTERVAL` | Seconds between checks | 60 |
| `MAX_RESTART_ATTEMPTS` | Attempts before circuit opens | 3 |
| `RESTART_COOLDOWN` | Seconds between restarts | 300 |
| `CIRCUIT_BREAKER_TIMEOUT` | Seconds before reset | 300 |

### Notifications

| Variable | Description | Default |
|----------|-------------|---------|
| `NOTIFICATION_WEBHOOK` | Webhook URL for alerts | - |
| `NOTIFICATION_SIGNAL` | Enable Signal notifications | false |
| `SIGNAL_API_URL` | Signal API endpoint | http://localhost:8080 |

## Troubleshooting

### Sync Issues

```bash
# Check sync status
bash scripts/multi-node-sync.sh --status

# Test SSH connectivity
ssh -i ~/.ssh/id_rsa pi@192.168.8.12 echo "Connected"

# View sync logs
tail -f logs/multi-node-sync.log
```

### Backup Issues

```bash
# Check backup status
bash scripts/automated-sync-backup.sh --status

# Verify backup integrity
bash scripts/automated-sync-backup.sh --verify

# View backup logs
tail -f logs/sync-backup.log
```

### Self-Heal Issues

```bash
# Check service status
bash scripts/self-heal.sh --status

# Reset circuit breakers
bash scripts/self-heal.sh --reset

# View self-heal logs
tail -f logs/self-heal.log
```

### Pre-Flight Failures

```bash
# Run with verbose output
bash scripts/pre-flight-check.sh --verbose

# Attempt automatic fixes
bash scripts/pre-flight-check.sh --fix
```

## Best Practices

### High Availability

1. **Deploy on two separate Pis** for hardware redundancy
2. **Use different power supplies** for each Pi
3. **Connect to different network switches** if possible
4. **Enable automated sync** between nodes
5. **Configure off-site backup** for disaster recovery

### Monitoring

1. **Enable self-healing daemon** on both nodes
2. **Configure notifications** for alerts
3. **Integrate with CoreSrv** for centralized monitoring
4. **Review logs weekly** for issues

### Backup Strategy

1. **Daily automated backups** to local storage
2. **Sync to peer node** for redundancy
3. **Weekly off-site backup** to NAS or cloud
4. **Test restore quarterly** to verify backups
5. **Keep at least 10 backups** locally

### Security

1. **Use SSH keys** for node-to-node communication
2. **Enable firewall** on both nodes
3. **Restrict network access** to management ports
4. **Rotate passwords** regularly
5. **Enable 2FA** for admin access (via Authelia)

## Related Documentation

- [Backup and Migration Guide](backup-and-migration.md)
- [Disaster Recovery](../DISASTER_RECOVERY.md)
- [Operations Guide](operations.md)
- [Health and HA Guide](health-and-ha.md)
- [NSM/AI Integration](ORION_SENTINEL_INTEGRATION.md)
