#!/bin/bash
# Shows a translucent waybar clock above fullscreen windows. The main bar sits
# on the top layer, which fullscreen covers; this runs a second, clock-only
# waybar on the overlay layer, bound to the monitors whose visible workspace
# has a fullscreen window, and kills it when none do.
set -uo pipefail

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
HYPR_DIR="$RUNTIME_DIR/hypr"
WAYBAR_DIR="$HOME/.dotfiles/waybar"
CONFIG="$RUNTIME_DIR/waybar-fullscreen-clock.json"

if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    SOCKET_PATH="$HYPR_DIR/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
else
    SOCKET_PATH=$(find "$HYPR_DIR" -name ".socket2.sock" 2>/dev/null | head -1)
fi

if [[ ! -S "$SOCKET_PATH" ]]; then
    echo "Error: Hyprland event socket not found" >&2
    exit 1
fi

pid=""
shown=""

stop_clock() {
    [[ -n "$pid" ]] && kill "$pid" 2>/dev/null
    pid=""
}
trap 'stop_clock; exit' EXIT INT TERM

# Monitors showing a true-fullscreen window (mode bit 2; plain maximize keeps
# the bar visible), as a JSON array of output names.
fullscreen_outputs() {
    jq -cn --argjson m "$(hyprctl monitors -j)" --argjson c "$(hyprctl clients -j)" '
        [$m[] | . as $mon
         | select(any($c[]; .fullscreen >= 2
             and (.workspace.id == $mon.activeWorkspace.id
                  or .workspace.id == $mon.specialWorkspace.id)))
         | .name]'
}

update() {
    local outputs
    outputs=$(fullscreen_outputs) || return
    [[ "$outputs" == "$shown" && ( -z "$pid" || -d /proc/$pid ) ]] && return
    shown="$outputs"
    stop_clock
    [[ "$outputs" == "[]" ]] && return
    # Inherits the clock module settings from the main bar config; the
    # negative top margin cancels the main bar's exclusive zone so the clock
    # lands where it normally is.
    jq -n --argjson o "$outputs" --arg inc "$WAYBAR_DIR/config.jsonc" '{
        include: [$inc],
        name: "fullscreen-clock",
        output: $o,
        layer: "overlay",
        exclusive: false,
        passthrough: true,
        "margin-top": -26,
        height: 26,
        "modules-left": [],
        "modules-center": ["clock"],
        "modules-right": []
    }' > "$CONFIG"
    waybar -c "$CONFIG" -s "$WAYBAR_DIR/style.css" &>/dev/null &
    pid=$!
}

update

while read -r line; do
    case "$line" in
        fullscreen\>\>*|workspace\>\>*|focusedmon\>\>*|activespecial\>\>*|\
        closewindow\>\>*|movewindow\>\>*|monitoradded\>\>*|monitorremoved\>\>*)
            update ;;
    esac
done < <(socat -U - "UNIX-CONNECT:$SOCKET_PATH")
