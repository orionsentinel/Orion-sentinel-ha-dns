# Deployment Guide

> **📌 This page redirects to the main installation guide.**

For deployment instructions, please see:

- **[GETTING_STARTED.md](GETTING_STARTED.md)** — Quick start guide
- **[INSTALL.md](INSTALL.md)** — Comprehensive installation reference
- **[docs/install-single-pi.md](docs/install-single-pi.md)** — Single Pi deployment
- **[docs/install-two-pi-ha.md](docs/install-two-pi-ha.md)** — Two-Pi HA deployment

---

## Deployment Options

| Option | Description | Best For |
|--------|-------------|----------|
| **Single-Pi HA** | One Pi, container redundancy | Home labs, testing |
| **Two-Pi HA** | Two Pis, hardware redundancy | Production |
| **VPN Edition** | HA DNS + WireGuard | Remote access |

See **[deployments/](deployments/)** for detailed configurations.

---

## Quick Start

```bash
git clone https://github.com/orionsentinel/Orion-sentinel-ha-dns.git
cd Orion-sentinel-ha-dns
bash install.sh
```

Then open `http://<your-pi-ip>:5555` and follow the wizard.

## How to Deploy

### Option 1: Fresh Installation (Recommended)

1. **Clone the repository** (if not already done):
   ```bash
   git clone https://github.com/orionsentinel/Orion-sentinel-ha-dns.git
   cd rpi-ha-dns-stack
   ```

2. **Configure environment**:
   ```bash
   cp .env.example .env
   nano .env
   ```
   
   Update the following settings:
   - Set `PIHOLE_PASSWORD` to a secure password
   - Set `GRAFANA_ADMIN_PASSWORD` to a secure password
   - Set `VRRP_PASSWORD` to a secure password
   - Verify `NETWORK_INTERFACE=eth0` (change if your interface is different)
   - Optional: Configure Signal notifications

3. **Run the installation**:
   ```bash
   sudo bash scripts/install.sh
   ```

### Option 2: Update Existing Installation

1. **Stop and remove old containers**:
   ```bash
   cd /opt/rpi-ha-dns-stack/stacks/dns
   sudo docker compose down
   ```

2. **Remove old network** (if it exists):
   ```bash
   sudo docker network rm dns_net 2>/dev/null || true
   ```

3. **Pull latest code**:
   ```bash
   cd /opt/rpi-ha-dns-stack
   git pull origin main
   ```

4. **Update your .env file** with new IP addresses:
   ```bash
   nano .env
   ```
   
   Make sure these variables are set correctly:
   ```env
   HOST_IP=192.168.8.250
   PRIMARY_DNS_IP=192.168.8.251
   SECONDARY_DNS_IP=192.168.8.252
   UNBOUND_PRIMARY_IP=192.168.8.253
   UNBOUND_SECONDARY_IP=192.168.8.254
   VIP_ADDRESS=192.168.8.255
   NETWORK_INTERFACE=eth0
   SUBNET=192.168.8.0/24
   GATEWAY=192.168.8.1
   ```

5. **Deploy the updated stack**:
   ```bash
   cd /opt/rpi-ha-dns-stack/stacks/dns
   
   # Build the keepalived image
   sudo docker compose build keepalived
   
   # Pull other images and start
   sudo docker compose pull
   sudo docker compose up -d
   ```

## Verification

After deployment, verify everything is working:

### 1. Check container status:
```bash
sudo docker compose ps
```

All containers should show "Up" status (not "Restarting").

**Expected output:**
```
NAME                IMAGE                      STATUS
keepalived          dns-keepalived            Up (healthy)
pihole_primary      pihole/pihole:latest      Up (healthy)
pihole_secondary    pihole/pihole:latest      Up (healthy)
unbound_primary     mvance/unbound-rpi:latest Up (healthy)
unbound_secondary   mvance/unbound-rpi:latest Up (healthy)
```

### 2. Check network:
```bash
sudo docker network inspect dns_net | egrep 'Driver|Subnet|Gateway'
```

Should show:
- Driver: macvlan
- Subnet: 192.168.8.0/24
- Gateway: 192.168.8.1

