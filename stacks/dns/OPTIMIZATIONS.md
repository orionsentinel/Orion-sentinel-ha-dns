# DNS Stack Optimizations

## Simplifications Based on Community Best Practices

This document explains the optimizations made to the Pi-hole + Unbound DNS stack based on research of popular GitHub implementations.

### 1. YAML Anchors in docker-compose.yml

**Problem:** Duplicate configuration for similar services (pihole_primary/secondary, unbound_primary/secondary)

**Solution:** Use YAML anchors (`x-pihole-common`, `x-unbound-common`) to define common configuration once and reference it multiple times.

**Benefits:**
- Reduced file size (190 lines → ~170 lines)
- Easier maintenance - change once, apply everywhere
- Consistent configuration across instances
- Industry standard Docker Compose pattern

**Example:**
```yaml
x-pihole-common: &pihole-common
  image: pihole/pihole:latest
  restart: unless-stopped
  # ... common settings

services:
  pihole_primary:
    <<: *pihole-common
    # Instance-specific overrides
```

### 2. Unified Unbound Configuration

**Problem:** Duplicate unbound configs in `unbound1/` and `unbound2/` directories

**Solution:** Single shared `unbound/unbound.conf` used by both instances

**Benefits:**
- Single source of truth for DNS configuration
- Easier updates - modify one file instead of two
- Reduced maintenance burden
- Consistent security and performance settings

**Migration:** The install script automatically migrates existing configs to the new structure.

### 3. Enhanced Unbound Settings

Added modern best practices:
- **Privacy**: `qname-minimisation`, `aggressive-nsec`
- **Performance**: `serve-expired`, `minimal-responses`, `rrset-roundrobin`
- **Security**: Comprehensive access-control lists for all private networks
- **Buffer Optimization**: `so-rcvbuf` and `so-sndbuf` for better throughput

### 4. Resource Optimization

**Current Settings (Optimized for Pi 3/4/5):**
- Pi-hole: 512M limit, 128M reservation
- Unbound: 256M limit, 64M reservation
- Keepalived: 128M limit, 32M reservation

**For Low-Memory Systems (1-2GB RAM):**
Edit `unbound.conf`:
```yaml
msg-cache-size: 25m
rrset-cache-size: 50m
```

**For High-Memory Systems (4GB+ RAM):**
Edit `unbound.conf`:
```yaml
msg-cache-size: 100m
rrset-cache-size: 200m
num-threads: 4
```

### 5. Healthcheck Improvements

**Pi-hole:** DNS query test ensures DNS resolution works
**Unbound:** Port check ensures service is listening
**Keepalived:** Process check ensures VRRP is running

All use appropriate intervals and timeouts for production use.

### 6. Optional Components

**Cloudflared** (DNS-over-HTTPS):
- Included but optional
- Can be removed if not using DoH
- Adds ~64MB memory overhead

**To disable:** Comment out the `cloudflared` service in `docker-compose.yml`

## Migration from Old Structure

The system automatically handles migration:

1. **Old structure** (still supported):
   ```
   stacks/dns/unbound1/unbound.conf
   stacks/dns/unbound2/unbound.conf
   ```

2. **New structure** (recommended):
   ```
   stacks/dns/unbound/unbound.conf  (shared)
   ```

The install script will:
- Create the new `unbound/` directory
- Copy existing config if found
- Use shared config for both instances

## Performance Benefits

### Before:
- 190 lines in docker-compose.yml
- 2 separate unbound configs to maintain
- 25+ shellcheck warnings
- Manual config synchronization

### After:
- ~170 lines in docker-compose.yml (11% reduction)
- 1 unified unbound config
- Clean shellcheck validation
- Automatic consistency

## Best Practices Applied

Based on analysis of popular implementations:

1. **pi-hole/docker-pi-hole** - Official Pi-hole Docker patterns
2. **MatthewVance/unbound-docker** - Unbound optimization techniques
3. **chriscrowe/docker-pihole-unbound** - Integration patterns
4. **IAmStoxe/wirehole** - HA patterns with WireGuard

### Key Takeaways:
- ✅ Use YAML anchors for DRY (Don't Repeat Yourself)
- ✅ Single source configs where possible
- ✅ Proper healthchecks with appropriate intervals
- ✅ Resource limits for predictable behavior
- ✅ Security-first defaults (DNSSEC, access control)
- ✅ Privacy-enhancing features enabled
- ✅ Performance tuning for Raspberry Pi hardware

## Compatibility

All changes are backward compatible:
- Old unbound1/unbound2 directories still work
- Automatic migration on next install
- No manual intervention required

## References

- Docker Compose Anchors: https://docs.docker.com/compose/compose-file/#extension-fields
- Unbound Documentation: https://nlnetlabs.nl/documentation/unbound/
- Pi-hole Docker: https://github.com/pi-hole/docker-pi-hole
- DNSSEC Best Practices: https://www.nlnetlabs.nl/documentation/unbound/howto-optimise/
