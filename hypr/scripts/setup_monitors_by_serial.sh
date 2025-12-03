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
