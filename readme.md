# Guster Gesture Daemon

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A lightweight Python daemon that brings Windows-like touchpad gesture functionality to Linux, supporting multiple desktop environments and display servers.

## ✨ Features

- **🎯 Multi-finger gesture recognition**: Detects 3-finger and 4-finger swipe gestures (left, right, up, down)
- **🔍 Desktop environment auto-detection**: Automatically configures appropriate commands for GNOME, KDE Plasma, XFCE, i3, Cinnamon, MATE, and others
- **🌐 Cross-platform compatibility**: Works on any apt-based Linux distribution
- **⚙️ Flexible configuration**: YAML-based config system for easy customization
- **🔄 Systemd integration**: Runs as a background service with automatic restart
- **🌊 Wayland support**: Partial support with appropriate fallbacks

## 🖥️ Supported Systems

### Linux Distributions
- ✅ Debian and derivatives (Ubuntu, Linux Mint, Pop!_OS, etc.)
- ✅ Any distribution with `apt` package manager

### Desktop Environments
- **GNOME** (X11/Wayland) - Uses D-Bus commands for overview and workspace switching
- **KDE Plasma** (X11/Wayland) - Uses QDBus for KWin integration
- **XFCE** - Uses xfconf and xdotool
- **i3** - Uses i3-msg and rofi
- **Cinnamon/MATE** - Fallback to generic X11 commands
- **Others** - Generic X11 commands with wmctrl

## 📦 Installation

### 🚀 Automated Installation (Recommended)

For a quick and easy setup, use the provided installation script:

```bash
# Make the script executable (Linux/macOS)
chmod +x install.sh

# Run the installation script
./install.sh
```

**Note:** The installation script is designed for Linux systems with apt package manager. It will not work on Windows.

The script will:
- 🔍 Detect your desktop environment automatically
- 📦 Install all required dependencies
- 🛠️ Install the daemon to `/usr/local/bin/`
- ⚙️ Create and enable a user systemd service
- 🧪 Test the installation
- 📝 Generate appropriate configuration files

**What gets installed:**
- Core daemon: `/usr/local/bin/guster-daemon.py`
- Configuration: `~/.config/guster/config.yml`
- Systemd service: `~/.config/systemd/user/guster.service`

### 🔧 Manual Installation

If you prefer to install manually or need more control:

#### 1. Install Dependencies

```bash
sudo apt update
sudo apt install libinput-tools python3-yaml xdotool wmctrl
```

**Desktop-specific dependencies:**

| Desktop Environment | Additional Packages |
|-------------------|-------------------|
| **GNOME** | `dbus-send` (usually pre-installed) |
| **KDE Plasma** | `qdbus` (usually pre-installed) |
| **i3** | `i3-wm rofi` |
| **XFCE** | `xfce4-appfinder` (usually pre-installed) |

**Install all recommended packages:**
```bash
sudo apt install libinput-tools python3-yaml xdotool wmctrl rofi
```

#### 2. Install the Daemon

```bash
sudo cp guster-daemon.py /usr/local/bin/guster-daemon.py
sudo chmod +x /usr/local/bin/guster-daemon.py
```

#### 3. Test Installation

Run a dry-run test to create the config and verify functionality:

```bash
python3 /usr/local/bin/guster-daemon.py --test
```

This will:
- 🔍 Detect your desktop environment
- 📝 Create `~/.config/guster/config.yml` with appropriate defaults
- 🧪 Show what commands would be executed (without actually running them)

## ⚙️ Configuration

The daemon uses a YAML configuration file at `~/.config/guster/config.yml`.

### Configuration Structure

```yaml
threshold:
  px_min: 50.0        # Minimum pixels to trigger gesture
  axis_ratio: 1.5     # Ratio for horizontal vs vertical detection

gestures:
  3_left: "command"   # 3-finger swipe left
  3_right: "command"  # 3-finger swipe right
  3_up: "command"     # 3-finger swipe up
  3_down: "command"   # 3-finger swipe down
  4_left: "command"   # 4-finger swipe left
  4_right: "command"  # 4-finger swipe right
  4_up: "command"     # 4-finger swipe up
  4_down: "command"   # 4-finger swipe down
```

### Default Gestures by Desktop Environment

#### 🐚 GNOME
```yaml
gestures:
  3_left: "xdotool key Alt+Left"        # Browser back
  3_right: "xdotool key Alt+Right"      # Browser forward
  3_up: "xdotool key Ctrl+Page_Up"      # Previous tab
  3_down: "xdotool key Ctrl+Page_Down"  # Next tab
  4_left: "dbus-send --session --type=method_call --dest=org.gnome.Shell /org/gnome/Shell org.gnome.Shell.Eval string:'Main.overview.show();'"
  4_right: "dbus-send --session --type=method_call --dest=org.gnome.Shell /org/gnome/Shell org.gnome.Shell.Eval string:'Main.overview.show();'"
  4_up: "xdotool key Super+d"           # Show desktop
  4_down: "xdotool key Super+s"         # Show overview
```

#### 🖥️ KDE Plasma
```yaml
gestures:
  3_left: "xdotool key Alt+Left"
  3_right: "xdotool key Alt+Right"
  3_up: "xdotool key Ctrl+Page_Up"
  3_down: "xdotool key Ctrl+Page_Down"
  4_left: "qdbus org.kde.kglobalaccel /component/kwin invokeShortcut 'Switch One Desktop to the Left'"
  4_right: "qdbus org.kde.kglobalaccel /component/kwin invokeShortcut 'Switch One Desktop to the Right'"
  4_up: "qdbus org.kde.kglobalaccel /component/kwin invokeShortcut 'Show Desktop'"
  4_down: "qdbus org.kde.kglobalaccel /component/kwin invokeShortcut 'Window Operations Menu'"
```

