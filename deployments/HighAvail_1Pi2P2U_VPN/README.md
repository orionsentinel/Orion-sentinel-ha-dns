# HighAvail_1Pi2P2U_VPN - VPN Edition

**High Availability DNS Stack with WireGuard VPN Front Door**

Single Pi with:
- ✅ 2x Pi-hole (Primary/Secondary)
- ✅ 2x Unbound (Primary/Secondary)
- ✅ Keepalived VIP (192.168.8.255)
- ✅ **WireGuard VPN** with QR code setup
- ✅ Self-healing, observability, automation

## What Makes This the "VPN Edition"

This deployment adds **secure remote access** to your HA DNS stack via WireGuard VPN:

```
Internet → Your Router (port 51820) → WireGuard VPN Gateway
                                            ↓
                                    VIP (192.168.8.255)
                                            ↓
                              Pi-hole HA + Unbound HA
```

**Key Benefits:**
- 🌐 Access your home network from anywhere
- 🛡️ Ad-blocking on all devices, everywhere
- 🔒 Encrypted VPN tunnel
- 📱 QR codes for instant phone setup
- 🚀 Uses HA VIP for automatic DNS failover

## Quick Start (10 Minutes)

### Step 1-2: Configure

```bash
cp .env.example .env
cp .env.vpn.example .env.vpn

# Edit both files
nano .env        # Set PIHOLE_PASSWORD, VIP_ADDRESS=192.168.8.255
nano .env.vpn    # Set WG_HOST, WGUI_PASSWORD
```

### Step 3: Router Port Forward

Forward **UDP 51820** → **192.168.8.250**

### Step 4: Deploy

```bash
# Create network
docker network create --subnet=192.168.8.0/24 dns_net

# Deploy DNS + VPN
docker compose up -d
docker compose -f docker-compose.vpn.yml --env-file .env.vpn --profile ui up -d
```

### Step 5: Get QR Codes

Open `http://192.168.8.250:5000` → Login → View QR codes

### Step 6: Connect & Test

1. Scan QR with WireGuard app
2. Connect
3. `ping 192.168.8.255` ✅

**Full documentation in this README below!**
