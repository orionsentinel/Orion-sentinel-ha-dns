# Production-Ready HA DNS Refactor Plan

## Overview

This document outlines the refactoring plan to transform Orion-sentinel-ha-dns into a production-ready, predictable, and low-maintenance HA DNS stack for a two-Raspberry-Pi home setup.

## Current State Assessment

### Existing Structure
- Multiple deployment modes in `deployments/` (HighAvail_1Pi2P2U_VPN, HighAvail_2Pi1P1U, Production_2Pi_HA, etc.)
- Configuration scattered across multiple directories
- Many environment files (.env.example, .env.multinode.example, env/.env.two-pi-ha.example)
- Extensive scripts directory with 50+ scripts
- Docker compose files duplicated across deployment modes
- No central Makefile for easy operations
- Complex documentation spread across 30+ markdown files

### Gaps Identified

1. **Complexity:** Too many deployment options confuse users
2. **Configuration:** Environment variables scattered and duplicated
3. **Automation:** No simple commands like `make up-core`
4. **Documentation:** Overwhelming amount of docs, need simplified quickstart
5. **Scripts:** Too many scripts, unclear which to use when
6. **Standardization:** No single source of truth for compose configuration

## Refactor Goals

Create a system where the operator (Yorgos) can:
1. Clone repo
2. Adjust `.env` file and maybe one per-node env file
3. Run `make up-core` or `make up-all`
4. Done!

## Implementation Plan

### Phase 1: Core Structure ✅ COMPLETE

**Files Created:**
- ✅ `Makefile` - Single entrypoint for all operations
- ✅ `compose.yml` - Root-level compose file with profiles
- ✅ `.env.production.example` - Simplified production config
- ✅ `env/pi1.env.example` - Node-specific config for Pi1
- ✅ `env/pi2.env.example` - Node-specific config for Pi2
- ✅ `README.production.md` - Clean, focused documentation

**Profiles Implemented:**
- `dns-core`: Pi-hole + Unbound + Keepalived (required)
- `exporters`: Node exporter + Pi-hole exporter + Unbound exporter (optional)
- `tools`: Future helper containers

### Phase 2: Configuration Management ✅ COMPLETE

**Directories Created:**
- ✅ `config/keepalived/` - Template-driven keepalived config
- ✅ `config/unbound/` - Unbound configuration
- ✅ `config/pihole/` - Pi-hole configuration (to be populated)

**Configuration Features:**
- ✅ Template-based keepalived config with env var substitution
- ✅ Unified Unbound config for both nodes
- ✅ Single .env file works for both single-pi and two-pi modes
- ✅ Node-specific overrides via env/pi1.env.example and env/pi2.env.example

### Phase 3: Scripts & Automation ✅ COMPLETE

**Essential Scripts Created:**
- ✅ `scripts/bootstrap-node.sh` - First-time node setup
- ✅ `scripts/check-dns.sh` - Health checking (used by Keepalived)
- ✅ `scripts/notify-master.sh` - MASTER state notification
- ✅ `scripts/notify-backup.sh` - BACKUP state notification
- ✅ `scripts/notify-fault.sh` - FAULT state notification

**Script Features:**
- ✅ All scripts have `set -euo pipefail`
- ✅ Idempotent where possible
- ✅ Clear error messages
- ✅ Logging to syslog

### Phase 4: Keepalived & HA Logic ✅ COMPLETE

**Implementation:**
- ✅ Template-driven keepalived.conf.tmpl
- ✅ Environment variable substitution at container startup
- ✅ Health check script tests both Pi-hole and Unbound
- ✅ Support for both unicast and multicast VRRP
- ✅ Same configuration works for both nodes (only env vars differ)

**Configuration Variables:**
- `VIP_ADDRESS` - Virtual IP
- `KEEPALIVED_PRIORITY` - Priority (higher = preferred MASTER)
- `NETWORK_INTERFACE` - Network interface name
- `VRRP_PASSWORD` - Authentication password
- `USE_UNICAST_VRRP` - Unicast vs multicast mode
- `PEER_IP` - IP of peer node (for unicast)

### Phase 5: Documentation 🔄 IN PROGRESS

**Created:**
- ✅ `README.production.md` - New simplified README
- ✅ `.env.production.example` with inline documentation
- ✅ Architecture diagram in ASCII art
- ✅ Step-by-step installation instructions

**To Do:**
- [ ] Migration guide (docs/migration.md)
- [ ] Grafana dashboard exports in grafana_dashboards/
- [ ] Update existing docs to reference new structure
- [ ] Create docs/architecture.md with detailed diagrams

### Phase 6: Testing & Validation 🔄 IN PROGRESS

**To Do:**
- [ ] Test single-pi deployment
- [ ] Test two-pi HA deployment
- [ ] Test failover scenarios
- [ ] Test backup/restore
- [ ] Validate all make targets
- [ ] Test bootstrap script on fresh Pi
- [ ] Verify monitoring exporters work

### Phase 7: Backwards Compatibility & Migration

**To Do:**
- [ ] Document migration from old deployments/ structure
- [ ] Provide scripts to migrate existing .env files
- [ ] Create compatibility layer for old environment variables
- [ ] Document volume/data migration if needed

## File Organization

### New Structure

