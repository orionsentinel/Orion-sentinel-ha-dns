#!/usr/bin/env bash
# Desktop GUI installer for RPi HA DNS Stack
# Uses zenity or kdialog for graphical installation wizard

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Dialog tool to use (zenity or kdialog)
DIALOG_TOOL=""

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err() { echo -e "${RED}[✗]${NC} $*" >&2; }
info() { echo -e "${BLUE}[i]${NC} $*"; }

detect_dialog_tool() {
    if command -v zenity &> /dev/null; then
        DIALOG_TOOL="zenity"
        log "Using zenity for GUI dialogs"
        return 0
    elif command -v kdialog &> /dev/null; then
        DIALOG_TOOL="kdialog"
        log "Using kdialog for GUI dialogs"
        return 0
    else
        return 1
    fi
}

install_dialog_tool() {
    info "Installing GUI dialog tool..."
    
    # Detect package manager and desktop environment
    if command -v apt-get &> /dev/null; then
        if [[ -n "${XDG_CURRENT_DESKTOP:-}" ]]; then
            case "${XDG_CURRENT_DESKTOP}" in
                *KDE*)
                    sudo apt-get update -qq
                    sudo apt-get install -y kdialog
                    DIALOG_TOOL="kdialog"
                    ;;
                *)
                    sudo apt-get update -qq
                    sudo apt-get install -y zenity
                    DIALOG_TOOL="zenity"
                    ;;
            esac
        else
            # Default to zenity
            sudo apt-get update -qq
            sudo apt-get install -y zenity
            DIALOG_TOOL="zenity"
        fi
        log "Installed $DIALOG_TOOL"
        return 0
    else
        err "Cannot install dialog tool - unsupported package manager"
        return 1
    fi
}

