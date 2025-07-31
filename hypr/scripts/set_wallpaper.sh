#!/bin/bash

WALLPAPER_DIR="$HOME/.config/hypr/wallpapers"
INDEX_FILE="$HOME/.config/hypr/wallpaper_index.txt"

if [ -d "$WALLPAPER_DIR" ] && [ "$(ls -A "$WALLPAPER_DIR")" ]; then
    WALLPAPERS=( $(ls -1 "$WALLPAPER_DIR") )
    NUM_WALLPAPERS=${#WALLPAPERS[@]}
    CURRENT_INDEX=0
    if [ -f "$INDEX_FILE" ]; then
        CURRENT_INDEX=$(cat "$INDEX_FILE")
    fi
    NEXT_INDEX=$(( (CURRENT_INDEX + 1) % NUM_WALLPAPERS ))
    NEXT_WALLPAPER="${WALLPAPERS[$NEXT_INDEX]}"
    WALLPAPER_PATH="$WALLPAPER_DIR/$NEXT_WALLPAPER"

    swaybg -i "$WALLPAPER_PATH" -m fit -c "#000000" &

    pgrep swaybg | grep -v "$!" | xargs kill

    echo "$NEXT_INDEX" > "$INDEX_FILE"
fi
