#!/bin/bash
set -euo pipefail

# Run system updates in a new Kitty terminal window
kitty --title "System Update" -e bash -c "
set -e

# Prompt for password once at the beginning
echo '=== Authentication Required ==='
sudo -v || {
    echo 'Error: Authentication failed'
    read -p 'Press Enter to exit'
    exit 1
}

# Keep sudo credentials alive in background
while true; do sudo -n true; sleep 50; kill -0 \"\$\$\" 2>/dev/null || exit; done &
SUDO_KEEPER_PID=\$!
trap 'kill \$SUDO_KEEPER_PID 2>/dev/null || true' EXIT

echo
echo '=== Syncing OneDrive ==='
if command -v onedrive &> /dev/null; then
    onedrive --synchronize --verbose || {
        echo 'Warning: OneDrive sync failed, continuing anyway...'
    }
else
    echo 'OneDrive not found, skipping sync'
fi
echo

echo '=== Running system updates (pacman) ==='
sudo pacman -Syu || {
    echo 'Error: pacman update failed'
    read -p 'Press Enter to continue anyway or close to cancel'
}
echo

echo '=== Running AUR updates (yay) ==='
if command -v yay &> /dev/null; then
    yay -Syu || {
        echo 'Error: yay update failed'
        read -p 'Press Enter to continue anyway or close to cancel'
    }
else
    echo 'yay not found, skipping AUR updates'
fi
echo

echo '=== All updates complete ==='
read -p 'Press Enter to shutdown or close this window to cancel: '

# Kill the sudo keeper process
kill \$SUDO_KEEPER_PID 2>/dev/null || true

# Use sudo for poweroff to ensure it works without additional prompts
sudo systemctl poweroff
"
