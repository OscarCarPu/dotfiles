# OCP's Dotfiles

An Arch Hyprland configuration for my daily computer.

# Quick Start

- *Os*: Arch Linux
- *WM*: Hyprland (Wayland)
- *Terminal*: Kitty
- *Shell*: Bash
- *Editor*: nvim

# Repository Structure

GNU Stow for symlinking

- `hypr/`: Hyprland configuration
- `nvim/`: Neovim configuration
- `waybar/`: Waybar configuration
- `swaync/`: SwayNC configuration
- `scripts/`: Custom system tools (`.local/bin`)
- `configs/`: Small configuration files
- `docs/`: Documentation

# Instalation

```Bash
# Clone the Repository
git clone https://github.com/OscarCarPu/dotfiles.git ~/.dotfiles 
cd ~/.dotfiles

# Run install.sh 
chmod +x ./install.sh
./install.sh
```

# Symlink list 

- nvim -> ~/.config/nvim
- hypr -> ~/.config/hypr
- waybar -> ~/.config/waybar
- swaync -> ~/.config/swaync
- configs/chromium-flags.conf -> ~/.config/chromium-flags.conf
- configs/user-places.xbel -> ~/.local/share/user-places.xbel
- configs/gtk-3.0/bookmarks -> ~/.config/gtk-3.0/bookmarks
- scripts -> ~/.local/bin

# More docs

- *Hyprland*: [Hyprland](docs/hyprland.md)
- *Neovim*: [Neovim](nvim/README.md)
- *System*: [System](docs/system.md)

# Maintenance

- No Symlink, no entry
- Document as you go, everything is documented on system.md 
