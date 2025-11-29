# Scripts Reference Guide

This directory contains helper scripts for managing your RPi HA DNS Stack.

## Installation Methods

The RPi HA DNS Stack offers **four different installation methods** to suit your preferences:

### Method 1: Command Line Installer (NEW - Recommended for Automation)
Full-featured CLI installer with both interactive and non-interactive modes.
```bash
# Interactive mode
bash scripts/cli-install.sh

# Non-interactive with options
bash scripts/cli-install.sh --mode single-pi-ha --host-ip 192.168.1.100 --non-interactive

# Dry-run to preview
bash scripts/cli-install.sh --mode single-pi-ha --dry-run

# Show full help
bash scripts/cli-install.sh --help
```
- **Interactive and non-interactive modes**
- **Full automation support** (CI/CD, scripting)
- **All deployment modes** (single-pi-ha, two-pi-simple, two-pi-ha)
- **Dry-run capability** to preview changes
- **Comprehensive --help** documentation
- Works over SSH and in headless environments
- Ideal for power users and automation

### Method 2: Web-Based Setup UI
Interactive web interface accessible from any device on your network.
```bash
bash scripts/launch-setup-ui.sh
```
- Visual, user-friendly interface
- Access from any browser (desktop, tablet, mobile)
- Real-time validation and feedback
- Perfect for beginners

### Method 3: Desktop GUI Installer
Native graphical installer for desktop Linux environments.
```bash
bash scripts/install-gui.sh
```
- Native desktop dialogs (zenity/kdialog)
- Step-by-step wizard
- Automatic browser launch
- Best for desktop Linux users

### Method 4: Terminal Setup
Command-line interactive setup for terminal enthusiasts.
```bash
bash scripts/setup.sh
```
- Keyboard-driven interface
- Works over SSH
- No GUI required
- Ideal for headless systems

All four methods provide the same configuration options and final result!

---

## Available Scripts

### 🚀 Upgrade & Maintenance Scripts

#### smart-upgrade.sh - Intelligent Upgrade System ⭐ NEW
**Purpose**: Comprehensive upgrade management with safety checks and rollback capability

**Usage**:
```bash
# Interactive mode (recommended)
bash scripts/smart-upgrade.sh -i

# Check for updates only
bash scripts/smart-upgrade.sh -c

# Perform full system upgrade
bash scripts/smart-upgrade.sh -u

# Upgrade specific stack
bash scripts/smart-upgrade.sh -s dns

# Verify system health
bash scripts/smart-upgrade.sh -v

# Create version tracking file
bash scripts/smart-upgrade.sh --create-version-file
```

**Features**:
- **Pre-upgrade Health Checks**: Validates disk space, Docker status, network connectivity
- **Automatic Backup**: Creates backup before any upgrade
- **Selective Upgrades**: Upgrade all stacks or individual components
- **Post-upgrade Verification**: Tests container health and DNS resolution
- **Interactive Menu**: User-friendly interface for upgrade operations
- **Detailed Logging**: All operations logged to `upgrade.log`
- **Rollback Support**: Easy recovery via backup restore

**What it checks**:
- Disk space (warns if >85% full)
- Docker daemon status
- Network connectivity
- Running container inventory
- Container health after upgrade
- DNS resolution functionality

**When to use**:
- Regular system updates (recommended monthly)
- Security patch deployment
- Major version upgrades
- Troubleshooting service issues

**See also**: [SMART_UPGRADE_GUIDE.md](../SMART_UPGRADE_GUIDE.md) for complete documentation

---

#### check-updates.sh - Automated Update Checker ⭐ NEW
**Purpose**: Check for Docker image updates and generate report

**Usage**:
```bash
# Check for updates
bash scripts/check-updates.sh

# View the generated report
cat update-report.md

# Setup automated daily checks (optional)
(crontab -l 2>/dev/null; echo "0 3 * * * $(pwd)/scripts/check-updates.sh") | crontab -
```

**What it does**:
- Scans all 24+ Docker images used in the stack
- Compares current vs. latest image digests
- Generates markdown report with update status
- Fetches latest version tags from Docker Hub
- Provides specific upgrade recommendations

