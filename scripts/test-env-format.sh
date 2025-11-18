#!/usr/bin/env bash
# Test .env file format by sourcing it in a clean shell
# This helps catch syntax errors that could cause "command not found" errors

set -u
IFS=$'\n\t'

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || (cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd))"
ENV_FILE="$REPO_ROOT/.env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err() { echo -e "${RED}[✗]${NC} $*" >&2; }

if [[ ! -f "$ENV_FILE" ]]; then
    err ".env file not found at $ENV_FILE"
    exit 1
fi

log "Testing .env file format: $ENV_FILE"
echo ""

# Create a temporary test script that sources the .env file
TEST_SCRIPT=$(mktemp)
trap "rm -f $TEST_SCRIPT" EXIT

cat > "$TEST_SCRIPT" << 'EOF'
#!/usr/bin/env bash
set -u
set -e
IFS=$'\n\t'

ENV_FILE="$1"

# Try to source the .env file
if ! set -a; then
    echo "Failed to set export mode"
    exit 1
fi

if ! source "$ENV_FILE"; then
    echo "Failed to source .env file - syntax error detected"
    exit 1
fi

if ! set +a; then
    echo "Failed to unset export mode"
    exit 1
fi

echo "Successfully sourced .env file"
exit 0
EOF

chmod +x "$TEST_SCRIPT"

# Run the test in a subshell to isolate any errors
if output=$("$TEST_SCRIPT" "$ENV_FILE" 2>&1); then
    log "$output"
    log ".env file can be sourced without errors"
    echo ""
    log "Format test PASSED"
    exit 0
else
    err "Failed to source .env file"
    err "$output"
    echo ""
    err "Format test FAILED"
    err "The .env file has syntax errors that will cause issues when sourced"
    err "Common issues:"
    err "  - Unquoted values with special characters"
    err "  - Stray unmatched quotes"
    err "  - Variable names with invalid characters"
    err "  - Lines not matching KEY=VALUE format"
    exit 1
fi
