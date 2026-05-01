#!/bin/bash
# Configure monitors based on EDID serial numbers
# This ensures correct monitor positioning regardless of KVM port swapping
set -euo pipefail

# Define monitor serials and their correct configurations
LEFTMOST_SERIAL="LXLEE0524282"      # Should be at 0x840
MIDDLE_SERIAL="PC3M665802149"       # Should be at 1920x0 with transform

# Wait for Hyprland IPC to answer with a populated monitor list before we
# query serials. On boot the `exec` line in hyprland.conf fires before
# `hyprctl monitors` returns valid data, so without this we'd miss the
# serials and fall back to the catch-all rule. Same idea as waybar's runit
# run script waiting for the Wayland socket. ~10s cap.
MONITORS="[]"
for _ in $(seq 1 50); do
    MONITORS=$(hyprctl monitors -j 2>/dev/null || echo "[]")
    [[ "$(echo "$MONITORS" | jq 'length')" -gt 0 ]] && break
    sleep 0.2
done

# Find which ports our monitors are on by querying hyprctl
LEFTMOST_PORT=$(echo "$MONITORS" | jq -r ".[] | select(.serial==\"$LEFTMOST_SERIAL\") | .name" 2>/dev/null || echo "")
MIDDLE_PORT=$(echo "$MONITORS" | jq -r ".[] | select(.serial==\"$MIDDLE_SERIAL\") | .name" 2>/dev/null || echo "")
HAS_EDP=0
echo "$MONITORS" | jq -e '.[] | select(.name=="eDP-1")' > /dev/null 2>&1 && HAS_EDP=1

# Configure each known monitor that is currently connected, keeping its
# absolute position so left/right relationships hold even when one of the
# three is unplugged. Workspace defaults are only set for present monitors.
if [[ -n "$LEFTMOST_PORT" ]]; then
    hyprctl keyword monitor "$LEFTMOST_PORT,1920x1080@60,0x840,1"
    hyprctl keyword workspace "1, monitor:$LEFTMOST_PORT, default:true"
    hyprctl dispatch moveworkspacetomonitor 1 "$LEFTMOST_PORT"
fi

if [[ -n "$MIDDLE_PORT" ]]; then
    hyprctl keyword monitor "$MIDDLE_PORT,1920x1080@60,1920x0,1,transform,1"
    hyprctl keyword workspace "2, monitor:$MIDDLE_PORT, default:true"
    hyprctl dispatch moveworkspacetomonitor 2 "$MIDDLE_PORT"
fi

if (( HAS_EDP )); then
    hyprctl keyword monitor "eDP-1,1920x1080@60,3000x840,1"
    hyprctl keyword workspace "3, monitor:eDP-1, default:true"
    hyprctl dispatch moveworkspacetomonitor 3 eDP-1
fi

if [[ -z "$LEFTMOST_PORT" && -z "$MIDDLE_PORT" && $HAS_EDP -eq 0 ]]; then
    echo "Warning: Could not identify any known monitors by serial. Keeping current configuration."
    exit 0
fi

