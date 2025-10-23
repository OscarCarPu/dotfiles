# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository for an Arch Linux system running Hyprland (Wayland compositor). The configuration manages a dual-monitor desktop environment with custom keybindings, scripts, and integrations.

## Architecture

### Core Components

**Hyprland Configuration** (`hypr/`)
- Main config: `hypr/hyprland.conf` - Central Hyprland configuration with monitor setup, keybindings, window rules, and startup programs
- Scripts directory: `hypr/scripts/` - Utility scripts for system management
- Wallpapers: `hypr/wallpapers/` - Wallpaper images with rotation tracking via `wallpaper_index.txt`

**Waybar** (`waybar/`)
- Status bar configuration for Hyprland
- `config.jsonc` defines modules (workspaces, clock, CPU, memory, network, brightness, audio, battery)
- Custom modules integrate with hypr scripts (brightness control)
- `style.css` provides styling

**SwayNC** (`swaync/`)
- Notification daemon configuration for Wayland
- Minimal config with timeout settings

**OneDrive Sync** (`onedrive/`)
- Configuration for OneDrive client
- Syncs to `~/Files` directory
- Excludes: `.git`, `venv`, `node_modules`, temp files

### System Integration

**Monitor Setup**
- Dual monitors: HDMI-A-1 (primary, left) at 0x0 + eDP-1 (laptop, right) at 1920x0
- Workspace 1 defaults to HDMI-A-1
- Workspace migration between monitors: `CTRL+ALT+SUPER+comma/period`

**Startup Services** (auto-launched via `exec-once`):
- Waybar status bar
- SwayNC notification daemon
- Wallpaper rotation script
- Brightness monitoring loop (60s interval)
- OneDrive background sync

**Key Scripts**:
- `brightness.sh` - Controls Intel backlight via brightnessctl (up/down/get modes)
- `set_wallpaper.sh` - Rotates wallpapers using swaybg with index tracking
- `onedrive_sync.sh` - Triggers OneDrive sync in background
- `shutdown.sh` - Interactive shutdown with system update workflow (OneDrive sync → pacman → yay → shutdown prompt)

### Key Bindings

**System**:
- `SUPER+V` - Shutdown script (with updates)
- `SUPER+N` - Toggle notification center
- `Print` - Screenshot to clipboard (grim + slurp)

**Applications**:
- `SUPER+E` - Kitty terminal
- `SUPER+R` - Wofi launcher
- `SUPER+F` - Chrome browser
- `SUPER+P` - Spotify
- `SUPER+O` - SoundCloud web app
- `SUPER+Q` - Kill active window

**Window Management**:
- `SUPER+arrows` - Focus direction
- `SUPER+tab` - Cycle windows
- `SUPER+1-9` - Switch workspace
- `SUPER+SHIFT+1-8` - Move to workspace
- `SUPER+W` - Rotate wallpaper

## Testing and Validation

**Configuration Testing**:
```bash
# Validate Hyprland config syntax
hyprctl reload

# Test waybar config
waybar -c waybar/config.jsonc -s waybar/style.css

# Check script execution
bash hypr/scripts/brightness.sh get
bash hypr/scripts/set_wallpaper.sh
```

**Script Testing**:
- Scripts use standard bash - test with `bash -n <script>` for syntax
- Brightness script requires `brightnessctl` and Intel backlight device
- Wallpaper script requires `swaybg` and populated `hypr/wallpapers/` directory

## Dependencies

**Required packages**:
- hyprland - Wayland compositor
- waybar - Status bar
- swaync - Notification daemon
- brightnessctl - Backlight control
- swaybg - Wallpaper manager
- grim, slurp - Screenshots
- wl-clipboard - Wayland clipboard
- wofi - Application launcher
- kitty - Terminal emulator
- onedrive - OneDrive sync client
- pacman, yay - Package managers

## Configuration Locations

This dotfiles repo expects to be deployed with configs linked to standard XDG locations:
- Hyprland: `~/.config/hypr/` → `dotfiles/hypr/`
- Waybar: `~/.config/waybar/` → `dotfiles/waybar/`
- SwayNC: `~/.config/swaync/` → `dotfiles/swaync/`
- OneDrive: `~/.config/onedrive/` → `dotfiles/onedrive/`

Scripts reference paths as `~/.config/hypr/scripts/` - maintain these paths when modifying.

## Important Patterns

**Path References**:
- Scripts use absolute paths with `$HOME` or `~` expansion
- Hyprland config uses `~/.config/hypr/scripts/` for script paths
- OneDrive syncs to `~/Files` (not `~/OneDrive`)

**State Files**:
- `wallpaper_index.txt` - Tracks current wallpaper rotation position
- `onedrive/items.sqlite3` - OneDrive sync state database
- `onedrive/refresh_token` - Authentication token (sensitive)

**Window Rules**:
- Kitty terminals with `kitty_float` title are floating/centered
- SoundCloud app runs fullscreen without borders

## Localization

- Keyboard layout: Spanish (es)
- Timezone: Europe/Madrid (waybar clock)
