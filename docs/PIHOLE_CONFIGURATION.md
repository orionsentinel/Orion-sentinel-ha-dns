# Pi-hole DNS Configuration Guide

## ⚠️ IMPORTANT: Privacy-First DNS Policy

This project **strictly requires** the use of **Unbound** (local recursive resolver) or **NextDNS** as the only upstream DNS providers for Pi-hole.

**DO NOT use public DNS resolvers** such as:
- ❌ Google DNS (8.8.8.8, 8.8.4.4)
- ❌ Cloudflare DNS (1.1.1.1, 1.0.0.1)
- ❌ OpenDNS (208.67.222.222, 208.67.220.220)
- ❌ Quad9 (9.9.9.9, 149.112.112.112)
- ❌ Any other third-party public DNS provider

---

## Why Only Unbound or NextDNS?

### Privacy Rationale

Using public DNS resolvers exposes your entire DNS query history to third parties. Every website you visit, every service you use, and every device on your network sends DNS queries that can be logged, analyzed, and potentially monetized.

| DNS Provider | Data Collection | Privacy Risk |
|--------------|-----------------|--------------|
| **Google DNS** | Logged for 24-48 hours, used for analytics | 🔴 High - ties to Google account |
| **Cloudflare DNS** | Claims "no logging" but anonymized data collected | 🟠 Medium - third-party trust required |
| **OpenDNS** | Full logging, used for threat intelligence | 🔴 High - owned by Cisco |
| **Quad9** | Anonymized logging for security research | 🟠 Medium - third-party trust |
| **Unbound (Local)** | No external queries to third parties | 🟢 **Maximum Privacy** |
| **NextDNS** | User-controlled logging, configurable privacy | 🟢 **User-Controlled Privacy** |

### Why Unbound?

**Unbound** is a validating, recursive, and caching DNS resolver that queries authoritative DNS servers directly, eliminating the need for third-party DNS providers entirely.

**Benefits:**
- 🔒 **Complete Privacy**: DNS queries go directly to authoritative servers (e.g., .com, .org root servers)
- ✅ **DNSSEC Validation**: Built-in cryptographic verification of DNS responses
- ⚡ **Performance**: Local caching reduces latency for repeated queries
- 🛡️ **No Third-Party Trust**: You control the entire DNS resolution chain
- 📊 **No Logging by Third Parties**: Your DNS history stays on your network

### Why NextDNS (As the Only Alternative)?

**NextDNS** is the only acceptable cloud alternative because:

- 🔐 **Encrypted Transport**: Uses DNS-over-TLS (DoT) or DNS-over-HTTPS (DoH)
- 🎛️ **User-Controlled Privacy**: You decide what gets logged (or disable logging entirely)
- 🌍 **Privacy-Focused Company**: Swiss-based with strong privacy commitments
- 📱 **Profile-Specific Endpoints**: Your traffic is isolated from other users
- 🚫 **No Data Selling**: Explicit policy against selling user data

---

## Allowed DNS Configurations

### Option 1: Unbound (Recommended - Maximum Privacy)

This is the **default configuration** for all Orion Sentinel DNS deployments.

**How it works:**
```
Client → Pi-hole (filtering) → Unbound (recursive) → Authoritative DNS Servers
```

**Environment Configuration:**
```bash
# Pi-hole upstream DNS (pointing to local Unbound)
PIHOLE_DNS1=127.0.0.1#5335
PIHOLE_DNS2=127.0.0.1#5335

# Or using Docker service names
PIHOLE_DNS_PRIMARY=unbound_primary#5335
PIHOLE_DNS_SECONDARY=unbound_secondary#5335
```

**What this means:**
- Pi-hole forwards all DNS queries to local Unbound instance(s)
- Unbound queries authoritative DNS servers directly
- No third-party DNS provider sees your queries
- DNSSEC validation is performed locally

### Option 2: NextDNS over DoT (User-Controlled Privacy)

Use this if you want cloud-based filtering with privacy controls.

**How it works:**
```
Client → Pi-hole (filtering) → Unbound (forwarder) → NextDNS (DoT encrypted) → Authoritative DNS
```

**Environment Configuration:**
```bash
# Enable NextDNS integration
NEXTDNS_ENABLED=true

# Your NextDNS profile-specific IPv4 endpoint
# Get this from: https://my.nextdns.io → Setup Guide → Endpoints
# Replace with your actual profile IP (e.g., 45.90.28.123)
NEXTDNS_IPV4=<YOUR_PROFILE_IP>

# Optional: IPv6 endpoint (if your network supports it)
NEXTDNS_IPV6=2a07:a8c0::xx:xxxx

# DoT port and hostname for TLS verification
NEXTDNS_DOT_PORT=853
NEXTDNS_HOSTNAME=dns.nextdns.io
```

**NextDNS Privacy Configuration (Recommended Settings):**

1. **Logs**: Set to "Disabled" or "1 hour retention" for maximum privacy
2. **Analytics**: Set to "Minimal" or "Disabled"
3. **Storage Location**: Choose a privacy-friendly region
4. **Block Page**: Disable if not needed (reduces tracking)

---

## Disallowed DNS Configurations

