# NextDNS Integration Guide

This guide explains how to configure the Orion Sentinel DNS HA stack to use **NextDNS** as the primary upstream resolver instead of local Unbound recursion.

## Overview

By default, the DNS stack uses **Unbound** for full recursive DNS resolution on both nodes. This provides maximum privacy as DNS queries go directly to root servers without any third-party intermediary.

With **NextDNS integration**, you can:
- Use NextDNS's cloud-based DNS filtering and security features
- Maintain Unbound as a fallback on the secondary node for resilience
- Switch between NextDNS and Unbound-only modes via environment variables

## Architecture

### Default Mode (Unbound-only)

```
┌─────────────────────────────────────────────────────────────────┐
│                        LAN Clients                               │
│                            │                                     │
│                            ▼                                     │
│                    ┌──────────────┐                             │
│                    │   VIP (DNS)  │  ← Keepalived               │
│                    └──────┬───────┘                             │
│              ┌────────────┴────────────┐                        │
│              ▼                         ▼                        │
│     ┌────────────────┐        ┌────────────────┐               │
│     │ Pi-hole        │        │ Pi-hole        │               │
│     │ (Primary)      │        │ (Secondary)    │               │
│     └───────┬────────┘        └───────┬────────┘               │
│             │                         │                         │
│             ▼                         ▼                         │
│     ┌────────────────┐        ┌────────────────┐               │
│     │ Unbound        │        │ Unbound        │               │
│     │ (Primary)      │        │ (Secondary)    │               │
│     └───────┬────────┘        └───────┬────────┘               │
│             │                         │                         │
│             └───────────┬─────────────┘                        │
│                         ▼                                       │
│                  Root DNS Servers                               │
└─────────────────────────────────────────────────────────────────┘
```

### NextDNS Mode

```
┌─────────────────────────────────────────────────────────────────┐
│                        LAN Clients                               │
│                            │                                     │
│                            ▼                                     │
│                    ┌──────────────┐                             │
│                    │   VIP (DNS)  │  ← Keepalived (unchanged)   │
│                    └──────┬───────┘                             │
│              ┌────────────┴────────────┐                        │
│              ▼                         ▼                        │
│     ┌────────────────┐        ┌────────────────┐               │
│     │ Pi-hole        │        │ Pi-hole        │               │
│     │ (Primary)      │        │ (Secondary)    │               │
│     │                │        │                │               │
│     │ Upstream:      │        │ Upstream #1:   │               │
│     │ NextDNS        │        │ NextDNS        │               │
│     │                │        │ Upstream #2:   │               │
│     │                │        │ Unbound ←──────┼── Fallback    │
│     └───────┬────────┘        └───────┬────────┘               │
│             │                         │                         │
│             │                         ▼                         │
│             │                 ┌────────────────┐               │
│             │                 │ Unbound        │               │
│             │                 │ (Secondary)    │               │
│             │                 └───────┬────────┘               │
│             │                         │                         │
│             ▼                         ▼                         │
│         NextDNS                 Root DNS Servers               │
│         (Cloud)                 (Fallback only)                 │
└─────────────────────────────────────────────────────────────────┘
```

## Configuration

### Prerequisites

