#!/bin/bash
# Monitor watcher for Hyprland - auto-reconfigures monitors on connection/disconnection
# Listens to Hyprland event socket and triggers monitor setup when monitors change
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_SCRIPT="$SCRIPT_DIR/setup_monitors_by_serial.sh"

# Verify setup script exists
if [[ ! -f "$SETUP_SCRIPT" ]]; then
    echo "Error: Monitor setup script not found at $SETUP_SCRIPT"
    exit 1
fi

# Function to reconfigure monitors
reconfigure_monitors() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Monitor change detected, reconfiguring..."

    # Small delay to ensure monitors are fully initialized
    sleep 1

    # Run the setup script
    if bash "$SETUP_SCRIPT"; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Monitor reconfiguration completed"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Warning: Monitor reconfiguration failed"
    fi
}

# Find Hyprland event socket
# Hyprland stores sockets in $XDG_RUNTIME_DIR/hypr/ (usually /run/user/UID/hypr/)
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
HYPR_DIR="$RUNTIME_DIR/hypr"

if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    SOCKET_PATH="$HYPR_DIR/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
else
    # Find the socket by searching the hypr directory
    SOCKET_PATH=$(find "$HYPR_DIR" -name ".socket2.sock" 2>/dev/null | head -1)
fi

# Verify socket exists
if [[ ! -S "$SOCKET_PATH" ]]; then
    echo "Error: Hyprland event socket not found at $SOCKET_PATH"
    exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Monitor watcher started, listening for events..."

# Listen to Hyprland events and trigger on monitor add/remove
socat -U - "UNIX-CONNECT:$SOCKET_PATH" | while read -r line; do
    # Check if event is monitor-related
    if [[ "$line" =~ ^monitoradded\>\> ]] || [[ "$line" =~ ^monitorremoved\>\> ]]; then
        reconfigure_monitors
    fi
done
