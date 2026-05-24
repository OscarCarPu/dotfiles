#!/bin/bash
set -euo pipefail

# Toggle touchpad enable/disable via Hyprland device keyword and emit JSON for
# the waybar custom/touchpad module.
# State persisted in /tmp/touchpad_enabled (1=on, 0=off); resets to 1 on boot.

DEVICES=(
    "elan0412:01-04f3:3240-touchpad"
    "etps/2-elantech-touchpad"
)
STATE_FILE="/tmp/touchpad_enabled"

notify_waybar() {
    pkill -RTMIN+10 waybar 2>/dev/null || true
}

emit_json() {
    if [ "$1" = "1" ]; then
        printf '{"text":"󰟾","class":"enabled","tooltip":"Touchpad: on"}\n'
    else
        printf '{"text":"󰤳","class":"disabled","tooltip":"Touchpad: off"}\n'
    fi
}

set_touchpad() {
    local val
    [ "$1" = "1" ] && val="true" || val="false"
    for dev in "${DEVICES[@]}"; do
        hyprctl keyword "device[$dev]:enabled" "$val" 2>/dev/null || true
    done
    echo "$1" > "$STATE_FILE"
}

current_state() {
    [ -f "$STATE_FILE" ] && cat "$STATE_FILE" || echo "1"
}

case "${1:-get}" in
    get)    emit_json "$(current_state)" ;;
    toggle) cur="$(current_state)"; [ "$cur" = "1" ] && set_touchpad 0 || set_touchpad 1; notify_waybar ;;
    *)      echo "Usage: $0 [get|toggle]" >&2; exit 1 ;;
esac
