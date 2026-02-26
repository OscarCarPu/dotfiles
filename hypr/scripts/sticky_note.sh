#!/bin/bash
# Toggle a floating sticky note window (kitty + micro)
# Keybinding: SUPER + SHIFT + N

NOTES_FILE="$HOME/.sticky-notes.md"

if hyprctl clients -j | grep -q '"class": "sticky-notes"'; then
    hyprctl dispatch closewindow class:sticky-notes
else
    kitty --class sticky-notes -e micro "$NOTES_FILE"
fi
