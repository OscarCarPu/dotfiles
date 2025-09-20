#!/bin/bash

# Run system updates in a new Kitty terminal window
kitty --title "System Update" -e bash -c "
echo 'Syncing onedrive';
onedrive -s --verbose;
echo 'Running system updates...';
sudo pacman -Syu;
echo;
yay -Syu;
echo;
read -p 'Updates complete. Press Enter to shutdown or close this window to cancel.';
systemctl poweroff
"
