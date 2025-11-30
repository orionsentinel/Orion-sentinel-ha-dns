# Keepalived Configuration Templates for Two-Pi HA Mode

This directory contains ready-to-use keepalived configuration templates for the two-Pi high availability DNS setup.

## Files

| File | Description |
|------|-------------|
| `keepalived.pi1.conf` | Configuration for Pi1 (MASTER node) |
| `keepalived.pi2.conf` | Configuration for Pi2 (BACKUP node) |
| `keepalived.template.conf` | Template with environment variable placeholders |

## Quick Start

### Option 1: Use with Docker Compose Override (Recommended)

1. Copy the appropriate config for your Pi to your local directory
2. Replace placeholder values:
   - `<VRRP_PASSWORD>` with your actual password
   - Update IP addresses if different from defaults
3. Create a `docker-compose.override.yml` to mount the config:

```yaml
# On Pi1: stacks/dns/docker-compose.override.yml
services:
  keepalived:
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./keepalived.pi1.conf:/etc/keepalived/keepalived.conf:ro
    entrypoint: ["keepalived", "--dont-fork", "--log-console", "--log-detail"]
```

4. Deploy: `docker compose --profile two-pi-ha-pi1 up -d`

### Option 2: Use Environment Variables (Dynamic)

The default setup uses environment variables to generate the keepalived config at runtime.

Set these in your `.env` file:
```bash
VIP_ADDRESS=192.168.8.249
HOST_IP=192.168.8.250  # This Pi's IP
PI1_IP=192.168.8.250
PI2_IP=192.168.8.251
VRRP_PASSWORD=your_secure_password
NETWORK_INTERFACE=eth0
KEEPALIVED_PRIORITY=100  # 100 for Pi1, 90 for Pi2
```

Then deploy normally: `docker compose --profile two-pi-ha-pi1 up -d`

### Option 3: Use envsubst

Generate a config from the template:

```bash
export VIP_ADDRESS=192.168.8.249
export HOST_IP=192.168.8.250
export PEER_IP=192.168.8.251
export VRRP_PASSWORD=your_password
export NETWORK_INTERFACE=eth0
export KEEPALIVED_PRIORITY=100
export KEEPALIVED_STATE=MASTER
export ROUTER_ID=pi1-dns

envsubst < keepalived.template.conf > keepalived.conf
```

## Default IP Addresses

The template files use these default addresses:

| Variable | Pi1 Value | Pi2 Value |
|----------|-----------|-----------|
| HOST_IP | 192.168.8.250 | 192.168.8.251 |
| VIP | 192.168.8.249 | 192.168.8.249 |
| PEER_IP | 192.168.8.251 | 192.168.8.250 |
| PRIORITY | 100 (MASTER) | 90 (BACKUP) |

Adjust these to match your network configuration.

## Troubleshooting

### Check if config is valid

```bash
# View the config inside the container
docker exec keepalived cat /etc/keepalived/keepalived.conf

# Check keepalived logs for parse errors
docker logs keepalived | grep -E "(error|Error|unknown|Unknown)"
```

### Common Issues

1. **"Unknown keyword" errors**: The config has syntax problems
2. **VIP not appearing**: Check interface name and VIP address
3. **Both Pis are MASTER**: VRRP_PASSWORD must match exactly

See [install-two-pi-ha.md](../../../docs/install-two-pi-ha.md) for detailed troubleshooting.
