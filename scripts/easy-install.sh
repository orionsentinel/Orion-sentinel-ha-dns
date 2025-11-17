#!/usr/bin/env bash
# Easy Install Script for RPi HA DNS Stack
# A robust, user-friendly installation script with proper error handling
# Usage: bash scripts/easy-install.sh [--verbose] [--skip-docker] [--force]

# Prevent exit on error initially - we'll handle errors gracefully
set -u

# Script directory and repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_STATE_FILE="$REPO_ROOT/.install_state"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
VERBOSE=false
SKIP_DOCKER=false
FORCE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --skip-docker)
            SKIP_DOCKER=true
            shift
            ;;
        --force|-f)
            FORCE=true
            shift
            ;;
        --help|-h)
            cat << EOF
Usage: bash scripts/easy-install.sh [OPTIONS]

A robust installation script for RPi HA DNS Stack with proper error handling.

OPTIONS:
    --verbose, -v       Enable verbose output for debugging
    --skip-docker       Skip Docker installation (assumes Docker is already installed)
    --force, -f         Force installation even if checks fail
    --help, -h          Show this help message

EXAMPLES:
    bash scripts/easy-install.sh                    # Normal installation
    bash scripts/easy-install.sh --verbose          # Verbose installation
    bash scripts/easy-install.sh --skip-docker      # Skip Docker installation
    bash scripts/easy-install.sh --force            # Force installation

EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Logging functions
log() { 
    echo -e "${GREEN}[✓]${NC} $*"
    [[ "$VERBOSE" == true ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $*" >> "$REPO_ROOT/install.log"
}

warn() { 
    echo -e "${YELLOW}[!]${NC} $*"
    [[ "$VERBOSE" == true ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARN: $*" >> "$REPO_ROOT/install.log"
}

err() { 
    echo -e "${RED}[✗]${NC} $*" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" >> "$REPO_ROOT/install.log"
}

info() { 
    echo -e "${BLUE}[i]${NC} $*"
    [[ "$VERBOSE" == true ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $*" >> "$REPO_ROOT/install.log"
}

section() { 
    echo ""
    echo -e "${CYAN}${BOLD}═══ $* ═══${NC}"
    echo ""
}

# Show banner
show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║    RPi High Availability DNS Stack - Easy Installer          ║
║                                                               ║
║    A robust installation with proper error handling          ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Save installation state
save_state() {
    local step="$1"
    echo "$step" > "$INSTALL_STATE_FILE"
    [[ "$VERBOSE" == true ]] && info "State saved: $step"
}

# Get installation state
get_state() {
    if [[ -f "$INSTALL_STATE_FILE" ]]; then
        cat "$INSTALL_STATE_FILE"
    else
        echo "not_started"
    fi
}

# Clear installation state
clear_state() {
    rm -f "$INSTALL_STATE_FILE"
}

# Safe exit handler
safe_exit() {
    local exit_code=$1
    local message="${2:-Installation interrupted}"
    
    if [[ $exit_code -ne 0 ]]; then
        err "$message"
        err "Installation failed at step: $(get_state)"
        echo ""
        info "You can try the following:"
        info "  1. Review the error messages above"
        info "  2. Check the log file: $REPO_ROOT/install.log"
        info "  3. Re-run the script - it will resume from the last successful step"
        info "  4. Use --verbose flag for more detailed output"
        info "  5. Seek help at: https://github.com/yorgosroussakis/rpi-ha-dns-stack/issues"
        echo ""
    fi
    
    exit "$exit_code"
}

# Trap interrupts and errors
trap 'safe_exit 130 "Installation interrupted by user"' INT TERM
trap 'safe_exit $? "An error occurred during installation"' ERR

# Check if running as root
check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        warn "This script should NOT be run as root"
        warn "It will use sudo when needed for specific commands"
        echo ""
        read -r -p "Continue anyway? (y/N): " response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            safe_exit 1 "Installation cancelled by user"
        fi
    fi
}

# Check system prerequisites
check_prerequisites() {
    section "Checking System Prerequisites"
    
    local all_checks_passed=true
    
    # Check OS
    if [[ "$(uname -s)" != "Linux" ]]; then
        err "This installer requires Linux (Raspberry Pi OS)"
        all_checks_passed=false
    else
        log "Running on Linux"
    fi
    
    # Check architecture
    local arch
    arch=$(uname -m)
    case "$arch" in
        aarch64|armv7l|x86_64)
            log "Architecture: $arch (supported)"
            ;;
        *)
            err "Unsupported architecture: $arch"
            all_checks_passed=false
            ;;
    esac
    
    # Check if Raspberry Pi (informational only)
    if [[ -f /proc/device-tree/model ]]; then
        local model
        model=$(tr -d '\0' < /proc/device-tree/model)
        log "Hardware: $model"
    else
        info "Not running on Raspberry Pi hardware (this is okay)"
    fi
    
    # Check disk space (minimum 5GB)
    local available_gb
    available_gb=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ "$available_gb" -lt 5 ]]; then
        err "Insufficient disk space: ${available_gb}GB available (minimum 5GB required)"
        all_checks_passed=false
    else
        log "Available disk space: ${available_gb}GB"
    fi
    
    # Check memory (minimum 2GB recommended)
    local total_mem_kb
    total_mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_mem_gb=$((total_mem_kb / 1024 / 1024))
    if [[ "$total_mem_gb" -lt 2 ]]; then
        warn "Low memory: ${total_mem_gb}GB detected (2GB+ recommended)"
        info "You can still proceed, but performance may be limited"
    else
        log "Total memory: ${total_mem_gb}GB"
    fi
    
    # Check network connectivity
    info "Checking network connectivity..."
    if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        log "Network connectivity verified"
    else
        err "No internet connectivity detected"
        err "Internet access is required for Docker installation"
        all_checks_passed=false
    fi
    
    # Check required commands
    local required_cmds=("git" "curl")
    for cmd in "${required_cmds[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            log "$cmd is installed"
        else
            err "$cmd is not installed"
            info "Install with: sudo apt-get install -y $cmd"
            all_checks_passed=false
        fi
    done
    
    if [[ "$all_checks_passed" == false ]]; then
        if [[ "$FORCE" == false ]]; then
            err "Some prerequisite checks failed"
            info "Fix the issues above or use --force to continue anyway"
            safe_exit 1 "Prerequisite checks failed"
        else
            warn "Some checks failed but continuing due to --force flag"
        fi
    fi
    
    save_state "prerequisites_checked"
    log "All prerequisite checks passed"
    echo ""
}

# Install Docker if needed
install_docker() {
    if [[ "$SKIP_DOCKER" == true ]]; then
        info "Skipping Docker installation (--skip-docker flag)"
        return 0
    fi
    
    section "Checking Docker Installation"
    
    # Check if Docker is installed
    if command -v docker >/dev/null 2>&1; then
        log "Docker is already installed"
        local docker_version
        docker_version=$(docker --version 2>/dev/null || echo "unknown")
        info "Version: $docker_version"
    else
        warn "Docker is not installed"
        echo ""
        info "This script will install Docker using the official convenience script"
        info "Source: https://get.docker.com"
        echo ""
        read -r -p "Do you want to install Docker? (Y/n): " response
        
        if [[ "$response" =~ ^[Nn]$ ]]; then
            err "Docker installation declined by user"
            err "Docker is required to run this stack"
            safe_exit 1 "Docker installation required"
        fi
        
        info "Installing Docker..."
        if curl -fsSL https://get.docker.com | sh; then
            log "Docker installed successfully"
        else
            err "Docker installation failed"
            safe_exit 1 "Failed to install Docker"
        fi
    fi
    
    # Check if Docker daemon is running
    if docker info >/dev/null 2>&1; then
        log "Docker daemon is running"
    else
        warn "Docker is installed but not running"
        info "Attempting to start Docker service..."
        
        if command -v systemctl >/dev/null 2>&1; then
            sudo systemctl start docker 2>/dev/null || true
            sleep 3
            
            if docker info >/dev/null 2>&1; then
                log "Docker daemon started successfully"
            else
                err "Failed to start Docker daemon"
                info "Try manually: sudo systemctl start docker"
                safe_exit 1 "Docker daemon not running"
            fi
        else
            err "Cannot start Docker (systemctl not available)"
            safe_exit 1 "Docker daemon not running"
        fi
    fi
    
    # Check Docker permissions
    if docker ps >/dev/null 2>&1; then
        log "Docker permissions verified"
    else
        warn "Current user lacks Docker permissions"
        info "Adding user to docker group..."
        
        if getent group docker >/dev/null 2>&1; then
            sudo usermod -aG docker "$USER" || true
            log "User added to docker group"
            echo ""
            warn "IMPORTANT: You need to log out and log back in for group changes to take effect"
            warn "Alternatively, run: newgrp docker"
            echo ""
            read -r -p "Press Enter after you've logged out and back in, or press Ctrl+C to exit..."
            
            # Verify permissions again
            if docker ps >/dev/null 2>&1; then
                log "Docker permissions now working"
            else
                err "Docker permissions still not working"
                err "Please log out and log back in, then run this script again"
                safe_exit 1 "Docker permission issue"
            fi
        else
            err "Docker group does not exist"
            safe_exit 1 "Docker group issue"
        fi
    fi
    
    # Check Docker Compose
    if docker compose version >/dev/null 2>&1; then
        log "Docker Compose plugin is available"
        local compose_version
        compose_version=$(docker compose version 2>/dev/null || echo "unknown")
        info "Version: $compose_version"
    else
        warn "Docker Compose plugin not found"
        info "Installing Docker Compose plugin..."
        
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update -qq
            if sudo apt-get install -y docker-compose-plugin; then
                log "Docker Compose plugin installed"
            else
                err "Failed to install Docker Compose plugin"
                safe_exit 1 "Docker Compose installation failed"
            fi
        else
            err "Cannot install Docker Compose (apt-get not available)"
            safe_exit 1 "Docker Compose not available"
        fi
    fi
    
    save_state "docker_installed"
    log "Docker installation complete"
    echo ""
}

# Choose installation method
choose_installation_method() {
    section "Choose Installation Method"
    
    echo "This stack provides two installation methods:"
    echo ""
    echo "  [1] Web Setup UI (Recommended)"
    echo "      • Modern web-based interface"
    echo "      • Easy-to-use step-by-step wizard"
    echo "      • Access from any device on your network"
    echo "      • Visual configuration and validation"
    echo ""
    echo "  [2] Terminal Setup"
    echo "      • Command-line interactive wizard"
    echo "      • Faster for experienced users"
    echo "      • No web browser required"
    echo ""
    
    while true; do
        read -r -p "Choose installation method (1 or 2): " method_choice
        
        case "$method_choice" in
            1)
                log "Selected: Web Setup UI"
                launch_web_ui
                break
                ;;
            2)
                log "Selected: Terminal Setup"
                launch_terminal_setup
                break
                ;;
            *)
                warn "Invalid choice. Please enter 1 or 2"
                ;;
        esac
    done
    
    save_state "installation_method_chosen"
}

