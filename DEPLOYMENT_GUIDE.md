# Deployment Guide for Fixed DNS Stack

## What Was Fixed

This update resolves critical issues preventing the DNS stack from running on Raspberry Pi (ARM64):

### 1. Architecture Issues ✅
**Problem**: The original docker-compose.yml used AMD64-only images, causing "exec format error" on ARM64 Raspberry Pi.

**Solution**: 
- Switched to `mvance/unbound-rpi:latest` (ARM64-compatible)
- Switched to `ghcr.io/rmartin16/keepalived:v2.2.7` (ARM64-compatible)
- Pi-hole already supports ARM64

### 2. Network Configuration Issues ✅
**Problem**: The network was showing as "bridge" instead of "macvlan" because docker-compose.yml didn't define the network properly.

**Solution**: Added proper macvlan network definition with IPAM:
```yaml
networks:
  dns_net:
    driver: macvlan
    driver_opts:
      parent: ${NETWORK_INTERFACE:-eth0}
    ipam:
      config:
        - subnet: ${SUBNET:-192.168.8.0/24}
          gateway: ${GATEWAY:-192.168.8.1}
          ip_range: 192.168.8.250/28
```

### 3. IP Address Conflicts ✅
**Problem**: Multiple containers were trying to use the same IP addresses:
- pihole_primary and unbound_primary both used .241
- pihole_secondary and unbound_secondary both used .242

**Solution**: Assigned unique IPs in the .250 range:
- **pihole_primary**: 192.168.8.251
- **pihole_secondary**: 192.168.8.252
- **unbound_primary**: 192.168.8.253
- **unbound_secondary**: 192.168.8.254
- **keepalived VIP**: 192.168.8.255

### 4. Keepalived Configuration ✅
**Problem**: Keepalived needs special network access for VRRP to work.

**Solution**: Changed to host network mode with required capabilities:
```yaml
keepalived:
  network_mode: host
  cap_add:
    - NET_ADMIN
    - NET_BROADCAST
    - NET_RAW
```

## How to Deploy

### Option 1: Fresh Installation (Recommended)

1. **Clone the repository** (if not already done):
   ```bash
   git clone https://github.com/yorgosroussakis/rpi-ha-dns-stack.git
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

### 2. Check network:
```bash
sudo docker network inspect dns_net | egrep 'Driver|Subnet|Gateway'
```

Should show:
- Driver: macvlan
- Subnet: 192.168.8.0/24
- Gateway: 192.168.8.1

### 3. Test connectivity:
```bash
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

### 4. Access dashboards:
- **Pi-hole Primary**: http://192.168.8.251/admin
- **Pi-hole Secondary**: http://192.168.8.252/admin
- **Grafana**: http://192.168.8.250:3000

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
This is a known limitation of macvlan. Containers can reach each other and the network, but the host cannot directly reach containers on the same macvlan network. To work around this:

1. Access Pi-hole from another device on your network
2. Or, create a macvlan bridge on the host (advanced - see Docker documentation)

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
