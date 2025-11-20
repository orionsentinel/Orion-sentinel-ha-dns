#!/bin/bash
# Docker healthcheck wrapper for Orion Sentinel DNS HA
# This script is designed to be used in Docker HEALTHCHECK directives
# It calls the Python health checker and returns appropriate exit codes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HEALTH_CHECKER="$SCRIPT_DIR/health_checker.py"

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    echo "ERROR: python3 not found"
    exit 2
fi

# Check if health checker script exists
if [ ! -f "$HEALTH_CHECKER" ]; then
    echo "ERROR: health_checker.py not found at $HEALTH_CHECKER"
    exit 2
fi

# Run the health checker in quiet mode
# Exit code 0 = healthy
# Exit code 1 = degraded (some checks failed but system functional)
# Exit code 2 = unhealthy (critical failure)
python3 "$HEALTH_CHECKER" --quiet --format json

exit $?
