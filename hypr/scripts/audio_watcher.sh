#!/bin/bash
set -euo pipefail

# Watches for USB audio device changes and refreshes PipeWire
# Run this in the background: exec-once in hyprland.conf

DOCK_VENDOR="17e9"
DOCK_PRODUCT="6000"
LAST_STATE=""

get_dock_state() {
    if lsusb -d "${DOCK_VENDOR}:${DOCK_PRODUCT}" &>/dev/null; then
        # Check if ALSA card exists for the dock
        if grep -q "USB3.1 Universal Docking" /proc/asound/cards 2>/dev/null; then
            echo "connected"
        else
            echo "partial"
        fi
    else
        echo "disconnected"
    fi
}

refresh_audio() {
    sleep 3  # Wait for device to fully initialize

    # Try to set dock as default sink without restarting PipeWire
    DOCK_SINK=$(pactl list short sinks 2>/dev/null | grep -i "USB3.1_Universal_Docking" | cut -f2)

    if [[ -n "$DOCK_SINK" ]]; then
        pactl set-default-sink "$DOCK_SINK"
        notify-send -t 3000 "Audio" "Switched to dock audio" 2>/dev/null || true
    else
        # Only restart if dock sink not found (needs re-detection)
        systemctl --user restart wireplumber pipewire pipewire-pulse
        sleep 2
        DOCK_SINK=$(pactl list short sinks 2>/dev/null | grep -i "USB3.1_Universal_Docking" | cut -f2)
        if [[ -n "$DOCK_SINK" ]]; then
            pactl set-default-sink "$DOCK_SINK"
            notify-send -t 3000 "Audio" "Dock audio detected and set" 2>/dev/null || true
        else
            notify-send -t 3000 "Audio" "Dock audio not found" 2>/dev/null || true
        fi
    fi
}

# Initial state
LAST_STATE=$(get_dock_state)
echo "Audio watcher started. Initial state: $LAST_STATE"

# Monitor for udev events on sound subsystem
udevadm monitor --subsystem-match=sound --property 2>/dev/null | while read -r line; do
    if [[ "$line" == *"ACTION="* ]]; then
        sleep 0.5  # Brief delay to let the event settle
        CURRENT_STATE=$(get_dock_state)

        if [[ "$CURRENT_STATE" != "$LAST_STATE" ]]; then
            echo "$(date): State changed from $LAST_STATE to $CURRENT_STATE"

            if [[ "$CURRENT_STATE" == "connected" ]]; then
                echo "Dock connected, refreshing audio..."
                refresh_audio
            fi

            LAST_STATE="$CURRENT_STATE"
        fi
    fi
done
