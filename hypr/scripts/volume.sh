#!/bin/bash
set -euo pipefail

# Verify wpctl is installed (part of WirePlumber/PipeWire)
if ! command -v wpctl &> /dev/null; then
    echo "Error: wpctl not found" >&2
    exit 1
fi

case "${1:-}" in
  up)
    wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
  ;;
  down)
    wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
  ;;
  mute)
    wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
  ;;
  get)
    wpctl get-volume @DEFAULT_AUDIO_SINK@
  ;;
  *)
    echo "Usage: $0 [up|down|mute|get]" >&2
    exit 1
  ;;
esac
