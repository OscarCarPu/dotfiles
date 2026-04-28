#!/bin/bash
set -euo pipefail

BRIGHTNESS_DEVICE="intel_backlight"

# Verify brightnessctl is installed
if ! command -v brightnessctl &> /dev/null; then
    echo "Error: brightnessctl not found" >&2
    exit 1
fi

# Refresh the waybar custom/brightness module on change.
# Matches "signal": 8 in waybar/config.jsonc -> SIGRTMIN+8.
notify_waybar() {
    pkill -RTMIN+8 waybar 2>/dev/null || true
}

case "${1:-}" in
  up)
    brightnessctl -d "$BRIGHTNESS_DEVICE" set +1% > /dev/null
    notify_waybar
  ;;
  down)
    brightnessctl -d "$BRIGHTNESS_DEVICE" set 1%- > /dev/null
    notify_waybar
  ;;
  get)
    BRIGHTNESS=$(brightnessctl -d "$BRIGHTNESS_DEVICE" get)
    MAX_BRIGHTNESS=$(brightnessctl -d "$BRIGHTNESS_DEVICE" max)
    PERCENTAGE=$((BRIGHTNESS * 100 / MAX_BRIGHTNESS))
    echo "$PERCENTAGE"
  ;;
  set)
    brightnessctl -d "$BRIGHTNESS_DEVICE" set "${2:-100}%" > /dev/null
    notify_waybar
  ;;
  *)
    echo "Usage: $0 [up|down|get|set <percent>]" >&2
    exit 1
  ;;
esac
