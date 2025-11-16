# DNS-over-HTTPS (DoH) Configuration Guide

## Overview

This guide covers DNS encryption options for your Pi-hole stack. DoH encrypts DNS queries to prevent ISP snooping and MITM attacks.

## Option 1: Self-Hosted DoH (RECOMMENDED) 🏆

**Advantages:**
- ✅ **Complete Privacy**: No external logging, you control everything
- ✅ **Lower Latency**: Processes locally, no external round-trip
- ✅ **Full Control**: Choose your own upstream resolvers
- ✅ **No External Dependencies**: Works even if external services are down
- ✅ **Better for Privacy**: No data leaves your network until final upstream query

**Disadvantages:**
- ⚠️ Slightly more resource usage (~50MB RAM)
- ⚠️ Requires maintaining certificates

### Setup Self-Hosted DoH

1. **Deploy the DoH server:**
```bash
cd /opt/rpi-ha-dns-stack/stacks/dns
docker compose up -d doh-server
```

2. **Verify it's working:**
```bash
# Check DoH server is running
docker ps | grep doh-server

# Test DoH query
curl -H 'accept: application/dns-json' \
  'http://192.168.8.250:8053/dns-query?name=google.com&type=A'
```

3. **Configure Pi-hole to use it:**
Pi-hole already configured to use `192.168.8.250#8053` as upstream.

## Option 2: Cloudflare DoH

**Advantages:**
- ✅ **Zero Maintenance**: Cloudflare manages everything
- ✅ **High Performance**: CDN-backed, very fast
- ✅ **Proven Reliability**: 99.99% uptime
- ✅ **Minimal Resources**: Only ~20MB RAM

**Disadvantages:**
- ⚠️ **Privacy Concerns**: Cloudflare sees all your DNS queries
- ⚠️ **External Dependency**: Requires internet connectivity
- ⚠️ **Data Collection**: Cloudflare may log queries (even if they claim not to)

### Setup Cloudflare DoH

```bash
cd /opt/rpi-ha-dns-stack/stacks/dns
docker compose up -d cloudflared
```

## Option 3: No DoH (Unencrypted)

**Only use if:**
- You're on a trusted network (home LAN only, no internet exposure)
- Your ISP is trustworthy and doesn't do DNS manipulation
- You prioritize simplicity over privacy

## Comparison Matrix

| Feature | Self-Hosted | Cloudflare | None |
|---------|-------------|------------|------|
| Privacy | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐ |
| Performance | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Complexity | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Resources | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Control | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ |

## Recommended Configuration

**For Maximum Privacy (Home Network):**
```yaml
Pi-hole → Self-Hosted DoH → Quad9 (9.9.9.9 via DoH)
```

**For Best Performance (Any Network):**
```yaml
Pi-hole → Cloudflare DoH → Cloudflare DNS (1.1.1.1)
```

**For Simplicity (Trusted Network Only):**
```yaml
Pi-hole → Unbound (local recursive resolver)
```

## Current Setup

Your stack is configured for **Self-Hosted DoH** by default:

1. **doh-server** container runs on `192.168.8.250:8053`
2. Pi-hole forwards to doh-server
3. doh-server queries upstream via HTTPS
4. All DNS queries encrypted end-to-end

## Switching Between Options

### To Self-Hosted:
```bash
cd /opt/rpi-ha-dns-stack/stacks/dns
docker compose up -d doh-server
docker compose restart pihole_primary pihole_secondary
```

### To Cloudflare:
```bash
cd /opt/rpi-ha-dns-stack/stacks/dns
docker compose stop doh-server
docker compose up -d cloudflared
# Update Pi-hole DNS setting to: 192.168.8.250#5053
docker compose restart pihole_primary pihole_secondary
```

### To Direct (No DoH):
```bash
cd /opt/rpi-ha-dns-stack/stacks/dns
docker compose stop doh-server cloudflared
# Update Pi-hole DNS setting to: 192.168.8.253#5335
docker compose restart pihole_primary pihole_secondary
```

## Testing DNS Encryption

### Test DNS Leak
1. Visit https://dnsleaktest.com
2. Run "Extended Test"
3. Should show your DoH provider's DNS servers, not your ISP's

### Test with dig
```bash
# Query via DoH server
dig @192.168.8.250 -p 8053 google.com

# Should get response with encrypted upstream
```

### Verify in Dashboard
1. Go to http://192.168.8.250/dashboard.html
2. Click "Testing" tab
3. Use provided leak test links

## Security Considerations

### Self-Hosted DoH
- ✅ Encrypts queries between Pi-hole and upstream
- ✅ No third-party can see your queries
- ✅ Your ISP only sees encrypted HTTPS traffic
- ⚠️ Upstream DNS provider (Quad9, etc.) still sees queries
- ⚠️ Use reputable upstream providers (Quad9, AdGuard DNS, OpenDNS)

### Cloudflare DoH
- ✅ Encrypts queries
- ✅ Your ISP cannot see queries
- ⚠️ Cloudflare sees ALL your DNS queries
- ⚠️ Cloudflare claims not to log, but you must trust them
- ⚠️ Potential privacy concern for sensitive queries

### Best Practice
For maximum privacy:
1. Use Self-Hosted DoH
2. Use Quad9 as upstream (privacy-focused, blocks malware)
3. Enable DNSSEC validation
4. Use Pi-hole blocklists to reduce queries
5. Regular audit of query logs

## Upstream Provider Recommendations

**For Privacy:**
- Quad9 (9.9.9.9) - Privacy-focused, blocks malware, Switzerland-based
- AdGuard DNS (94.140.14.14) - Blocks ads, logs minimal data

**For Performance:**
- Cloudflare (1.1.1.1) - Fastest, but privacy concerns
- Google (8.8.8.8) - Fast, but Google tracks everything

**For Security:**
- Quad9 (9.9.9.9) - Blocks known malicious domains
- Cleanbrowsing (185.228.168.9) - Family-safe filtering

## Current Configuration

Your `docker-compose.yml` includes both options. By default:
- **doh-server** is enabled (self-hosted)
- Pi-hole upstream: `192.168.8.250#8053`
- Upstream resolvers: Quad9 (9.9.9.9, 149.112.112.112)

## Performance Impact

| Configuration | Query Time | Privacy | Security |
|---------------|------------|---------|----------|
| Direct (unbound) | 15-30ms | ⭐⭐ | ⭐⭐⭐⭐ |
| Self-Hosted DoH | 25-40ms | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Cloudflare DoH | 20-35ms | ⭐⭐⭐ | ⭐⭐⭐⭐ |

**Recommendation**: Use Self-Hosted DoH for best balance of privacy, performance, and control.

## Troubleshooting

### DoH not working
```bash
# Check doh-server logs
docker logs doh-server

# Test DoH endpoint
curl http://192.168.8.250:8053/dns-query?name=google.com

# Verify Pi-hole upstream
docker exec pihole_primary cat /etc/pihole/setupVars.conf | grep PIHOLE_DNS
```

### High latency
```bash
# Check doh-server resources
docker stats doh-server

# Test upstream connectivity
docker exec doh-server ping -c 4 9.9.9.9
```

## Further Reading

- DoH RFC: https://datatracker.ietf.org/doc/html/rfc8484
- DNS Privacy: https://dnsprivacy.org/
- Quad9 Privacy Policy: https://quad9.net/privacy/policy/
- Cloudflare Privacy: https://www.cloudflare.com/privacypolicy/
