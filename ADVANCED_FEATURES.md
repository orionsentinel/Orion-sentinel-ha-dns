# Advanced Features Guide

## DNSSEC Validation ✅

### What is DNSSEC?
DNSSEC (DNS Security Extensions) cryptographically signs DNS records to prevent DNS spoofing and cache poisoning attacks.

### Implementation
DNSSEC validation is now enabled in both unbound instances:

```yaml
# Unbound DNSSEC Configuration
module-config: "validator iterator"
auto-trust-anchor-file: "/var/lib/unbound/root.key"
trust-anchor-signaling: yes
root-key-sentinel: yes
harden-dnssec-stripped: yes
harden-below-nxdomain: yes
harden-referral-path: yes
use-caps-for-id: yes
val-clean-additional: yes
val-permissive-mode: no
val-log-level: 1
```

### Features
- ✅ Automatic trust anchor updates
- ✅ Validates all DNS responses
- ✅ Rejects invalid/tampered responses
- ✅ Logs validation failures
- ✅ Hardens against various DNS attacks

### Testing DNSSEC
```bash
# Query a DNSSEC-signed domain
dig @192.168.8.253 dnssec-failed.org +dnssec

# Should return SERVFAIL (validation failed)

# Query a valid DNSSEC domain
dig @192.168.8.253 cloudflare.com +dnssec +multi

# Should return valid signatures
```

### Benefits
- 🛡️ **Security**: Prevents DNS spoofing/poisoning
- 🔒 **Integrity**: Ensures DNS data hasn't been tampered with
- ✅ **Trust**: Cryptographic proof of authenticity
- 🚫 **Protection**: Blocks malicious redirects

---

## Multi-Region Failover ✅

### Architecture
```
Primary (Local) → Secondary (Local) → Backup1 (Cloud) → Backup2 (Cloud) → Public DNS (8.8.8.8, 1.1.1.1)
```

### Components

#### 1. Local DNS Servers
- **Primary**: 192.168.8.251 (Pi-hole + Unbound)
- **Secondary**: 192.168.8.252 (Pi-hole + Unbound)

#### 2. Cloud Backup Servers  
- **Backup1**: CoreDNS on port 5380 (forwards to primary/secondary)
- **Backup2**: CoreDNS on port 5381 (independent backup)

#### 3. Failover Manager
- Monitors all DNS servers every 30 seconds
- Automatically switches to backup on failure
- Fails back to higher priority when available
- Exposes Prometheus metrics

### Deployment

```bash
# Deploy multi-region failover
cd /opt/rpi-ha-dns-stack/stacks/dns
docker compose -f docker-compose.yml -f multi-region-failover.yml up -d
```

### Failover Priority

| Priority | Server | Location | Use Case |
|----------|--------|----------|----------|
| 1 | Primary | Local | Normal operation |
| 2 | Secondary | Local | Primary failure |
| 3 | Backup1 | Container | Both local failed |
| 4 | Backup2 | Container | All local failed |
| 5 | Cloud1 (8.8.8.8) | Internet | Emergency |
| 6 | Cloud2 (1.1.1.1) | Internet | Last resort |

### Monitoring
```bash
# Check failover status
curl http://192.168.8.250:8081/metrics | grep dns_failover

# View active server
curl http://192.168.8.250:8081/health
```

### Metrics Available
- `dns_failover_checks_total` - Health checks performed
- `dns_failover_response_seconds` - Query response times
- `dns_failover_server_status` - Server up/down status
- `dns_failover_active_server` - Currently active server
- `dns_failover_events_total` - Failover event counter

### Testing Failover
```bash
# Stop primary Pi-hole
docker stop pihole_primary

# Wait 30 seconds - failover manager will switch to secondary
curl http://192.168.8.250:8081/metrics | grep active_server

# Restart primary
docker start pihole_primary

# Wait 30 seconds - will fail back to primary
```

---

## Traffic Analytics 📊

### Overview
Comprehensive DNS traffic analysis system that collects, analyzes, and visualizes query patterns.

### Features
- ✅ **Real-time Collection**: Collects from Pi-hole every 60 seconds
- ✅ **Pattern Analysis**: Identifies trends, anomalies, peak times
- ✅ **Long-term Storage**: 90-day data retention in SQLite
- ✅ **Prometheus Metrics**: Full observability integration
- ✅ **Grafana Dashboards**: Beautiful visualizations
- ✅ **Query Statistics**: Top domains, blocked domains, clients
- ✅ **Hourly Patterns**: Identify busy/quiet periods
- ✅ **Client Analytics**: Per-client query statistics

### Deployment

```bash
cd /opt/rpi-ha-dns-stack/stacks/traffic-analytics
docker compose up -d
```

### Access
- **Analytics Dashboard**: http://192.168.8.250:3001
- **Metrics Endpoint**: http://192.168.8.250:8082/metrics

### Data Collected

#### Query Statistics
- Total queries per hour/day/week
- Blocked queries percentage
- Cache hit rates
- Query types (A, AAAA, PTR, etc.)

#### Domain Analysis  
- Top queried domains
- Top blocked domains
- Domain query frequency
- First-time domains

#### Client Analytics
- Queries per client
- Most active clients
- Client block rates
- Client query patterns

#### Temporal Patterns
- Hourly query distribution
- Day-of-week patterns
- Peak usage times
- Anomaly detection