### 3. Test connectivity:
**IMPORTANT:** Due to macvlan limitations, you cannot test from the Docker host. Use another device on your network.

```bash
# From ANOTHER device on your network (not the Raspberry Pi)

# Test individual Pi-hole instances
ping -c 2 192.168.8.251
ping -c 2 192.168.8.252

# Test VIP
ping -c 2 192.168.8.255

# Test DNS resolution
dig google.com @192.168.8.251
dig google.com @192.168.8.252
dig google.com @192.168.8.255
```

**From the Raspberry Pi host**, you can check logs instead:
```bash
# Check if services are responding
sudo docker exec pihole_primary dig @127.0.0.1 google.com
sudo docker exec unbound_primary drill @127.0.0.1 -p 5335 google.com
```

### 4. Access dashboards:
**IMPORTANT:** Access these from another device on your network (not from the Raspberry Pi itself due to macvlan limitations).

- **Pi-hole Primary**: http://192.168.8.251/admin
- **Pi-hole Secondary**: http://192.168.8.252/admin
- **Grafana**: http://192.168.8.250:3000 (host network, accessible from host)

## Troubleshooting

### Containers keep restarting:
```bash
# Check logs
sudo docker logs pihole_primary --tail=50
sudo docker logs unbound_primary --tail=50
sudo docker logs keepalived --tail=50
```

### Network issues:
```bash
# Verify interface exists
ip link show eth0

# Recreate network manually
sudo docker network create \
  -d macvlan \
  --subnet=192.168.8.0/24 \
  --gateway=192.168.8.1 \
  -o parent=eth0 \
  dns_net
```

### Can't reach containers from host:
**This is expected behavior with macvlan networks.** Containers on a macvlan network cannot communicate with the Docker host that created the network. This is a known Docker limitation, not a bug.

**Workaround options:**
1. **Access from another device** on your network (recommended)
   ```bash
   # From a different computer/device on your network
   ping 192.168.8.251
   dig google.com @192.168.8.251
   ```

2. **Create a macvlan shim** on the host (advanced):
   ```bash
   # Create a macvlan interface on the host
   sudo ip link add macvlan-shim link eth0 type macvlan mode bridge
   sudo ip addr add 192.168.8.250/32 dev macvlan-shim
   sudo ip link set macvlan-shim up
   sudo ip route add 192.168.8.251/32 dev macvlan-shim
   sudo ip route add 192.168.8.252/32 dev macvlan-shim
   sudo ip route add 192.168.8.255/32 dev macvlan-shim
   ```

**What works:**
- ✅ Containers can reach each other
- ✅ Containers can reach the internet
- ✅ Other devices on your network can reach the containers
- ✅ DNS queries from client devices work normally
- ❌ Host cannot directly ping/access containers (this is normal)

### DNS not working:
```bash
# Check if unbound is running
sudo docker exec unbound_primary drill @127.0.0.1 google.com

# Check if pihole can reach unbound
sudo docker exec pihole_primary dig @192.168.8.253 google.com
```

## Network Diagram

```plaintext
[192.168.8.250] <- Raspberry Pi Host (eth0)
     |
     |
[192.168.8.251] [192.168.8.252]
 Pi-hole 1       Pi-hole 2
     |               |
     v               v
[192.168.8.253] [192.168.8.254]
 Unbound 1       Unbound 2
     |               |
     +-------+-------+
             |
             v
     [192.168.8.255] <- VIP (Keepalived)
```

## Client Configuration

To use this DNS stack, configure your devices or DHCP server to use:
- **Primary DNS**: 192.168.8.255 (VIP - automatically fails over)
- **Secondary DNS**: 192.168.8.251 or 192.168.8.252 (direct access to Pi-hole)

## Notes

- The .250 IP range (192.168.8.250-255) is reserved for this DNS stack
- Make sure no other devices on your network are using these IPs
- The VIP (192.168.8.255) will automatically switch between the primary and secondary Pi-hole instances if one fails
- All containers use ARM64-compatible images and should run without "exec format error"
