#!/bin/bash
set -euo pipefail

# Run system updates in a new Kitty terminal window
kitty --title "System Update Manager" -e bash -c "
set -e

echo '=== System Update & Power Management ==='
echo '1. Shutdown'
echo '2. Update only'
echo '3. Reboot'
echo
read -p 'Select option (1/2/3): ' ACTION_CHOICE

if [[ ! \"\$ACTION_CHOICE\" =~ ^[123]\$ ]]; then
    echo 'Invalid option. Exiting.'; sleep 2; exit 1
fi

# Authenticate once
sudo -v

# Keep-alive sudo
(while true; do sudo -n true 2>/dev/null || exit; sleep 50; done) &
SUDO_KEEPER_PID=\$!
trap 'kill \$SUDO_KEEPER_PID 2>/dev/null' EXIT

echo -e '\n=== Fetching Package Summaries ==='

# List Pacman updates first
echo -e '\n[ Arch Repositories ]'
if ! checkupdates; then
    echo 'No system updates available.'
else
    checkupdates
fi

# List AUR updates if yay is present
if command -v yay &> /dev/null; then
    echo -e '\n[ AUR Packages ]'
    yay -Qu || echo 'No AUR updates available.'
fi

echo -e '\n---------------------------------'
read -p 'Proceed with these updates? (y/N): ' CONFIRM
if [[ ! \"\$CONFIRM\" =~ ^[Yy]\$ ]]; then
    echo 'Update cancelled by user.'
else
    echo 'Running updates...'
    sudo pacman -Syu
    if command -v yay &> /dev/null; then
        yay -Sua
    fi
fi

# Clean up sudo keeper
kill \$SUDO_KEEPER_PID 2>/dev/null || true

case \"\$ACTION_CHOICE\" in
    1) echo 'Shutting down...'; sudo systemctl poweroff ;;
    2) echo 'Done. Press Enter to close.'; read ;;
    3) echo 'Rebooting...'; sudo systemctl reboot ;;
esac
"
