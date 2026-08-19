#!/bin/bash
# Rotate the wallpaper one step through the directory, in filename order.
#
# Sequential rather than random so every image gets shown once per cycle
# instead of the same handful reappearing while others never come up. The
# position is kept in INDEX_FILE, so the `set-wallpaper` service's 180 s pass
# and a manual SUPER + W both advance the same cursor.
#
# On a cold start (no index yet) the starting point is random, so a fresh boot
# doesn't always open on the same image.
set -euo pipefail

WALLPAPER_DIR="$HOME/media/images/main"
INDEX_FILE="${WALLPAPER_INDEX_FILE:-$HOME/.cache/wallpaper_index}"

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

# Get list of wallpapers. Sorted, so the sequence is stable across runs.
mapfile -t WALLPAPERS < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \
    \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | sort)

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

# Current position. A missing/garbage index means first run: start somewhere
# random. Files being added or removed just shifts the cursor, hence the
# modulo rather than a bounds check.
INDEX=$(cat "$INDEX_FILE" 2>/dev/null || true)
case "$INDEX" in
'' | *[!0-9]*) INDEX=$((RANDOM % NUM_WALLPAPERS)) ;;
*) INDEX=$((INDEX % NUM_WALLPAPERS)) ;;
esac

# Monitors are offset from each other so a multi-head setup doesn't show the
# same image twice, and the cursor advances by one image per monitor.
for i in "${!MONITORS[@]}"; do
    monitor="${MONITORS[$i]}"
    SELECTED_WALLPAPER="${WALLPAPERS[$(((INDEX + i) % NUM_WALLPAPERS))]}"

    if [ ! -f "$SELECTED_WALLPAPER" ]; then
        echo "Error: Selected wallpaper no longer exists: $SELECTED_WALLPAPER" >&2
        continue
    fi

    awww img -o "$monitor" --resize fit --transition-type fade --transition-duration 1 "$SELECTED_WALLPAPER"
done

mkdir -p "$(dirname "$INDEX_FILE")"
echo "$(((INDEX + ${#MONITORS[@]}) % NUM_WALLPAPERS))" >"$INDEX_FILE"
