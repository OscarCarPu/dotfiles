
#!/bin/bash

WALLPAPER_DIR="$HOME/.config/hypr/wallpapers"

if [ -d "$WALLPAPER_DIR" ] && [ "$(ls -A "$WALLPAPER_DIR")" ]; then
  RANDOM_WALLPAPER=$(ls "$WALLPAPER_DIR" | shuf -n 1)
  WALLPAPER_PATH="$WALLPAPER_DIR/$RANDOM_WALLPAPER"

  swaybg -i "$WALLPAPER_PATH" -m fill &

  pgrep swaybg | grep -v "$!" | xargs kill
fi
