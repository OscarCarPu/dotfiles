#!/bin/bash

# User-level symlinks (config files and dirs)
declare -A DOTFILES=(
    ["bash/.bash_profile"]="$HOME/.bash_profile"
    ["bash/.bashrc"]="$HOME/.bashrc"
    ["home/Makefile"]="$HOME/Makefile"
    ["hypr"]="$HOME/.config/hypr"
    ["nvim"]="$HOME/.config/nvim"
    ["waybar"]="$HOME/.config/waybar"
    ["wofi"]="$HOME/.config/wofi"
    ["swaync"]="$HOME/.config/swaync"
    ["wireplumber"]="$HOME/.config/wireplumber"
    ["git/.gitconfig"]="$HOME/.gitconfig"
    ["configs/user-places.xbel"]="$HOME/.local/share/user-places.xbel"
    ["configs/user-dirs.dirs"]="$HOME/.config/user-dirs.dirs"
    ["configs/mimeapps.list"]="$HOME/.config/mimeapps.list"
    ["configs/gtk-3.0/bookmarks"]="$HOME/.config/gtk-3.0/bookmarks"
    ["configs/gtk-3.0/settings.ini"]="$HOME/.config/gtk-3.0/settings.ini"
    ["configs/PrusaSlicer/filament"]="$HOME/.config/PrusaSlicer/filament"
    ["configs/PrusaSlicer/printer"]="$HOME/.config/PrusaSlicer/printer"
    ["configs/PrusaSlicer/print"]="$HOME/.config/PrusaSlicer/print"
    ["configs/applications/autofirma.desktop"]="$HOME/.local/share/applications/autofirma.desktop"
    ["configs/applications/nvim-kitty.desktop"]="$HOME/.local/share/applications/nvim-kitty.desktop"
    ["claude/skills"]="$HOME/.claude/skills"
    ["configs/librewolf.overrides.cfg"]="$HOME/.librewolf/librewolf.overrides.cfg"
)

# User-level runit services. Only `run` and `log/run` are symlinked into each
# service dir so that runtime state (supervise/, log/main/) lives outside the repo.
USER_RUNIT_SERVICES=(
    pipewire
    wireplumber
    pipewire-pulse
    set-wallpaper
    battery-notify
    waybar
    obsidian-theme
    seafile
)

# System-level files (require sudo). Run with --system flag to apply.
declare -A SYSTEM_DOTFILES=(
    ["configs/sysctl.d/90-disable-ipv6.conf"]="/etc/sysctl.d/90-disable-ipv6.conf"
    ["configs/modules-load.d/evdi.conf"]="/etc/modules-load.d/evdi.conf"
    ["configs/NetworkManager/dispatcher.d/10-eth-no-offloads"]="/etc/NetworkManager/dispatcher.d/10-eth-no-offloads"
    ["configs/udev/rules.d/50-dock-usb-no-autosuspend.rules"]="/etc/udev/rules.d/50-dock-usb-no-autosuspend.rules"
    ["runit/system-overrides/elogind-run"]="/etc/runit/sv/elogind/run"
    ["configs/pacman.conf"]="/etc/pacman.conf"
)

# Sudoers drop-ins. Cannot be symlinked — sudo refuses files not owned by
# root with mode > 0440, and validation walks symlinks to the target.
declare -A SYSTEM_SUDOERS=(
    ["configs/sudoers.d/10-cpu-governor"]="/etc/sudoers.d/10-cpu-governor"
)

# System-level runit services (require sudo). Symlinked into /etc/runit/sv/.
# Use this for services whose run script lives in this repo
# (`runit/system/<svc>/run`).
SYSTEM_RUNIT_SERVICES=(
    displaylink
)

# System-level runit services to activate at boot. Each entry is symlinked
# from /etc/runit/runsvdir/current/<svc> -> /etc/runit/sv/<svc>. Use this for
# both repo-provided services (above) and package-provided services
# (e.g. docker-runit ships /etc/runit/sv/docker).
SYSTEM_RUNIT_ACTIVATE=(
    displaylink
    docker
)

