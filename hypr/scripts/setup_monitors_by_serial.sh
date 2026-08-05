#!/bin/bash
# Configure monitors based on EDID serial numbers
# This ensures correct monitor positioning regardless of KVM port swapping
set -euo pipefail

# Monitor serials — match labels in hyprland.conf desc: rules
LEFT_SERIAL="LXLEE0524282"     # left:   Acer Technologies Acer V226HQL
MIDDLE_SERIAL="PC3M665802149"  # middle: Microstep MSI MP275G (rotated 90°)
# main: eDP-1 (BOE 0x07D8) — identified by name, has no serial

# Wait for Hyprland IPC to answer with monitors AND populated EDID serials.
# On boot the `exec` line fires before `hyprctl monitors` returns valid data;
# on hotplug the port appears in the list before its EDID has been read, so
# the serial is briefly empty. Either case would make the lookup below miss
# and we'd fall through to the catch-all rule. eDP-1 has no EDID serial, so
# it's exempt. ~10s cap.
MONITORS="[]"
for _ in $(seq 1 50); do
    MONITORS=$(hyprctl monitors -j 2>/dev/null || echo "[]")
    if [[ "$(echo "$MONITORS" | jq 'length')" -gt 0 ]] && \
       ! echo "$MONITORS" | jq -e '[.[] | select(.name != "eDP-1")] | any(.serial == null or .serial == "")' >/dev/null 2>&1; then
        break
    fi
    sleep 0.2
done

# Find which ports our monitors are on by querying hyprctl
LEFT_PORT=$(echo "$MONITORS" | jq -r ".[] | select(.serial==\"$LEFT_SERIAL\") | .name" 2>/dev/null || echo "")
MIDDLE_PORT=$(echo "$MONITORS" | jq -r ".[] | select(.serial==\"$MIDDLE_SERIAL\") | .name" 2>/dev/null || echo "")
HAS_MAIN=0
echo "$MONITORS" | jq -e '.[] | select(.name=="eDP-1")' > /dev/null 2>&1 && HAS_MAIN=1

if [[ -z "$LEFT_PORT" && -z "$MIDDLE_PORT" && $HAS_MAIN -eq 0 ]]; then
    echo "Warning: Could not identify any known monitors by serial. Keeping current configuration."
    exit 0
fi

# Place each present monitor adjacent to the previous one by accumulating an
# X offset. Hardcoding absolute positions left a gap when the middle monitor
# was unplugged, blocking the cursor from crossing between the two extremes.
# Widths: leftmost 1920, middle rotated -> 1080, eDP-1 1920.
#
# Apply all monitor moves in a single `hyprctl eval` chunk so Hyprland never
# sees a transient state where two monitors share coordinates. Issuing them
# serially briefly placed e.g. a freshly-connected LEFTMOST at 0x840 while
# eDP-1 still sat there, which fired the "overlapping monitors" warning and
# dropped waybar from the output it had been bound to.
#
# Hyprland 0.55+ parses a Lua config, and `hyprctl keyword` refuses to run
# against it ("keyword can't work with non-legacy parsers. Use eval.") — while
# still exiting 0, so the failure is silent. One eval of several hl.monitor()
# statements replaces the old `--batch` of `keyword monitor` lines and is
# atomic for the same reason. See docs/desktop.md#config-format.
X_OFFSET=0
LUA=""

if [[ -n "$LEFT_PORT" ]]; then
    LUA+="hl.monitor({output = \"$LEFT_PORT\", mode = \"1920x1080@60\", position = \"${X_OFFSET}x840\", scale = 1, transform = 0}) "
    X_OFFSET=$((X_OFFSET + 1920))
fi

if [[ -n "$MIDDLE_PORT" ]]; then
    LUA+="hl.monitor({output = \"$MIDDLE_PORT\", mode = \"1920x1080@60\", position = \"${X_OFFSET}x0\", scale = 1, transform = 1}) "
    X_OFFSET=$((X_OFFSET + 1080))
fi

if (( HAS_MAIN )); then
    LUA+="hl.monitor({output = \"eDP-1\", mode = \"1920x1080@60\", position = \"${X_OFFSET}x840\", scale = 1, transform = 0}) "
fi

hyprctl eval "$LUA"

# Workspace assignments after monitor coordinates are settled.
if [[ -n "$LEFT_PORT" ]]; then
    hyprctl eval "hl.workspace_rule({workspace = 1, monitor = \"$LEFT_PORT\", default = true})"
    hyprctl dispatch "hl.dsp.workspace.move({workspace = 1, monitor = \"$LEFT_PORT\"})"
fi

if [[ -n "$MIDDLE_PORT" ]]; then
    hyprctl eval "hl.workspace_rule({workspace = 2, monitor = \"$MIDDLE_PORT\", default = true})"
    hyprctl dispatch "hl.dsp.workspace.move({workspace = 2, monitor = \"$MIDDLE_PORT\"})"
fi

if (( HAS_MAIN )); then
    hyprctl eval 'hl.workspace_rule({workspace = 3, monitor = "eDP-1", default = true})'
    hyprctl dispatch 'hl.dsp.workspace.move({workspace = 3, monitor = "eDP-1"})'
fi

