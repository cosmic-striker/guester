#!/usr/bin/env bash

# Exit Immediately if a command fails
set -o errexit

readonly REPO_DIR="$(dirname "$(readlink -m "${0}")")"
# source "${REPO_DIR}/core.sh"  # Uncomment if core.sh exists

usage() {
cat << EOF

Usage: $0 [OPTION]...

Guster Gesture Daemon - Installation Script

OPTIONS:
  -i, --install   Install Guster daemon and dependencies (default)
  -r, --remove    Remove/Uninstall Guster daemon
  -t, --test      Test installation without making changes
  -d, --dry-run   Show what would be done without executing
  -h, --help      Show this help

EOF
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root. Please run as a regular user."
        exit 1
    fi
}

# Detect package manager
detect_package_manager() {
    if command -v apt &> /dev/null; then
        echo "apt"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v pacman &> /dev/null; then
        echo "pacman"
    else
        print_error "Unsupported package manager. This script supports apt, dnf, and pacman."
        exit 1
    fi
}

# Install dependencies
install_dependencies() {
    local pm=$(detect_package_manager)
    print_info "Detected package manager: $pm"

    case $pm in
        apt)
            print_info "Updating package list..."
            sudo apt update
            print_info "Installing dependencies..."
            sudo apt install -y libinput-tools python3-yaml xdotool wmctrl
            ;;
        dnf)
            print_info "Installing dependencies..."
            sudo dnf install -y libinput-tools python3-yaml xdotool wmctrl
            ;;
        pacman)
            print_info "Installing dependencies..."
            sudo pacman -S --noconfirm libinput python-yaml xdotool wmctrl
            ;;
    esac

    print_success "Dependencies installed successfully"
}

# Install daemon
install_daemon() {
    print_info "Installing Guster daemon..."

    sudo cp "${REPO_DIR}/guster-daemon.py" /usr/local/bin/guster-daemon.py
    sudo chmod +x /usr/local/bin/guster-daemon.py

    print_success "Daemon installed to /usr/local/bin/guster-daemon.py"
}

# Setup systemd service
setup_service() {
    print_info "Setting up systemd service..."

    mkdir -p ~/.config/systemd/user

    cat > ~/.config/systemd/user/guster.service << EOF
[Unit]
Description=Guster Gesture Daemon
After=graphical.target

[Service]
Type=simple
Environment=DISPLAY=:0
ExecStart=/usr/local/bin/guster-daemon.py
Restart=on-failure

[Install]
WantedBy=default.target
EOF

    print_success "Systemd service created at ~/.config/systemd/user/guster.service"
}

# Enable and start service
enable_service() {
    print_info "Enabling and starting Guster service..."

    systemctl --user daemon-reload
    systemctl --user enable --now guster.service

    print_success "Service enabled and started"
}

# Test installation
test_installation() {
    print_info "Testing installation..."

    if python3 /usr/local/bin/guster-daemon.py --test; then
        print_success "Installation test passed!"
    else
        print_error "Installation test failed!"
        return 1
    fi
}

# Remove installation
remove_installation() {
    print_info "Removing Guster daemon..."

    # Stop and disable service
    systemctl --user stop guster.service 2>/dev/null || true
    systemctl --user disable guster.service 2>/dev/null || true

    # Remove service file
    rm -f ~/.config/systemd/user/guster.service

    # Remove daemon
    sudo rm -f /usr/local/bin/guster-daemon.py

    # Remove config (ask user?)
    if [[ -d ~/.config/guster ]]; then
        read -p "Remove configuration directory ~/.config/guster? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf ~/.config/guster
            print_info "Configuration removed"
        fi
    fi

    print_success "Guster daemon removed successfully"
}

# Show post-installation info
show_post_install() {
    echo
    print_success "🎉 Guster Gesture Daemon installation completed!"
    echo
    echo "📋 What was installed:"
    echo "  • Core daemon: /usr/local/bin/guster-daemon.py"
    echo "  • Configuration: ~/.config/guster/config.yml"
    echo "  • Systemd service: ~/.config/systemd/user/guster.service"
    echo
    echo "🛠️  Useful commands:"
    echo "  • Check status: systemctl --user status guster.service"
    echo "  • View logs: journalctl --user -u guster.service -f"
    echo "  • Restart: systemctl --user restart guster.service"
    echo "  • Stop: systemctl --user stop guster.service"
    echo
    echo "⚙️  Configuration:"
    echo "  • Edit config: nano ~/.config/guster/config.yml"
    echo "  • Test gestures: python3 /usr/local/bin/guster-daemon.py --test"
    echo
    echo "📚 For more information, see: README.md"
}

# Dry run function
dry_run() {
    print_info "DRY RUN MODE - No changes will be made"
    echo
    echo "Would perform the following actions:"
    echo "  • Update package list"
    echo "  • Install dependencies: libinput-tools, python3-yaml, xdotool, wmctrl"
    echo "  • Copy guster-daemon.py to /usr/local/bin/"
    echo "  • Create systemd service at ~/.config/systemd/user/guster.service"
    echo "  • Enable and start guster.service"
    echo "  • Test installation"
    echo
    print_info "Run without --dry-run to perform actual installation"
}

#######################################################
#   :::::: A R G U M E N T   H A N D L I N G ::::::   #
#######################################################

install='true'
remove='false'
test_mode='false'
dry_run_mode='false'

while [[ $# -gt 0 ]]; do
  case "${1}" in
    -i|--install)
      install='true'
      remove='false'
      shift
      ;;
    -r|--remove)
      remove='true'
      install='false'
      shift
      ;;
    -t|--test)
      test_mode='true'
      shift
      ;;
    -d|--dry-run)
      dry_run_mode='true'
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      print_error "ERROR: Unrecognized option '$1'."
      print_info "Try '$0 --help' for more information."
      exit 1
      ;;
  esac
done

#############################
#   :::::: M A I N ::::::   #
#############################

if [[ "${dry_run_mode}" == 'true' ]]; then
    dry_run
    exit 0
fi

if [[ "${remove}" == 'true' ]]; then
    check_root
    remove_installation
    print_success "Uninstallation completed!"
elif [[ "${test_mode}" == 'true' ]]; then
    check_root
    if test_installation; then
        print_success "Test completed successfully!"
    else
        print_error "Test failed!"
        exit 1
    fi
else
    echo "🚀 Guster Gesture Daemon - Installation Script"
    echo "=============================================="
    echo

    check_root
    install_dependencies
    install_daemon
    setup_service
    if test_installation; then
        enable_service
        show_post_install
    else
        print_error "Installation failed due to test failure!"
        exit 1
    fi
fi

exit 0