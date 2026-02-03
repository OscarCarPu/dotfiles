#!/bin/bash
set -euo pipefail

# Watches for sound device changes (USB dock, Switch, etc.) and recovers audio.
# Run this in the background: exec-once in hyprland.conf

DOCK_CARD_NAME="USB3.1 Universal Docking"
COOLDOWN=10
LAST_RESTART=0

dock_audio_alive() {
    grep -q "$DOCK_CARD_NAME" /proc/asound/cards 2>/dev/null
}

restart_audio() {
    local now
    now=$(date +%s)
    if (( now - LAST_RESTART < COOLDOWN )); then
        return
    fi
    LAST_RESTART=$now

    echo "$(date): Restarting audio stack..."
    systemctl --user restart wireplumber pipewire pipewire-pulse
    sleep 2

    # Wait up to 10s for the dock audio to reappear
    for i in $(seq 1 10); do
        if dock_audio_alive; then
            # Set dock as default sink
            local sink_id
            sink_id=$(wpctl status 2>/dev/null | grep -A5 "Sinks:" | grep "USB3.1" | grep -oP '^\s*\*?\s*\K\d+' | head -1)
            if [[ -n "$sink_id" ]]; then
                wpctl set-default "$sink_id" 2>/dev/null || true
            fi
            notify-send -t 3000 "Audio" "Audio recovered - dock active" 2>/dev/null || true
            echo "$(date): Audio recovered after ${i}s"
            return
        fi
        sleep 1
    done

    notify-send -t 3000 "Audio" "Audio restarted - dock not found" 2>/dev/null || true
    echo "$(date): Audio restarted but dock not detected"
}

echo "Audio watcher started. Dock present: $(dock_audio_alive && echo yes || echo no)"

# Monitor udev sound subsystem events
udevadm monitor --subsystem-match=sound --property 2>/dev/null | while read -r line; do
    if [[ "$line" == *"ACTION=add"* ]] || [[ "$line" == *"ACTION=remove"* ]]; then
        sleep 2

        if ! dock_audio_alive; then
            echo "$(date): Dock audio disappeared, waiting for it to come back..."
            # Wait up to 15s for device to re-enumerate
            for i in $(seq 1 15); do
                if dock_audio_alive; then
                    echo "$(date): Dock audio reappeared after ${i}s, restarting..."
                    restart_audio
                    break
                fi
                sleep 1
            done
        else
            # Dock is still there but something changed - verify audio is working
            # by checking if the sink exists in PipeWire
            if ! wpctl status 2>/dev/null | grep -q "USB3.1"; then
                echo "$(date): Dock present in ALSA but not in PipeWire, restarting..."
                restart_audio
            fi
        fi
    fi
done
