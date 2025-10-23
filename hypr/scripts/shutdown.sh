#!/bin/bash
set -euo pipefail

# Run system updates in a new Kitty terminal window
kitty --title "System Update" -e bash -c "
set -e

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
systemctl poweroff
"
