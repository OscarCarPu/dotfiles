#!/bin/bash
BRIGHTNESS_DEVICE="intel_backlight"

case "$1" in
  up)
    brightnessctl set +1% > /dev/null
  ;;
down)
    brightnessctl set 1%- > /dev/null
  ;;
get)
   BRIGHTNESS=$(brightnessctl -d "$BRIGHTNESS_DEVICE" get)
   MAX_BRIGHTNESS=$(brightnessctl -d "$BRIGHTNESS_DEVICE" max)
   PERCENTAGE=$((BRIGHTNESS * 100 / MAX_BRIGHTNESS))
   echo "$PERCENTAGE"
  ;;
*)
  echo "Uso: $0 [up|down|get]"
  exit 1
  ;;
esac
