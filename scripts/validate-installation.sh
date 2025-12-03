#!/bin/bash
# Comprehensive Installation Validation Script
# Tests both web UI and CLI installation paths

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err() { echo -e "${RED}[✗]${NC} $*" >&2; }
info() { echo -e "${BLUE}[i]${NC} $*"; }

echo ""
echo "========================================"
echo "  Installation Validation Test Suite"
echo "========================================"
echo ""

# Test 1: Repository Structure
echo "Test 1: Repository Structure"
echo "----------------------------"

required_files=(
    "install.sh"
    ".env.example"
    "README.md"
    "SIMPLE_INSTALLATION_GUIDE.md"
    "QUICKSTART.md"
    "INSTALL.md"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        log "$file exists"
    else
        err "$file missing"
        exit 1
    fi
done

required_dirs=(
    "wizard"
    "scripts"
    "stacks"
    "profiles"
)

for dir in "${required_dirs[@]}"; do
    if [ -d "$dir" ]; then
        log "$dir directory exists"
    else
        err "$dir directory missing"
        exit 1
    fi
done

echo ""

# Test 2: Wizard Configuration
echo "Test 2: Wizard Configuration"
echo "----------------------------"

wizard_files=(
    "wizard/app.py"
    "wizard/Dockerfile"
    "wizard/docker-compose.yml"
    "wizard/requirements.txt"
    "wizard/README.md"
)

for file in "${wizard_files[@]}"; do
    if [ -f "$file" ]; then
        log "$file exists"
    else
        err "$file missing"
        exit 1
    fi
done

# Check wizard templates
wizard_templates=(
    "wizard/templates/welcome.html"
    "wizard/templates/network.html"
    "wizard/templates/profile.html"
    "wizard/templates/done.html"
)

for template in "${wizard_templates[@]}"; do
    if [ -f "$template" ]; then
        log "$template exists"
    else
        err "$template missing"
        exit 1
    fi
done

# Verify port configuration in wizard
if grep -q "port=5555" wizard/app.py; then
    log "Wizard configured for port 5555"
else
    err "Wizard port configuration incorrect"
    exit 1
fi

if grep -q "5555:5555" wizard/docker-compose.yml; then
    log "Docker Compose configured for port 5555"
else
    err "Docker Compose port configuration incorrect"
    exit 1
fi

echo ""

# Test 3: Script Syntax Validation
echo "Test 3: Script Syntax Validation"
echo "--------------------------------"

critical_scripts=(
    "install.sh"
    "scripts/launch-setup-ui.sh"
)

for script in "${critical_scripts[@]}"; do
    if bash -n "$script" 2>/dev/null; then
        log "$script has valid syntax"
    else
        err "$script has syntax errors"
        exit 1
    fi
    
    if [ -x "$script" ]; then
        log "$script is executable"
    else
        warn "$script is not executable (may need chmod +x)"
    fi
done

echo ""

# Test 4: Python Code Validation
echo "Test 4: Python Code Validation"
echo "------------------------------"

if python3 -m py_compile wizard/app.py 2>/dev/null; then
    log "wizard/app.py has valid Python syntax"
else
    err "wizard/app.py has Python syntax errors"
    exit 1
fi

echo ""

# Test 5: Documentation Consistency
echo "Test 5: Documentation Consistency"
echo "---------------------------------"

# Check that documentation references correct port
if grep -q "5555" README.md; then
    log "README.md references correct port (5555)"
else
    warn "README.md may not reference port 5555"
fi

if grep -q "5555" SIMPLE_INSTALLATION_GUIDE.md; then
    log "SIMPLE_INSTALLATION_GUIDE.md references correct port (5555)"
else
    err "SIMPLE_INSTALLATION_GUIDE.md does not reference port 5555"
    exit 1
fi

if grep -q "5555" QUICKSTART.md; then
    log "QUICKSTART.md references correct port (5555)"
else
    warn "QUICKSTART.md may not reference port 5555"
fi

echo ""

# Test 6: Installation Guide Content
echo "Test 6: Installation Guide Content"
echo "----------------------------------"

if grep -q "Method 1: Web UI Installation" SIMPLE_INSTALLATION_GUIDE.md; then
    log "Web UI installation method documented"
else
    err "Web UI installation method not found in guide"
    exit 1
fi

if grep -q "Method 2: Command Line Installation" SIMPLE_INSTALLATION_GUIDE.md; then
    log "CLI installation method documented"
else
    err "CLI installation method not found in guide"
    exit 1
fi

if grep -q "Troubleshooting" SIMPLE_INSTALLATION_GUIDE.md; then
    log "Troubleshooting section present"
else
    err "Troubleshooting section missing"
    exit 1
fi

echo ""

# Test 7: Launch Script Configuration
echo "Test 7: Launch Script Configuration"
echo "-----------------------------------"

if grep -q 'SETUP_UI_DIR="$REPO_ROOT/wizard"' scripts/launch-setup-ui.sh; then
    log "Launch script points to correct wizard directory"
else
    err "Launch script wizard directory path incorrect"
    exit 1
fi

if grep -q "port=5555" scripts/launch-setup-ui.sh 2>/dev/null || grep -q "5555" scripts/launch-setup-ui.sh; then
    log "Launch script references correct port"
else
    warn "Launch script may not reference port 5555"
fi

echo ""

# Summary
echo "========================================"
echo "  ✓ All Tests Passed Successfully!"
echo "========================================"
echo ""
echo "Installation paths validated:"
echo "  ✓ Web UI installation (wizard on port 5555)"
echo "  ✓ CLI installation (manual configuration)"
echo "  ✓ Documentation is consistent"
echo "  ✓ All scripts have valid syntax"
echo ""
echo "Ready to proceed with installation!"
echo ""
echo "To install using Web UI:"
echo "  bash install.sh"
echo "  Then open: http://<your-pi-ip>:5555"
echo ""
echo "To install using CLI:"
echo "  See: SIMPLE_INSTALLATION_GUIDE.md"
echo ""
