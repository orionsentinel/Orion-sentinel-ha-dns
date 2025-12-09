#!/bin/bash
# Unbound entrypoint script
# Generates final unbound.conf from base config and optional performance tuning
# Based on UNBOUND_SMART_PREFETCH environment variable

set -e

CONFIG_DIR="/opt/unbound/etc/unbound"
BASE_CONFIG="${CONFIG_DIR}/unbound.conf.base"
SMART_CONFIG="${CONFIG_DIR}/30-performance-and-privacy.conf"
FINAL_CONFIG="${CONFIG_DIR}/unbound.conf"

# Optional environment variable with default
UNBOUND_SMART_PREFETCH="${UNBOUND_SMART_PREFETCH:-0}"

echo "=========================================="
echo "Unbound Configuration"
echo "=========================================="
echo "UNBOUND_SMART_PREFETCH: ${UNBOUND_SMART_PREFETCH}"

# Start with base configuration
cp "${BASE_CONFIG}" "${FINAL_CONFIG}"

# Apply smart prefetch configuration if enabled
if [[ "${UNBOUND_SMART_PREFETCH}" == "1" ]] || [[ "${UNBOUND_SMART_PREFETCH}" == "true" ]]; then
    echo "Enabling smart prefetch and performance tuning..."
    
    # Append include directive to load the performance config
    echo "" >> "${FINAL_CONFIG}"
    echo "# Include smart prefetch and performance tuning (enabled via UNBOUND_SMART_PREFETCH)" >> "${FINAL_CONFIG}"
    echo "include: \"${SMART_CONFIG}\"" >> "${FINAL_CONFIG}"
    
    echo "Smart prefetch configuration enabled."
else
    echo "Smart prefetch configuration disabled (set UNBOUND_SMART_PREFETCH=1 to enable)."
fi

echo "=========================================="
echo "Final configuration applied."
echo "=========================================="

# Execute the original entrypoint from the base image
exec /usr/sbin/unbound -d -c "${FINAL_CONFIG}"
