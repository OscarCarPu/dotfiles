# Dotfiles

Personal dotfiles for Arch Linux with Hyprland (Wayland compositor) desktop environment.

## Overview

This repository contains configuration files for:
- **Hyprland**: Wayland compositor with dual-monitor setup and custom keybindings
- **Waybar**: Status bar with system monitoring modules
- **SwayNC**: Notification daemon for Wayland
- **Neovim**: LazyVim-based configuration with Python LSP and GitHub Copilot
- **OneDrive**: Cloud storage sync to `~/Files`

## Documentation

Detailed documentation is available in the [`docs/`](docs/) folder:
- **[Neovim Setup Guide](docs/nvim-setup.md)** - Python autocompletion, GitHub Copilot, and editor configuration
- **[Neovim Overview](docs/nvim-overview.md)** - LazyVim introduction and getting started

## System Configuration

### Monitors
- **Primary**: HDMI-A-1 (1920x1080) - Left monitor, workspace 1 default
- **Secondary**: eDP-1 (laptop screen) - Right monitor

### Key Features
- Automatic wallpaper rotation every 60 seconds from `~/Files/Imágenes/Wallpapers`
- Battery notifications at 15% and 10%
- Brightness control with Intel backlight
- OneDrive background sync to `~/Files`
- Spanish keyboard layout
- Custom shutdown workflow with system updates

### Neovim Features
- **LazyVim** distribution with sensible defaults
- **Python Development**: Pyright LSP, Black formatter, Ruff linter, debugpy
- **GitHub Copilot**: AI-powered code suggestions (disabled by default, enable with `:Copilot enable`)
- **Smart Quote Auto-pairing**: Third consecutive quote doesn't auto-pair (perfect for Python docstrings)
- **Line Wrapping**: Enabled by default with word-boundary breaks
- **Tab Size**: 4 spaces (optimized for Python)

See [Neovim Setup Guide](docs/nvim-setup.md) for detailed configuration and usage.

## Installation

### Prerequisites

Install required packages:
```bash
# Core system packages
sudo pacman -S hyprland waybar swaync kitty brightnessctl swaybg \
               grim slurp wl-clipboard wofi google-chrome

# Neovim and development tools
sudo pacman -S neovim nodejs npm python-pip

# AUR packages
yay -S onedrive-abraunegg
```

For Neovim setup (Python LSP, GitHub Copilot), see [Neovim Setup Guide](docs/nvim-setup.md).

### Setup

1. Clone this repository:
```bash
git clone <your-repo-url> ~/dotfiles
cd ~/dotfiles
```

2. Run the installation script:
```bash
./scripts/install.sh
```

Or manually create symlinks if needed (config runs from `~/dotfiles/` by default).

3. Configure OneDrive:
```bash
onedrive --confdir ~/dotfiles/onedrive
```

4. Reload Hyprland:
```bash
hyprctl reload
```

## Key Bindings

### Applications
- `SUPER + E` - Kitty terminal
- `SUPER + R` - Wofi launcher
- `SUPER + F` - Chrome browser
- `SUPER + P` - Spotify
- `SUPER + O` - SoundCloud web app

### System
- `SUPER + V` - Shutdown script (with system updates)
- `SUPER + N` - Toggle notification center
- `SUPER + W` - Rotate wallpaper manually
- `SUPER + SHIFT + O` - Trigger OneDrive sync
- `Print` - Screenshot to clipboard

### Window Management
- `SUPER + Q` - Kill active window
- `SUPER + arrows` - Focus direction
- `SUPER + tab` - Cycle windows
- `SUPER + mouse wheel` - Scroll through workspaces

### Workspaces
- `SUPER + 1-9` - Switch to workspace
- `SUPER + SHIFT + 1-8` - Move window to workspace
- `CTRL + ALT + SUPER + comma/period` - Move workspace between monitors

### Brightness
- `XF86MonBrightnessUp/Down` - Adjust brightness
- Scroll on waybar brightness module also works

## Directory Structure

