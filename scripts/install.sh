#!/bin/bash
set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

DOTFILES_DIR="$HOME/dotfiles"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Dotfiles Installation Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# Check if running from the dotfiles directory
if [ ! -f "$DOTFILES_DIR/README.md" ]; then
    echo -e "${RED}Error: Dotfiles not found at $DOTFILES_DIR${NC}"
    echo "Please clone the repository to ~/dotfiles first"
    exit 1
fi

cd "$DOTFILES_DIR"

echo -e "${YELLOW}Step 1: Checking dependencies...${NC}"
if ! ./scripts/check_dependencies.sh; then
    echo
    read -p "Some dependencies are missing. Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 1
    fi
fi

echo
echo -e "${YELLOW}Step 2: Creating necessary directories...${NC}"
if mkdir -p "$HOME/.cache" "$HOME/.config" "$HOME/Files/Imágenes/Wallpapers"; then
    echo -e "${GREEN}✓${NC} Directories created"
else
    echo -e "${RED}✗${NC} Failed to create directories"
    exit 1
fi

echo
echo -e "${YELLOW}Step 3: Setting up symlinks...${NC}"
# Chromium flags need to be symlinked to ~/.config/
if ln -sf "$DOTFILES_DIR/chromium/chromium-flags.conf" "$HOME/.config/chromium-flags.conf"; then
    echo -e "${GREEN}✓${NC} Chromium flags symlinked"
else
    echo -e "${YELLOW}!${NC} Warning: Could not create chromium-flags.conf symlink"
fi

# WirePlumber config for auto-switching audio devices
mkdir -p "$HOME/.config/wireplumber/wireplumber.conf.d"
if ln -sf "$DOTFILES_DIR/wireplumber/"*.conf "$HOME/.config/wireplumber/wireplumber.conf.d/" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} WirePlumber config symlinked"
else
    echo -e "${YELLOW}!${NC} Warning: Could not create wireplumber config symlinks"
fi

echo
echo -e "${YELLOW}Step 4: Making scripts executable...${NC}"
if chmod +x "$DOTFILES_DIR/hypr/scripts/"*.sh "$DOTFILES_DIR/scripts/"*.sh 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Scripts are executable"
else
    echo -e "${YELLOW}!${NC} Warning: Some scripts may not have been made executable"
fi

echo
echo -e "${YELLOW}Step 5: OneDrive configuration${NC}"
if [ -f "$DOTFILES_DIR/onedrive/refresh_token" ]; then
    echo -e "${GREEN}✓${NC} OneDrive already configured"
else
    echo -e "${YELLOW}!${NC} OneDrive not configured yet"
    read -p "Do you want to configure OneDrive now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        onedrive --confdir "$DOTFILES_DIR/onedrive"
    else
        echo "You can configure OneDrive later with:"
        echo "  onedrive --confdir ~/dotfiles/onedrive"
    fi
fi

echo
echo -e "${YELLOW}Step 6: Checking wallpapers...${NC}"
WALLPAPER_COUNT=$(find "$HOME/Files/Imágenes/Wallpapers" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) 2>/dev/null | wc -l)
if [ "$WALLPAPER_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} Found $WALLPAPER_COUNT wallpaper(s)"
else
    echo -e "${YELLOW}!${NC} No wallpapers found"
    echo "Add images to ~/Files/Imágenes/Wallpapers/ for automatic rotation"
fi

echo
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo
echo "Next steps:"
echo "  1. Log out and select Hyprland from your display manager"
echo "  2. Or reload Hyprland if already running: hyprctl reload"
echo
echo "Note: Configuration runs directly from ~/dotfiles/"
echo "      No symlinks are required."
echo