# Launch web UI
launch_web_ui() {
    section "Launching Web Setup UI"
    
    local setup_ui_script="$REPO_ROOT/scripts/launch-setup-ui.sh"
    
    if [[ ! -f "$setup_ui_script" ]]; then
        err "Web Setup UI script not found: $setup_ui_script"
        err "The repository may be incomplete"
        safe_exit 1 "Missing setup UI script"
    fi
    
    info "Starting the web-based setup wizard..."
    
    # Run the launch script
    if bash "$setup_ui_script"; then
        save_state "web_ui_launched"
        log "Web Setup UI launched successfully"
        
        # Get the IP address
        local host_ip
        host_ip=$(hostname -I | awk '{print $1}')
        
        echo ""
        echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}${BOLD}   Web Setup UI is Ready!${NC}"
        echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${CYAN}Access the setup wizard at:${NC}"
        echo -e "  ${BOLD}http://localhost:5555${NC}"
        echo -e "  ${BOLD}http://$host_ip:5555${NC}"
        echo ""
        echo -e "${YELLOW}Follow the on-screen instructions to complete the installation.${NC}"
        echo ""
        echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
        echo ""
        
        clear_state
        log "Installation helper complete - continue in Web UI"
    else
        err "Failed to launch Web Setup UI"
        warn "You can try the terminal setup instead"
        echo ""
        read -r -p "Would you like to try terminal setup? (y/N): " response
        
        if [[ "$response" =~ ^[Yy]$ ]]; then
            launch_terminal_setup
        else
            safe_exit 1 "Web UI launch failed"
        fi
    fi
}

# Launch terminal setup
launch_terminal_setup() {
    section "Launching Terminal Setup"
    
    local terminal_setup_script="$REPO_ROOT/scripts/setup.sh"
    
    if [[ ! -f "$terminal_setup_script" ]]; then
        err "Terminal setup script not found: $terminal_setup_script"
        err "The repository may be incomplete"
        safe_exit 1 "Missing terminal setup script"
    fi
    
    info "Starting the terminal-based setup wizard..."
    echo ""
    
    # Run the terminal setup script
    if bash "$terminal_setup_script"; then
        save_state "terminal_setup_complete"
        log "Terminal setup completed successfully"
        clear_state
    else
        err "Terminal setup failed"
        safe_exit 1 "Terminal setup failed"
    fi
}

# Main installation flow
main() {
    show_banner
    
    echo "Welcome to the Easy Installer for RPi HA DNS Stack!"
    echo ""
    echo "This installer will:"
    echo "  1. Check your system prerequisites"
    echo "  2. Install Docker (if needed)"
    echo "  3. Launch the setup wizard of your choice"
    echo ""
    echo "The installation is safe and can be resumed if interrupted."
    echo ""
    
    if [[ "$VERBOSE" == true ]]; then
        info "Verbose mode enabled"
    fi
    
    if [[ "$FORCE" == true ]]; then
        warn "Force mode enabled - some checks will be skipped"
    fi
    
    echo ""
    read -r -p "Press Enter to begin installation or Ctrl+C to cancel..."
    
    # Check current state
    local current_state
    current_state=$(get_state)
    
    if [[ "$current_state" != "not_started" ]]; then
        info "Resuming installation from: $current_state"
    fi
    
    # Run installation steps
    check_not_root
    
    if [[ "$current_state" == "not_started" ]]; then
        check_prerequisites
    fi
    
    if [[ "$current_state" == "not_started" ]] || [[ "$current_state" == "prerequisites_checked" ]]; then
        install_docker
    fi
    
    choose_installation_method
    
    echo ""
    log "Easy Installer completed successfully!"
    echo ""
}

# Run main function
main "$@"
