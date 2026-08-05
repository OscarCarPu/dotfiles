-- Hyprland config (Lua). Ported from the legacy hyprland.conf — hyprlang is
-- deprecated since 0.55 and Hyprland now prefers ~/.config/hypr/hyprland.lua.
-- Wiki: https://wiki.hypr.land/Configuring/Start/

local DOTS = os.getenv("HOME") .. "/.dotfiles/hypr/scripts"

------------------
---- MONITORS ----
------------------

-- Monitors matched by EDID description (serial) so port names like DVI-I-3/4 don't matter.
-- Dock monitors PARK at negative coordinates on connect: eDP-1 may have been
-- gap-shifted to 0x840 while undocked, so full-dock positions here would
-- overlap it and fire the "overlaps with other monitors" notification on
-- every re-dock. Negative X can never collide with eDP-1 (always at X>=0);
-- setup_monitors_by_serial.sh moves everything to its real position once the
-- outputs settle.
hl.monitor({ -- left (parked)
    output   = "desc:Acer Technologies Acer V226HQL LXLEE0524282",
    mode     = "1920x1080@60",
    position = "-3000x840",
    scale    = 1,
})
hl.monitor({ -- middle (parked)
    output    = "desc:Microstep MSI MP275G PC3M665802149",
    mode      = "1920x1080@60",
    position  = "-1080x0",
    scale     = 1,
    transform = 1,
})
hl.monitor({ -- main
    output   = "eDP-1",
    mode     = "1920x1080@60",
    position = "3000x840",
    scale    = 1,
})
-- Catch-all: place unknown monitors far off-screen so they never overlap.
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "10000x0",
    scale    = 1,
})

-------------------
---- AUTOSTART ----
-------------------

-- waybar runs as a runit user service (see runit/user/waybar/) — auto-restarts
-- on crash and waits for the Wayland socket before launching.
-- Wallpaper rotation, battery alerts and audio stack also run as runit user
-- services under ~/.local/share/runit/sv/ — see docs/system.md.
hl.on("hyprland.start", function()
    hl.exec_cmd(DOTS .. "/brightness.sh set 100")
    hl.exec_cmd(DOTS .. "/monitor_watcher.sh")
    hl.exec_cmd(DOTS .. "/audio_watcher.sh")
    hl.exec_cmd("swaync")
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd(DOTS .. "/fullscreen_dnd.sh")
    hl.exec_cmd(DOTS .. "/startup_apps.sh")
    hl.exec_cmd("wl-paste --type text  --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("udiskie -a -n")
end)

-- Legacy `exec` (as opposed to `exec-once`): runs at config parse time and
-- again on every reload, so a reload re-applies real monitor positions.
-- `config.reloaded` also fires on the initial parse, so this covers startup
-- too — do NOT also list it under `hyprland.start` or it runs twice at boot.
hl.on("config.reloaded", function()
    hl.exec_cmd(DOTS .. "/setup_monitors_by_serial.sh")
end)

-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = { top = 10, right = 5, bottom = 10, left = 5 },

        border_size = 2,

        col = {
            active_border   = { colors = { "rgb(fab387)", "rgb(89b4fa)" }, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },

        layout = "dwindle",
    },

    decoration = {
        rounding     = 5,
        dim_inactive = true,
        dim_strength = 0.1,

        blur = {
            enabled  = true,
            size     = 3,
            passes   = 1,
            vibrancy = 0.16,
        },

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = "rgba(00000099)",
        },
    },

    dwindle = {
        preserve_split = true,
    },

    cursor = {
        no_hardware_cursors = false,
    },

    animations = {
        enabled = true,
    },
})

hl.curve("easeOutExpo", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })

hl.animation({ leaf = "windows",    enabled = true, speed = 7,  bezier = "easeOutExpo" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 7,  bezier = "easeOutExpo", style = "popin 80%" })
hl.animation({ leaf = "border",     enabled = true, speed = 10, bezier = "easeOutExpo" })
hl.animation({ leaf = "fade",       enabled = true, speed = 7,  bezier = "easeOutExpo" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6,  bezier = "easeOutExpo" })

---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout          = "es",
        numlock_by_default = true,
        follow_mouse       = 1,
        accel_profile      = "adaptive",
        sensitivity        = 0.8,
    },
})

----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        mouse_move_enables_dpms  = true,
        key_press_enables_dpms   = true,
        vrr                      = 1,
        enable_swallow           = true,
        swallow_regex            = "^(kitty)$",
        focus_on_activate        = true,
    },
})

--------------------
---- WINDOW RULES --
--------------------

-- Wine/XWayland games (e.g. Celeste): honor focus activation requests so
-- keyboard input routes correctly after alt-tab.
hl.window_rule({
    name  = "xwayland-focus-on-activate",
    match = { xwayland = true },

    focus_on_activate = true,
})

---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"

hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd(DOTS .. "/shutdown.sh"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("kitty"))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("wofi --show drun"))
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd("librewolf"))
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("spotify"))
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("librewolf https://soundcloud.com"))
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd("obsidian"))

-- Clipboard history (cliphist + wofi)
hl.bind(mainMod .. " + SHIFT + V",
    hl.dsp.exec_cmd('cliphist list | wofi --dmenu --prompt "Clipboard" | cliphist decode | wl-copy'))

-- Brightness control
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(DOTS .. "/brightness.sh up"),   { repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(DOTS .. "/brightness.sh down"), { repeating = true })
hl.bind(mainMod .. " + F9",      hl.dsp.exec_cmd(DOTS .. "/brightness.sh up"),   { repeating = true })
hl.bind(mainMod .. " + F8",      hl.dsp.exec_cmd(DOTS .. "/brightness.sh down"), { repeating = true })

-- Volume control
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(DOTS .. "/volume.sh up"),   { repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(DOTS .. "/volume.sh down"), { repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd(DOTS .. "/volume.sh mute"))
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd(DOTS .. "/volume.sh mic-mute"))
hl.bind(mainMod .. " + F6",     hl.dsp.exec_cmd(DOTS .. "/volume.sh up"),   { repeating = true })
hl.bind(mainMod .. " + F5",     hl.dsp.exec_cmd(DOTS .. "/volume.sh down"), { repeating = true })
hl.bind(mainMod .. " + F3",     hl.dsp.exec_cmd(DOTS .. "/volume.sh mute"))

-- Touchpad toggle
hl.bind(mainMod .. " + F1", hl.dsp.exec_cmd(DOTS .. "/touchpad.sh toggle"))

-- Notification center
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("swaync-client -t -sw"))

-- Workspace and focus
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "d" }))
hl.bind(mainMod .. " + tab",   hl.dsp.window.cycle_next({}))

for i = 1, 10 do
    hl.bind(mainMod .. " + " .. (i % 10), hl.dsp.focus({ workspace = i }))
end

-- Legacy config only bound SHIFT + 1..8; kept as-is.
for i = 1, 8 do
    hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

hl.bind("CTRL + ALT + " .. mainMod .. " + comma",  hl.dsp.workspace.move({ monitor = "l" }))
hl.bind("CTRL + ALT + " .. mainMod .. " + period", hl.dsp.workspace.move({ monitor = "r" }))

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Screenshot
hl.bind("Print",           hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy --type image/png'))
hl.bind("SHIFT + Print",   hl.dsp.exec_cmd('grim -o "$(hyprctl activeworkspace -j | jq -r .monitor)" - | wl-copy --type image/png'))

-- Wallpaper
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(DOTS .. "/set_wallpaper.sh"))
