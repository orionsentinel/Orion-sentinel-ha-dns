# Scripts Reference Guide

This directory contains helper scripts for managing your RPi HA DNS Stack.

## Available Scripts

### 🚀 setup.sh - Interactive Setup Wizard
**Purpose**: Guide new users through initial configuration and deployment

**Usage**:
```bash
bash scripts/setup.sh
```

**What it does**:
- Interactive prompts for all configuration options
- Securely collects passwords (hidden input)
- Validates network settings
- Creates `.env` file with your configuration
- Optionally deploys the stack immediately
- Backs up existing configuration before changes

**When to use**:
- First-time setup
- Reconfiguring the stack
- Starting fresh after major changes

---

### 📦 install.sh - Automated Deployment
**Purpose**: Deploy the stack using existing configuration

**Usage**:
```bash
bash scripts/install.sh
```

**What it does**:
- Installs Docker and Docker Compose (if missing)
- Enables IP forwarding (for DNS)
- Creates Docker networks
- Creates necessary directories
- Deploys all services
- Verifies deployment

**When to use**:
- After running setup.sh
- Redeploying with existing config
- Automated deployment scenarios

**Note**: Requires `.env` file to exist

---

### 🔄 update.sh - Update and Upgrade
**Purpose**: Safely update your installation from the git repository

**Usage**:
```bash
bash scripts/update.sh
```

**What it does**:
1. **Backup Phase**:
   - Backs up `.env` file
   - Backs up all `docker-compose.override.yml` files
   - Saves backups to `.backups/` directory with timestamps

2. **Update Phase**:
   - Checks git repository status
   - Pulls latest changes from remote
   - Handles merge conflicts gracefully
   - Shows recent changes

3. **Rebuild Phase**:
   - Stops all running containers
   - Rebuilds custom images (signal-webhook-bridge, ai-watchdog)
   - Pulls latest official images
   - Restarts all services

4. **Verification Phase**:
   - Checks container health
   - Reports any issues
   - Offers to clean up old images

**When to use**:
- Repository has been updated with new features
- Bug fixes are available
- You want to pull latest official Docker images
- Periodic maintenance

**Safety features**:
- Automatic configuration backup
- Preserves your `.env` and override files
- Graceful handling of git conflicts
- Option to cancel at any point
- Verification step before applying changes

---

### 🧪 test-signal-integration.sh
**Purpose**: Validate Signal webhook integration

**Usage**:
```bash
bash scripts/test-signal-integration.sh
```

**What it does**:
- Runs 11 automated tests
- Validates configuration files
- Checks Python syntax
- Verifies docker-compose files
- Reports pass/fail for each test

---

### ✅ deployment-readiness-check.sh
**Purpose**: Verify system is ready for deployment

**Usage**:
```bash
bash scripts/deployment-readiness-check.sh
```

**What it does**:
- Runs 14 deployment checks
- Verifies all files exist
- Validates configurations
- Checks documentation
- Provides next steps

---

### 🔧 deploy.sh
**Purpose**: Simple deployment script

**Usage**:
```bash
bash scripts/deploy.sh
```

**What it does**:
- Deploys all three stacks (DNS, observability, AI-watchdog)
- Shows container status

---

### 📡 fetch-root-hints.sh
**Purpose**: Download DNS root hints for Unbound

**Usage**:
```bash
bash scripts/fetch-root-hints.sh
```

**What it does**:
- Downloads latest root hints from IANA
- Places file in correct location for Unbound

---

## Typical Workflows

### First Time Setup
```bash
# 1. Clone repository
git clone https://github.com/yorgosroussakis/rpi-ha-dns-stack.git
cd rpi-ha-dns-stack

# 2. Run interactive setup
bash scripts/setup.sh

# 3. Verify deployment
bash scripts/deployment-readiness-check.sh
```

### Updating Your Installation
```bash
# 1. Navigate to repository
cd rpi-ha-dns-stack

# 2. Run update script
bash scripts/update.sh

# 3. Verify health
docker ps
```

### Manual Deployment
```bash
# 1. Create/edit .env file
cp .env.example .env
nano .env

# 2. Run installation
bash scripts/install.sh

# 3. Test Signal integration
bash scripts/test-signal-integration.sh
```

### Troubleshooting
```bash
# Check container status
docker ps -a

# View container logs
docker logs <container-name>

# Verify configuration
bash scripts/deployment-readiness-check.sh

# Test Signal notifications
curl -X POST http://192.168.8.240:8080/test \
  -H "Content-Type: application/json" \
  -d '{"message":"Test"}'
```

---

## Configuration Files

### .env
Main configuration file created by `setup.sh`. Contains:
- Network settings (IPs, subnet, gateway)
- Passwords (Pi-hole, Grafana, Keepalived)
- Signal API credentials
- Monitoring settings

**Important**: Never commit `.env` to git (it's in `.gitignore`)

### docker-compose.override.yml
Optional per-stack customizations. Examples provided:
- `stacks/dns/docker-compose.override.yml.example`
- `stacks/observability/docker-compose.override.yml.example`

Copy `.example` to `docker-compose.override.yml` and customize.

### .backups/
Directory created by `update.sh` to store configuration backups.
Format: `<file>.backup.<YYYYMMDD_HHMMSS>`

---

## Environment Variables

All scripts respect these environment variables:

- `REPO_ROOT`: Override repository root directory
- `ENV_FILE`: Override .env file location
- `BACKUP_DIR`: Override backup directory location

---

## Exit Codes

Scripts use standard exit codes:
- `0`: Success
- `1`: Error occurred
- `130`: Interrupted by user (Ctrl-C)

---

## Getting Help

For script-specific help, most scripts support:
```bash
bash scripts/<script-name>.sh --help
```

For general help, see the main [README.md](../README.md)
