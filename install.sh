#!/usr/bin/env bash
# Quick Install Script for RPi HA DNS Stack
# One-command installation for Raspberry Pi
# Usage: curl -fsSL https://raw.githubusercontent.com/yorgosroussakis/rpi-ha-dns-stack/main/install.sh | bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err() { echo -e "${RED}[✗]${NC} $*" >&2; }
info() { echo -e "${BLUE}[i]${NC} $*"; }
section() { echo -e "\n${CYAN}${BOLD}═══ $* ═══${NC}\n"; }

show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║    RPi High Availability DNS Stack - Quick Installer         ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

check_os() {
    section "Checking System"
    
    # Check if running on Linux
    if [[ "$(uname -s)" != "Linux" ]]; then
        err "This installer requires Linux (Raspberry Pi OS)"
        exit 1
    fi
    log "Running on Linux"
    
    # Check if running on Raspberry Pi
    if [[ -f /proc/device-tree/model ]]; then
        MODEL=$(cat /proc/device-tree/model | tr -d '\0')
        log "Detected: $MODEL"
    else
        warn "Not running on Raspberry Pi hardware (will continue anyway)"
    fi
    
    # Check architecture
    ARCH=$(uname -m)
    if [[ "$ARCH" != "aarch64" && "$ARCH" != "armv7l" && "$ARCH" != "x86_64" ]]; then
        err "Unsupported architecture: $ARCH"
        exit 1
    fi
    log "Architecture: $ARCH"
}

install_dependencies() {
    section "Installing Dependencies"
    
    # Check if running as root or with sudo
    if [[ $EUID -ne 0 ]]; then
        info "This script needs sudo privileges to install dependencies"
        SUDO="sudo"
    else
        SUDO=""
    fi
    
    # Update package list
    info "Updating package list..."
    $SUDO apt-get update -qq
    
    # Install required packages
    PACKAGES="git curl"
    info "Installing required packages: $PACKAGES"
    $SUDO apt-get install -y $PACKAGES
    log "Dependencies installed"
    
    # Install Docker if not present
    if ! command -v docker &> /dev/null; then
        info "Docker not found, installing..."
        curl -fsSL https://get.docker.com | $SUDO sh
        $SUDO usermod -aG docker "$USER" || true
        log "Docker installed"
        warn "You may need to log out and back in for Docker permissions to take effect"
    else
        log "Docker already installed"
    fi
    
    # Install Docker Compose if not present
    if ! docker compose version &> /dev/null; then
        info "Docker Compose plugin not found, installing..."
        $SUDO apt-get install -y docker-compose-plugin
        log "Docker Compose installed"
    else
        log "Docker Compose already installed"
    fi
}

clone_repository() {
    section "Cloning Repository"
    
    INSTALL_DIR="$HOME/rpi-ha-dns-stack"
    
    if [[ -d "$INSTALL_DIR" ]]; then
        warn "Directory $INSTALL_DIR already exists"
        read -r -p "Do you want to update it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cd "$INSTALL_DIR"
            git pull
            log "Repository updated"
        else
            info "Using existing repository"
        fi
    else
        info "Cloning repository to $INSTALL_DIR..."
        git clone https://github.com/yorgosroussakis/rpi-ha-dns-stack.git "$INSTALL_DIR"
        log "Repository cloned"
    fi
    
    cd "$INSTALL_DIR"
}

launch_web_ui() {
    section "Launching Web Setup UI"
    
    info "Starting the web-based setup wizard..."
    info "This will guide you through the configuration process"
    
    # Validate launch-setup-ui.sh exists
    if [[ ! -f "scripts/launch-setup-ui.sh" ]]; then
        err "scripts/launch-setup-ui.sh not found!"
        err "The setup UI script is missing from the repository."
        err "Please ensure you have cloned the complete repository."
        exit 1
    fi
    
    # Start the setup UI
    if ! bash scripts/launch-setup-ui.sh; then
        err "Failed to start the setup UI"
        warn "You can still proceed with manual installation using: bash scripts/install.sh"
        exit 1
    fi
    
    # Get the IP address
    HOST_IP=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}   Installation Complete!${NC}"
    echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}Access the Web Setup UI at:${NC}"
    echo -e "  ${BOLD}http://localhost:5555${NC}"
    echo -e "  ${BOLD}http://$HOST_IP:5555${NC}"
    echo ""
    echo -e "${CYAN}Or from any device on your network:${NC}"
    echo -e "  ${BOLD}http://$HOST_IP:5555${NC}"
    echo ""
    echo -e "${YELLOW}The setup wizard will guide you through:${NC}"
    echo -e "  • System prerequisites check"
    echo -e "  • Hardware survey"
    echo -e "  • Deployment option selection"
    echo -e "  • Node role configuration (for multi-Pi setups)"
    echo -e "  • Network configuration"
    echo -e "  • Security settings"
    echo -e "  • Signal notifications (optional)"
    echo ""
    echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
}

# Main execution
main() {
    show_banner
    
    echo -e "${CYAN}This installer will:${NC}"
    echo -e "  1. Check your system compatibility"
    echo -e "  2. Install required dependencies (Docker, Git)"
    echo -e "  3. Clone the RPi HA DNS Stack repository"
    echo -e "  4. Launch the web-based setup wizard"
    echo ""
    
    read -r -p "Press Enter to continue or Ctrl+C to cancel..."
    
    check_os
    install_dependencies
    clone_repository
    launch_web_ui
}

main "$@"
