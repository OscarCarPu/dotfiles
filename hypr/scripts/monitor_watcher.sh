#!/bin/bash
# Monitor watcher for Hyprland - auto-reconfigures monitors on connection/disconnection
# Listens to Hyprland event socket and triggers monitor setup when monitors change.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_SCRIPT="$SCRIPT_DIR/setup_monitors_by_serial.sh"

# Verify setup script exists
if [[ ! -f "$SETUP_SCRIPT" ]]; then
    echo "Error: Monitor setup script not found at $SETUP_SCRIPT"
    exit 1
fi

reconfigure_monitors() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Monitor change detected, reconfiguring..."
    sleep 1
    if bash "$SETUP_SCRIPT"; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Monitor reconfiguration completed"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Warning: Monitor reconfiguration failed"
    fi

    # After monitor + workspace shuffle Hyprland sometimes loses keyboard/mouse
    # focus on the active window (terminals go unresponsive). Force-refocus the
    # currently-active window to wake input handling back up.
    local active_addr
    active_addr=$(hyprctl activewindow 2>/dev/null | awk '/^Window /{print $2; exit}')
    if [[ -n "$active_addr" ]]; then
        hyprctl dispatch focuswindow "address:$active_addr" >/dev/null 2>&1 || true
    else
        # No active window? Refocus the currently focused monitor instead.
        local focused_mon
        focused_mon=$(hyprctl monitors 2>/dev/null | awk '/^Monitor /{name=$2} /focused: yes/{print name; exit}')
        [[ -n "$focused_mon" ]] && hyprctl dispatch focusmonitor "$focused_mon" >/dev/null 2>&1 || true
    fi
}

# Find Hyprland event socket
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
HYPR_DIR="$RUNTIME_DIR/hypr"

if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    SOCKET_PATH="$HYPR_DIR/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
else
    SOCKET_PATH=$(find "$HYPR_DIR" -name ".socket2.sock" 2>/dev/null | head -1)
fi

if [[ ! -S "$SOCKET_PATH" ]]; then
    echo "Error: Hyprland event socket not found at $SOCKET_PATH"
    exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Monitor watcher started, listening for events..."

socat -U - "UNIX-CONNECT:$SOCKET_PATH" | while read -r line; do
    case "$line" in
        monitoradded\>\>*|monitorremoved\>\>*)
            reconfigure_monitors
            ;;
    esac
done
