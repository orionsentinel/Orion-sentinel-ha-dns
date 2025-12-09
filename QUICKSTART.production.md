# Orion Sentinel HA DNS - Quick Start Guide

**Get your HA DNS running in under 10 minutes!**

---

## 🎯 What You'll Get

- **Ad-blocking DNS** via Pi-hole
- **Privacy-focused** recursive DNS via Unbound
- **High availability** with automatic failover (two-Pi setup)
- **Single IP** for all your devices (VIP)

---

## 📋 Before You Start

### You Need:

- **Two Raspberry Pi 4/5** (4GB+ RAM)
- **Static IPs configured** for each Pi
- **One free IP** for the VIP (Virtual IP)
- **Basic knowledge** of SSH and command line

### You Should Know:

- **Pi1 IP:** (e.g., 192.168.8.250)
- **Pi2 IP:** (e.g., 192.168.8.251)
- **VIP:** (e.g., 192.168.8.249) - This is what devices will use for DNS

---

## 🚀 Installation - Two Commands Per Pi!

### On Pi #1 (Primary):

```bash
# 1. Bootstrap the node
sudo bash <(curl -fsSL https://raw.githubusercontent.com/orionsentinel/Orion-sentinel-ha-dns/main/scripts/bootstrap-node.sh) \
  --node=pi1 --ip=192.168.8.250

# 2. Edit configuration
cd /opt/orion-dns-ha
sudo nano .env

# Set these values:
PIHOLE_PASSWORD=<generate with: openssl rand -base64 32>
VRRP_PASSWORD=<generate with: openssl rand -base64 20>
VIP_ADDRESS=192.168.8.249
HOST_IP=192.168.8.250
NODE_ROLE=MASTER
KEEPALIVED_PRIORITY=200
PEER_IP=192.168.8.251

# 3. Deploy
sudo make up-core
```

### On Pi #2 (Secondary):

```bash
# 1. Bootstrap the node
sudo bash <(curl -fsSL https://raw.githubusercontent.com/orionsentinel/Orion-sentinel-ha-dns/main/scripts/bootstrap-node.sh) \
  --node=pi2 --ip=192.168.8.251

# 2. Edit configuration (USE SAME PASSWORDS AS PI1!)
cd /opt/orion-dns-ha
sudo nano .env

# Set these values (passwords MUST match Pi1):
PIHOLE_PASSWORD=<SAME AS PI1>
VRRP_PASSWORD=<SAME AS PI1>
VIP_ADDRESS=192.168.8.249
HOST_IP=192.168.8.251
NODE_ROLE=BACKUP
KEEPALIVED_PRIORITY=150
PEER_IP=192.168.8.250

# 3. Deploy
sudo make up-core
```

---

## ✅ Verify It Works

### 1. Check Services Running

```bash
# On either Pi
docker ps

# You should see:
# - pihole_primary
# - unbound_primary
# - keepalived
```

### 2. Check VIP Assignment

```bash
# On Pi1 (should show VIP)
ip addr show | grep 192.168.8.249

# On Pi2 (should NOT show VIP - it's on standby)
ip addr show | grep 192.168.8.249
```

### 3. Test DNS

```bash
# From the Pi
dig @192.168.8.249 google.com

# Should return an IP address
```

### 4. Test Failover

```bash
# On Pi1, stop services
sudo make down

# Wait 5-10 seconds

# On Pi2, check VIP (should now have it)
ip addr show | grep 192.168.8.249

# Test DNS still works
dig @192.168.8.249 google.com

# Bring Pi1 back up
sudo make up-core
```

---

## 🎛️ Configure Your Devices

Point your devices to use the VIP for DNS:

### Router Configuration (Recommended)

**Most routers:** DHCP Settings → DNS Server → `192.168.8.249`

This automatically configures ALL devices on your network.

### Individual Device Configuration

**Windows:**
- Network Settings → Change Adapter Options
- Right-click adapter → Properties → IPv4
- Set DNS: `192.168.8.249`

**macOS:**
- System Preferences → Network → Advanced
- DNS tab → Add: `192.168.8.249`

**Linux:**
```bash
# Edit /etc/resolv.conf
nameserver 192.168.8.249
```

