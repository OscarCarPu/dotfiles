#!/bin/bash
# Monitor watcher for Hyprland - auto-reconfigures monitors on connection/disconnection
# Listens to Hyprland event socket and triggers monitor setup when monitors change.
set -euo pipefail

# Hyprland's stdout sink is disabled (debug:disable_logs), so exec-once output
# vanishes. Keep our own log with a crude size cap.
LOG_FILE="$HOME/.cache/monitor_watcher.log"
{ [[ -f "$LOG_FILE" && $(stat -c%s "$LOG_FILE") -gt 1048576 ]] && mv -f "$LOG_FILE" "$LOG_FILE.old"; } || true
exec >>"$LOG_FILE" 2>&1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_SCRIPT="$SCRIPT_DIR/setup_monitors_by_serial.sh"

# Verify setup script exists
if [[ ! -f "$SETUP_SCRIPT" ]]; then
    echo "Error: Monitor setup script not found at $SETUP_SCRIPT"
    exit 1
fi

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# audio_watcher.sh raises this flag while it may be bouncing the PipeWire stack.
AUDIO_BUSY_FLAG="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/audio_watcher_busy"

# waybar's pulse module talks to pipewire-pulse via libpulse, so probe that
# (pactl) when available; wpctl only proves WirePlumber is up.
audio_ready() {
    if command -v pactl >/dev/null 2>&1; then
        pactl info >/dev/null 2>&1
    else
        wpctl status >/dev/null 2>&1
    fi
}

# Wait until audio_watcher has been idle for 2 consecutive checks AND the
# pulse shim answers, so waybar never starts against a PipeWire stack that is
# mid-bounce - pa_context_connect() failing aborts waybar outright. A flag
# older than 60s is stale (audio_watcher's EXIT trap can't run on SIGKILL);
# treat it as absent instead of paying the full wait on every burst.
# Cap at 12s, not more: runit restarts waybar if it crashes and the run-script
# self-check recovers missed bars, while a long gate delays every dock switch
# (2026-07-18: two full 30s timeouts made a dock event take ~70s).
wait_for_audio_settled() {
    local streak=0 flag_age
    for _ in $(seq 1 12); do
        if [[ -e "$AUDIO_BUSY_FLAG" ]]; then
            flag_age=$(( $(date +%s) - $(stat -c %Y "$AUDIO_BUSY_FLAG" 2>/dev/null || echo 0) ))
            if (( flag_age < 60 )); then
                streak=0
                sleep 1
                continue
            fi
        fi
        streak=$((streak + 1))
        if (( streak >= 2 )) && audio_ready; then
            return 0
        fi
        sleep 1
    done
    log "Warning: audio stack not settled after 12s, restarting waybar anyway"
}

# Output set the last waybar restart was issued for - identical re-settles
# (same connectors flapping down and up) don't need another waybar bounce.
LAST_WAYBAR_SIG=""

handle_monitor_burst() {
    # Coalesce the event burst instead of debouncing with a fixed cooldown:
    # evdi flaps each output connected/disconnected several times while the
    # dock enumerates (3+ cycles per attach on aquamarine 0.10), and the old
    # 20s cooldown - stamped at the START of a pass that itself took ~20s -
    # let a queued event re-trigger a full second pass with a second waybar
    # restart. Instead, keep draining events from the socket until none
    # arrive for 4s, then reconfigure against the settled list. A fresh
    # monitor event during the post-reconfigure drain re-arms another pass
    # (capped) so a late final flap cycle is never silently swallowed.
    local pass=1 settle_start ev rc rearm sig
    log "Monitor event burst started, waiting for outputs to settle..."
    while :; do
        # Wall-clock settle: socket2 also streams workspace/window chatter,
        # so count seconds since the last MONITOR event rather than counting
        # quiet read-timeouts (chatter would starve those).
        settle_start=$SECONDS
        while (( SECONDS - settle_start < 4 )); do
            rc=0
            read -r -t 0.5 ev || rc=$?
            if (( rc == 0 )); then
                case "$ev" in
                    monitoradded*|monitorremoved*) settle_start=$SECONDS ;;
                esac
            elif (( rc <= 128 )); then
                return 0              # EOF - socket gone (Hyprland exiting)
            fi                        # else: timeout - no event this poll
        done

        log "Outputs quiet for 4s, reconfiguring (pass $pass)..."
        if bash "$SETUP_SCRIPT"; then
            log "Monitor reconfiguration completed"
        else
            log "Warning: Monitor reconfiguration failed"
        fi

        sig=$(hyprctl monitors -j 2>/dev/null | jq -r '[.[].name] | sort | join(",")' 2>/dev/null || echo "?")
        if [[ -n "$sig" && "$sig" != "?" && "$sig" == "$LAST_WAYBAR_SIG" ]]; then
            # Same output set waybar is already bound to. waybar handles
            # runtime wl_output remove/re-add itself, and its run-script
            # self-check covers startup bind misses - no forced bounce needed.
            log "Output set unchanged ($sig), skipping waybar restart"
        else
            wait_for_audio_settled
            # Restart waybar so it binds bars to any newly connected outputs.
            export SVDIR="$HOME/.local/share/runit/sv"
            sv restart waybar 2>/dev/null || true
            LAST_WAYBAR_SIG="$sig"
            log "Waybar restarted (outputs: $sig)"
        fi

        # After monitor + workspace shuffle Hyprland sometimes loses keyboard/mouse
        # focus on the active window (terminals go unresponsive). Force-refocus the
        # currently-active window to wake input handling back up.
        local active_addr
        active_addr=$(hyprctl activewindow 2>/dev/null | awk '/^Window /{print $2; exit}' || true)
        if [[ -n "$active_addr" ]]; then
            hyprctl dispatch focuswindow "address:$active_addr" >/dev/null 2>&1 || true
        else
            # No active window? Refocus the currently focused monitor instead.
            local focused_mon
            focused_mon=$(hyprctl monitors 2>/dev/null | awk '/^Monitor /{name=$2} /focused: yes/{print name; exit}' || true)
            [[ -n "$focused_mon" ]] && hyprctl dispatch focusmonitor "$focused_mon" >/dev/null 2>&1 || true
        fi

        # Our own keyword/batch calls in the setup script can fire further
        # monitor events; swallow anything arriving within 2s - but a REAL
        # late flap cycle must re-trigger a pass, not be eaten. Wall-bounded
        # so socket chatter can't pin us in the drain.
        rearm=0
        settle_start=$SECONDS
        while (( SECONDS - settle_start < 2 )); do
            rc=0
            read -r -t 2 ev || rc=$?
            (( rc == 0 )) || break  # timeout or EOF - drain done
            case "$ev" in
                monitoradded*|monitorremoved*)
                    rearm=1
                    break
                    ;;
            esac
        done

        (( rearm )) || break
        if (( pass >= 5 )); then
            log "Warning: monitor events still arriving after $pass passes, yielding until next event"
            break
        fi
        pass=$((pass + 1))
        log "Monitor event during drain, re-handling (pass $pass)..."
    done
    log "Burst handled"
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

log "Monitor watcher started, listening for events..."

socat -U - "UNIX-CONNECT:$SOCKET_PATH" | while read -r line; do
    case "$line" in
        monitoradded*|monitorremoved*)
            handle_monitor_burst
            ;;
    esac
done
