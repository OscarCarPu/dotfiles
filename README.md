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
- `runit/user/`: User runit services (pipewire stack, set-wallpaper, battery-notify, obsidian-theme, seafile, seafile-watch)
- `runit/system/`: System runit services (displaylink)
- `obsidian/`: Shared Obsidian config (appearance, plugins, theme) — symlinked into every vault by the `obsidian-theme` runit service
- `kitty/`: Kitty terminal configuration
- `ssh/`: SSH client config (host aliases + Cloudflare `ProxyCommand`; no keys)
- `scripts/`: Custom system tools (`~/.local/bin`)
- `configs/`: Small configuration files (sysctl, modules-load, gtk, NetworkManager)
- `claude/`: Claude Code config — skills, `settings.json`, statusline
- `docs/`: Documentation

# Installation

Starting from a blank disk? Everything that has to happen before these commands
work — partitioning, base install, locale, bootloader, first services — is in
[`docs/bootstrap.md`](docs/bootstrap.md).

On a booting Artix with a user and a network:

```bash
git clone https://github.com/OscarCarPu/dotfiles.git ~/.dotfiles
cd ~/.dotfiles

# Local credentials (PrusaLink, ...) — kept out of the repo
install -Dm600 configs/secrets.env.example ~/.config/dotfiles/secrets.env
$EDITOR ~/.config/dotfiles/secrets.env

# Packages from docs/packages.md (bootstraps yay if needed) + uv-managed
# Python tooling (pyright, ruff) for nvim
bash install-packages.sh

# User-level symlinks (configs, runit user services, scripts, git filters)
bash install.sh

# System-level symlinks (sudo): /etc/sysctl.d, /etc/modules-load.d, /etc/runit/sv
bash install.sh --system

# Log out and back in (new groups), then file sync — ~26 GB on a first run
seafile-setup

# Confirm the machine matches the repo
bash install.sh --check
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
- `kitty/kitty.conf` → `~/.config/kitty/kitty.conf`
- `ssh/config` → `~/.ssh/config`
- `waybar` → `~/.config/waybar`
- `wofi` → `~/.config/wofi`
- `swaync` → `~/.config/swaync`
- `wireplumber` → `~/.config/wireplumber`
- `git/.gitconfig` → `~/.gitconfig`
- `configs/user-places.xbel` → `~/.local/share/user-places.xbel`
- `configs/gtk-3.0/bookmarks` → `~/.config/gtk-3.0/bookmarks`
- `configs/gtk-3.0/settings.ini` → `~/.config/gtk-3.0/settings.ini`
- `claude/skills` → `~/.claude/skills`
- `claude/settings.json` → `~/.claude/settings.json`
- `claude/statusline.sh` → `~/.claude/statusline.sh`
- `scripts/*` → `~/.local/bin/`
- `runit/user/<svc>/{run,log/run}` → `~/.local/share/runit/sv/<svc>/...`

System (`bash install.sh --system`):
- `configs/sysctl.d/90-disable-ipv6.conf` → `/etc/sysctl.d/90-disable-ipv6.conf`
- `configs/modules-load.d/evdi.conf` → `/etc/modules-load.d/evdi.conf`
- `configs/pacman.conf` → `/etc/pacman.conf`
- `configs/chrony.conf` → `/etc/chrony.conf`
- `runit/system/displaylink/{run,log/run}` → `/etc/runit/sv/displaylink/...`
- activates: `displaylink`, `docker`, `chrony`, `bluetoothd`, `cupsd`

# More docs

- *Bootstrap*: [Bootstrap](docs/bootstrap.md) — blank disk → this exact system, step by step
- *Packages*: [Packages](docs/packages.md) — single source of truth for what's installed
- *System*: [System](docs/system.md) — kernel, runit, drivers, network, post-install fixes
- *Desktop*: [Desktop](docs/desktop.md) — Hyprland, Waybar, monitors, startup, power menu
- *Workflow*: [Workflow](docs/workflow.md) — git aliases, Makefile, bookmarks, bt-spotify, boot-bench
- *Seafile*: [Seafile](docs/seafile.md) — file sync, Cloudflare wrapper, ignore patterns
- *Claude Code*: [Claude](docs/claude.md) — custom skills
- *Printing*: [Printing](docs/printing.md) — CUPS driverless queue for the Epson ET-3850
- *Neovim*: [Neovim](nvim/README.md)
- *Homelab*: [Homelab](docs/homelab.md)

# Maintenance

- No symlink, no entry — everything must go through `install.sh`
- Document as you go
