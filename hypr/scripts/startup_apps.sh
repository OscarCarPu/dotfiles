#!/usr/bin/env bash
# On Hyprland startup: always run normal_setup.
# Other functions kept as reference — to switch the boot flow, change the
# dispatch at the bottom of this file (e.g. `learn_rust` instead of `normal_setup`).
set -euo pipefail

# Wait until the machine has internet, up to ~30s. Without this brave's daily
# tabs all open as "no internet" pages on a cold boot before NetworkManager
# finishes connecting. Prefer curl for a real reachability check; fall back
# to DNS-only if curl isn't installed.
wait_for_internet() {
    local max_seconds="${1:-30}" deadline have_curl
    deadline=$(( $(date +%s) + max_seconds ))
    command -v curl >/dev/null 2>&1 && have_curl=1 || have_curl=0
    while (( $(date +%s) < deadline )); do
        if (( have_curl )); then
            curl -fsS --max-time 2 -o /dev/null https://mail.google.com/generate_204 2>/dev/null && return 0
        else
            getent hosts mail.google.com >/dev/null 2>&1 && return 0
        fi
        sleep 0.5
    done
    return 1
}

open_web() {
    wait_for_internet || true
    brave \
        "https://mail.google.com/mail/u/0/" \
        "https://mail.google.com/mail/u/1/" \
        "https://mail.google.com/mail/u/2/" \
        "https://mail.google.com/mail/u/3/" \
        "https://gv.lab-ocp.com/" \
        "https://www.claude.ai/new" \
        "https://web.whatsapp.com/" \
        "$@" &
}

# Wait until a window with the given class appears, up to N tenths of a second.
wait_for_class() {
    local class="$1" max_tenths="${2:-50}" i=0
    while (( i < max_tenths )); do
        if hyprctl clients 2>/dev/null | grep -q "class: $class$"; then
            return 0
        fi
        sleep 0.1
        ((i++))
    done
    return 1
}

# Kitty is dispatched onto ws2 with the per-launch workspace selector.

normal_setup() {
    hyprctl dispatch workspace 3
    spotify &
    wait_for_class Spotify || true
    hyprctl dispatch workspace 1
    open_web
    hyprctl dispatch exec '[workspace 2 silent] kitty'
}

learn_rust() {
    hyprctl dispatch workspace 3
    spotify &
    wait_for_class Spotify || true
    hyprctl dispatch workspace 1
    open_web "https://doc.rust-lang.org/book/"
    hyprctl dispatch exec '[workspace 2 silent] kitty --directory ~/dev/play/rust/thebook/'
}

musescore() {
    hyprctl dispatch workspace 3
    spotify &
    wait_for_class Spotify || true
    hyprctl dispatch workspace 1
    open_web
    mscore &
}

boot_arch() {
    kitty -e bash -c '~/.dotfiles/scripts/boot_arch || { echo; read -n1 -rp "Press any key to close..."; }'
}

normal_setup
