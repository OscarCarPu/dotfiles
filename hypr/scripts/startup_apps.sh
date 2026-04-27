#!/usr/bin/env bash
# On Hyprland startup: always run normal_setup.
# Other functions kept as reference — to switch the boot flow, change the
# dispatch at the bottom of this file (e.g. `learn_rust` instead of `normal_setup`).
set -euo pipefail

open_web() {
    brave \
        "https://mail.google.com/mail/u/0/" \
        "https://mail.google.com/mail/u/1/" \
        "https://mail.google.com/mail/u/2/" \
        "https://gv.lab-ocp.com/" \
        "https://www.claude.ai/new" \
        "https://web.whatsapp.com/" \
        "$@" &
}

# Spotify lands on ws3 via windowrule in hyprland.conf.
# Kitty is dispatched onto ws2 with the per-launch workspace selector.

normal_setup() {
    hyprctl dispatch workspace 3
    spotify &
    sleep 1
    hyprctl dispatch workspace 1
    open_web
    hyprctl dispatch exec '[workspace 2 silent] kitty'
}

learn_rust() {
    hyprctl dispatch workspace 3
    spotify &
    sleep 1
    hyprctl dispatch workspace 1
    open_web "https://doc.rust-lang.org/book/"
    hyprctl dispatch exec '[workspace 2 silent] kitty --directory ~/dev/play/rust/thebook/'
}

musescore() {
    hyprctl dispatch workspace 3
    spotify &
    sleep 1
    hyprctl dispatch workspace 1
    open_web
    mscore &
}

boot_arch() {
    kitty -e bash -c '~/.dotfiles/scripts/boot_arch || { echo; read -n1 -rp "Press any key to close..."; }'
}

normal_setup
