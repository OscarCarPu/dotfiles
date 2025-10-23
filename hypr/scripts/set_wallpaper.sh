#!/bin/bash
set -euo pipefail

WALLPAPER_DIR="$HOME/Files/Imágenes/Wallpapers"

# Verify swaybg is installed
if ! command -v swaybg &> /dev/null; then
    echo "Error: swaybg not found" >&2
    exit 1
fi

# Check if wallpaper directory exists
if [ ! -d "$WALLPAPER_DIR" ]; then
    echo "Error: Wallpaper directory not found: $WALLPAPER_DIR" >&2
    exit 1
fi

# Get sorted list of wallpapers
mapfile -t WALLPAPERS < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) | sort)

NUM_WALLPAPERS=${#WALLPAPERS[@]}

if [ "$NUM_WALLPAPERS" -eq 0 ]; then
    echo "Error: No wallpapers found in $WALLPAPER_DIR" >&2
    exit 1
fi

# Find current wallpaper by checking swaybg process
CURRENT_WALLPAPER=$(pgrep -a swaybg | grep -oP '(?<=-i )[^ ]+' | head -1 || echo "")

# Find next wallpaper
if [ -n "$CURRENT_WALLPAPER" ]; then
    # If a wallpaper is currently set, cycle to the next one in sequence
    NEXT_WALLPAPER="${WALLPAPERS[0]}"
    for i in "${!WALLPAPERS[@]}"; do
        if [ "${WALLPAPERS[$i]}" = "$CURRENT_WALLPAPER" ]; then
            NEXT_INDEX=$(( (i + 1) % NUM_WALLPAPERS ))
            NEXT_WALLPAPER="${WALLPAPERS[$NEXT_INDEX]}"
            break
        fi
    done
else
    # If no wallpaper is set, start with a random one
    RANDOM_INDEX=$(( RANDOM % NUM_WALLPAPERS ))
    NEXT_WALLPAPER="${WALLPAPERS[$RANDOM_INDEX]}"
fi

# Kill old swaybg instances
pkill -x swaybg 2>/dev/null || true
sleep 0.1

# Start new wallpaper with fit mode to show entire image
swaybg -i "$NEXT_WALLPAPER" -m fit &