1. A paid **NextDNS** account (https://nextdns.io)
2. Your NextDNS profile ID and dedicated IP endpoints

### Step 1: Get Your NextDNS Endpoints

1. Log in to [my.nextdns.io](https://my.nextdns.io)
2. Select or create a profile
3. Go to the **Setup** tab
4. Find your dedicated IP endpoints:
   - IPv4: `45.90.28.xxx` and `45.90.30.xxx`
   - IPv6: `2a07:a8c0::xx:xxxx` and `2a07:a8c1::xx:xxxx`

### Step 2: Configure Environment Variables

Edit your `.env` file (e.g., `env/.env.two-pi-ha.example` or your active `.env`):

```bash
#####################################
# NEXTDNS CONFIGURATION
#####################################
# Enable NextDNS as primary upstream
NEXTDNS_ENABLED=true

# Your NextDNS Profile ID (for reference/documentation)
NEXTDNS_PROFILE_ID=abc123

# NextDNS IPv4 endpoint (required)
NEXTDNS_DNS_IPV4=45.90.28.123

# NextDNS IPv6 endpoint (optional)
NEXTDNS_DNS_IPV6=2a07:a8c0::ab:cd12

# Keep Unbound as fallback on secondary node (recommended)
UNBOUND_FALLBACK_SECONDARY=true

# Force Unbound-only mode (set to true to revert to original behavior)
UNBOUND_ONLY_MODE=false
```

### Step 3: Generate DNS Configuration

Before deploying, source the configuration script:

```bash
# Navigate to the repository
cd /opt/rpi-ha-dns-stack

# Generate and apply DNS configuration
source <(./scripts/configure-dns-upstream.sh)

# Verify the configuration
echo "Primary DNS: $PIHOLE_DNS_PRIMARY"
echo "Secondary DNS: $PIHOLE_DNS_SECONDARY"
```

### Step 4: Deploy the Stack

Deploy using your preferred profile:

```bash
# Single Pi HA mode
cd stacks/dns
docker compose --profile single-pi-ha up -d

# Two Pi HA mode (on Pi1)
docker compose --profile two-pi-ha-pi1 up -d

# Two Pi HA mode (on Pi2)
docker compose --profile two-pi-ha-pi2 up -d
```

## Environment Variables Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `NEXTDNS_ENABLED` | `false` | Enable NextDNS as primary upstream |
| `NEXTDNS_PROFILE_ID` | (empty) | Your NextDNS profile ID (for documentation) |
| `NEXTDNS_DNS_IPV4` | (empty) | NextDNS IPv4 endpoint (required when enabled) |
| `NEXTDNS_DNS_IPV6` | (empty) | NextDNS IPv6 endpoint (optional) |
| `NEXTDNS_DOH_URL` | (empty) | NextDNS DoH URL (for future DoH support) |
| `UNBOUND_FALLBACK_SECONDARY` | `true` | Keep Unbound as fallback on secondary node |
| `UNBOUND_ONLY_MODE` | `false` | Force Unbound-only mode (overrides NextDNS) |

## Behavior by Node

### Primary Node (Pi #1)

| Mode | Upstream Configuration |
|------|----------------------|
| Unbound-only (`NEXTDNS_ENABLED=false`) | Unbound (local recursion) |
| NextDNS (`NEXTDNS_ENABLED=true`) | NextDNS only |

### Secondary Node (Pi #2)

| Mode | Upstream Configuration |
|------|----------------------|
| Unbound-only | Unbound (local recursion) |
| NextDNS with fallback | NextDNS (primary) + Unbound (fallback) |
| NextDNS without fallback | NextDNS only |

## Switching Back to Unbound-Only Mode

To quickly revert to the original behavior (full local recursion):

### Option 1: Use UNBOUND_ONLY_MODE

```bash
# In your .env file
UNBOUND_ONLY_MODE=true
```

This overrides `NEXTDNS_ENABLED` without removing your NextDNS configuration.

### Option 2: Disable NextDNS

```bash
# In your .env file
NEXTDNS_ENABLED=false
```

### After Changing

```bash
# Regenerate configuration
source <(./scripts/configure-dns-upstream.sh)

# Restart Pi-hole containers
cd stacks/dns
docker compose --profile <your-profile> up -d
```

## Verifying NextDNS is Working

### Method 1: NextDNS Dashboard

1. Log in to [my.nextdns.io](https://my.nextdns.io)
2. Go to your profile's **Logs** tab
3. You should see DNS queries from your Pi-hole

### Method 2: NextDNS Test Page

1. From a device using your Pi-hole as DNS
2. Visit [test.nextdns.io](https://test.nextdns.io)
3. It should show your profile is active

### Method 3: Pi-hole Query Log

1. Open Pi-hole admin (http://192.168.8.251/admin or http://192.168.8.252/admin)
2. Go to **Query Log**
3. Look for upstream responses - they should come from the NextDNS IP

### Method 4: Command Line Test

```bash
# Test DNS resolution via Pi-hole
dig @192.168.8.251 example.com

# Check the upstream in Pi-hole settings
docker exec pihole_primary cat /etc/pihole/setupVars.conf | grep PIHOLE_DNS
```

## Troubleshooting

### NextDNS Not Working

1. **Check environment variables are set:**
   ```bash
   echo $NEXTDNS_ENABLED
   echo $NEXTDNS_DNS_IPV4
   ```

2. **Verify configuration was generated:**
   ```bash
   source <(./scripts/configure-dns-upstream.sh)
   ```

3. **Check Pi-hole container logs:**
   ```bash
   docker logs pihole_primary
   ```

4. **Verify network connectivity to NextDNS:**
   ```bash
   dig @45.90.28.123 example.com
   ```

### Unbound Fallback Not Working

1. **Verify Unbound is running on secondary:**
   ```bash
   docker ps | grep unbound_secondary
   ```

2. **Test Unbound directly:**
   ```bash
   dig @unbound_secondary -p 5335 example.com
   ```

3. **Check `UNBOUND_FALLBACK_SECONDARY` is true:**
   ```bash
   echo $UNBOUND_FALLBACK_SECONDARY
   ```

## Best Practices

1. **Keep Unbound fallback enabled** on the secondary node for resilience
2. **Test after configuration changes** to verify DNS is working
3. **Monitor NextDNS dashboard** for query logs and security events
4. **Use NextDNS's own analytics** in addition to Pi-hole stats

## Security Considerations

- **Privacy tradeoff:** NextDNS sees your DNS queries (unlike local Unbound recursion)
- **NextDNS encryption:** Consider using DoH/DoT for encrypted DNS to NextDNS
- **Account security:** Secure your NextDNS account with 2FA
- **Fallback privacy:** Unbound fallback maintains privacy when NextDNS is unavailable

## Related Documentation

- [DNS Stack Deployment](../README.md)
- [Two-Pi HA Installation](install-two-pi-ha.md)
- [Health & HA Guide](health-and-ha.md)
- [Troubleshooting](../TROUBLESHOOTING.md)