**Report includes**:
- 🟢 Up to date images
- 🟡 Images with updates available
- ⚪ Not installed images
- Recommended upgrade commands
- Automated update schedule info

**Monitored services**:
- Core DNS: Pi-hole, Unbound, Cloudflared
- Monitoring: Grafana, Prometheus, Loki, Promtail
- Management: Portainer, Homepage, Uptime Kuma, Netdata
- Security: Authelia, OAuth2 Proxy, Trivy
- VPN: WireGuard, Tailscale
- And more...

**When to use**:
- Before planning upgrades
- Regular maintenance checks
- Security audit preparation
- Version compliance verification

---

#### update.sh - Standard Update Script
**Purpose**: Traditional update method for the stack

**Usage**:
```bash
bash scripts/update.sh
```

**What it does**:
- Backs up current configuration
- Pulls latest changes from git
- Rebuilds updated containers
- Restarts services
- Preserves .env and override files

**When to use**:
- When you prefer traditional update method
- As fallback if smart-upgrade has issues
- For simple git pull + rebuild operations

**Note**: For enhanced safety and features, use `smart-upgrade.sh` instead

---

### 🚀 cli-install.sh - Command Line Installer ⭐ NEW
**Purpose**: Full-featured CLI installer with interactive and non-interactive modes

**Usage**:
```bash
# Interactive installation (guided prompts)
bash scripts/cli-install.sh

# Non-interactive with specified options
bash scripts/cli-install.sh --mode single-pi-ha --host-ip 192.168.1.100 --non-interactive

# Dry-run to preview what would happen
bash scripts/cli-install.sh --mode single-pi-ha --dry-run

# Generate config file only (don't deploy)
bash scripts/cli-install.sh --mode single-pi-ha --generate-config

# Two-Pi HA mode for primary node
bash scripts/cli-install.sh --mode two-pi-ha --node-role MASTER --host-ip 192.168.1.10

# Show all options
bash scripts/cli-install.sh --help
```

**Key Features**:
- **Interactive mode**: Guided prompts for all configuration options
- **Non-interactive mode**: Fully scriptable for automation
- **Dry-run mode**: Preview changes without making any modifications
- **All deployment modes**: single-pi-ha, two-pi-simple, two-pi-ha
- **Complete CLI options**: IP addresses, passwords, network settings
- **Generate config only**: Create .env without deploying
- **Verbose mode**: Detailed output for debugging

**Available Options**:
| Option | Description |
|--------|-------------|
| `--mode <mode>` | Deployment mode (single-pi-ha, two-pi-simple, two-pi-ha) |
| `--node-role <role>` | Node role for two-pi modes (MASTER, BACKUP) |
| `--host-ip <ip>` | Host IP address |
| `--vip <ip>` | Virtual IP address for HA |
| `--interface <iface>` | Network interface (eth0, wlan0, etc.) |
| `--subnet <cidr>` | Network subnet (e.g., 192.168.1.0/24) |
| `--gateway <ip>` | Network gateway |
| `--timezone <tz>` | Timezone (e.g., Europe/London) |
| `--pihole-password <pw>` | Pi-hole admin password |
| `--grafana-password <pw>` | Grafana admin password |
| `--vrrp-password <pw>` | VRRP/Keepalived password |
| `--non-interactive` | Run without prompts |
| `--generate-config` | Generate .env only, don't deploy |
| `--dry-run` | Preview changes without applying |
| `--skip-docker` | Skip Docker installation check |
| `--skip-validation` | Skip prerequisite checks |
| `--force` | Continue even if checks fail |
| `--verbose` | Enable detailed output |

**When to use**:
- Automated deployments (CI/CD pipelines)
- Scripted installation across multiple Pis
- Headless/SSH installations
- Power users who prefer CLI
- Testing with dry-run before deployment

---

### 📦 Installation Scripts

#### ✓ install-check.sh - Pre-Installation Validation
**Purpose**: Check system prerequisites before installation

**Usage**:
```bash
bash scripts/install-check.sh
```

