#
# ~/.bash_profile
#

if [ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && [ "$XDG_VTNR" = "1" ]; then
    exec dbus-run-session bash -c '
        runsvdir "$HOME/.local/share/runit/sv" &
        exec start-hyprland
    '
fi

[[ -f ~/.bashrc ]] && . ~/.bashrc
