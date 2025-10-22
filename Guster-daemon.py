#!/usr/bin/env python3
"""
Guster Gesture Daemon - Prototype

This prototype listens to `libinput debug-events` output and recognizes
3- and 4-finger swipe gestures (left/right/up/down). When a gesture is
recognized, it executes the mapped command from a YAML config file.

Requirements (install on Debian/Ubuntu-like):
  sudo apt install libinput-tools xdotool wmctrl python3-yaml

Files & locations:
  - ~/.config/guster/config.yml   # user config (created if missing)
  - /usr/local/bin/guster-daemon.py (this script)
  - A systemd unit is included in the README below

Notes & limitations:
  - This is a lightweight prototype: it parses textual output from
    `libinput debug-events` so it should work on distros with libinput.
  - Gesture parsing is heuristic-based (thresholds/time windows). Tweak
    thresholds in the CONFIG_DEFAULT dict to match your touchpad.

Usage:
  python3 guster-daemon.py --test    # run a test (dry-run)
  python3 guster-daemon.py           # run daemon (prints events)

"""

import subprocess
import threading
import time
import re
import os
import sys
import shlex
from pathlib import Path

try:
    import yaml
except Exception:
    print("Missing dependency: pyyaml. Install with: sudo apt install python3-yaml")
    raise

CONFIG_PATH = Path.home() / ".config" / "guster" / "config.yml"
CONFIG_DIR = CONFIG_PATH.parent

CONFIG_DEFAULT = {
    'threshold': {
        # minimum absolute motion (units depend on libinput output; tune this)
        'px_min': 50.0,
        # minimum ratio to consider primary axis movement
        'axis_ratio': 1.5,
    },
    'gestures': {
        # format: "<fingers>_<dir>": command
        '3_left': 'xdotool key ctrl+Page_Up',
        '3_right': 'xdotool key ctrl+Page_Down',
        '4_left': 'wmctrl -s $(($(wmctrl -d | grep "\*" | cut -d" " -f1) - 1))',
        '4_right': 'wmctrl -s $(($(wmctrl -d | grep "\*" | cut -d" " -f1) + 1))',
        '4_up': 'xdotool key Super',
        '4_down': 'xdotool key Super',
    }
}

LINE_RE_GESTURE_BEGIN = re.compile(r'GESTURE_SWIPE_BEGIN.*n_fingers\s*(\d+)')
LINE_RE_GESTURE_UPDATE = re.compile(r'GESTURE_SWIPE_UPDATE.*delta\s*([\-0-9\.]+)\s*([\-0-9\.]+)')
LINE_RE_GESTURE_END = re.compile(r'GESTURE_SWIPE_END.*n_fingers\s*(\d+)')

class GestureCollector:
    def __init__(self, config):
        self.lock = threading.Lock()
        self.reset()
        self.config = config

    def reset(self):
        with getattr(self, 'lock', threading.Lock()):
            self.active = False
            self.fingers = 0
            self.total_dx = 0.0
            self.total_dy = 0.0
            self.last_time = None

    def begin(self, fingers):
        with self.lock:
            self.active = True
            self.fingers = int(fingers)
            self.total_dx = 0.0
            self.total_dy = 0.0
            self.last_time = time.time()
            #print(f"[guster] swipe begin: {self.fingers} fingers")

    def update(self, dx, dy):
        with self.lock:
            if not self.active:
                return
            self.total_dx += float(dx)
            self.total_dy += float(dy)
            self.last_time = time.time()
            #print(f"[guster] update: dx={dx} dy={dy} tot_dx={self.total_dx} tot_dy={self.total_dy}")

    def end(self, fingers):
        with self.lock:
            if not self.active:
                return None
            # finalize
            f = int(fingers)
            dx = self.total_dx
            dy = self.total_dy
            self.reset()
            return f, dx, dy


def load_or_create_config():
    if not CONFIG_DIR.exists():
        CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    if not CONFIG_PATH.exists():
        with open(CONFIG_PATH, 'w') as fp:
            yaml.safe_dump(CONFIG_DEFAULT, fp)
        print(f"Created default config at {CONFIG_PATH}. Edit to customize gestures.")
    with open(CONFIG_PATH, 'r') as fp:
        cfg = yaml.safe_load(fp) or {}
    # merge defaults for safety
    merged = CONFIG_DEFAULT.copy()
    merged.update(cfg)
    # deep merge gestures
    merged['gestures'] = CONFIG_DEFAULT['gestures'].copy()
    user_g = cfg.get('gestures', {})
    merged['gestures'].update(user_g)
    # threshold
    merged['threshold'] = CONFIG_DEFAULT['threshold'].copy()
    merged['threshold'].update(cfg.get('threshold', {}))
    return merged


