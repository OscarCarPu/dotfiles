#!/bin/bash
set -euo pipefail

BRIGHTNESS_DEVICE="intel_backlight"

# Verify brightnessctl is installed
if ! command -v brightnessctl &> /dev/null; then
    echo "Error: brightnessctl not found" >&2
    exit 1
fi

case "${1:-}" in
  up)
    brightnessctl -d "$BRIGHTNESS_DEVICE" set +1% > /dev/null
  ;;
  down)
    brightnessctl -d "$BRIGHTNESS_DEVICE" set 1%- > /dev/null
  ;;
  get)
    BRIGHTNESS=$(brightnessctl -d "$BRIGHTNESS_DEVICE" get)
    MAX_BRIGHTNESS=$(brightnessctl -d "$BRIGHTNESS_DEVICE" max)
    PERCENTAGE=$((BRIGHTNESS * 100 / MAX_BRIGHTNESS))
    echo "$PERCENTAGE"
  ;;
  *)
    echo "Usage: $0 [up|down|get]" >&2
    exit 1
  ;;
esac