#### 🪟 i3 Window Manager
```yaml
gestures:
  3_left: "xdotool key Alt+Left"
  3_right: "xdotool key Alt+Right"
  3_up: "xdotool key Ctrl+Page_Up"
  3_down: "xdotool key Ctrl+Page_Down"
  4_left: "i3-msg workspace prev"
  4_right: "i3-msg workspace next"
  4_up: "i3-msg exec 'rofi -show run'"
  4_down: "i3-msg exec 'rofi -show window'"
```

## 🚀 Usage

### Automated Setup

If you used the installation script (`./install.sh`), the daemon is already running as a systemd service. The script automatically:

- ✅ Installs all dependencies
- ✅ Sets up the systemd user service
- ✅ Enables and starts the service
- ✅ Creates appropriate configuration

### Manual Testing

```bash
# Test mode (shows what would be executed)
python3 guster-daemon.py --test

# Run daemon (actual execution)
python3 guster-daemon.py
```

### As a System Service

#### 🔧 System-wide Service (recommended for most users)

```bash
sudo cp guster.service /etc/systemd/system/guster.service
sudo systemctl daemon-reload
sudo systemctl enable --now guster.service
```

#### 👤 User Service (for per-user configuration)

```bash
mkdir -p ~/.config/systemd/user
cp guster.service ~/.config/systemd/user/guster.service
systemctl --user daemon-reload
systemctl --user enable --now guster.service
```

### Service Management

```bash
# Check status (system-wide)
sudo systemctl status guster.service

# Check status (user service)
systemctl --user status guster.service

# View logs (system-wide)
sudo journalctl -u guster.service -f

# View logs (user service)
journalctl --user -u guster.service -f

# Restart service (system-wide)
sudo systemctl restart guster.service

# Restart service (user service)
systemctl --user restart guster.service

# Stop service (system-wide)
sudo systemctl stop guster.service

# Stop service (user service)
systemctl --user stop guster.service
```

## 🔧 Troubleshooting

### 🚫 No Gestures Detected

**Symptoms:** No output when swiping on touchpad

**Solutions:**
1. 🔍 Check if libinput detects gestures:
   ```bash
   sudo libinput debug-events --verbose
   ```
2. 🔐 Ensure you have input device permissions
3. 👑 Try running the daemon as root: `sudo python3 guster-daemon.py`

### 🎯 Gestures Too Sensitive/Not Sensitive Enough

**Solution:** Adjust thresholds in `~/.config/guster/config.yml`:
- 🔽 Lower `px_min` for more sensitivity
- 🔼 Increase `px_min` for less sensitivity
- ⚖️ Adjust `axis_ratio` to fine-tune horizontal vs vertical detection

### 🚫 Commands Not Executing

**Solutions:**
1. 🧪 Test commands manually in terminal
2. 📝 Check command syntax in config file
3. 📦 Ensure required tools are installed (xdotool, wmctrl, etc.)
4. 🖥️ Verify DISPLAY environment variable is set

### 🌊 Wayland Issues

**Symptoms:** Limited functionality on Wayland compositors

**Solutions:**
1. 👑 Run daemon with sudo for input access
2. 🔧 Use Wayland-compatible commands (dbus-send, qdbus)
3. ⚠️ Some X11 tools (xdotool) may not work on pure Wayland

### 🔍 Desktop Environment Not Detected

**Check environment variables:**
```bash
echo $XDG_CURRENT_DESKTOP
echo $DESKTOP_SESSION
```

**Manual override:** Edit `~/.config/guster/config.yml` with custom commands

### 🔐 Permission Issues

**For X11:**
- 🖥️ Ensure DISPLAY and XAUTHORITY are set correctly
- 👤 Run as the user owning the X session

**For Wayland:**
- 👑 May require root access for input device monitoring
- 🔧 Check compositor-specific permissions

## 📁 Project Files

- `guster-daemon.py` - Main daemon script
- `install.sh` - Automated installation and setup script for Linux systems
- `guster.service` - Systemd service file template
- `config.yml` - Sample configuration (generated automatically)
- `readme.md` - This documentation

## 🛠️ Development

### Requirements

- 🐍 Python 3.6+
- 🔧 libinput-tools
- 📄 PyYAML

### Testing

```bash
# Syntax check
python3 -m py_compile guster-daemon.py

# Dry run test
python3 guster-daemon.py --test
```

### Customization

The daemon is designed to be easily extensible:

- ➕ Add new gesture patterns in `determine_direction()`
- 🖥️ Implement DE-specific command sets in `get_default_gestures()`
- 🔒 Replace shell command execution with safer subprocess calls for production use

## ⚠️ Limitations

- 🧪 **Prototype status**: Uses text parsing of libinput output (fragile across versions)
- 🔒 **Security**: Uses `shell=True` for command execution (convenient but not secure for multi-user systems)
- 🌊 **Wayland**: Limited support, may require root privileges
- 💻 **Hardware dependent**: Thresholds may need tuning per device

## 🤝 Contributing

1. 🍴 Fork the repository
2. 🌿 Create a feature branch
3. 🔧 Make your changes
4. 🧪 Test thoroughly
5. 📤 Submit a pull request

## 📄 License

This project is provided as-is. Use and modify at your own risk.

## 🙏 Acknowledgments

- 🛠️ Built on top of libinput for gesture detection
- 💡 Inspired by Windows touchpad gesture functionality
- 👥 Community contributions for multi-DE support

