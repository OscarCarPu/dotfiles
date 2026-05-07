#!/bin/bash
set -euo pipefail

# Toggle the CPU scaling governor between `performance` and `powersave`
# (the only two governors exposed on this Intel laptop) and emit JSON for
# the waybar `custom/power-profile` module.
#
# Writes to /sys/.../scaling_governor go through `sudo tee`; the NOPASSWD
# rule lives in configs/sudoers.d/10-cpu-governor.

GOV_GLOB=(/sys/devices/system/cpu/cpufreq/policy*/scaling_governor)
GOV_FILE="${GOV_GLOB[0]}"

# Refresh the waybar module on change. Matches "signal": 9 in
# waybar/config.jsonc -> SIGRTMIN+9.
notify_waybar() {
    pkill -RTMIN+9 waybar 2>/dev/null || true
}

emit_json() {
    local gov="$1"
    case "$gov" in
        performance) printf '{"text":"󰓅","class":"performance","tooltip":"CPU governor: performance"}\n' ;;
        powersave)   printf '{"text":"󰌪","class":"powersave","tooltip":"CPU governor: powersave"}\n' ;;
        *)           printf '{"text":"󰍛","class":"unknown","tooltip":"CPU governor: %s"}\n' "$gov" ;;
    esac
}

set_governor() {
    local new="$1"
    for f in "${GOV_GLOB[@]}"; do
        echo "$new" | sudo -n tee "$f" >/dev/null
    done
    notify_waybar
}

case "${1:-get}" in
    get)
        emit_json "$(< "$GOV_FILE")"
        ;;
    toggle)
        cur="$(< "$GOV_FILE")"
        [ "$cur" = "powersave" ] && set_governor performance || set_governor powersave
        ;;
    set)
        case "${2:-}" in
            performance|powersave) set_governor "$2" ;;
            *) echo "Usage: $0 set {performance|powersave}" >&2; exit 1 ;;
        esac
        ;;
    *)
        echo "Usage: $0 [get|toggle|set <profile>]" >&2
        exit 1
        ;;
esac
