#!/usr/bin/env bash
set -euo pipefail

# Startup script to open default browser with tabs and Spotify on different workspaces
# Called from hyprland.conf exec-once

# Delay to ensure Hyprland is fully loaded
sleep 5

# Open Chromium with Gmail, vida.lab-ocp.com, and Gemini on workspace 1
hyprctl dispatch workspace 3
chromium "https://mail.google.com" "https://vida.lab-ocp.com" "https://gv.lab-ocp.com" "https://gemini.google.com" "https://web.whatsapp.com/" &

# Wait for browser to start
sleep 3

# Open Spotify on workspace 2
hyprctl dispatch workspace 2
spotify &

# Return to workspace 1
sleep 2
hyprctl dispatch workspace 3
