#!/bin/bash

# User-level symlinks (config files and dirs)
declare -A DOTFILES=(
    ["bash/.bash_profile"]="$HOME/.bash_profile"
    ["bash/.bashrc"]="$HOME/.bashrc"
    ["home/Makefile"]="$HOME/Makefile"
    ["hypr"]="$HOME/.config/hypr"
    ["nvim"]="$HOME/.config/nvim"
    ["waybar"]="$HOME/.config/waybar"
    ["swaync"]="$HOME/.config/swaync"
    ["wireplumber"]="$HOME/.config/wireplumber"
    ["git/.gitconfig"]="$HOME/.gitconfig"
    ["configs/user-places.xbel"]="$HOME/.local/share/user-places.xbel"
    ["configs/gtk-3.0/bookmarks"]="$HOME/.config/gtk-3.0/bookmarks"
)

# User-level runit services. Only `run` and `log/run` are symlinked into each
# service dir so that runtime state (supervise/, log/main/) lives outside the repo.
USER_RUNIT_SERVICES=(
    pipewire
    wireplumber
    pipewire-pulse
    set-wallpaper
    battery-notify
)

# System-level files (require sudo). Run with --system flag to apply.
declare -A SYSTEM_DOTFILES=(
    ["configs/sysctl.d/90-disable-ipv6.conf"]="/etc/sysctl.d/90-disable-ipv6.conf"
    ["configs/modules-load.d/evdi.conf"]="/etc/modules-load.d/evdi.conf"
    ["configs/NetworkManager/dispatcher.d/10-eth-no-offloads"]="/etc/NetworkManager/dispatcher.d/10-eth-no-offloads"
    ["runit/system-overrides/elogind-run"]="/etc/runit/sv/elogind/run"
)

# System-level runit services (require sudo). Symlinked into /etc/runit/sv/.
# Activation (linking into /etc/runit/runsvdir/default/) is left to the operator.
SYSTEM_RUNIT_SERVICES=(
    displaylink
)

DOTFILES_DIR=$(pwd)

if [ "$DOTFILES_DIR" != "$HOME/.dotfiles" ]; then
    echo "Dotfiles are not on .dotfiles, you are in $DOTFILES_DIR"
    read -p "Continue? [y/N] " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || exit 1
fi

# --- helpers --------------------------------------------------------------

link_file() {
    local src="$1" target="$2"
    mkdir -p "$(dirname "$target")"
    if [ -e "$target" ] || [ -L "$target" ]; then
        echo " Removing existing: $target"
        rm -rf "$target"
    fi
    echo " Symlinking: $src -> $target"
    ln -sf "$src" "$target"
}

sudo_link_file() {
    local src="$1" target="$2"
    sudo mkdir -p "$(dirname "$target")"
    if sudo test -e "$target" || sudo test -L "$target"; then
        echo " Removing existing: $target"
        sudo rm -rf "$target"
    fi
    echo " Symlinking (sudo): $src -> $target"
    sudo ln -sf "$src" "$target"
}

# --- system mode ----------------------------------------------------------

if [ "${1:-}" = "--system" ]; then
    echo "Installing system files (sudo)..."
    for src in "${!SYSTEM_DOTFILES[@]}"; do
        sudo_link_file "$DOTFILES_DIR/$src" "${SYSTEM_DOTFILES[$src]}"
    done

    echo "Installing system runit services (sudo)..."
    for svc in "${SYSTEM_RUNIT_SERVICES[@]}"; do
        target="/etc/runit/sv/$svc"
        sudo mkdir -p "$target/log"
        sudo_link_file "$DOTFILES_DIR/runit/system/$svc/run"     "$target/run"
        sudo_link_file "$DOTFILES_DIR/runit/system/$svc/log/run" "$target/log/run"
        echo " To activate: sudo ln -s /etc/runit/sv/$svc /run/runit/service/"
    done

    echo "Done (system)."
    exit 0
fi

# --- user mode (default) --------------------------------------------------

echo "Symlinking user dotfiles..."
for src in "${!DOTFILES[@]}"; do
    link_file "$DOTFILES_DIR/$src" "${DOTFILES[$src]}"
done

echo "Symlinking user runit services..."
for svc in "${USER_RUNIT_SERVICES[@]}"; do
    target="$HOME/.local/share/runit/sv/$svc"
    mkdir -p "$target/log"
    link_file "$DOTFILES_DIR/runit/user/$svc/run"     "$target/run"
    link_file "$DOTFILES_DIR/runit/user/$svc/log/run" "$target/log/run"
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
    link_file "$script" "$LOCAL_BIN/$script_name"
done

echo "Done."
echo
echo "Next: 'bash install.sh --system' to install /etc files (requires sudo)."
