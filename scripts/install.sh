#!/bin/bash
set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

DOTFILES_DIR="$HOME/dotfiles"

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Dotfiles Installation Script         ║${NC}"
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
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
mkdir -p "$HOME/.cache"
mkdir -p "$HOME/Files/Imágenes/Wallpapers"
echo -e "${GREEN}✓${NC} Directories created"

echo
echo -e "${YELLOW}Step 3: Making scripts executable...${NC}"
chmod +x "$DOTFILES_DIR/hypr/scripts/"*.sh
chmod +x "$DOTFILES_DIR/scripts/"*.sh
echo -e "${GREEN}✓${NC} Scripts are executable"

echo
echo -e "${YELLOW}Step 4: OneDrive configuration${NC}"
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
echo -e "${YELLOW}Step 5: Checking wallpapers...${NC}"
WALLPAPER_COUNT=$(find "$HOME/Files/Imágenes/Wallpapers" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) 2>/dev/null | wc -l)
if [ "$WALLPAPER_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} Found $WALLPAPER_COUNT wallpaper(s)"
else
    echo -e "${YELLOW}!${NC} No wallpapers found"
    echo "Add images to ~/Files/Imágenes/Wallpapers/ for automatic rotation"
fi

echo
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Installation Complete!                ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo
echo "Next steps:"
echo "  1. Log out and select Hyprland from your display manager"
echo "  2. Or reload Hyprland if already running: hyprctl reload"
echo
echo "Note: Configuration runs directly from ~/dotfiles/"
echo "      No symlinks are required."
echo
