#!/bin/bash
set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "Checking dotfiles dependencies..."
echo

MISSING_DEPS=()
MISSING_AUR=()

# Function to check if command exists
check_command() {
    local cmd="${1:?Command name required}"
    local package="${2:-$1}"
    local is_aur="${3:-false}"

    if command -v "$cmd" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $cmd"
        return 0
    else
        echo -e "${RED}✗${NC} $cmd (package: $package)"
        if [ "$is_aur" = "true" ]; then
            MISSING_AUR+=("$package")
        else
            MISSING_DEPS+=("$package")
        fi
        return 1
    fi
}

echo "Core Dependencies:"
check_command hyprland hyprland
check_command waybar waybar
check_command swaync swaync
check_command kitty kitty
check_command wofi wofi
check_command google-chrome-stable google-chrome

echo
echo "System Tools:"
check_command brightnessctl brightnessctl
check_command swaybg swaybg
check_command grim grim
check_command slurp slurp
check_command wl-copy wl-clipboard
check_command notify-send libnotify
check_command pactl libpulse

echo
echo "Optional Dependencies:"
check_command spotify spotify false
check_command onedrive onedrive-abraunegg true
check_command yay yay true
check_command nvim neovim

echo
echo "Checking for wlogout (referenced in waybar):"
check_command wlogout wlogout true

echo
echo "================================"
if [ ${#MISSING_DEPS[@]} -eq 0 ] && [ ${#MISSING_AUR[@]} -eq 0 ]; then
    echo -e "${GREEN}All dependencies are installed!${NC}"
    exit 0
else
    echo -e "${YELLOW}Missing dependencies found:${NC}"

    if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
        echo
        echo "Install with pacman:"
        echo -e "${YELLOW}sudo pacman -S ${MISSING_DEPS[*]}${NC}"
    fi

    if [ ${#MISSING_AUR[@]} -gt 0 ]; then
        echo
        echo "Install from AUR (with yay):"
        echo -e "${YELLOW}yay -S ${MISSING_AUR[*]}${NC}"
    fi

    echo
    exit 1
fi
