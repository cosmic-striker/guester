#!/bin/bash

# Guster Gesture Daemon - Installation and Setup Script
# This script installs and configures the Guster Gesture Daemon

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
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

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root. Please run as a regular user."
        exit 1
    fi
}

# Function to check if we're on an apt-based system
check_apt() {
    if ! command -v apt &> /dev/null; then
        print_error "This script requires apt package manager. This appears to be a non-Debian/Ubuntu system."
        exit 1
    fi
}

# Function to detect desktop environment
detect_de() {
    local desktop=""
    local session=""

    if [[ -n "$XDG_CURRENT_DESKTOP" ]]; then
        desktop=$(echo "$XDG_CURRENT_DESKTOP" | tr '[:upper:]' '[:lower:]')
    fi

    if [[ -n "$DESKTOP_SESSION" ]]; then
        session=$(echo "$DESKTOP_SESSION" | tr '[:upper:]' '[:lower:]')
    fi

    if [[ "$desktop" == *"gnome"* ]] || [[ "$session" == *"gnome"* ]]; then
        echo "gnome"
    elif [[ "$desktop" == *"kde"* ]] || [[ "$session" == *"plasma"* ]]; then
        echo "kde"
    elif [[ "$desktop" == *"xfce"* ]] || [[ "$session" == *"xfce"* ]]; then
        echo "xfce"
    elif [[ "$session" == *"i3"* ]]; then
        echo "i3"
    elif [[ "$desktop" == *"cinnamon"* ]] || [[ "$session" == *"cinnamon"* ]]; then
        echo "cinnamon"
    elif [[ "$desktop" == *"mate"* ]] || [[ "$session" == *"mate"* ]]; then
        echo "mate"
    else
        echo "unknown"
    fi
}

# Function to install dependencies
install_dependencies() {
    print_status "Updating package list..."
    sudo apt update

    print_status "Installing core dependencies..."
    sudo apt install -y libinput-tools python3-yaml xdotool wmctrl

    local de=$(detect_de)
    print_status "Detected desktop environment: $de"

    case $de in
        "gnome")
            print_status "Installing GNOME-specific dependencies..."
            # dbus-send is usually pre-installed
            ;;
        "kde")
            print_status "Installing KDE-specific dependencies..."
            # qdbus is usually pre-installed
            ;;
        "i3")
            print_status "Installing i3-specific dependencies..."
            sudo apt install -y i3-wm rofi
            ;;
        "xfce")
            print_status "Installing XFCE-specific dependencies..."
            # xfce4-appfinder is usually pre-installed
            ;;
        *)
            print_status "Installing general dependencies..."
            ;;
    esac

    print_success "Dependencies installed successfully"
}

# Function to install the daemon
install_daemon() {
    print_status "Installing Guster daemon..."

    # Copy daemon to /usr/local/bin
    sudo cp guster-daemon.py /usr/local/bin/guster-daemon.py
    sudo chmod +x /usr/local/bin/guster-daemon.py

    print_success "Daemon installed to /usr/local/bin/guster-daemon.py"
}

# Function to setup systemd service
setup_systemd() {
    print_status "Setting up systemd service..."

    # Create user systemd directory if it doesn't exist
    mkdir -p ~/.config/systemd/user

    # Create the service file
    cat > ~/.config/systemd/user/guster.service << 'EOF'
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

# Function to test installation
test_installation() {
    print_status "Testing installation..."

    # Test if daemon can run
    if python3 /usr/local/bin/guster-daemon.py --test; then
        print_success "Installation test passed!"
    else
        print_error "Installation test failed!"
        exit 1
    fi
}

# Function to enable and start service
enable_service() {
    print_status "Enabling and starting Guster service..."

    systemctl --user daemon-reload
    systemctl --user enable --now guster.service

    print_success "Service enabled and started"
    print_status "Check service status with: systemctl --user status guster.service"
}

# Function to show post-installation info
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

# Main installation function
main() {
    echo "🚀 Guster Gesture Daemon - Installation Script"
    echo "=============================================="
    echo

    check_root
    check_apt

    install_dependencies
    install_daemon
    setup_systemd
    test_installation
    enable_service
    show_post_install
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi