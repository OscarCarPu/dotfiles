# OCP's Dotfiles

An Artix Hyprland configuration for my daily computer.

# Quick Start

- *OS*: Artix Linux (runit)
- *WM*: Hyprland (Wayland)
- *Terminal*: Kitty
- *Shell*: Bash
- *Editor*: nvim

# Repository Structure

- `bash/`: Bash login + interactive files (`.bash_profile`, `.bashrc`)
- `home/`: Files that live at the root of `$HOME` (e.g. `Makefile`)
- `hypr/`: Hyprland configuration
- `nvim/`: Neovim configuration
- `waybar/`: Waybar configuration
- `wofi/`: Wofi launcher styling
- `swaync/`: SwayNC configuration
- `wireplumber/`: WirePlumber priority rules
- `runit/user/`: User runit services (pipewire stack, set-wallpaper, battery-notify)
- `runit/system/`: System runit services (displaylink)
- `scripts/`: Custom system tools (`~/.local/bin`)
- `configs/`: Small configuration files (sysctl, modules-load, gtk, NetworkManager)
- `claude/`: Claude Code skills (`claude/skills/` → `~/.claude/skills/`)
- `docs/`: Documentation

# Installation

```bash
git clone https://github.com/OscarCarPu/dotfiles.git ~/.dotfiles
cd ~/.dotfiles

# Packages from docs/packages.md (bootstraps yay if needed) + uv-managed
# Python tooling (pyright, ruff) for nvim
bash install-packages.sh

# User-level symlinks (configs, runit user services, scripts)
bash install.sh

# System-level symlinks (sudo): /etc/sysctl.d, /etc/modules-load.d, /etc/runit/sv
bash install.sh --system
```

The package list lives in [`docs/packages.md`](docs/packages.md). System
bring-up (runit, drivers, post-install fixes) is in
[`docs/system.md`](docs/system.md).

# Symlink list

User (`bash install.sh`):
- `bash/.bash_profile` → `~/.bash_profile`
- `bash/.bashrc` → `~/.bashrc`
- `home/Makefile` → `~/Makefile`
- `hypr` → `~/.config/hypr`
- `nvim` → `~/.config/nvim`
- `waybar` → `~/.config/waybar`
- `wofi` → `~/.config/wofi`
- `swaync` → `~/.config/swaync`
- `wireplumber` → `~/.config/wireplumber`
- `git/.gitconfig` → `~/.gitconfig`
- `configs/user-places.xbel` → `~/.local/share/user-places.xbel`
- `configs/gtk-3.0/bookmarks` → `~/.config/gtk-3.0/bookmarks`
- `configs/gtk-3.0/settings.ini` → `~/.config/gtk-3.0/settings.ini`
- `claude/skills` → `~/.claude/skills`
- `scripts/*` → `~/.local/bin/`
- `runit/user/<svc>/{run,log/run}` → `~/.local/share/runit/sv/<svc>/...`

System (`bash install.sh --system`):
- `configs/sysctl.d/90-disable-ipv6.conf` → `/etc/sysctl.d/90-disable-ipv6.conf`
- `configs/modules-load.d/evdi.conf` → `/etc/modules-load.d/evdi.conf`
- `configs/pacman.conf` → `/etc/pacman.conf`
- `runit/system/displaylink/{run,log/run}` → `/etc/runit/sv/displaylink/...`

# More docs

- *Packages*: [Packages](docs/packages.md) — single source of truth for what's installed
- *System*: [System](docs/system.md) — kernel, runit, drivers, network, post-install fixes
- *Desktop*: [Desktop](docs/desktop.md) — Hyprland, Waybar, monitors, startup, power menu
- *Workflow*: [Workflow](docs/workflow.md) — git aliases, Makefile, bookmarks, bt-spotify, boot-bench
- *Claude Code*: [Claude](docs/claude.md) — custom skills
- *Neovim*: [Neovim](nvim/README.md)
- *Homelab*: [Homelab](docs/homelab.md)

# Maintenance

- No symlink, no entry — everything must go through `install.sh`
- Document as you go