The following configurations are **NOT supported** and should **NEVER** be used:

### ❌ Public DNS as Pi-hole Upstream

```bash
# DO NOT USE THESE!
PIHOLE_DNS1=8.8.8.8        # Google DNS
PIHOLE_DNS2=1.1.1.1        # Cloudflare DNS
PIHOLE_DNS1=208.67.222.222 # OpenDNS
PIHOLE_DNS2=9.9.9.9        # Quad9
```

### ❌ Mixed Public/Private DNS

```bash
# DO NOT MIX like this!
PIHOLE_DNS1=127.0.0.1#5335  # Good (Unbound)
PIHOLE_DNS2=8.8.8.8         # BAD - Leaks queries to Google
```

### ❌ Direct DoH/DoT to Public Providers

```bash
# DO NOT configure Unbound to forward to public resolvers!
# Even encrypted, these still expose your queries to third parties.
forward-addr: 1.1.1.1@853   # BAD - Cloudflare DoT
forward-addr: 8.8.8.8@853   # BAD - Google DoT
```

---

## Configuration Reference

### Single-Node Setup

```bash
# In your .env file:
PIHOLE_DNS1=127.0.0.1#5335
PIHOLE_DNS2=127.0.0.1#5335
```

### Two-Node HA Setup

```bash
# In your .env file (same on both nodes):
PIHOLE_DNS_PRIMARY=unbound_primary#5335
PIHOLE_DNS_SECONDARY=unbound_secondary#5335
```

### With NextDNS Enabled

```bash
# In your .env file:
NEXTDNS_ENABLED=true
NEXTDNS_IPV4=<YOUR_PROFILE_IP>  # Replace with your profile IP (e.g., 45.90.28.123)
NEXTDNS_DOT_PORT=853
NEXTDNS_HOSTNAME=dns.nextdns.io

# Unbound will forward to NextDNS over DoT automatically
# Pi-hole still points to Unbound
PIHOLE_DNS1=127.0.0.1#5335
```

---

## Verifying Your Configuration

### Check Pi-hole Upstream Settings

1. Access Pi-hole web interface: `http://<PIHOLE_IP>/admin`
2. Navigate to: **Settings → DNS**
3. Verify **only** these are checked:
   - ✅ Custom 1 (IPv4): `127.0.0.1#5335`
   - ✅ Custom 2 (IPv4): `127.0.0.1#5335` (for HA setups)
4. Verify **none** of these are checked:
   - ❌ Google (ECS, DNSSEC)
   - ❌ OpenDNS (ECS, DNSSEC)
   - ❌ Quad9 (...)
   - ❌ Cloudflare (DNSSEC)
   - ❌ Any other preset provider

### Check Unbound is Working

```bash
# Test Unbound directly
dig @127.0.0.1 -p 5335 google.com

# Test DNSSEC validation
dig @127.0.0.1 -p 5335 cloudflare.com +dnssec

# Test a DNSSEC-signed failing domain (should return SERVFAIL)
dig @127.0.0.1 -p 5335 dnssec-failed.org
```

### Check No Third-Party DNS Leaks

```bash
# Check outgoing DNS traffic (should only see queries to root/TLD servers)
# Run on your Pi while making DNS queries
sudo tcpdump -i eth0 port 53 -n

# You should NOT see traffic to:
# - 8.8.8.8 or 8.8.4.4 (Google)
# - 1.1.1.1 or 1.0.0.1 (Cloudflare)
# - 208.67.222.222 or 208.67.220.220 (OpenDNS)
# - 9.9.9.9 or 149.112.112.112 (Quad9)
```

---

## FAQ

### Q: Why can't I use Cloudflare DNS? It's privacy-focused!

**A:** While Cloudflare markets itself as privacy-focused, you're still trusting a third party with your complete DNS query history. With Unbound, no single entity sees all your queries - they're distributed across authoritative servers.

### Q: Is NextDNS really better than other cloud DNS?

**A:** NextDNS gives you **control** over logging and privacy settings. You can disable logging entirely, making it effectively a privacy-respecting forwarder with filtering capabilities. Other providers don't offer this level of user control.

### Q: Won't Unbound be slower than cloud DNS?

**A:** Initially, Unbound may have slightly higher latency for uncached queries. However:
- Cached queries are **faster** (local)
- Prefetching eliminates most latency for popular domains
- Privacy is worth the milliseconds

### Q: What if I need parental controls?

**A:** Use NextDNS with filtering enabled, or use Pi-hole's blocklists. Don't compromise on privacy by using other cloud DNS providers.

### Q: Can I use Pi-hole's built-in DNS provider options?

**A:** **No.** Always use "Custom" and point to Unbound. The built-in options (Google, Cloudflare, etc.) send your queries to third parties.

---

## Related Documentation

- [INSTALLATION_GUIDE.md](../INSTALLATION_GUIDE.md) - Complete installation instructions
- [README.md](../README.md) - Project overview and quick start
- [docs/orion-dns-nextdns-v1.1.md](orion-dns-nextdns-v1.1.md) - Detailed NextDNS setup guide
- [SECURITY_GUIDE.md](../SECURITY_GUIDE.md) - Security best practices
