# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository for an Arch Linux system running Hyprland (Wayland compositor). The configuration manages a dual-monitor desktop environment with custom keybindings, scripts, and integrations.

**Important**: All paths reference `~/dotfiles/` directly (not `~/.config/`). The configuration runs from the repository directory without requiring symlinks.

## Architecture

### Core Components

**Hyprland Configuration** (`hypr/`)
- Main config: `hypr/hyprland.conf` - Central Hyprland configuration with monitor setup, keybindings, window rules, startup programs, and misc settings (VRR, power management, window swallowing)
- Scripts directory: `hypr/scripts/` - Utility scripts for system management with proper error handling

**Waybar** (`waybar/`)
- Status bar configuration for Hyprland
- `config.jsonc` defines modules (workspaces, clock, CPU, memory, network, brightness, audio, battery)
- Custom modules integrate with hypr scripts (brightness control)
- `style.css` provides styling with CSS variables for easy theme customization

**Neovim Configuration** (`nvim/`)
- LazyVim-based configuration
- Custom plugins for DBML support

**SwayNC** (`swaync/`)
- Notification daemon configuration for Wayland
- Minimal config with timeout settings

**Chromium** (`chromium/`)
- Browser flags optimized for Wayland + Intel graphics
- `chromium-flags.conf` symlinked to `~/.config/chromium-flags.conf`
- Wayland/Ozone platform configuration
- Intel GPU hardware acceleration (VaapiVideo)
- Performance optimizations (disabled GPU vsync, driver workarounds)

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
- Automatic wallpaper rotation (every 60 seconds)
- Battery notification monitoring (every 30 seconds)
- OneDrive background sync

**Key Scripts**:
- `brightness.sh` - Controls Intel backlight via brightnessctl with error handling (up/down/get modes)
- `set_wallpaper.sh` - Automatically rotates wallpapers from `~/Files/Imágenes/Wallpapers` using swaybg. Detects current wallpaper and cycles alphabetically without requiring index files
- `battery_notify.sh` - Monitors battery and sends notifications at 15% and 10% with state tracking to prevent duplicates
- `onedrive_sync.sh` - Triggers OneDrive sync with logging to `~/.cache/onedrive_sync.log`
- `shutdown.sh` - Interactive shutdown with comprehensive error handling for system updates (OneDrive sync → pacman → yay → shutdown prompt)

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
- Scripts use bash with `set -euo pipefail` for safety - test with `bash -n <script>` for syntax
- All scripts include error handling and dependency checks
- Brightness script requires `brightnessctl` and Intel backlight device
- Wallpaper script requires `swaybg` and wallpapers in `~/Files/Imágenes/Wallpapers/`
- Run `./scripts/check_dependencies.sh` to verify all required packages are installed

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
- google-chrome - Web browser
- libnotify, libpulse - System libraries

**Optional/AUR packages**:
- onedrive-abraunegg - OneDrive sync client
- yay - AUR helper
- spotify - Music player
- wlogout - Logout menu (referenced in waybar)
- neovim - Text editor

Run `./scripts/check_dependencies.sh` to check which packages are installed.

## Configuration Locations

This dotfiles repository runs directly from `~/dotfiles/` with minimal symlinks:
- Hyprland config: `~/dotfiles/hypr/hyprland.conf`
- Scripts: `~/dotfiles/hypr/scripts/`
- Waybar: `~/dotfiles/waybar/`
- SwayNC: `~/dotfiles/swaync/`
- Neovim: `~/dotfiles/nvim/`
- OneDrive: `~/dotfiles/onedrive/`
- Chromium: `~/dotfiles/chromium/` (symlinked to `~/.config/chromium-flags.conf`)

**Installation**: Run `./scripts/install.sh` to set up the environment, create symlinks, and check dependencies.

## Important Patterns

**Path References**:
- All scripts use absolute paths with `$HOME` or `~` expansion
- Most configurations reference `~/dotfiles/` directly (not `~/.config/`)
- Exception: `chromium-flags.conf` symlinked to `~/.config/` (required by Chromium)
- Wallpapers stored in `~/Files/Imágenes/Wallpapers/` (synced via OneDrive)
- OneDrive syncs to `~/Files` (not `~/OneDrive`)

**State Files** (gitignored):
- `~/.cache/battery_notify_state` - Battery notification state tracking
- `~/.cache/onedrive_sync.log` - OneDrive sync logs
- `onedrive/items.sqlite3` - OneDrive sync state database (sensitive)
- `onedrive/refresh_token` - Authentication token (SENSITIVE - never commit!)

**Security**:
- `.gitignore` excludes sensitive OneDrive files and state files
- All scripts include input validation and error handling

**Window Rules**:
- Kitty terminals with `kitty_float` title are floating/centered
- SoundCloud app runs fullscreen without borders

## Localization

- Keyboard layout: Spanish (es)
- Timezone: Europe/Madrid (waybar clock)