def determine_direction(dx, dy, threshold):
    ax = abs(dx)
    ay = abs(dy)
    if max(ax, ay) < threshold['px_min']:
        return None
    if ax >= ay * threshold['axis_ratio']:
        return 'right' if dx > 0 else 'left'
    if ay >= ax * threshold['axis_ratio']:
        return 'down' if dy > 0 else 'up'
    return None


def execute_action(command, dry_run=False):
    if not command:
        return
    if dry_run:
        print(f"[guster] would execute: {command}")
        return
    try:
        # Use shell=true because commands may use shell features; in prod prefer safer approach
        subprocess.Popen(command, shell=True)
        print(f"[guster] executed: {command}")
    except Exception as e:
        print(f"[guster] failed to execute '{command}': {e}")


def run_daemon(dry_run=False):
    cfg = load_or_create_config()
    collector = GestureCollector(cfg)

    # Start libinput debug-events process
    proc = subprocess.Popen(['libinput', 'debug-events'], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    print('[guster] listening to libinput debug-events...')

    try:
        for raw_line in proc.stdout:
            line = raw_line.strip()
            # quick debug printing (comment out for quiet mode)
            #print('[libinput]', line)
            m = LINE_RE_GESTURE_BEGIN.search(line)
            if m:
                fingers = int(m.group(1))
                collector.begin(fingers)
                continue
            m2 = LINE_RE_GESTURE_UPDATE.search(line)
            if m2:
                dx = float(m2.group(1))
                dy = float(m2.group(2))
                collector.update(dx, dy)
                continue
            m3 = LINE_RE_GESTURE_END.search(line)
            if m3:
                fingers = int(m3.group(1))
                res = collector.end(fingers)
                if res is None:
                    continue
                f, dx, dy = res
                direction = determine_direction(dx, dy, cfg['threshold'])
                if not direction:
                    print(f"[guster] gesture ignored (too small): f={f} dx={dx:.1f} dy={dy:.1f}")
                    continue
                key = f"{f}_{direction}"
                cmd = cfg['gestures'].get(key)
                print(f"[guster] detected gesture: fingers={f} dir={direction} -> key={key}")
                if cmd:
                    execute_action(cmd, dry_run=dry_run)
                else:
                    print(f"[guster] no mapping for gesture '{key}'.")
                continue
    except KeyboardInterrupt:
        print('\n[guster] exiting (keyboard interrupt)')
        proc.terminate()
    except Exception as e:
        print(f"[guster] error: {e}")
        proc.terminate()


if __name__ == '__main__':
    dry = False
    if len(sys.argv) > 1 and sys.argv[1] in ('--test', '-t'):
        dry = True
        print('[guster] running in dry-run/test mode')
    run_daemon(dry_run=dry)

# ---------------------------
# Example config (saved to ~/.config/guster/config.yml when first run)
# ---------------------------
# threshold:
#   px_min: 50.0
#   axis_ratio: 1.5
# gestures:
#   3_left: "xdotool key ctrl+Page_Up"
#   3_right: "xdotool key ctrl+Page_Down"
#   4_left: "wmctrl -s $(($(wmctrl -d | grep '\*' | cut -d' ' -f1) - 1))"
#   4_right: "wmctrl -s $(($(wmctrl -d | grep '\*' | cut -d' ' -f1) + 1))"

# ---------------------------
# Quick systemd unit example (save to /etc/systemd/system/guster.service)
# ---------------------------
# [Unit]
# Description=Guster Gesture Daemon
# After=graphical.target
# 
# [Service]
# Type=simple
# ExecStart=/usr/bin/python3 /usr/local/bin/guster-daemon.py
# Restart=on-failure
# Environment=DISPLAY=:0
# Environment=XAUTHORITY=/home/YOURUSER/.Xauthority
# User=YOURUSER
# 
# [Install]
# WantedBy=default.target
# ---------------------------

# README / quick install steps (local):
# 1) Copy this file to /usr/local/bin/guster-daemon.py and make it executable
#    sudo cp guster-daemon.py /usr/local/bin/guster-daemon.py
#    sudo chmod +x /usr/local/bin/guster-daemon.py
# 2) Install dependencies: libinput-tools, xdotool, wmctrl, python3-yaml
#    sudo apt install libinput-tools xdotool wmctrl python3-yaml
# 3) Create a systemd unit like the example above, enable and start it
#    sudo systemctl enable --now guster.service
# 4) Tweak ~/.config/guster/config.yml to map gestures to your favorite commands
#
# Troubleshooting:
# - If you don't see GESTURE_SWIPE_* lines from libinput debug-events, your touchpad
#   drivers or compositor might not expose gesture events. Test with:
#     sudo libinput debug-events --verbose
# - Tune px_min in the config to be smaller/larger depending on sensitivity.
# - For Wayland (GNOME) the approach may require different hooks (libinput still works
#   if you can access the seat debug-events)."
