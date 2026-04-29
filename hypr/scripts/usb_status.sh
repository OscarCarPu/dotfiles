#!/bin/bash
# Waybar custom/usb module: emit JSON describing mounted removable media.
# udiskie auto-mounts under /run/media/$USER/<label>/. Empty text hides the
# module so it disappears when nothing is plugged in.
set -euo pipefail
shopt -s nullglob

dir="/run/media/$USER"
mounts=("$dir"/*)

if [ ${#mounts[@]} -eq 0 ]; then
    echo '{"text":"","tooltip":""}'
    exit 0
fi

names=()
for m in "${mounts[@]}"; do names+=("$(basename "$m")"); done
joined=$(printf '%s\n' "${names[@]}")
tooltip=$(printf 'Click to unmount\n\n%s' "$joined")

jq -nc \
    --arg t "󰕓 ${#mounts[@]}" \
    --arg tt "$tooltip" \
    '{text:$t, tooltip:$tt, class:"mounted"}'