### Grafana Dashboards

**1. DNS Overview**
- Total queries (24h, 7d, 30d)
- Block rate trending
- Top 10 domains
- Top 10 clients
- Query type distribution

**2. Security Analysis**
- Blocked domain trends
- Malicious query attempts
- DNSSEC validation failures
- Suspicious patterns

**3. Performance Metrics**
- Query response times
- Cache hit rates
- Upstream server performance
- Failover events

**4. Client Analytics**
- Per-client query volume
- Client device identification
- Query pattern analysis
- Anomalous client behavior

### API Endpoints

```bash
# Get current statistics
curl http://192.168.8.250:8082/metrics

# Sample metrics:
# dns_analytics_queries_collected_total 125643
# dns_analytics_unique_domains 3421
# dns_analytics_unique_clients 15
# dns_analytics_blocked_percentage 23.5
# dns_analytics_top_domain_queries{domain="google.com"} 1234
```

### Database Schema

```sql
-- Query statistics (time-series)
CREATE TABLE query_stats (
    timestamp INTEGER PRIMARY KEY,
    total_queries INTEGER,
    blocked_queries INTEGER,
    unique_domains INTEGER,
    unique_clients INTEGER,
    cache_hit_rate REAL
);

-- Domain statistics
CREATE TABLE domain_stats (
    timestamp INTEGER,
    domain TEXT,
    query_count INTEGER,
    blocked INTEGER,
    PRIMARY KEY (timestamp, domain)
);

-- Client statistics  
CREATE TABLE client_stats (
    timestamp INTEGER,
    client_ip TEXT,
    query_count INTEGER,
    blocked_count INTEGER,
    PRIMARY KEY (timestamp, client_ip)
);

-- Hourly patterns
CREATE TABLE hourly_patterns (
    hour INTEGER,
    day_of_week INTEGER,
    avg_queries INTEGER,
    avg_blocked INTEGER,
    PRIMARY KEY (hour, day_of_week)
);
```

### Use Cases

**1. Security Monitoring**
- Detect malware/botnet activity (unusual query patterns)
- Identify compromised devices (high block rates)
- Track malicious domains attempts

**2. Performance Optimization**
- Identify cache optimization opportunities
- Determine peak usage times for capacity planning
- Optimize blocklist effectiveness

**3. User Behavior Analysis**
- Understand network usage patterns
- Identify bandwidth-heavy applications
- Track device activity times

**4. Compliance & Reporting**
- Generate usage reports
- Track blocked content categories
- Audit DNS query logs

### Configuration

Edit `/opt/rpi-ha-dns-stack/stacks/traffic-analytics/docker-compose.yml`:

```yaml
environment:
  - PIHOLE_PRIMARY=192.168.8.251  # Primary Pi-hole IP
  - PIHOLE_SECONDARY=192.168.8.252  # Secondary Pi-hole IP
  - COLLECTION_INTERVAL=60  # Collection frequency (seconds)
  - RETENTION_DAYS=90  # Data retention period
```

### Performance Impact
- CPU: ~0.1-0.2% average
- Memory: ~128MB
- Disk: ~50MB per month (depends on query volume)
- Network: Minimal (local API calls only)

---

## Complete Feature Matrix

| Feature | Status | Performance | Security | Complexity |
|---------|--------|-------------|----------|------------|
| DNSSEC Validation | ✅ Enabled | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| Multi-Region Failover | ✅ Enabled | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| Traffic Analytics | ✅ Enabled | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| DNS-over-HTTPS | ✅ Available | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ |
| Self-Healing | ✅ Enabled | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| Automated Backups | ✅ Enabled | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ |

---

## Quick Start All Features

```bash
# 1. Enable DNSSEC (already enabled, restart to apply)
cd /opt/rpi-ha-dns-stack/stacks/dns
docker compose restart unbound_primary unbound_secondary

# 2. Deploy multi-region failover
docker compose -f docker-compose.yml -f multi-region-failover.yml up -d

# 3. Deploy traffic analytics
cd /opt/rpi-ha-dns-stack/stacks/traffic-analytics
docker compose up -d

# 4. Verify all services
docker ps | grep -E 'dns|failover|analytics'
```

---

## Monitoring All Features

```bash
# DNSSEC status
docker exec unbound_primary unbound-control status | grep validator

# Failover status
curl http://192.168.8.250:8081/metrics | grep active_server

# Analytics status
curl http://192.168.8.250:8082/metrics | grep dns_analytics
```

---

## Troubleshooting

### DNSSEC Issues
```bash
# Check DNSSEC logs
docker logs unbound_primary | grep -i dnssec

# Test DNSSEC validation
dig @192.168.8.253 +dnssec dnssec-failed.org
```

### Failover Issues
```bash
# Check failover manager logs
docker logs dns-failover-manager

# Manual DNS test
dig @192.168.8.250 -p 5380 google.com
```

### Analytics Issues
```bash
# Check analytics logs
docker logs traffic-analytics

# Verify database
docker exec traffic-analytics ls -lh /app/data/
```

---

## Further Reading

- **DNSSEC**: https://www.cloudflare.com/dns/dnssec/how-dnssec-works/
- **Failover Design**: https://www.nginx.com/blog/dns-service-discovery-nginx-plus/
- **DNS Analytics**: https://www.dnsstats.org/