**What it does**:
- Checks OS compatibility (Debian, Ubuntu, Raspberry Pi OS)
- Verifies architecture (ARM, x86_64)
- Checks disk space (minimum 5GB)
- Checks memory (minimum 1GB)
- Verifies network connectivity
- Tests Docker availability
- Checks port availability
- Provides detailed report with recommendations

**When to use**:
- Before starting installation
- Troubleshooting installation issues
- Verifying system meets requirements

---

### 🖥️ install-gui.sh - Desktop GUI Installer
**Purpose**: Graphical installation wizard for desktop Linux

**Usage**:
```bash
bash scripts/install-gui.sh
```

**What it does**:
- Detects desktop environment
- Installs GUI dialog tool (zenity/kdialog)
- Runs prerequisite checks with progress dialogs
- Offers choice of installation modes
- Opens web browser automatically for web UI mode
- Provides visual feedback throughout

**Requirements**:
- Desktop environment (GNOME, KDE, XFCE, etc.)
- X11 or Wayland display server

**When to use**:
- Desktop Linux installations
- Users who prefer GUI over terminal
- Visual feedback during installation

---

### 🌐 launch-setup-ui.sh - Web Setup UI Launcher
**Purpose**: Start/stop the web-based setup wizard

**Usage**:
```bash
bash scripts/launch-setup-ui.sh [start|stop|restart|logs|status]
```

**What it does**:
- Validates Docker and Python 3 installation
- Checks port 5555 availability
- Starts web UI in Docker container
- Verifies service is running
- Provides access URLs

**Commands**:
- `start` - Launch the web UI (default)
- `stop` - Stop the web UI
- `restart` - Restart the web UI
- `logs` - Show web UI logs
- `status` - Check if web UI is running

**When to use**:
- Starting web-based configuration
- Accessing setup from another device
- Managing the setup UI service

---

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

---

### ✅ validate-network.sh - Network Configuration Validator
**Purpose**: Diagnose DNS network configuration issues

**Usage**:
```bash
bash scripts/validate-network.sh
```

**What it does**:
- Checks if `dns_net` network exists
- Verifies network driver type (should be macvlan, not bridge)
- Validates network subnet and gateway settings
- Checks parent interface configuration
- Provides detailed error messages and fix instructions

**When to use**:
- DNS containers are unreachable
- Before deploying DNS stack
- Troubleshooting "host unreachable" errors
- Verifying network setup after changes

**Exit codes**:
- `0`: Network is correctly configured
- `1`: Network has issues or doesn't exist

---

### 🔧 fix-dns-network.sh - DNS Network Repair Tool
**Purpose**: Automatically fix incorrect DNS network configuration

**Usage**:
```bash
bash scripts/fix-dns-network.sh
```

**What it does**:
1. Detects network configuration issues
2. Stops DNS stack containers
3. Removes incorrectly configured network
4. Creates new macvlan network with correct settings
5. Restarts DNS stack
6. Verifies deployment

**When to use**:
- After `validate-network.sh` reports issues
- DNS containers show "host unreachable" errors
- Network was created as bridge instead of macvlan
- Quick recovery from network misconfiguration

**Safety features**:
- Asks for confirmation before making changes
- Provides clear status messages at each step
- Validates parent interface before creating network
- Verifies container status after restart

---

### 🌐 deploy-dns.sh - DNS Stack Deployment
**Purpose**: Deploy DNS stack with proper network validation

**Usage**:
```bash
bash scripts/deploy-dns.sh
```

**What it does**:
- Loads configuration from `.env`
- Validates network interface exists
- Creates or validates macvlan network
- Stops any running DNS containers
- Builds keepalived image
- Deploys all DNS services
- Shows deployment status and next steps

**Enhanced features**:
- Automatic network type validation
- Interactive fix for incorrect networks
- Clear error messages for common issues
- Helpful deployment instructions

**When to use**:
- First-time DNS stack deployment
- Redeploying DNS stack after changes
- Alternative to running docker compose directly

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
# Check network configuration
bash scripts/validate-network.sh

# Fix network issues
bash scripts/fix-dns-network.sh

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
