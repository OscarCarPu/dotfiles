#!/bin/bash
set -euo pipefail

WALLPAPER_DIR="$HOME/media/images/main"

if ! command -v awww &>/dev/null; then
    echo "Error: awww not found" >&2
    exit 1
fi

if [ ! -d "$WALLPAPER_DIR" ]; then
    echo "Error: Wallpaper directory not found: $WALLPAPER_DIR" >&2
    exit 1
fi

# Ensure the daemon is running
awww query &>/dev/null || awww-daemon &

# Get list of wallpapers
mapfile -t WALLPAPERS < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) | sort)

NUM_WALLPAPERS=${#WALLPAPERS[@]}

if [ "$NUM_WALLPAPERS" -eq 0 ]; then
    echo "Error: No wallpapers found in $WALLPAPER_DIR" >&2
    exit 1
fi

# Get list of monitors
mapfile -t MONITORS < <(hyprctl monitors | grep "Monitor " | awk '{print $2}' | sed 's/:$//')

if [ "${#MONITORS[@]}" -eq 0 ]; then
    echo "Error: No monitors found" >&2
    exit 1
fi

# Set random wallpaper for each monitor
for monitor in "${MONITORS[@]}"; do
    RANDOM_INDEX=$((RANDOM % NUM_WALLPAPERS))
    SELECTED_WALLPAPER="${WALLPAPERS[$RANDOM_INDEX]}"

    if [ ! -f "$SELECTED_WALLPAPER" ]; then
        echo "Error: Selected wallpaper no longer exists: $SELECTED_WALLPAPER" >&2
        continue
    fi

    awww img -o "$monitor" --resize fit --transition-type fade --transition-duration 1 "$SELECTED_WALLPAPER"
done
