#!/bin/bash
set -euo pipefail

# Battery notification script - alerts at 15% and 10%
# Prevents duplicate notifications by tracking state
# Dismisses notification when charger is plugged in

STATE_FILE="$HOME/.cache/battery_notify_state"
NOTIFY_ID_FILE="$HOME/.cache/battery_notify_id"

# Find first available battery
BATTERY_PATH=""
for bat in /sys/class/power_supply/BAT*; do
    if [ -d "$bat" ]; then
        BATTERY_PATH="$bat"
        break
    fi
done

# Get current battery percentage
if [ -n "$BATTERY_PATH" ] && [ -f "$BATTERY_PATH/capacity" ]; then
    BATTERY_PERCENTAGE=$(<"$BATTERY_PATH/capacity")
    BATTERY_STATUS=$(<"$BATTERY_PATH/status")
else
    BATTERY_PERCENTAGE=""
    BATTERY_STATUS=""
fi

# Exit if battery info unavailable
if [ -z "$BATTERY_PERCENTAGE" ]; then
    exit 0
fi

# Read previous state
if [ -f "$STATE_FILE" ]; then
    PREVIOUS_STATE=$(<"$STATE_FILE")
else
    PREVIOUS_STATE="OK"
fi

# Function to close existing battery notification
close_notification() {
    if [ -f "$NOTIFY_ID_FILE" ]; then
        local notify_id
        notify_id=$(<"$NOTIFY_ID_FILE")
        gdbus call --session \
            --dest org.freedesktop.Notifications \
            --object-path /org/freedesktop/Notifications \
            --method org.freedesktop.Notifications.CloseNotification \
            "$notify_id" 2>/dev/null || true
        rm -f "$NOTIFY_ID_FILE"
    fi
}

# Function to send notification and save ID
send_notification() {
    local urgency="$1"
    local title="$2"
    local body="$3"
    local icon="$4"

    local notify_id
    notify_id=$(gdbus call --session \
        --dest org.freedesktop.Notifications \
        --object-path /org/freedesktop/Notifications \
        --method org.freedesktop.Notifications.Notify \
        "battery-notify" 0 "$icon" "$title" "$body" "[]" "{\"urgency\": <byte $urgency>}" 0 \
        | sed 's/(uint32 \([0-9]*\),)/\1/')

    mkdir -p "$(dirname "$NOTIFY_ID_FILE")"
    echo "$notify_id" > "$NOTIFY_ID_FILE"
}

# Determine current state
CURRENT_STATE="OK"
if [ "$BATTERY_STATUS" != "Charging" ] && [ "$BATTERY_STATUS" != "Full" ]; then
    if [ "$BATTERY_PERCENTAGE" -le 10 ]; then
        CURRENT_STATE="CRITICAL"
    elif [ "$BATTERY_PERCENTAGE" -le 15 ]; then
        CURRENT_STATE="LOW"
    fi
fi

# Handle state changes
if [ "$CURRENT_STATE" != "$PREVIOUS_STATE" ]; then
    case "$CURRENT_STATE" in
        "CRITICAL")
            close_notification
            send_notification 2 "Battery Critical!" "Battery at ${BATTERY_PERCENTAGE}% - Please plug in charger immediately" "battery-caution"
            ;;
        "LOW")
            close_notification
            send_notification 2 "Battery Low" "Battery at ${BATTERY_PERCENTAGE}% - Please plug in charger soon" "battery-low"
            ;;
        "OK")
            # Battery recovered (plugged in) - dismiss notification
            close_notification
            ;;
    esac

    # Update state file
    mkdir -p "$(dirname "$STATE_FILE")"
    echo "$CURRENT_STATE" > "$STATE_FILE"
fi
