# WireGuard VPN Front Door - Quick Start Guide

Add secure VPN access to your HA DNS stack in **5 minutes**!

## What This Does

Adds a **WireGuard VPN gateway** that integrates with your existing HA DNS infrastructure:

```
Internet → Your Router → WireGuard VPN → Your Devices
                              ↓
                         VIP (192.168.8.255)
                              ↓
                    Pi-hole HA + Unbound HA
                    (Automatic failover!)
```

**Key Benefits:**
- 🔒 Secure remote access to your home network
- 🚀 VPN clients automatically use your HA DNS (VIP 192.168.8.255)
- 📱 QR codes for instant phone setup
- 🌐 Access all home services remotely
- 🛡️ Ad-blocking everywhere via your Pi-hole

## Prerequisites

✅ Your HA DNS stack is running (Pi-hole + Unbound + Keepalived with VIP 192.168.8.255)  
✅ You have port forwarding access to your router  
✅ You know your public IP or have a DDNS hostname  

## Quick Setup (5 Minutes)

### Step 1: Configure Environment

```bash
cd /opt/rpi-ha-dns-stack/stacks/vpn

# Copy example config
cp .env.vpn.example .env.vpn

# Edit configuration
nano .env.vpn
```

**Minimal required changes:**
```bash
# Change this to your public IP or DDNS hostname
WG_HOST=myhome.duckdns.org  # or your public IP like 203.0.113.45

# Optional: Customize peer names (or leave as "3" for peer_1, peer_2, peer_3)
WG_PEERS=phone,laptop,tablet

# Optional: Set strong passwords
WGUI_PASSWORD=YourSecurePassword123!
WGUI_SESSION_SECRET=$(openssl rand -base64 32)
```

### Step 2: Configure Router Port Forwarding

Forward **UDP port 51820** from Internet to your Pi:

```
Router Settings:
  External Port: 51820 UDP
  Internal IP: 192.168.8.250 (your Pi)
  Internal Port: 51820
  Protocol: UDP
```

### Step 3: Deploy VPN Stack

```bash
# Deploy with Web UI (RECOMMENDED - includes QR codes)
docker compose -f docker-compose.vpn.yml --env-file .env.vpn --profile ui up -d

# Or deploy without UI (QR codes still generated as PNG files)
docker compose -f docker-compose.vpn.yml --env-file .env.vpn up -d
```

### Step 4: Get QR Codes for Mobile Devices

**Option A: Web UI (Easiest)**

1. Open browser: `http://192.168.8.250:5000`
2. Login with credentials from `.env.vpn`:
   - Username: `admin` (or your `WGUI_USERNAME`)
   - Password: (your `WGUI_PASSWORD`)
3. Click on a peer to see QR code
4. Scan with WireGuard mobile app!

**Option B: PNG Files**

```bash
# View QR code images
ls -la wireguard/config/peer_*/peer_*.png

# Display QR in terminal (requires qrencode)
cat wireguard/config/peer_phone/peer_phone.conf | qrencode -t ansiutf8
```

### Step 5: Connect Clients

#### Mobile (iOS/Android)

1. Install **WireGuard** app from App Store/Play Store
2. Open app → **Add Tunnel** → **Scan QR Code**
3. Scan the QR code from Step 4
4. Toggle connection **ON**
5. Done! ✅

#### Desktop (Windows/Mac/Linux)