**iPhone/Android:**
- WiFi Settings → Configure DNS → Manual
- Add: `192.168.8.249`

---

## 🖥️ Access Pi-hole Admin

**URL:** http://192.168.8.250/admin (use Pi1's IP, or Pi2's IP)

**Password:** The PIHOLE_PASSWORD you set in .env

**What you can do:**
- View query statistics
- Add custom blocklists
- Whitelist/blacklist domains
- View query log
- Manage local DNS records

---

## 📊 Enable Monitoring (Optional)

Want to see pretty graphs?

```bash
# On one Pi (usually Pi1), edit .env:
DEPLOY_MONITORING=true

# Deploy exporters
make up-exporters

# Metrics available at:
# - Node metrics: http://192.168.8.250:9100/metrics
# - Pi-hole metrics: http://192.168.8.250:9617/metrics
# - Unbound metrics: http://192.168.8.250:9167/metrics

# Point your Prometheus at these endpoints
# Import dashboards from grafana_dashboards/
```

---

## 🔧 Common Commands

```bash
# Start services
make up-core

# Stop services
make down

# View logs
make logs

# Follow logs in real-time
make logs-follow

# Run health check
make health-check

# Backup configuration
make backup

# Restart services
make restart

# Update to latest version
make update

# Show all commands
make help
```

---

## 🐛 Troubleshooting

### DNS not working

```bash
# Check if containers are running
docker ps

# Check health
make health-check

# Check logs
make logs
```

### VIP not assigned

```bash
# Check keepalived
docker logs keepalived

# Verify config
cat .env | grep VIP
cat .env | grep VRRP
```

### Can't access Pi-hole admin

```bash
# Check Pi-hole container
docker ps | grep pihole

# Check logs
docker logs pihole_primary

# Verify password
cat .env | grep PIHOLE_PASSWORD
```

---

## 📖 Next Steps

Now that your HA DNS is running:

1. **Customize Blocklists**
   - Access Pi-hole admin
   - Add/remove blocklists as needed
   - Update gravity: Settings → Update Gravity

2. **Add Custom DNS Records**
   - Local DNS → Add record
   - Point `myserver.local` to `192.168.x.x`

3. **Setup Monitoring**
   - Enable exporters: `DEPLOY_MONITORING=true`
   - Deploy Grafana dashboard
   - Set up alerts

4. **Configure Backups**
   - Automatic backups enabled by default
   - Manual backup: `make backup`
   - Backups saved to `/opt/orion-dns-ha/backups/`

5. **Read Full Docs**
   - [README.production.md](README.production.md) - Complete guide
   - [docs/migration.md](docs/migration.md) - Migration from old setup
   - [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues

---

## ❓ FAQ

**Q: Do I need two Raspberry Pis?**
A: For high availability, yes. For testing/home use, one Pi works fine (set `DEPLOYMENT_MODE=single-pi-ha`).

**Q: What if one Pi fails?**
A: The VIP automatically moves to the healthy Pi. DNS keeps working. Your devices won't notice.

**Q: Can I use different Pi models?**
A: Yes, but both should have 4GB+ RAM for best performance.

**Q: Will this block ads on all devices?**
A: Yes, once you configure your router's DHCP to use the VIP as DNS.

**Q: How do I update?**
A: Run `make update` on each Pi. It pulls latest images and restarts.

**Q: Can I whitelist a domain?**
A: Yes, in Pi-hole admin: Whitelist → Add domain → Save

**Q: How much bandwidth does this use?**
A: Very little. DNS queries are tiny. Maybe 1-5 MB/day for a typical home.

**Q: Is my browsing data private?**
A: Yes! Unbound queries root DNS servers directly. No third-party sees your queries.

---

## 🆘 Getting Help

- **Health check:** `make health-check`
- **Logs:** `make logs`
- **Full docs:** [README.production.md](README.production.md)
- **Issues:** https://github.com/orionsentinel/Orion-sentinel-ha-dns/issues

---

**That's it! Your HA DNS stack is now protecting your entire network.** 🎉

Ads blocked ✅ | Privacy protected ✅ | High availability ✅