# Groups the invoking user (`$SUDO_USER`) should belong to. Applied in
# --system mode via `gpasswd -a` (idempotent).
SYSTEM_GROUPS=(
    docker
    uucp
    android-sdk
    adbusers
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

sudo_install_sudoers() {
    local src="$1" target="$2"
    sudo mkdir -p "$(dirname "$target")"
    echo " Installing (sudo, 0440 root): $src -> $target"
    sudo install -m 0440 -o root -g root "$src" "$target"
    sudo visudo -cf "$target" >/dev/null
}

# --- system mode ----------------------------------------------------------

if [ "${1:-}" = "--system" ]; then
    echo "Installing system files (sudo)..."
    for src in "${!SYSTEM_DOTFILES[@]}"; do
        sudo_link_file "$DOTFILES_DIR/$src" "${SYSTEM_DOTFILES[$src]}"
    done

    echo "Installing sudoers drop-ins (sudo)..."
    for src in "${!SYSTEM_SUDOERS[@]}"; do
        sudo_install_sudoers "$DOTFILES_DIR/$src" "${SYSTEM_SUDOERS[$src]}"
    done

    echo "Installing system runit services (sudo)..."
    for svc in "${SYSTEM_RUNIT_SERVICES[@]}"; do
        target="/etc/runit/sv/$svc"
        sudo mkdir -p "$target/log"
        sudo_link_file "$DOTFILES_DIR/runit/system/$svc/run"     "$target/run"
        sudo_link_file "$DOTFILES_DIR/runit/system/$svc/log/run" "$target/log/run"
    done

    echo "Activating system runit services (sudo)..."
    for svc in "${SYSTEM_RUNIT_ACTIVATE[@]}"; do
        if [ ! -d "/etc/runit/sv/$svc" ]; then
            echo " Skipping $svc: /etc/runit/sv/$svc missing (install the package?)"
            continue
        fi
        sudo_link_file "/etc/runit/sv/$svc" "/etc/runit/runsvdir/current/$svc"
    done

    target_user="${SUDO_USER:-$USER}"
    if [ -n "$target_user" ] && [ "$target_user" != "root" ]; then
        echo "Adding $target_user to system groups (sudo)..."
        for grp in "${SYSTEM_GROUPS[@]}"; do
            if ! getent group "$grp" >/dev/null; then
                echo " Skipping $grp: group does not exist (install the package?)"
                continue
            fi
            echo " gpasswd -a $target_user $grp"
            sudo gpasswd -a "$target_user" "$grp" >/dev/null
        done
    else
        echo "Skipping group setup: no non-root invoking user (set SUDO_USER)."
    fi

    echo "Reloading udev rules (sudo)..."
    sudo udevadm control --reload-rules
    sudo udevadm trigger

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
    mkdir -p "$target/log/main"
    link_file "$DOTFILES_DIR/runit/user/$svc/run"     "$target/run"
    link_file "$DOTFILES_DIR/runit/user/$svc/log/run" "$target/log/run"
done

# Librewolf user.js: symlink into the install-default profile so session prefs
# survive across restarts. Detects the profile dynamically from profiles.ini.
lw_profile=$(awk -F= '/^\[Install/{found=1} found && /^Default=/{print $2; exit}' \
    "$HOME/.librewolf/profiles.ini" 2>/dev/null)
if [ -n "$lw_profile" ]; then
    link_file "$DOTFILES_DIR/configs/librewolf-user.js" \
        "$HOME/.librewolf/$lw_profile/user.js"
else
    echo " Skipping librewolf user.js: no Librewolf profile found (launch it once first)"
fi

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
    # Skip dangling entries: a tracked symlink whose target has gone away (e.g.
    # a self-updating tool like claude that moved to a new version dir) must
    # not be linked into ~/.local/bin, or it would clobber a working binary.
    if [ ! -e "$script" ]; then
        echo " Skipping $(basename "$script"): broken symlink ($(readlink "$script"))"
        continue
    fi
    script_name=$(basename "$script")
    link_file "$script" "$LOCAL_BIN/$script_name"
done

echo "Done."
echo
echo "Next:"
echo "  bash install.sh --system   # /etc files (requires sudo)"
echo "  bash install-packages.sh   # pacman/AUR packages from docs/packages.md"
