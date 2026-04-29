#!/bin/bash
# Install every package listed in docs/packages.md, plus the `uv tool`
# dependencies that nvim's Python LSP/formatter needs.
#
# Skips sections marked as not managed by this repo:
#   - "Base system"                      (provided by the Artix install medium)
#   - "External programs (not via pacman)" (claude, bun)
#
# Uses yay for everything else: it falls back to pacman for repo packages and
# builds AUR ones in the same run.
set -euo pipefail

DOTFILES_DIR=$(cd "$(dirname "$0")" && pwd)
PACKAGES_MD="$DOTFILES_DIR/docs/packages.md"

if [ ! -f "$PACKAGES_MD" ]; then
    echo "Cannot find $PACKAGES_MD" >&2
    exit 1
fi

# --- bootstrap yay --------------------------------------------------------

if ! command -v yay >/dev/null 2>&1; then
    echo "yay not found; bootstrapping yay-bin from AUR..."
    sudo pacman -S --needed --noconfirm git base-devel
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' EXIT
    git clone https://aur.archlinux.org/yay-bin.git "$tmpdir/yay-bin"
    (cd "$tmpdir/yay-bin" && makepkg -si --noconfirm)
fi

# --- parse packages.md ----------------------------------------------------

# Convention in packages.md: each list item starts "- `pkg`[, `pkg`]*"
# followed by optional " — prose" where further backticks are just references.
# Capture only the leading comma-separated run of packages.
mapfile -t pkgs < <(awk '
    /^## / {
        heading = substr($0, 4)
        include = (heading != "Base system" && \
                   heading != "External programs (not via pacman)")
        next
    }
    include && /^- `[a-z0-9]/ {
        line = $0
        sub(/^- /, "", line)
        while (match(line, /^`[a-z0-9][a-z0-9._+-]*`/)) {
            print substr(line, RSTART + 1, RLENGTH - 2)
            line = substr(line, RSTART + RLENGTH)
            if (match(line, /^,[ \t]+/)) {
                line = substr(line, RSTART + RLENGTH)
            } else {
                break
            }
        }
    }
' "$PACKAGES_MD")

if [ "${#pkgs[@]}" -eq 0 ]; then
    echo "No packages parsed from $PACKAGES_MD — aborting." >&2
    exit 1
fi

echo "Installing ${#pkgs[@]} packages from packages.md (repo + AUR via yay)..."
printf '  %s\n' "${pkgs[@]}"
yay -S --needed "${pkgs[@]}"

# --- uv-managed Python tooling for nvim -----------------------------------

if command -v uv >/dev/null 2>&1; then
    echo "Installing pyright + ruff via uv tool (nvim Python LSP/formatter)..."
    uv tool install pyright
    uv tool install ruff
else
    echo "uv not on PATH — skipping pyright/ruff." >&2
    echo "Open a new shell so PATH picks up uv, then re-run this script." >&2
fi

# --- cargo-installed ESP32 tooling ----------------------------------------

echo "Installing espup + espflash via cargo (ESP32 toolchain)..."
cargo install --locked espup
cargo install --locked espflash
espup install

# --- refresh running Hyprland env so new /etc/profile.d/*.sh takes effect -
# Newly installed packages may drop into /etc/profile.d/ (e.g. flatpak.sh
# adds XDG_DATA_DIRS so launchers see .desktop entries). The compositor
# was started before that file existed, so push the fresh values in.

if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    echo "Refreshing Hyprland env (XDG_DATA_DIRS, PATH) from /etc/profile..."
    new_xdg=$(env -i HOME="$HOME" PATH=/usr/bin:/usr/sbin bash -lc 'printf %s "$XDG_DATA_DIRS"')
    new_path=$(env -i HOME="$HOME" PATH=/usr/bin:/usr/sbin bash -lc 'printf %s "$PATH"')
    hyprctl keyword env "XDG_DATA_DIRS,$new_xdg" >/dev/null
    hyprctl keyword env "PATH,$new_path" >/dev/null
fi

echo "Done."
