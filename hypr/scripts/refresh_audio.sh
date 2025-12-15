#!/bin/bash
set -euo pipefail

# Refresh PipeWire audio devices after KVM switch
# This restarts WirePlumber and PipeWire to re-detect USB audio devices

notify-send -t 2000 "Audio" "Refreshing audio devices..." 2>/dev/null || true

systemctl --user restart wireplumber pipewire pipewire-pulse

sleep 1

# Get the new default sink name
DEFAULT_SINK=$(wpctl status | grep -A 5 "Sinks:" | grep '^\s*\*' | sed 's/.*\*\s*[0-9]*\.\s*//' | sed 's/\s*\[vol:.*//' | xargs)

notify-send -t 3000 "Audio" "Audio refreshed: $DEFAULT_SINK" 2>/dev/null || true

echo "Audio devices refreshed. Default sink: $DEFAULT_SINK"