1. Install **WireGuard** from [wireguard.com/install](https://www.wireguard.com/install/)
2. Get config file:
   ```bash
   # Copy config from Pi to your computer
   cat wireguard/config/peer_laptop/peer_laptop.conf
   ```
3. In WireGuard app: **Add Tunnel** → **Import from file**
4. Select the downloaded `.conf` file
5. **Activate** tunnel
6. Done! ✅

## Test Your VPN

Once connected:

```bash
# Test 1: Ping the VIP (HA DNS endpoint)
ping 192.168.8.255
# Should work! ✅

# Test 2: DNS resolution through Pi-hole
nslookup google.com 192.168.8.255
# Should resolve! ✅

# Test 3: Access Pi-hole admin
# Open browser: http://192.168.8.251/admin
# Should load! ✅

# Test 4: Check DNS is blocking ads
curl -I http://doubleclick.net
# Should be blocked by Pi-hole! ✅
```

## Architecture Details

### Network Flow

```
VPN Client (10.6.0.2)
    ↓
WireGuard Tunnel
    ↓
Pi (192.168.8.250)
    ↓
VIP (192.168.8.255) ← Keepalived HA
    ↓
├─→ Pi-hole Primary (192.168.8.251)
│      ↓
│   Unbound Primary (192.168.8.253)
│
└─→ Pi-hole Secondary (192.168.8.252) ← Automatic failover!
       ↓
    Unbound Secondary (192.168.8.254)
```

### Key Integration Points

1. **VIP DNS (192.168.8.255)**: VPN clients use the HA VIP for DNS
2. **Automatic Failover**: If Pi-hole Primary fails, VIP routes to Secondary
3. **Ad-Blocking**: All VPN traffic gets Pi-hole ad-blocking
4. **Recursive DNS**: Unbound provides privacy and caching

### Split Tunnel vs Full Tunnel

**Split Tunnel (Default - RECOMMENDED)**
```bash
WG_ALLOWEDIPS=192.168.8.0/24,10.6.0.0/24
```
- ✅ Only home network traffic goes through VPN
- ✅ Better performance (internet traffic direct)
- ✅ Lower battery usage on mobile
- ✅ Still get ad-blocking DNS everywhere!

**Full Tunnel**
```bash
WG_ALLOWEDIPS=0.0.0.0/0
```
- ✅ All traffic encrypted through home
- ✅ Maximum privacy
- ⚠️ Slower performance (limited by home upload speed)

## Common Operations

### View Logs

```bash
# WireGuard server logs
docker logs wireguard

# WireGuard-UI logs
docker logs wireguard-ui
```

### Add More Peers

**Option A: Via Web UI**

1. Go to `http://192.168.8.250:5000`
2. Click "Add Client"
3. Enter name, click "Create"
4. QR code appears instantly!

**Option B: Edit .env.vpn**

```bash
# Edit config
nano .env.vpn

# Change: WG_PEERS=phone,laptop,tablet
# To: WG_PEERS=phone,laptop,tablet,newdevice

# Restart
docker compose -f docker-compose.vpn.yml --env-file .env.vpn --profile ui restart
```

### Regenerate QR Codes

```bash
# QR codes are automatically generated on startup
# To regenerate, restart the container:
docker restart wireguard

# Or view existing QR in terminal:
cat wireguard/config/peer_phone/peer_phone.conf | qrencode -t ansiutf8
```

### Check Connected Clients

```bash
# Show active connections
docker exec wireguard wg show

# Example output:
# interface: wg0
#   peer: ABC123...
#     endpoint: 203.0.113.45:54321
#     latest handshake: 30 seconds ago
#     transfer: 1.2 MiB received, 856 KiB sent
```

### Stop/Remove VPN

```bash
# Stop VPN stack
docker compose -f docker-compose.vpn.yml --env-file .env.vpn down

# Remove including config (WARNING: deletes peer configs!)
docker compose -f docker-compose.vpn.yml --env-file .env.vpn down -v
rm -rf wireguard/
```

## Troubleshooting

### VPN Won't Connect

**Check 1: Port forwarding**
```bash
# Test from outside your network (use mobile data or https://www.yougetsignal.com)
# Port 51820 UDP should be open
```

**Check 2: Verify WG_HOST is correct**
```bash
# Check your current public IP
curl ifconfig.me

# Ensure WG_HOST in .env.vpn matches
grep WG_HOST .env.vpn
```

**Check 3: Check WireGuard logs**
```bash
docker logs wireguard
# Look for errors
```

### Can't Reach VIP (192.168.8.255)

**Check 1: Verify VIP is active**
```bash
# From the Pi itself
ping 192.168.8.255
# Should work!
```

**Check 2: Verify routing**
```bash
# Check WireGuard routing
docker exec wireguard ip route
# Should show route to 192.168.8.0/24
```

**Check 3: Verify ALLOWEDIPS includes your LAN**
```bash
grep WG_ALLOWEDIPS .env.vpn
# Should include: 192.168.8.0/24
```

### DNS Not Working on VPN

**Check 1: Verify DNS setting in peer config**
```bash
# Check a peer config file
cat wireguard/config/peer_phone/peer_phone.conf

# Should have:
# DNS = 192.168.8.255
```

**Check 2: Test DNS from VPN client**
```bash
# While connected to VPN:
nslookup google.com 192.168.8.255
# Should resolve!
```

**Check 3: Verify Pi-hole is running**
```bash
# Check Pi-hole status
docker ps | grep pihole
# Both primary and secondary should be running
```

### Web UI Not Accessible

**Check 1: Verify UI is running**
```bash
docker ps | grep wireguard-ui
# Should show container running
```

**Check 2: Check if deployed with --profile ui**
```bash
# Redeploy with UI profile
docker compose -f docker-compose.vpn.yml --env-file .env.vpn --profile ui up -d
```

**Check 3: Verify port 5000 is listening**
```bash
netstat -tuln | grep 5000
# Should show listening
```

## Security Best Practices

1. **Strong Passwords**: Use `openssl rand -base64 32` for passwords
2. **Limit Peers**: Only create configs for devices you own
3. **Regular Updates**: Keep WireGuard image updated
4. **Monitor Connections**: Regularly check `wg show` for active peers
5. **Revoke Access**: Remove peer configs when device is lost/retired
6. **Backup Configs**: Keep secure backups of wireguard/config/

## Integration with Existing Deployments

### For HighAvail_1Pi2P2U Users

Your VPN is now integrated! The VIP (192.168.8.255) automatically provides:
- ✅ Automatic failover between Pi-hole Primary/Secondary
- ✅ Load balancing across Unbound instances
- ✅ Self-healing from AI-Watchdog
- ✅ All observability metrics

### For Multi-Pi Deployments

Deploy VPN on your **primary** Pi only. The VIP will automatically:
- ✅ Route DNS to available Pi-holes across both Pis
- ✅ Maintain HA even if primary Pi fails
- ✅ Provide consistent DNS endpoint for VPN clients

## Advanced Configuration

### Custom VPN Subnet

```bash
# In .env.vpn
WG_SUBNET=10.13.13.0/24  # Change to avoid conflicts
```

### Custom DNS Servers

```bash
# Use specific Pi-hole instead of VIP
WG_PEER_DNS=192.168.8.251  # Primary only

# Use multiple DNS servers
WG_PEER_DNS=192.168.8.255,1.1.1.1  # VIP + Cloudflare backup
```

### Custom AllowedIPs

```bash
# Route only DNS queries through VPN
WG_ALLOWEDIPS=192.168.8.255/32

# Route multiple subnets
WG_ALLOWEDIPS=192.168.8.0/24,192.168.9.0/24,10.6.0.0/24
```

## What's Next?

Now that you have VPN access:

1. **Access Home Services**: Jellyfin, NAS, Home Assistant, etc.
2. **Remote Administration**: Manage Pi-hole, check Grafana dashboards
3. **Secure Public WiFi**: All traffic encrypted when away from home
4. **Ad-Blocking Everywhere**: Pi-hole blocks ads on all devices, anywhere

## Support

- **WireGuard Issues**: Check [WireGuard documentation](https://www.wireguard.com/)
- **Integration Issues**: See main stack [TROUBLESHOOTING.md](../../TROUBLESHOOTING.md)
- **Report Bugs**: [GitHub Issues](https://github.com/yorgosroussakis/rpi-ha-dns-stack/issues)

---

**🎉 Enjoy your HA DNS + VPN setup!**

Your VPN clients now benefit from:
- ✅ High Availability DNS
- ✅ Automatic Failover
- ✅ Ad-Blocking
- ✅ Privacy (Unbound)
- ✅ Self-Healing
- ✅ Secure Remote Access
