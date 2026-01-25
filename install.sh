#!/bin/bash

# Map for symlinking
declare -A DOTFILES=(
    ["configs/chromium-flags.conf"]="$HOME/.config/chromium-flags.conf"
    ["hypr"]="$HOME/.config/hypr"
    ["nvim"]="$HOME/.config/nvim"
    ["waybar"]="$HOME/.config/waybar"
    ["swaync"]="$HOME/.config/swaync"
    ["scripts"]="$HOME/.local/bin"
)

# Check if running from the dotfiles directory
DOTFILES_DIR=$(pwd)

if [ $DOTFILES_DIR != $HOME/.dotfiles ]; then
    echo "Dotfiles are not on .dotfiles, you are in $DOTFILES_DIR"
    echo "Do you want to continue? [y/N]"
    read -p "(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Continuing..."
    else
        echo "Exiting..."
        exit 1
    fi
fi

echo "Symlinking..."

for src in "${!DOTFILES[@]}"; do
    target="${DOTFILES[$src]}"
    src_path="$DOTFILES_DIR/$src"

    mkdir -p "$(dirname "$target")"

    if [ -e "$target" ] || [ -L "$target" ]; then
        echo " Removing existing: $target"
        rm -rf "$target"
    fi

    echo " Symlinking: $src -> $target"
    ln -sf "$src_path" "$target"
done

echo "Done!"