```
orion-sentinel-ha-dns/
├── compose.yml                    # Main compose file (NEW)
├── Makefile                       # Operations commands (NEW)
├── .env.production.example        # Simplified config (NEW)
├── README.production.md           # New focused README (NEW)
│
├── config/                        # Configuration files (NEW)
│   ├── keepalived/
│   │   ├── Dockerfile
│   │   ├── entrypoint.sh
│   │   └── keepalived.conf.tmpl
│   ├── unbound/
│   │   ├── Dockerfile
│   │   ├── entrypoint.sh
│   │   └── unbound.conf
│   └── pihole/
│       └── (future configs)
│
├── env/                           # Node-specific configs
│   ├── pi1.env.example           # Pi1 settings (NEW)
│   └── pi2.env.example           # Pi2 settings (NEW)
│
├── scripts/                       # Essential scripts only
│   ├── bootstrap-node.sh         # First-time setup (NEW)
│   ├── check-dns.sh              # Health check (NEW)
│   ├── notify-master.sh          # Notifications (NEW)
│   ├── notify-backup.sh          # (NEW)
│   ├── notify-fault.sh           # (NEW)
│   └── validate-env.sh           # (existing, keep)
│
├── grafana_dashboards/            # Dashboard exports (TO CREATE)
│   ├── README.md
│   └── dns-ha-overview.json
│
├── docs/                          # Detailed documentation
│   ├── migration.md              # (TO CREATE)
│   ├── architecture.md           # (TO CREATE)
│   └── (existing docs, to review)
│
└── deployments/                   # Legacy (TO DEPRECATE)
    └── (old deployment modes)
```

### Deprecated Structure

The following will be marked as deprecated:
- `deployments/HighAvail_*` - Use root compose.yml instead
- `.env.multinode.example` - Use .env.production.example
- `env/.env.two-pi-ha.example` - Use .env.production.example + env/pi*.env.example

## Key Features

### 1. Single Source of Truth

- **One compose file:** `compose.yml` at root
- **One env file:** `.env` (from .env.production.example)
- **Node overrides:** env/pi1.env.example or env/pi2.env.example
- **All configs:** In `config/` directory

### 2. Profile-Based Deployment

```bash
# Core only
make up-core
# or: docker compose --profile dns-core up -d

# Core + monitoring
make up-all
# or: docker compose --profile dns-core --profile exporters up -d
```

### 3. Template-Driven Configuration

- Keepalived config generated from template
- Environment variables substituted at runtime
- Same files work for both nodes
- No manual editing of compose or config files

### 4. Simple Operations

```bash
make up-core        # Start DNS
make down           # Stop everything
make logs           # View logs
make health-check   # Check health
make backup         # Backup config
```

### 5. Comprehensive Health Checking

- Docker healthchecks on all services
- Keepalived health script tests real DNS resolution
- Manual health check script for diagnostics
- VIP only assigned to healthy nodes

## Environment Variables

### Required (Must Set)

```bash
PIHOLE_PASSWORD      # Generate: openssl rand -base64 32
VRRP_PASSWORD        # Generate: openssl rand -base64 20
VIP_ADDRESS          # Floating IP for DNS
HOST_IP              # This node's IP
```

### Node-Specific (Different on each Pi)

```bash
NODE_ROLE            # MASTER or BACKUP
KEEPALIVED_PRIORITY  # 200 for Pi1, 150 for Pi2
PEER_IP              # IP of the other Pi
```

### Optional

```bash
DEPLOY_MONITORING    # true/false
UNBOUND_SMART_PREFETCH  # 0/1
NOTIFY_ON_FAILOVER   # true/false
BACKUP_INTERVAL      # Seconds
```

## Migration Path

For existing users:

1. **Backup existing setup:**
   ```bash
   cd /opt/rpi-ha-dns-stack
   bash scripts/backup-config.sh
   ```

2. **Pull new structure:**
   ```bash
   git pull origin main
   ```

3. **Migrate environment:**
   ```bash
   # Copy old .env values to new .env.production.example
   cp .env.production.example .env
   # Manually transfer settings from old .env
   ```

4. **Deploy new structure:**
   ```bash
   make up-core
   ```

5. **Verify:**
   ```bash
   make health-check
   dig @<VIP_ADDRESS> google.com
   ```

## Success Criteria

- [ ] User can deploy with < 5 commands after cloning repo
- [ ] Single .env file + optional per-node env file
- [ ] All operations via `make` commands
- [ ] Clear, minimal documentation
- [ ] Automatic failover works reliably
- [ ] Health checks validate DNS functionality
- [ ] Monitoring exporters optional but easy to enable
- [ ] Bootstrap script sets up fresh Pi in one command
- [ ] No manual editing of compose files needed
- [ ] Same config works for single-pi and two-pi modes

## Timeline

- **Phase 1-3:** Core structure, configs, scripts ✅ COMPLETE
- **Phase 4:** Keepalived & HA ✅ COMPLETE
- **Phase 5:** Documentation 🔄 IN PROGRESS
- **Phase 6:** Testing & validation 🔄 NEXT
- **Phase 7:** Backwards compatibility & migration ⏳ PENDING

## Notes

### Design Decisions

1. **Why root-level compose.yml?**
   - Single entrypoint, no confusion about which file to use
   - Profiles provide flexibility without duplication

2. **Why Makefile?**
   - Easier to remember `make up-core` than docker compose flags
   - Validates environment before deployment
   - Provides helpful error messages

3. **Why template-based keepalived config?**
   - Same config file works for both nodes
   - Only environment variables differ
   - No manual editing of keepalived.conf

4. **Why separate config/ directory?**
   - Version control all configs
   - Easy to backup/restore
   - Clear separation from code

### Future Enhancements

- [ ] Grafana dashboard auto-import
- [ ] Automated testing framework
- [ ] CI/CD for validation
- [ ] ansible playbook for multi-node deployment
- [ ] Web-based setup wizard (existing wizard/ can be adapted)

---

**Status:** Implementation in progress
**Last Updated:** 2025-12-09
**Owner:** Yorgos / Orion Sentinel Team
