#!/bin/bash

# Battery notification script - alerts at 15% and 10%
# Prevents duplicate notifications by tracking state

STATE_FILE="$HOME/.cache/battery_notify_state"

# Get current battery percentage
BATTERY_PERCENTAGE=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1)
BATTERY_STATUS=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1)

# Exit if battery info unavailable
if [ -z "$BATTERY_PERCENTAGE" ]; then
    exit 0
fi

# Read previous state
if [ -f "$STATE_FILE" ]; then
    PREVIOUS_STATE=$(cat "$STATE_FILE")
else
    PREVIOUS_STATE="OK"
fi

# Determine current state
CURRENT_STATE="OK"
if [ "$BATTERY_STATUS" != "Charging" ] && [ "$BATTERY_STATUS" != "Full" ]; then
    if [ "$BATTERY_PERCENTAGE" -le 10 ]; then
        CURRENT_STATE="CRITICAL"
    elif [ "$BATTERY_PERCENTAGE" -le 15 ]; then
        CURRENT_STATE="LOW"
    fi
fi

# Send notification if state changed
if [ "$CURRENT_STATE" != "$PREVIOUS_STATE" ]; then
    case "$CURRENT_STATE" in
        "CRITICAL")
            notify-send -u critical "Battery Critical!" "Battery at ${BATTERY_PERCENTAGE}% - Please plug in charger immediately" -i battery-caution
            ;;
        "LOW")
            notify-send -u critical "Battery Low" "Battery at ${BATTERY_PERCENTAGE}% - Please plug in charger soon" -i battery-low
            ;;
        "OK")
            # Battery recovered (plugged in)
            if [ "$PREVIOUS_STATE" != "OK" ]; then
                notify-send -u normal "Battery Charging" "Battery now charging" -i battery-charging
            fi
            ;;
    esac

    # Update state file
    echo "$CURRENT_STATE" > "$STATE_FILE"
fi
