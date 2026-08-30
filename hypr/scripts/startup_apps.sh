#!/usr/bin/env bash
# On Hyprland startup: always run normal_setup.
# Other functions kept as reference — to switch the boot flow, change the
# dispatch at the bottom of this file (e.g. `learn_rust` instead of `normal_setup`).
set -euo pipefail

# Wait until the machine has internet, up to ~30s. Without this librewolf's daily
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
    librewolf \
        "https://mail.google.com/mail/u/0/" \
        "https://mail.google.com/mail/u/1/" \
        "https://mail.google.com/mail/u/2/" \
        "https://mail.google.com/mail/u/3/" \
        "https://gv.lab-ocp.com/tasks/" \
        "https://www.claude.ai/new" \
        "https://web.whatsapp.com/" \
        "$@" &
    # aula.uoc.edu must open in a FOREGROUND tab: LibreWolf only autofills the
    # saved login when the tab is focused (background tabs stay empty until
    # clicked), and the uoc-aula-autosubmit userscript needs the filled form to
    # submit. A second librewolf call opens it into the running window as the
    # active tab, so autofill fires and the script logs in.
    wait_for_class librewolf 100 || true
    sleep 1
    librewolf --new-tab "https://aula.uoc.edu/" &
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

# Hyprland 0.55+ uses a Lua config, and `hyprctl dispatch` now evaluates its
# argument as Lua. The old positional forms (`hyprctl dispatch workspace 3`,
# `... exec '[workspace 2 silent] kitty'`) are Lua parse errors and exit 7,
# which under `set -e` killed this script before it launched anything.
# See docs/desktop.md#config-format.
go_workspace() {
    hyprctl dispatch "hl.dsp.focus({workspace = $1})" >/dev/null
}

# Kitty is dispatched onto ws2 with the per-launch workspace selector.
exec_on_workspace() {
    local cmd="$1" ws="$2"
    hyprctl dispatch "hl.dsp.exec_cmd(\"$cmd\", {workspace = \"$ws silent\"})" >/dev/null
}

normal_setup() {
    go_workspace 3
    spotify &
    wait_for_class Spotify || true
    go_workspace 1
    open_web
    exec_on_workspace "kitty" 2
}

learn_rust() {
    go_workspace 3
    spotify &
    wait_for_class Spotify || true
    go_workspace 1
    open_web "https://doc.rust-lang.org/book/"
    exec_on_workspace "kitty --directory $HOME/dev/play/rust/thebook/" 2
}

musescore() {
    go_workspace 3
    spotify &
    wait_for_class Spotify || true
    go_workspace 1
    open_web
    mscore &
}

boot_arch() {
    kitty -e bash -c '~/.dotfiles/scripts/boot_arch || { echo; read -n1 -rp "Press any key to close..."; }'
}

normal_setup
