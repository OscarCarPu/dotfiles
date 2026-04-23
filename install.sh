#!/bin/bash

# Map for symlinking
declare -A DOTFILES=(
    ["configs/chromium-flags.conf"]="$HOME/.config/chromium-flags.conf"
    ["hypr"]="$HOME/.config/hypr"
    ["nvim"]="$HOME/.config/nvim"
    ["waybar"]="$HOME/.config/waybar"
    ["swaync"]="$HOME/.config/swaync"
    ["wireplumber"]="$HOME/.config/wireplumber"
    ["git/.gitconfig"]="$HOME/.gitconfig"
    ["configs/user-places.xbel"]="$HOME/.local/share/user-places.xbel"
    ["configs/gtk-3.0/bookmarks"]="$HOME/.config/gtk-3.0/bookmarks"
    ["systemd/rclone-bisync-arreglos.service"]="$HOME/.config/systemd/user/rclone-bisync-arreglos.service"
    ["systemd/rclone-bisync-arreglos.timer"]="$HOME/.config/systemd/user/rclone-bisync-arreglos.timer"
    ["configs/sysctl.d/90-disable-ipv6.conf"]="/etc/sysctl.d/90-disable-ipv6.conf"
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

# Scripts: per-file symlinks so ~/.local/bin stays a real directory
# and external tools (uv, claude, etc.) can write there without polluting this repo.
LOCAL_BIN="$HOME/.local/bin"
SCRIPTS_DIR="$DOTFILES_DIR/scripts"

if [ -L "$LOCAL_BIN" ]; then
    echo " Converting $LOCAL_BIN from directory symlink to real directory..."
    rm "$LOCAL_BIN"
fi
mkdir -p "$LOCAL_BIN"

for script in "$SCRIPTS_DIR"/*; do
    script_name=$(basename "$script")
    target="$LOCAL_BIN/$script_name"
    if [ -e "$target" ] || [ -L "$target" ]; then
        rm -f "$target"
    fi
    echo " Symlinking script: $script_name"
    ln -sf "$script" "$target"
done

echo "Done!"
