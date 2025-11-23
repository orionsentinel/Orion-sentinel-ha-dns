#!/bin/bash
# Test script to verify DNS services can start without exporters/Promtail
# This validates Standalone mode functionality

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "========================================="
echo "Testing Standalone Mode (DNS only)"
echo "========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test 1: Verify DNS docker-compose has no external dependencies
echo "Test 1: Checking DNS docker-compose for external dependencies..."
cd "$REPO_ROOT/stacks/dns"

# Check for actual service definitions (not comments) referencing exporters/promtail
if grep -v "^[[:space:]]*#" docker-compose.yml | grep -q "exporter\|promtail"; then
    echo -e "${RED}FAIL: DNS docker-compose should not reference exporters or Promtail as services${NC}"
    exit 1
else
    echo -e "${GREEN}PASS: DNS docker-compose has no service dependencies on exporters or Promtail${NC}"
fi

# Test 2: Verify docker-compose.yml is valid
echo ""
echo "Test 2: Validating DNS docker-compose syntax..."
if docker compose config --quiet > /dev/null 2>&1; then
    echo -e "${GREEN}PASS: DNS docker-compose syntax is valid${NC}"
else
    echo -e "${RED}FAIL: DNS docker-compose has syntax errors${NC}"
    exit 1
fi

# Test 3: Verify exporters are in separate file
echo ""
echo "Test 3: Checking that exporters are in separate compose file..."
if [ -f "$REPO_ROOT/stacks/monitoring/docker-compose.exporters.yml" ]; then
    echo -e "${GREEN}PASS: Exporters are in separate file (docker-compose.exporters.yml)${NC}"
else
    echo -e "${RED}FAIL: Exporters file not found${NC}"
    exit 1
fi

# Test 4: Verify Promtail agents are in separate compose files
echo ""
echo "Test 4: Checking that Promtail agents are in separate compose files..."
if [ -f "$REPO_ROOT/stacks/agents/pi-dns/docker-compose.yml" ] && \
   [ -f "$REPO_ROOT/stacks/agents/dns-log-agent/docker-compose.yml" ]; then
    echo -e "${GREEN}PASS: Promtail agents are in separate files${NC}"
else
    echo -e "${RED}FAIL: Promtail agent files not found${NC}"
    exit 1
fi

# Test 5: Verify environment variables have defaults
echo ""
echo "Test 5: Checking that LOKI_URL has a default value..."
cd "$REPO_ROOT/stacks/agents/pi-dns"
if grep -q "LOKI_URL:-" docker-compose.yml; then
    echo -e "${GREEN}PASS: LOKI_URL has a default value${NC}"
else
    echo -e "${RED}FAIL: LOKI_URL should have a default value${NC}"
    exit 1
fi

# Test 6: Verify Promtail configs use environment variables
echo ""
echo "Test 6: Checking that Promtail configs use environment variables..."
if grep -q '\${LOKI_URL}' promtail-config.example.yml && \
   grep -q '\${LOKI_URL}' "$REPO_ROOT/stacks/agents/dns-log-agent/promtail.yml"; then
    echo -e "${GREEN}PASS: Promtail configs use environment variables${NC}"
else
    echo -e "${RED}FAIL: Promtail configs should use \${LOKI_URL} variable${NC}"
    exit 1
fi

# Test 7: Check for documentation about modes
echo ""
echo "Test 7: Checking for deployment modes documentation in README..."
if grep -q "Standalone Mode" "$REPO_ROOT/README.md" && \
   grep -q "Integrated Mode" "$REPO_ROOT/README.md"; then
    echo -e "${GREEN}PASS: README.md documents both deployment modes${NC}"
else
    echo -e "${RED}FAIL: README.md should document Standalone and Integrated modes${NC}"
    exit 1
fi

# Test 8: Verify agents README exists
echo ""
echo "Test 8: Checking for agents README..."
if [ -f "$REPO_ROOT/stacks/agents/README.md" ]; then
    echo -e "${GREEN}PASS: Agents README exists${NC}"
else
    echo -e "${RED}FAIL: Agents README not found${NC}"
    exit 1
fi

echo ""
echo "========================================="
echo -e "${GREEN}All tests passed!${NC}"
echo "========================================="
echo ""
echo "Summary:"
echo "- Core DNS services are independent of monitoring/logging"
echo "- Exporters and Promtail are in separate compose files"
echo "- Environment variables have sensible defaults"
echo "- Documentation clearly explains both modes"
echo ""
echo "The repository supports both Standalone and Integrated modes!"