```
~/dotfiles/
├── hypr/
│   ├── hyprland.conf          # Main Hyprland config
│   └── scripts/
│       ├── brightness.sh       # Brightness control
│       ├── set_wallpaper.sh   # Wallpaper rotation
│       ├── battery_notify.sh  # Battery notifications
│       ├── onedrive_sync.sh   # OneDrive sync trigger
│       └── shutdown.sh        # Update & shutdown workflow
├── waybar/
│   ├── config.jsonc           # Waybar modules config
│   └── style.css              # Waybar styling with CSS variables
├── swaync/
│   ├── config.json            # Notification settings
│   └── style.css              # Notification styling
├── onedrive/
│   ├── config                 # OneDrive configuration
│   └── sync_list              # Sync filter (currently empty)
├── nvim/                      # Neovim LazyVim configuration
│   ├── lua/
│   │   ├── config/            # Base configuration (options, keymaps, autocmds)
│   │   └── plugins/           # Plugin configurations
│   │       ├── python.lua     # Python LSP and tools
│   │       ├── ai.lua         # GitHub Copilot setup
│   │       ├── editor.lua     # Editor behavior (smart quotes)
│   │       └── dbml.lua       # DBML language support
│   └── init.lua               # Neovim entry point
├── docs/                      # Documentation
│   ├── README.md              # Documentation index
│   ├── nvim-setup.md          # Neovim setup guide
│   └── nvim-overview.md       # LazyVim overview
├── CLAUDE.md                  # AI assistant instructions
└── README.md                  # This file
```

## Scripts

### brightness.sh
Controls Intel backlight brightness via `brightnessctl`.
- `brightness.sh up` - Increase by 1%
- `brightness.sh down` - Decrease by 1%
- `brightness.sh get` - Get current percentage

### set_wallpaper.sh
Automatically rotates through wallpapers in `~/Files/Imágenes/Wallpapers`. Detects current wallpaper from swaybg process and cycles to the next one alphabetically. Runs every 60 seconds via exec-once loop.

### battery_notify.sh
Monitors battery level and sends notifications:
- Warning at 15%
- Critical at 10%
- Confirmation when plugged in after warning

### onedrive_sync.sh
Triggers OneDrive synchronization with logging to `~/.cache/onedrive_sync.log`.

### shutdown.sh
Interactive shutdown workflow in Kitty terminal:
1. Syncs OneDrive
2. Updates system packages (pacman)
3. Updates AUR packages (yay)
4. Prompts for shutdown confirmation

## Customization

### Wallpapers
Place images in `~/Files/Imágenes/Wallpapers/`. Supported formats: JPG, PNG, JPEG. Wallpapers rotate automatically every 60 seconds in alphabetical order.

### Waybar Colors
Edit CSS variables in `waybar/style.css`:
```css
:root {
    --bg-primary: rgba(29, 31, 33, 0.8);
    --bg-cpu: #2ecc71;
    --bg-memory: #9b59b6;
    /* ... */
}
```

### Monitor Layout
Edit monitor configuration in `hypr/hyprland.conf`:
```
monitor=HDMI-A-1,preferred,0x0,1
monitor=eDP-1,preferred,1920x0,1
```

## Troubleshooting

### Brightness control not working
Check that your device is detected:
```bash
brightnessctl -l
```

### Wallpaper not rotating
Check that wallpapers exist:
```bash
ls ~/Files/Imágenes/Wallpapers/
```

Check swaybg is running:
```bash
pgrep -a swaybg
```

### OneDrive not syncing
Check OneDrive status:
```bash
onedrive --confdir ~/dotfiles/onedrive --display-config
```

View sync logs:
```bash
tail -f ~/.cache/onedrive_sync.log
```

### Neovim Issues
For Neovim-specific troubleshooting (LSP, Copilot, plugins), see:
- [Neovim Setup Guide - Troubleshooting](docs/nvim-setup.md#troubleshooting)
- Check Neovim health: `:checkhealth`
- Check Copilot status: `:Copilot status`

## License

Personal configuration files. Feel free to adapt for your own use.
