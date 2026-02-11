#!/usr/bin/env bash
set -euo pipefail

# Startup script with boot mode selection popup
# Called from hyprland.conf exec-once

# =============================================================================
# OPTION FUNCTIONS
# Define function as: name|Label Text
# =============================================================================

normal_setup() {
    hyprctl dispatch workspace 3
    spotify &
    sleep 1

    hyprctl dispatch workspace 1
    chromium \
        "https://mail.google.com" \
        "https://app.clockify.me/tracker" \
        "https://gemini.google.com" \
        "https://web.whatsapp.com/" &
    sleep 1
}

learn_go() {
    hyprctl dispatch workspace 3
    spotify &
    sleep 1

    hyprctl dispatch workspace 1
    chromium \
        "https://mail.google.com" \
        "https://app.clockify.me/tracker" \
        "https://gemini.google.com" \
        "https://web.whatsapp.com/" \
        "https://quii.gitbook.io/learn-go-with-tests" &
    sleep 0.5
    kitty --directory ~/dev/play/go/learn-tests/ &
    sleep 1
}

boot_windows() {
    kitty -e winboot &
}

start_pvz() {
    hyprctl dispatch workspace 3 
    spotify &
    chromium \
        "https://mail.google.com" \
        "https://app.clockify.me/tracker" \
        "https://gemini.google.com" \
        "https://web.whatsapp.com/" &
    sleep 1

    hyprctl dispatch workspace 1
    kitty --directory ~/pvzfusion/ -e ./pvzfusion.sh &
}

musescore() {
    hyprctl dispatch workspace 3
    spotify &
    chromium \
        "https://mail.google.com" \
        "https://app.clockify.me/tracker" \
        "https://gemini.google.com" \
        "https://web.whatsapp.com/" &
    sleep 1

    hyprctl dispatch workspace 1 
    mscore &
}

# =============================================================================
# ENABLED OPTIONS
# Add/remove entries to enable/disable options: "function_name|Display Label"
# =============================================================================

ENABLED_OPTIONS=(
    "normal_setup|Normal Setup"
    "learn_go|Learn Go"
    "musescore|MuseScore"
    "boot_windows|Boot Windows"
    "start_pvz|Start PVZ"
)

# =============================================================================
# MAIN
# =============================================================================

sleep 2

# Build numbered menu
menu=""
for i in "${!ENABLED_OPTIONS[@]}"; do
    label="${ENABLED_OPTIONS[$i]#*|}"
    menu+="$((i + 1))  $label"$'\n'
done
menu="${menu%$'\n'}"

# Calculate height (roughly 40px per line + padding)
line_height=40
padding=30
height=$(( ${#ENABLED_OPTIONS[@]} * line_height + padding ))

CHOICE=$(echo "$menu" | wofi --dmenu \
    --prompt "Boot Mode" \
    --cache-file /dev/null \
    --insensitive \
    --width 300 \
    --height "$height" \
    --lines ${#ENABLED_OPTIONS[@]})

# Extract selected number and call corresponding function
selected_num="${CHOICE%%  *}"
if [[ "$selected_num" =~ ^[0-9]+$ ]]; then
    idx=$((selected_num - 1))
    func_name="${ENABLED_OPTIONS[$idx]%|*}"
    $func_name
fi
