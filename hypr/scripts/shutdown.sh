#!/bin/bash
set -euo pipefail

# Run system updates in a new Kitty terminal window
kitty --title "System Update" -e bash -c "
set -e

# Prompt for action choice
echo '=== System Update & Power Management ==='
echo '1. Shutdown (sync, update, then shutdown)'
echo '2. Update only (sync and update, no shutdown)'
echo '3. Reboot (sync, update, then reboot)'
echo
read -p 'Select option (1/2/3): ' ACTION_CHOICE

# Validate input
if [[ ! \"\$ACTION_CHOICE\" =~ ^[123]\$ ]]; then
    echo 'Invalid option. Exiting.'
    read -p 'Press Enter to exit'
    exit 1
fi

echo

# Prompt for password once at the beginning
echo '=== Authentication Required ==='
sudo -v || {
    echo 'Error: Authentication failed'
    read -p 'Press Enter to exit'
    exit 1
}

# Keep sudo credentials alive in background
(while true; do sudo -n true 2>/dev/null || exit; sleep 50; done) &
SUDO_KEEPER_PID=\$!
trap 'kill \$SUDO_KEEPER_PID 2>/dev/null || true; wait \$SUDO_KEEPER_PID 2>/dev/null || true' EXIT

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
sudo pacman -Syu --noconfirm || {
    echo 'Error: pacman update failed'
    read -p 'Press Enter to continue anyway or close to cancel'
}
echo

echo '=== Running AUR updates (yay) ==='
if command -v yay &> /dev/null; then
    yay -Syu --noconfirm || {
        echo 'Error: yay update failed'
        read -p 'Press Enter to continue anyway or close to cancel'
    }
else
    echo 'yay not found, skipping AUR updates'
fi
echo

echo '=== All updates complete ==='

# Kill the sudo keeper process gracefully
if [ -n "\${SUDO_KEEPER_PID:-}" ] && kill -0 \$SUDO_KEEPER_PID 2>/dev/null; then
    kill \$SUDO_KEEPER_PID 2>/dev/null || true
    wait \$SUDO_KEEPER_PID 2>/dev/null || true
fi

# Perform action based on user choice
case \"\$ACTION_CHOICE\" in
    1)
        echo 'Shutting down...'
        sudo systemctl poweroff
        ;;
    2)
        echo 'Updates complete. You can close this window.'
        read -p 'Press Enter to exit'
        ;;
    3)
        echo 'Rebooting...'
        sudo systemctl reboot
        ;;
esac
"
