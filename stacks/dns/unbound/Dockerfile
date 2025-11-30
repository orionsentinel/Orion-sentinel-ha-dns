# Unbound DNS Resolver with Smart Prefetch Configuration Support
# Based on klutchell/unbound with custom entrypoint for environment-based config
#
# Features:
# - Conditional smart prefetch configuration via UNBOUND_SMART_PREFETCH env var
# - NextDNS DoT forwarding (default) or full recursive resolution
# - DNSSEC validation and privacy hardening

FROM klutchell/unbound:latest

# Install bash for entrypoint script
USER root
RUN apk add --no-cache bash

# Copy configuration files
COPY unbound.conf /opt/unbound/etc/unbound/unbound.conf.base
COPY 30-performance-and-privacy.conf /opt/unbound/etc/unbound/30-performance-and-privacy.conf

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER unbound

ENTRYPOINT ["/entrypoint.sh"]