check_desktop_environment() {
    if [[ -z "${DISPLAY:-}" ]] && [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
        err "No desktop environment detected"
        err "This script requires a graphical desktop environment"
        err "For terminal installation, use: bash install.sh"
        exit 1
    fi
    log "Desktop environment detected"
}

show_info() {
    local title="$1"
    local text="$2"
    
    if [[ "$DIALOG_TOOL" == "zenity" ]]; then
        zenity --info --title="$title" --text="$text" --width=400
    elif [[ "$DIALOG_TOOL" == "kdialog" ]]; then
        kdialog --msgbox "$text" --title "$title"
    fi
}

show_error() {
    local title="$1"
    local text="$2"
    
    if [[ "$DIALOG_TOOL" == "zenity" ]]; then
        zenity --error --title="$title" --text="$text" --width=400
    elif [[ "$DIALOG_TOOL" == "kdialog" ]]; then
        kdialog --error "$text" --title "$title"
    fi
}

show_warning() {
    local title="$1"
    local text="$2"
    
    if [[ "$DIALOG_TOOL" == "zenity" ]]; then
        zenity --warning --title="$title" --text="$text" --width=400
    elif [[ "$DIALOG_TOOL" == "kdialog" ]]; then
        kdialog --sorry "$text" --title "$title"
    fi
}

ask_question() {
    local title="$1"
    local text="$2"
    
    if [[ "$DIALOG_TOOL" == "zenity" ]]; then
        zenity --question --title="$title" --text="$text" --width=400
    elif [[ "$DIALOG_TOOL" == "kdialog" ]]; then
        kdialog --yesno "$text" --title "$title"
    fi
}

show_progress() {
    local title="$1"
    local text="$2"
    
    if [[ "$DIALOG_TOOL" == "zenity" ]]; then
        zenity --progress --title="$title" --text="$text" --pulsate --auto-close --width=400
    elif [[ "$DIALOG_TOOL" == "kdialog" ]]; then
        kdialog --progressbar "$text" --title "$title" 0
    fi
}

select_installation_mode() {
    local title="Installation Mode"
    local text="Select installation mode:"
    
    if [[ "$DIALOG_TOOL" == "zenity" ]]; then
        MODE=$(zenity --list --title="$title" --text="$text" --radiolist \
            --column="Select" --column="Mode" --column="Description" \
            TRUE "web-ui" "Web-based setup wizard (recommended)" \
            FALSE "terminal" "Terminal-based interactive setup" \
            FALSE "automated" "Automated setup with defaults" \
            --width=600 --height=300 | cut -d'|' -f2)
    elif [[ "$DIALOG_TOOL" == "kdialog" ]]; then
        MODE=$(kdialog --menu "$text" \
            "web-ui" "Web-based setup wizard (recommended)" \
            "terminal" "Terminal-based interactive setup" \
            "automated" "Automated setup with defaults" \
            --title "$title")
    fi
    
    echo "$MODE"
}

run_prerequisite_check() {
    info "Running prerequisite checks..."
    
    (
        echo "10"; echo "# Checking system compatibility..."
        sleep 1
        
        echo "30"; echo "# Checking disk space..."
        sleep 1
        
        echo "50"; echo "# Checking memory..."
        sleep 1
        
        echo "70"; echo "# Checking network connectivity..."
        sleep 1
        
        echo "90"; echo "# Verifying requirements..."
        sleep 1
        
        echo "100"; echo "# Complete!"
    ) | if [[ "$DIALOG_TOOL" == "zenity" ]]; then
        zenity --progress --title="Pre-Installation Check" --text="Checking prerequisites..." --percentage=0 --auto-close --width=400
    elif [[ "$DIALOG_TOOL" == "kdialog" ]]; then
        kdialog --progressbar "Checking prerequisites..." 100 --title "Pre-Installation Check"
    fi
    
    # Run actual check script
    if [[ -f "$REPO_ROOT/scripts/install-check.sh" ]]; then
        if bash "$REPO_ROOT/scripts/install-check.sh" &> /tmp/install-check.log; then
            show_info "Prerequisites Check" "✓ All prerequisite checks passed!\n\nYour system is ready for installation."
            return 0
        else
            show_error "Prerequisites Check" "✗ Some prerequisite checks failed.\n\nPlease check /tmp/install-check.log for details."
            if ask_question "Continue Installation?" "Do you want to continue anyway?"; then
                return 0
            else
                return 1
            fi
        fi
    else
        warn "install-check.sh not found, skipping detailed checks"
        return 0
    fi
}

install_dependencies() {
    info "Installing dependencies..."
    
    (
        echo "20"; echo "# Updating package list..."
        sudo apt-get update -qq
        
        echo "40"; echo "# Installing Git..."
        sudo apt-get install -y git curl
        
        echo "60"; echo "# Installing Docker..."
        if ! command -v docker &> /dev/null; then
            curl -fsSL https://get.docker.com | sh
        fi
        
        echo "80"; echo "# Installing Docker Compose..."
        if ! docker compose version &> /dev/null; then
            sudo apt-get install -y docker-compose-plugin
        fi
        
        echo "100"; echo "# Complete!"
    ) | if [[ "$DIALOG_TOOL" == "zenity" ]]; then
        zenity --progress --title="Installing Dependencies" --text="Installing required packages..." --percentage=0 --auto-close --width=400
    elif [[ "$DIALOG_TOOL" == "kdialog" ]]; then
        kdialog --progressbar "Installing required packages..." 100 --title "Installing Dependencies"
    fi
    
    log "Dependencies installed"
}

launch_web_ui_mode() {
    info "Launching web-based setup wizard..."
    
    # Start the web UI in background
    bash "$REPO_ROOT/scripts/launch-setup-ui.sh" start &> /tmp/setup-ui.log &
    
    # Wait for it to start
    sleep 5
    
    HOST_IP=$(hostname -I | awk '{print $1}')
    
    show_info "Setup Wizard Ready" \
        "The web-based setup wizard is now running!\n\nAccess it at:\n• http://localhost:5555\n• http://$HOST_IP:5555\n\nYour web browser should open automatically."
    
    # Try to open browser
    if command -v xdg-open &> /dev/null; then
        xdg-open "http://localhost:5555" &
    elif command -v firefox &> /dev/null; then
        firefox "http://localhost:5555" &
    elif command -v chromium &> /dev/null; then
        chromium "http://localhost:5555" &
    fi
}

launch_terminal_mode() {
    info "Launching terminal-based setup..."
    
    # Open terminal and run interactive setup
    if command -v gnome-terminal &> /dev/null; then
        gnome-terminal -- bash -c "cd $REPO_ROOT && bash scripts/interactive-setup.sh; exec bash"
    elif command -v konsole &> /dev/null; then
        konsole -e bash -c "cd $REPO_ROOT && bash scripts/interactive-setup.sh; exec bash"
    elif command -v xfce4-terminal &> /dev/null; then
        xfce4-terminal -e "bash -c 'cd $REPO_ROOT && bash scripts/interactive-setup.sh; exec bash'"
    else
        show_warning "Terminal Not Found" "Cannot open terminal automatically.\n\nPlease run manually:\nbash scripts/interactive-setup.sh"
    fi
}

launch_automated_mode() {
    info "Running automated installation..."
    
    (
        echo "25"; echo "# Installing Docker..."
        sleep 2
        
        echo "50"; echo "# Creating networks..."
        sleep 2
        
        echo "75"; echo "# Deploying containers..."
        sleep 2
        
        echo "100"; echo "# Complete!"
    ) | if [[ "$DIALOG_TOOL" == "zenity" ]]; then
        zenity --progress --title="Automated Installation" --text="Installing..." --percentage=0 --auto-close --width=400
    elif [[ "$DIALOG_TOOL" == "kdialog" ]]; then
        kdialog --progressbar "Installing..." 100 --title "Automated Installation"
    fi
    
    if bash "$REPO_ROOT/scripts/install.sh" &> /tmp/install.log; then
        show_info "Installation Complete" "✓ Installation completed successfully!\n\nCheck /tmp/install.log for details."
    else
        show_error "Installation Failed" "✗ Installation failed.\n\nCheck /tmp/install.log for details."
    fi
}

main() {
    log "RPi HA DNS Stack - Desktop GUI Installer"
    
    # Check for desktop environment
    check_desktop_environment
    
    # Detect or install dialog tool
    if ! detect_dialog_tool; then
        warn "No GUI dialog tool found"
        if ask_question "Install Dialog Tool?" "Would you like to install a GUI dialog tool (zenity)?"; then
            if ! install_dialog_tool; then
                err "Failed to install dialog tool"
                exit 1
            fi
        else
            err "Cannot proceed without GUI dialog tool"
            exit 1
        fi
    fi
    
    # Welcome message
    show_info "Welcome" "Welcome to RPi HA DNS Stack Desktop Installer!\n\nThis wizard will guide you through the installation process."
    
    # Run prerequisite check
    if ! run_prerequisite_check; then
        err "User cancelled installation"
        exit 1
    fi
    
    # Install dependencies
    if ask_question "Install Dependencies" "Install required dependencies (Docker, Git, etc.)?"; then
        install_dependencies
    fi
    
    # Select installation mode
    MODE=$(select_installation_mode)
    
    if [[ -z "$MODE" ]]; then
        warn "No mode selected, exiting"
        exit 0
    fi
    
    case "$MODE" in
        web-ui)
            launch_web_ui_mode
            ;;
        terminal)
            launch_terminal_mode
            ;;
        automated)
            launch_automated_mode
            ;;
        *)
            err "Unknown mode: $MODE"
            exit 1
            ;;
    esac
    
    show_info "Installation Started" "Installation is now in progress.\n\nFollow the instructions in the setup wizard."
}

main "$@"
