#!/bin/bash
# Ask GUI apps to exit cleanly before a power action, so they get to save
# session state instead of being killed by the seat manager.
#
# Called from both halves of shutdown.sh: the outer menu (plain Shutdown /
# Reboot) and the inner update terminal, which is a separate `bash -c` and
# therefore cannot reuse a shell function.
#
# Usage: graceful_quit.sh [app ...]   (defaults to the list below)

APPS=(librewolf)
[ "$#" -gt 0 ] && APPS=("$@")

for app in "${APPS[@]}"; do
    pkill -TERM -x "$app" 2>/dev/null
done

# Poll instead of `wait`: these are not our children. 10s cap total, shared
# across the whole list, so adding apps never lengthens the shutdown.
for _ in $(seq 10); do
    running=0
    for app in "${APPS[@]}"; do
        pgrep -x "$app" >/dev/null 2>&1 && { running=1; break; }
    done
    [ "$running" -eq 0 ] && break
    sleep 1
done

exit 0
