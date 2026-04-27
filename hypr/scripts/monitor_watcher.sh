#!/bin/bash
# Monitor watcher for Hyprland - auto-reconfigures monitors on connection/disconnection
# Listens to Hyprland event socket and triggers monitor setup when monitors change.
# Also persists workspace -> monitor (by EDID serial) so workspaces return to the
# same physical screen across unplug/replug.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_SCRIPT="$SCRIPT_DIR/setup_monitors_by_serial.sh"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hypr"
WORKSPACE_MAP="$STATE_DIR/workspace-monitor-map"
MAX_MONITORS_FILE="$STATE_DIR/max-monitor-count"

mkdir -p "$STATE_DIR"

# Read the high-water mark of how many monitors we've ever seen connected at once.
# Used to gate snapshots: only update workspace->monitor map when at full count,
# otherwise the snapshot would record post-disconnect reassignments and overwrite
# the "good" mapping we want to restore on replug.
read_max_monitors() {
    [[ -f "$MAX_MONITORS_FILE" ]] && cat "$MAX_MONITORS_FILE" 2>/dev/null || echo 0
}

write_max_monitors() {
    echo "$1" > "$MAX_MONITORS_FILE"
}

current_monitor_count() {
    hyprctl monitors -j 2>/dev/null | jq 'length' 2>/dev/null || echo 0
}

# Verify setup script exists
if [[ ! -f "$SETUP_SCRIPT" ]]; then
    echo "Error: Monitor setup script not found at $SETUP_SCRIPT"
    exit 1
fi

# Snapshot current workspace -> monitor-serial mapping.
# Format: "<workspace_id>\t<monitor_serial>"
# Empty serial (eDP-1 etc.) is recorded as the monitor name prefixed with @.
snapshot_workspaces() {
    local ws_json mon_json count max
    count=$(current_monitor_count)
    max=$(read_max_monitors)
    # Bump the high-water mark when more monitors are present than we've seen.
    if (( count > max )); then
        write_max_monitors "$count"
        max=$count
    fi
    # Only snapshot when all known monitors are connected. During a partial
    # state (e.g. one screen unplugged) Hyprland reassigns orphaned workspaces,
    # which would corrupt the stored mapping if we recorded it.
    if (( count < max )); then
        return 0
    fi

    ws_json=$(hyprctl workspaces -j 2>/dev/null) || return 0
    mon_json=$(hyprctl monitors -j 2>/dev/null) || return 0

    echo "$ws_json" | jq -r --argjson mons "$mon_json" '
        .[] | . as $ws |
        ($mons[] | select(.name == $ws.monitor)) as $m |
        "\($ws.id)\t\(if ($m.serial // "") == "" then "@" + $m.name else $m.serial end)"
    ' > "$WORKSPACE_MAP.tmp" 2>/dev/null && mv "$WORKSPACE_MAP.tmp" "$WORKSPACE_MAP"
}

# Restore workspaces to their previously-recorded monitors based on current serial->port mapping.
restore_workspaces() {
    [[ -f "$WORKSPACE_MAP" ]] || return 0
    local mon_json
    mon_json=$(hyprctl monitors -j 2>/dev/null) || return 0

    while IFS=$'\t' read -r ws_id serial; do
        [[ -z "$ws_id" || -z "$serial" ]] && continue
        local target_port
        if [[ "$serial" == @* ]]; then
            target_port="${serial#@}"
        else
            target_port=$(echo "$mon_json" | jq -r --arg s "$serial" '.[] | select(.serial==$s) | .name' | head -1)
        fi
        [[ -z "$target_port" ]] && continue
        # Verify the target port is currently active
        echo "$mon_json" | jq -e --arg p "$target_port" '.[] | select(.name==$p)' >/dev/null || continue
        hyprctl dispatch moveworkspacetomonitor "$ws_id" "$target_port" >/dev/null 2>&1 || true
    done < "$WORKSPACE_MAP"
}

reconfigure_monitors() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Monitor change detected, reconfiguring..."
    sleep 1
    if bash "$SETUP_SCRIPT"; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Monitor reconfiguration completed"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Warning: Monitor reconfiguration failed"
    fi
    restore_workspaces
    snapshot_workspaces

    # After monitor + workspace shuffle Hyprland sometimes loses keyboard/mouse
    # focus on the active window (terminals go unresponsive). Force-refocus the
    # currently-active window to wake input handling back up.
    local active_addr
    active_addr=$(hyprctl activewindow -j 2>/dev/null | jq -r '.address // empty')
    if [[ -n "$active_addr" ]]; then
        hyprctl dispatch focuswindow "address:$active_addr" >/dev/null 2>&1 || true
    else
        # No active window? Refocus the currently focused monitor instead.
        local focused_mon
        focused_mon=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .name' | head -1)
        [[ -n "$focused_mon" ]] && hyprctl dispatch focusmonitor "$focused_mon" >/dev/null 2>&1 || true
    fi
}

# Find Hyprland event socket
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
HYPR_DIR="$RUNTIME_DIR/hypr"

if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    SOCKET_PATH="$HYPR_DIR/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
else
    SOCKET_PATH=$(find "$HYPR_DIR" -name ".socket2.sock" 2>/dev/null | head -1)
fi

if [[ ! -S "$SOCKET_PATH" ]]; then
    echo "Error: Hyprland event socket not found at $SOCKET_PATH"
    exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Monitor watcher started, listening for events..."

# Take an initial snapshot
snapshot_workspaces

# Listen to Hyprland events:
#  - monitoradded/removed: reconfigure + restore
#  - workspace/moveworkspace/createworkspace: refresh snapshot so we have a current mapping
socat -U - "UNIX-CONNECT:$SOCKET_PATH" | while read -r line; do
    case "$line" in
        monitoradded\>\>*|monitorremoved\>\>*)
            reconfigure_monitors
            ;;
        workspace\>\>*|moveworkspace\>\>*|createworkspace\>\>*|destroyworkspace\>\>*|focusedmon\>\>*)
            snapshot_workspaces
            ;;
    esac
done
