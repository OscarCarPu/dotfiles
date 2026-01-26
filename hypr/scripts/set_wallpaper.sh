#!/bin/bash
set -euo pipefail

WALLPAPER_DIR="$HOME/media/images/main"
CACHE_DIR="$HOME/.cache"
WALLPAPER_STATE_FILE="$CACHE_DIR/wallpaper_state"

# Verify swaybg is installed
if ! command -v swaybg &>/dev/null; then
    echo "Error: swaybg not found" >&2
    exit 1
fi

# Check if wallpaper directory exists
if [ ! -d "$WALLPAPER_DIR" ]; then
    echo "Error: Wallpaper directory not found: $WALLPAPER_DIR" >&2
    exit 1
fi

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"

# Get list of wallpapers
mapfile -t WALLPAPERS < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) | sort)

NUM_WALLPAPERS=${#WALLPAPERS[@]}

if [ "$NUM_WALLPAPERS" -eq 0 ]; then
    echo "Error: No wallpapers found in $WALLPAPER_DIR" >&2
    exit 1
fi

# Get list of monitors from hyprctl
mapfile -t MONITORS < <(hyprctl monitors | grep "Monitor " | awk '{print $2}' | sed 's/:$//')

if [ "${#MONITORS[@]}" -eq 0 ]; then
    echo "Error: No monitors found" >&2
    exit 1
fi

# Kill old swaybg instances
pkill -x swaybg 2>/dev/null || true
sleep 0.1

# Set random wallpaper for each monitor
for monitor in "${MONITORS[@]}"; do
    RANDOM_INDEX=$((RANDOM % NUM_WALLPAPERS))
    SELECTED_WALLPAPER="${WALLPAPERS[$RANDOM_INDEX]}"

    if [ ! -f "$SELECTED_WALLPAPER" ]; then
        echo "Error: Selected wallpaper no longer exists: $SELECTED_WALLPAPER" >&2
        continue
    fi

    # Start swaybg for this monitor
    swaybg -o "$monitor" -i "$SELECTED_WALLPAPER" -m fit &
done

# Save state for reference (optional)
{
    for monitor in "${MONITORS[@]}"; do
        echo "monitor=$monitor"
    done
} >"$WALLPAPER_STATE_FILE"
