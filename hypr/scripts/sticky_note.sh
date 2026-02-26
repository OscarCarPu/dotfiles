#!/bin/bash
# Toggle a floating sticky note window (kitty + micro)
# Keybinding: SUPER + SHIFT + N

NOTES_FILE="$HOME/.sticky-notes.md"

if hyprctl clients -j | grep -q '"class": "sticky-notes"'; then
    hyprctl dispatch closewindow class:sticky-notes
else
    touch "$NOTES_FILE"
    kitty \
        --class sticky-notes \
        --override window_padding_width=16 \
        -e vim -c "source $HOME/.dotfiles/hypr/scripts/sticky_note.vim" "$NOTES_FILE"
fi
