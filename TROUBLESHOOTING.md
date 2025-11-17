# Troubleshooting Guide

This guide helps you resolve common installation and operation issues with the RPi HA DNS Stack.

## Table of Contents
- [Installation Issues](#installation-issues)
- [Terminal/SSH Disconnection Issues](#terminalssh-disconnection-issues)
- [Docker Issues](#docker-issues)
- [Network Issues](#network-issues)
- [Web UI Issues](#web-ui-issues)
- [DNS Resolution Issues](#dns-resolution-issues)
- [Container Issues](#container-issues)
- [Performance Issues](#performance-issues)
- [Getting Help](#getting-help)

---

## Installation Issues

### Issue: Installation script causes system reboot

**Symptoms:**
- Running terminal setup scripts causes SSH session to disconnect
- System appears to reboot during installation
- Terminal freezes or becomes unresponsive

**Causes:**
- The original scripts used `set -euo pipefail` which causes abrupt exits
- Docker group membership changes required session restart
- Errors in scripts weren't handled gracefully

**Solution:**
Use the new **Easy Installer** which has proper error handling:

```bash
cd rpi-ha-dns-stack
bash scripts/easy-install.sh
```

Or if you still experience issues, use the Web UI instead:
```bash
bash scripts/launch-setup-ui.sh
```

**Prevention:**
- Always run installation scripts in a `screen` or `tmux` session
- Use the `--verbose` flag to see detailed output: `bash scripts/easy-install.sh --verbose`
- Check logs in `install.log` if issues occur

### Issue: "Permission denied" errors during installation

**Symptoms:**
- Docker commands fail with permission errors
- Cannot create directories
- Cannot start services

**Solution:**

1. **For Docker permissions:**
```bash
# Add your user to docker group
sudo usermod -aG docker $USER

# Log out and log back in, or run:
newgrp docker

# Verify Docker access
docker ps
```

2. **For file permissions:**
```bash
# Ensure you own the repository directory
sudo chown -R $USER:$USER ~/rpi-ha-dns-stack

# Or run installation with sudo (not recommended)
sudo bash scripts/easy-install.sh
```

### Issue: Installation fails with "Docker not found"

**Symptoms:**
- Error: "Docker is not installed"
- Cannot proceed with installation

**Solution:**

1. **Install Docker manually:**
```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker
```

2. **Verify Docker is installed:**
```bash
docker --version
docker compose version
```

3. **Start Docker service:**
```bash
sudo systemctl start docker
sudo systemctl enable docker
```

### Issue: "Insufficient disk space" error

**Symptoms:**
- Installation fails with disk space error
- Minimum 5GB required message

**Solution:**

1. **Check available space:**
```bash
df -h
```

2. **Free up space:**
```bash
# Remove old Docker images/containers
docker system prune -a

# Remove old logs
sudo journalctl --vacuum-time=7d

# Check large files
sudo du -h / | sort -rh | head -20
```

3. **Use external storage:**
- Mount an external drive
- Move Docker data directory to external storage

---

## Terminal/SSH Disconnection Issues

### Issue: SSH session disconnects during installation

**Symptoms:**
- Connection lost during script execution
- "Connection closed" or "Broken pipe" errors
- Cannot reconnect immediately

**Solution:**

1. **Use `screen` or `tmux` for persistent sessions:**
```bash
# Install screen
sudo apt-get install -y screen

# Start a screen session
screen -S install

# Run installation
bash scripts/easy-install.sh

# If disconnected, reconnect with:
screen -r install
```

2. **Use `nohup` to run in background:**
```bash
nohup bash scripts/easy-install.sh > install.log 2>&1 &

# Check progress
tail -f install.log
```

3. **Check SSH configuration:**
```bash
# Edit SSH config
sudo nano /etc/ssh/sshd_config

# Add/modify these lines:
ClientAliveInterval 60
ClientAliveCountMax 3

# Restart SSH
sudo systemctl restart sshd
```

### Issue: System reboots unexpectedly during setup

**Symptoms:**
- Pi reboots in middle of installation
- Services fail to start
- Configuration incomplete

**Causes:**
- Power supply insufficient (most common)
- Overheating
- Corrupted SD card

**Solution:**

1. **Check power supply:**
- Use official 3A+ power supply
- Avoid using phone chargers
- Check for voltage warnings: `vcgencmd get_throttled`

2. **Monitor temperature:**
```bash
# Check current temperature
vcgencmd measure_temp

# Add cooling if temp > 70°C
# - Add heatsinks
# - Add active cooling fan
# - Improve ventilation
```

3. **Check SD card health:**
```bash
# Check for errors
sudo dmesg | grep -i mmc

# Test SD card
sudo apt-get install f3
f3probe /dev/mmcblk0
```

---

## Docker Issues

### Issue: Docker daemon not running

**Symptoms:**
- "Cannot connect to Docker daemon" error
- Docker commands fail

**Solution:**

1. **Start Docker:**
```bash
sudo systemctl start docker
sudo systemctl status docker
```

2. **Enable Docker to start on boot:**
```bash
sudo systemctl enable docker
```

3. **Check Docker logs:**
```bash
sudo journalctl -u docker -n 50
```

### Issue: Docker Compose not found

**Symptoms:**
- "docker compose: command not found"
- Installation fails at Docker Compose check

**Solution:**

1. **Install Docker Compose plugin:**
```bash
sudo apt-get update
sudo apt-get install -y docker-compose-plugin
```

2. **Verify installation:**
```bash
docker compose version
```

### Issue: Docker containers fail to start

**Symptoms:**
- Containers exit immediately
- "Exited (1)" status
- Cannot access services

**Solution:**

1. **Check container logs:**
```bash
docker logs <container_name>
```

2. **Check resource usage:**
```bash
docker stats
free -h
df -h
```

3. **Restart containers:**
```bash
cd rpi-ha-dns-stack/stacks/dns
docker compose restart
```

4. **Rebuild containers:**
```bash
docker compose down
docker compose up -d --build
```

---

## Network Issues

### Issue: Cannot create macvlan network

**Symptoms:**
- "network create failed" error
- Parent interface error

**Solution:**

1. **Check network interface:**
```bash
ip link show

# Find your interface (usually eth0)
```

2. **Update .env file:**
```bash
# Edit the .env file
nano .env

# Set correct interface
NETWORK_INTERFACE=eth0  # or your interface name
```

3. **Use bridge network as fallback:**
```bash
# Remove failed macvlan network
docker network rm dns_net

# Create bridge network instead
docker network create dns_net
```

### Issue: IP conflicts

**Symptoms:**
- Containers can't get IP addresses
- "Address already in use" errors
- Network unreachable

**Solution:**

1. **Check for IP conflicts:**
```bash
# Scan your network
sudo nmap -sn 192.168.8.0/24

# Check specific IPs
ping -c 1 192.168.8.251
ping -c 1 192.168.8.252
```

2. **Change IP addresses in .env:**
```bash
nano .env

# Update to free IPs
PIHOLE_PRIMARY_IP=192.168.8.241
PIHOLE_SECONDARY_IP=192.168.8.242
```

3. **Recreate containers:**
```bash
docker compose down
docker compose up -d
```

---

## Web UI Issues

### Issue: Cannot access Web Setup UI

**Symptoms:**
- Port 5555 not accessible
- "Connection refused" error
- Blank page

**Solution:**

1. **Check if UI is running:**
```bash
docker ps | grep setup-ui
```

2. **Start the UI:**
```bash
bash scripts/launch-setup-ui.sh
```

3. **Check port availability:**
```bash
sudo netstat -tlnp | grep 5555
# or
sudo ss -tlnp | grep 5555
```

4. **Check firewall:**
```bash
# Check if ufw is active
sudo ufw status

# Allow port 5555
sudo ufw allow 5555/tcp
```

5. **Access from correct IP:**
```bash
# Get your Pi's IP
hostname -I

# Access from browser:
# http://<pi-ip>:5555
```

### Issue: Web UI loads but forms don't work

**Symptoms:**
- Page loads but buttons don't respond
- Form submissions fail
- JavaScript errors in browser console

**Solution:**

1. **Clear browser cache:**
- Ctrl+Shift+R (force refresh)
- Clear cookies and cache

2. **Check browser console:**
- Press F12
- Look for JavaScript errors
- Report errors to GitHub issues

3. **Try different browser:**
- Chrome/Chromium
- Firefox
- Safari

---

## DNS Resolution Issues

### Issue: DNS not resolving

**Symptoms:**
- `dig` commands fail
- `nslookup` fails
- Websites don't load

**Solution:**

1. **Check Pi-hole status:**
```bash
docker logs pihole_primary
docker logs pihole_secondary
```

2. **Test DNS directly:**
```bash
# Test primary Pi-hole
dig @192.168.8.251 google.com

# Test secondary Pi-hole
dig @192.168.8.252 google.com

# Test VIP
dig @192.168.8.255 google.com
```

3. **Check Unbound status:**
```bash
docker logs unbound_primary
docker logs unbound_secondary
```

4. **Verify network connectivity:**
```bash
# From another device, ping the Pi
ping 192.168.8.251

# Check if port 53 is open
nc -zv 192.168.8.251 53
```

---

## Container Issues

### Issue: Container keeps restarting

**Symptoms:**
- Container status shows "Restarting"
- Service unavailable
- Logs show repeated errors

**Solution:**

1. **Check container logs:**
```bash
docker logs <container_name> --tail 100
```

2. **Check resource limits:**
```bash
docker stats
```

3. **Stop restart loop:**
```bash
docker update --restart=no <container_name>
docker stop <container_name>
```

4. **Fix underlying issue and restart:**
```bash
docker start <container_name>
```

### Issue: Cannot access container from host

**Symptoms:**
- Host cannot ping container IPs
- Cannot access web interfaces from Pi itself

**Explanation:**
This is **normal behavior** with macvlan networks. The host cannot directly communicate with containers on a macvlan network.

**Solution:**
- Access services from another device on your network
- Or use `docker exec` to access containers:
```bash
docker exec -it pihole_primary bash
```

---

## Performance Issues

### Issue: High CPU usage

**Symptoms:**
- Pi runs hot
- Slow response
- High load average

**Solution:**

1. **Check which container is using CPU:**
```bash
docker stats
```

2. **Reduce query logging:**
- Access Pi-hole admin
- Disable query logging temporarily
- Adjust log retention

3. **Increase cooling:**
- Add heatsinks
- Add fan
- Improve ventilation

### Issue: High memory usage

**Symptoms:**
- Out of memory errors
- Containers being killed
- System swapping heavily

**Solution:**

1. **Check memory usage:**
```bash
free -h
docker stats
```

2. **Reduce memory usage:**
- Disable unused stacks (traffic-analytics, etc.)
- Reduce Prometheus retention
- Reduce log retention

3. **Add swap space:**
```bash
sudo dphys-swapfile swapoff
sudo nano /etc/dphys-swapfile
# Set CONF_SWAPSIZE=2048
sudo dphys-swapfile setup
sudo dphys-swapfile swapon
```

---

## Getting Help

If you're still experiencing issues:

### 1. Collect Diagnostic Information

```bash
# System information
uname -a
cat /etc/os-release

# Docker information
docker --version
docker compose version
docker ps -a
docker stats --no-stream

# Network information
ip addr
ip route

# Logs
docker compose -f stacks/dns/docker-compose.yml logs --tail=100

# Check for errors
dmesg | tail -50
sudo journalctl -n 100
```

### 2. Enable Verbose Logging

```bash
# Run with verbose output
bash scripts/easy-install.sh --verbose

# Check install log
cat install.log
```

### 3. Search Existing Issues

Check if your problem is already reported:
https://github.com/yorgosroussakis/rpi-ha-dns-stack/issues

### 4. Create a New Issue

Include:
- Clear description of the problem
- Steps to reproduce
- Relevant logs and error messages
- System information
- What you've tried already

### 5. Community Support

- GitHub Discussions: Share experiences and ask questions
- Check the documentation:
  - [INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md)
  - [USER_GUIDE.md](USER_GUIDE.md)
  - [SECURITY_GUIDE.md](SECURITY_GUIDE.md)

---

## Quick Fixes Reference

### Reset Installation
```bash
cd rpi-ha-dns-stack
docker compose -f stacks/dns/docker-compose.yml down
docker compose -f stacks/observability/docker-compose.yml down
docker compose -f stacks/ai-watchdog/docker-compose.yml down
rm -f .install_state
bash scripts/easy-install.sh
```

### Full Clean Reset
```bash
cd rpi-ha-dns-stack
docker compose -f stacks/dns/docker-compose.yml down -v
docker compose -f stacks/observability/docker-compose.yml down -v
docker compose -f stacks/ai-watchdog/docker-compose.yml down -v
docker network rm dns_net observability_net
docker system prune -af
rm -f .install_state .env
bash scripts/easy-install.sh
```

### Emergency Recovery
```bash
# If system is unresponsive
sudo systemctl stop docker
sudo systemctl start docker

# If out of disk space
docker system prune -af --volumes

# If networking is broken
sudo systemctl restart networking
```

---

**Remember:** Most issues are caused by:
1. Insufficient power supply
2. Docker permission issues
3. Network configuration errors
4. Resource constraints

Always check these first!
