#!/bin/bash
# Configure monitors based on EDID serial numbers
# This ensures correct monitor positioning regardless of KVM port swapping
set -euo pipefail

# Define monitor serials and their correct configurations
LEFTMOST_SERIAL="LXLEE0524282"      # Should be at 0x840
MIDDLE_SERIAL="PC3M665802149"       # Should be at 1920x0 with transform

# Get current hyprctl monitor output
MONITORS=$(hyprctl monitors -j)

# Find which ports our monitors are on by querying hyprctl
LEFTMOST_PORT=$(echo "$MONITORS" | jq -r ".[] | select(.serial==\"$LEFTMOST_SERIAL\") | .name" 2>/dev/null || echo "")
MIDDLE_PORT=$(echo "$MONITORS" | jq -r ".[] | select(.serial==\"$MIDDLE_SERIAL\") | .name" 2>/dev/null || echo "")

# If we couldn't find monitors by serial, bail out
if [[ -z "$LEFTMOST_PORT" ]] || [[ -z "$MIDDLE_PORT" ]]; then
    echo "Warning: Could not identify monitors by serial. Keeping current configuration."
    exit 0
fi

# Apply configurations based on identified ports
# Leftmost monitor: position at 0x840
hyprctl keyword monitor "$LEFTMOST_PORT,1920x1080@60,0x840,1"

# Middle monitor: position at 1920x0 with rotation
hyprctl keyword monitor "$MIDDLE_PORT,1920x1080@60,1920x0,1,transform,1"

# Note: eDP-1 (laptop screen) is configured separately if present
if echo "$MONITORS" | jq -e '.[] | select(.name=="eDP-1")' > /dev/null 2>&1; then
    hyprctl keyword monitor "eDP-1,1920x1080@60,3000x840,1"
fi

# Bind default workspaces: 1=left, 2=middle, 3=right
hyprctl keyword workspace "1, monitor:$LEFTMOST_PORT, default:true"
hyprctl keyword workspace "2, monitor:$MIDDLE_PORT, default:true"
if echo "$MONITORS" | jq -e '.[] | select(.name=="eDP-1")' > /dev/null 2>&1; then
    hyprctl keyword workspace "3, monitor:eDP-1, default:true"
fi

# Force-move existing workspaces to the correct monitors
hyprctl dispatch moveworkspacetomonitor 1 "$LEFTMOST_PORT"
hyprctl dispatch moveworkspacetomonitor 2 "$MIDDLE_PORT"
if echo "$MONITORS" | jq -e '.[] | select(.name=="eDP-1")' > /dev/null 2>&1; then
    hyprctl dispatch moveworkspacetomonitor 3 eDP-1
fi

