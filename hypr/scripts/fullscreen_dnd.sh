#!/bin/bash
# Toggles swaync Do Not Disturb based on fullscreen state.
# When any window is fullscreen, DND is enabled to prevent
# notification surfaces from triggering video control overlays.
set -euo pipefail

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
HYPR_DIR="$RUNTIME_DIR/hypr"

if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    SOCKET_PATH="$HYPR_DIR/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
else
    SOCKET_PATH=$(find "$HYPR_DIR" -name ".socket2.sock" 2>/dev/null | head -1)
fi

if [[ ! -S "$SOCKET_PATH" ]]; then
    echo "Error: Hyprland event socket not found" >&2
    exit 1
fi

check_fullscreen() {
    hyprctl clients -j | jq -e '[.[] | select(.fullscreen != 0)] | length > 0' &>/dev/null
}

update_dnd() {
    if check_fullscreen; then
        swaync-client --dnd-on --skip-wait &>/dev/null
    else
        swaync-client --dnd-off --skip-wait &>/dev/null
    fi
}

# Set initial state
update_dnd

socat -U - "UNIX-CONNECT:$SOCKET_PATH" | while read -r line; do
    if [[ "$line" =~ ^fullscreen\>\> ]]; then
        update_dnd
    fi
done
