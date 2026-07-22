#!/bin/bash
set -euo pipefail

# Watches for sound device changes (USB dock, Switch, etc.) and recovers audio.
# Run this in the background: exec-once in hyprland.conf

# Hyprland's stdout sink is disabled (debug:disable_logs), so exec-once output
# vanishes. Keep our own log with a crude size cap.
LOG_FILE="$HOME/.cache/audio_watcher.log"
{ [[ -f "$LOG_FILE" && $(stat -c%s "$LOG_FILE") -gt 1048576 ]] && mv -f "$LOG_FILE" "$LOG_FILE.old"; } || true
exec >>"$LOG_FILE" 2>&1

DOCK_CARD_NAME="USB3.1 Universal Docking"
DOCK_USB_VENDOR="17e9"  # DisplayLink
COOLDOWN=10
LAST_RESTART=0

# Raised only while the PipeWire stack is actually being bounced so
# monitor_watcher.sh holds its waybar restart - waybar aborts when
# pa_context_connect() fails against a mid-restart PipeWire. Raising it for
# every udev event kept it up through whole dock attach storms and starved
# monitor_watcher's settle wait (2026-07-18: ~70s dock switch).
BUSY_FLAG="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/audio_watcher_busy"
trap 'rm -f "$BUSY_FLAG"' EXIT

dock_audio_alive() {
    grep -q "$DOCK_CARD_NAME" /proc/asound/cards 2>/dev/null
}

# The dock's ALSA card vanishes both on physical unplug and during dock
# re-enumeration; its USB device entry only vanishes on unplug. Checking the
# bus tells the two cases apart instantly instead of waiting out a 15s
# timeout for a re-enumeration that will never come.
dock_usb_present() {
    grep -qs "$DOCK_USB_VENDOR" /sys/bus/usb/devices/*/idVendor
}

# waybar's pulse module talks to pipewire-pulse via libpulse, so probe that
# (pactl) when available; wpctl only proves WirePlumber is up.
audio_ready() {
    if command -v pactl >/dev/null 2>&1; then
        pactl info >/dev/null 2>&1
    else
        wpctl status >/dev/null 2>&1
    fi
}

set_dock_default() {
    # wpctl prefixes sink lines with a multibyte tree glyph that \s does not
    # match, so don't anchor at line start - take the number before the dot.
    local sink_id
    sink_id=$(wpctl status 2>/dev/null | grep -A5 "Sinks:" | grep "USB3.1" | grep -oP '\b\d+(?=\.\s)' | head -1 || true)
    [[ -n "$sink_id" ]] && wpctl set-default "$sink_id" 2>/dev/null || true
}

# Bounce the PipeWire stack, then decide by USB presence whether to wait for
# the dock sink or fall back to built-in. During the cooldown the restart is
# DEFERRED, not skipped - a skipped call used to silently leave the wrong
# default sink, or no built-in fallback at all when an unplug landed within
# 10s of a re-enumeration restart.
restart_audio() {
    touch "$BUSY_FLAG"
    bounce_audio
    rm -f "$BUSY_FLAG"
}

bounce_audio() {
    local now wait_left
    now=$(date +%s)
    wait_left=$(( COOLDOWN - (now - LAST_RESTART) ))
    # date +%s is not monotonic: a backwards clock step (NTP, suspend) could
    # blow wait_left past COOLDOWN and stall the whole event loop. Clamp it.
    (( wait_left > COOLDOWN )) && wait_left=$COOLDOWN
    if (( wait_left > 0 )); then
        echo "$(date): Restart requested ${wait_left}s into cooldown, deferring..."
        sleep "$wait_left"
        # Conditions may have changed while deferred - skip the bounce if the
        # dock audio is up and PipeWire already sees it.
        if dock_audio_alive && wpctl status 2>/dev/null | grep -q "USB3.1"; then
            set_dock_default
            echo "$(date): Audio healthy after cooldown, restart not needed"
            return
        fi
    fi
    LAST_RESTART=$(date +%s)

    echo "$(date): Restarting audio stack..."
    export SVDIR="$HOME/.local/share/runit/sv"
    sv restart pipewire wireplumber pipewire-pulse || echo "$(date): Warning: sv restart reported failure"
    sleep 2
    # Hold until the pulse shim accepts connections again - the busy flag is
    # only meaningful to monitor_watcher if it outlives the actual bounce.
    for _ in $(seq 1 10); do
        audio_ready && break
        sleep 1
    done

    if ! dock_usb_present; then
        notify-send -t 3000 "Audio" "Dock disconnected - using built-in audio" 2>/dev/null || true
        echo "$(date): Audio restarted on built-in (dock gone)"
        return
    fi

    # Dock USB is on the bus - wait up to 10s for its audio card
    local i
    for i in $(seq 1 10); do
        if dock_audio_alive; then
            set_dock_default
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
rm -f "$BUSY_FLAG"

# Track whether the dock was on the bus at the last event so headset/Switch
# hotplugs while undocked don't trigger a spurious "dock disconnected"
# restart - PipeWire handles ordinary device hotplug natively.
DOCK_PRESENT=0
dock_usb_present && DOCK_PRESENT=1

# Monitor udev sound subsystem events
udevadm monitor --subsystem-match=sound --property 2>/dev/null | while read -r line; do
    if [[ "$line" == *"ACTION=add"* ]] || [[ "$line" == *"ACTION=remove"* ]]; then
        sleep 2

        if ! dock_audio_alive; then
            if ! dock_usb_present; then
                if (( DOCK_PRESENT )); then
                    # Physical unplug - no re-enumeration is coming. Fall back
                    # to built-in audio right away instead of waiting 15s + 10s.
                    echo "$(date): Dock USB gone (unplugged), falling back to built-in audio"
                    restart_audio || true
                fi
                # else: some other audio device came/went while undocked -
                # nothing to do
            else
                echo "$(date): Dock audio disappeared but USB still present, waiting for re-enumeration..."
                # Wait up to 15s for the ALSA card to re-register
                handled=0
                for i in $(seq 1 15); do
                    if dock_audio_alive; then
                        handled=1
                        echo "$(date): Dock audio reappeared after ${i}s, restarting..."
                        restart_audio || true
                        break
                    fi
                    if ! dock_usb_present; then
                        # Unplugged mid-wait - stop waiting, fall back now.
                        handled=1
                        echo "$(date): Dock USB vanished mid-wait, falling back to built-in audio"
                        restart_audio || true
                        break
                    fi
                    sleep 1
                done
                # USB present but ALSA card never came back: restart and let
                # the dock-poll inside restart_audio report what happened.
                if (( handled == 0 )); then
                    echo "$(date): Dock audio still gone after 15s with USB present, restarting..."
                    restart_audio || true
                fi
            fi
        else
            # Dock is still there but something changed - verify audio is working
            # by checking if the sink exists in PipeWire
            if ! wpctl status 2>/dev/null | grep -q "USB3.1"; then
                echo "$(date): Dock present in ALSA but not in PipeWire, restarting..."
                restart_audio || true
            fi
        fi

        DOCK_PRESENT=0
        dock_usb_present && DOCK_PRESENT=1
    fi
done
