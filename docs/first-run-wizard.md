# First-Run Web Wizard

**Orion Sentinel DNS HA - Setup Wizard Guide**

The first-run web wizard provides a graphical interface for configuring your DNS HA stack without editing YAML files manually.

---

## Table of Contents

- [Overview](#overview)
- [Accessing the Wizard](#accessing-the-wizard)
- [Wizard Steps](#wizard-steps)
- [After Setup](#after-setup)
- [Re-running the Wizard](#re-running-the-wizard)
- [Disabling the Wizard](#disabling-the-wizard)

---

## Overview

The first-run wizard is a minimal Flask web application that helps you:

1. **Configure Network Settings**: Set up IP addresses, deployment mode (single-node vs HA), and network interface
2. **Choose DNS Profile**: Select from pre-configured security profiles (Standard, Family, Paranoid)
3. **Generate Configuration**: Create the `.env` file with your settings
4. **Get Deployment Instructions**: Step-by-step guide to deploy the stack

**Benefits:**
- ✅ No command-line configuration needed
- ✅ Visual interface with helpful hints
- ✅ Validation of configuration values
- ✅ Clear next steps after setup

---

## Accessing the Wizard

### Start the Wizard

**Option 1: Using Docker Compose (Integrated)**

If you've already deployed the stack with the wizard service enabled:

```bash
# The wizard runs automatically on port 8080
# Access it at:
http://<your-pi-ip>:8080
```

**Option 2: Standalone (Before Stack Deployment)**

Run the wizard standalone before deploying the full stack:

```bash
cd ~/Orion-sentinel-ha-dns
python3 wizard/app.py
```

Then access at:
- From Pi: `http://localhost:8080`
- From network: `http://<pi-ip>:8080`

### Prerequisites

**Python Dependencies:**
```bash
# Install wizard dependencies
pip3 install -r wizard/requirements.txt
```

Required packages:
- Flask (web framework)
- PyYAML (for reading profile configurations)

---

## Wizard Steps

### Step 1: Welcome Page

The welcome page introduces the wizard and explains what it will do.

**Actions:**
- Click **"Get Started"** to begin configuration
- Or click **"View CLI installation guide"** for manual setup

### Step 2: Network Configuration

Configure your network settings and deployment mode.

#### Deployment Mode

**Single-Node Mode:**
- Runs all services on one Raspberry Pi
- VIP is set to your Pi's IP (no actual failover)
- Best for: Home labs, testing, single Pi setups

**Two-Node HA Mode:**
- Runs on two Raspberry Pis with automatic failover
- Uses a shared Virtual IP (VIP) that floats between nodes
- Best for: Production, 24/7 availability

#### Network Settings

**Pi's LAN IP Address:**
- The static IP of this Raspberry Pi
- Auto-detected from your system
- Example: `192.168.8.250`

**Network Interface:**
- The network interface to use
- Usually `eth0` for Ethernet or `wlan0` for WiFi
- Auto-detected from your system

#### HA Mode Settings (Only for Two-Node HA)

**Virtual IP (VIP):**
- Shared IP address that floats between both Pis
- Must be unused on your network
- Example: `192.168.8.255`

**Node Role:**
- **MASTER**: Primary node that owns the VIP by default
- **BACKUP**: Secondary node that takes VIP if primary fails

#### Security

**Pi-hole Admin Password:**
- Strong password for Pi-hole web interface
- Minimum 8 characters
- Generate with: `openssl rand -base64 32`

**Important:** 
- For HA mode, both Pis must use the **same** password
- For HA mode, both Pis must use the **same** VIP address

### Step 3: Profile Selection

Choose a DNS security profile for your filtering needs.

#### Standard Profile (Recommended) ⚖️

**Protection:**
- ✅ Ad blocking
- ✅ Malware protection
- ✅ Basic tracking protection
- ❌ No content filtering

**Best for:** Home users, small offices

#### Family Profile 👨‍👩‍👧‍👦

**Protection:**
- ✅ Everything in Standard
- ✅ Adult content blocking
- ✅ Gambling site blocking
- ✅ Enhanced malware protection

**Best for:** Families with children, schools

#### Paranoid Profile 🔒

**Protection:**
- ✅ Everything in Standard
- ✅ Aggressive telemetry blocking (Windows, Apple, Google)
- ✅ Social media tracking blockers
- ✅ Smart TV ad blocking

**Best for:** Privacy-conscious users

⚠️ **Warning:** May break some websites and services

### Step 4: Setup Complete

The wizard saves your configuration and displays next steps.

**What Happens:**
1. ✅ `.env` file is created with your settings
2. ✅ Profile selection is saved
3. ✅ Wizard is marked as completed (`.setup_done` sentinel file created)

**Next Steps Displayed:**
1. Deploy the stack with `bash scripts/install.sh`
2. Configure your router to use the DNS VIP
3. Access Pi-hole admin interface
4. Apply your selected profile (optional, after deployment)

---

## After Setup

### Deploying the Stack

After completing the wizard, deploy the stack:

```bash
cd ~/Orion-sentinel-ha-dns
bash scripts/install.sh
```

This will:
- Create Docker networks
- Pull container images
- Start all services (Pi-hole, Unbound, Keepalived, etc.)

### Applying Your Profile

After the stack is deployed, apply your selected DNS profile:

```bash
# Replace 'standard' with your chosen profile
python3 scripts/apply-profile.py --profile standard
```

**Available profiles:**
- `standard` - Balanced protection
- `family` - Family-safe filtering
- `paranoid` - Maximum privacy

### Accessing Services

**Pi-hole Admin:**
- URL: `http://<vip>/admin`
- Username: (none, just password)
- Password: From your `.env` file

**Grafana Dashboard:**
- URL: `http://<pi-ip>:3000`
- Username: `admin`
- Password: From your `.env` file

**Prometheus:**
- URL: `http://<pi-ip>:9090`

---

## Re-running the Wizard

### When to Re-run

Re-run the wizard if you want to:
- Change from single-node to HA mode (or vice versa)
- Reconfigure network settings
- Switch to a different profile
- Reset configuration after testing

### How to Re-run

**Delete the sentinel file:**
```bash
cd ~/Orion-sentinel-ha-dns
rm wizard/.setup_done
```

**Restart the wizard:**
```bash
python3 wizard/app.py
```

Then access at `http://<pi-ip>:8080`

**⚠️ Warning:** 
- This will NOT delete your existing `.env` file
- The wizard will overwrite values in `.env`
- Consider backing up your `.env` first: `cp .env .env.backup`

---

## Disabling the Wizard

### After First-Run

Once you've completed setup, the wizard will display the "Setup Complete" page on all future visits.

**The wizard is safe to keep running** as it only allows reconfiguration if you delete the sentinel file.

### Stopping the Wizard Service

If running as a Docker service, you can disable it:

**Option 1: Stop the container**
```bash
docker compose -f stacks/dns/docker-compose.yml stop dns-wizard
```

**Option 2: Remove from docker-compose.yml**

Edit `stacks/dns/docker-compose.yml` and remove or comment out the `dns-wizard` service.

**Option 3: Disable via environment variable**

Set in your `.env`:
```env
DNS_WIZARD_ENABLED=0
```

Then restart the stack:
```bash
docker compose -f stacks/dns/docker-compose.yml up -d
```

---

## Troubleshooting

### Wizard not accessible

**Check if wizard is running:**
```bash
# Standalone
ps aux | grep wizard/app.py

# Docker
docker ps | grep dns-wizard
```

**Check firewall:**
```bash
# Allow port 8080
sudo ufw allow 8080/tcp
```

**Check from Pi itself:**
```bash
curl http://localhost:8080/health
# Should return: {"status": "ok", "setup_done": true/false}
```

### Configuration not saving

**Check file permissions:**
```bash
# Ensure .env is writable
ls -la .env

# Fix if needed
chmod 644 .env
```

**Check wizard logs:**
```bash
# Docker
docker logs dns-wizard

# Standalone
# Check terminal output where wizard is running
```

### Profile not applying

**Apply profile manually after deployment:**
```bash
python3 scripts/apply-profile.py --profile standard --dry-run
# Check output, then apply without --dry-run
```

**Check Pi-hole is running:**
```bash
docker ps | grep pihole
```

**Check apply-profile.py exists:**
```bash
ls -la scripts/apply-profile.py
```

---

## Security Considerations

### Wizard Access

The wizard runs on port 8080 and is accessible from your local network.

**Recommendations:**
- Only run the wizard during initial setup
- Disable/stop the wizard after configuration
- Do not expose port 8080 to the internet
- Use a firewall to restrict access if needed

### Passwords

The wizard stores passwords in `.env` file:
- The `.env` file contains sensitive credentials
- Ensure proper file permissions: `chmod 600 .env`
- Never commit `.env` to git (it's in `.gitignore`)
- Back up `.env` securely

---

## Advanced Usage

### Custom Profiles

You can create custom profile YAML files:

```bash
# Copy existing profile
cp profiles/standard.yml profiles/my-custom.yml

# Edit the profile
nano profiles/my-custom.yml

# Apply via CLI (wizard doesn't support custom profiles yet)
python3 scripts/apply-profile.py --profile my-custom
```

See [docs/profiles.md](profiles.md) for profile customization guide.

### Integration with Setup Scripts

The wizard can be used alongside CLI scripts:

1. Use wizard to generate `.env` configuration
2. Use `scripts/install.sh` to deploy
3. Use `scripts/apply-profile.py` to apply profiles
4. Use `scripts/backup-config.sh` for backups

---

## Related Documentation

- [Install Single Pi Guide](install-single-pi.md) - CLI-based single Pi setup
- [Install Two Pi HA Guide](install-two-pi-ha.md) - CLI-based HA setup
- [Profiles Guide](profiles.md) - DNS profile details
- [Operations Guide](operations.md) - Backup, restore, upgrade procedures

---

## Support

For issues or questions:
1. Check this guide for troubleshooting
2. Review [TROUBLESHOOTING.md](../TROUBLESHOOTING.md)
3. Open an issue on [GitHub](https://github.com/yorgosroussakis/Orion-sentinel-ha-dns/issues)
