[⬅ Back to main README](../README.md)

# Desktop layer

Hyprland + Waybar + SwayNC + Wofi + Kitty, plus the monitor / startup / power
flows that sit on top of them. For the system layer below this (kernel,
runit, drivers) see [`system.md`](system.md).

Package list lives in [`packages.md`](packages.md).

## Keybindings

| Key | Action |
|-----|--------|
| `SUPER + E` | Open Kitty terminal |
| `SUPER + R` | Open Wofi launcher |
| `SUPER + Q` | Kill active window |
| `SUPER + V` | Power menu (wofi) — shutdown, reboot, or update |

Screenshot: `Print` → `grim -g "$(slurp)" | wl-copy`.

## Power menu (Super+V)

A wofi selection menu for power actions and system updates.

| Option | Behavior |
|--------|----------|
| `⏻  Shutdown` | Immediate shutdown — no terminal opens |
| `↺  Reboot` | Immediate reboot — no terminal opens |
| `⟳  Update + Shutdown` | Opens update terminal, then shuts down |
| `⟳  Update + Reboot` | Opens update terminal, then reboots |
| `⟳  Update Only` | Opens update terminal, no power action |
| `×  Cancel` | Dismiss menu |

**Update terminal flow:**
1. Calculates available updates and starts AI summary fetch in the background
2. Shows latest distro news (pulled from `archlinux.org` — Artix tracks the same packages)
3. Lists packages updating (critical ones highlighted in red)
4. Optionally shows AI summary — already fetched, no waiting
5. Confirms before running the update
6. Checks `.pacnew` files after update

**AI summary** requires `GROQ_API_KEY` set in `~/.bashrc`. Uses the LLM's
training knowledge — no slow GitHub changelog fetching.

Source: [`hypr/scripts/shutdown.sh`](../hypr/scripts/shutdown.sh).

The actual shutdown / reboot calls go through `loginctl`; see
[`system.md`](system.md#7-power--shutdown).

## Monitors

`hypr/scripts/setup_monitors_by_serial.sh` identifies the two external panels
by EDID serial (`LXLEE0524282`, `PC3M665802149`) and pins them to absolute
positions, regardless of which DisplayLink port the dock assigned. If you
swap monitors, update the serials in that script.

`hypr/scripts/monitor_watcher.sh` listens to Hyprland's event socket (via
`socat` + `jq`) and re-runs the setup script whenever monitors are added or
removed (KVM switching, unplugging the dock, etc.). It also persists the
workspace → monitor mapping under `$XDG_STATE_HOME/hypr/` so workspaces
return to the same physical screen after a replug.

Both are launched as `exec-once` from `hypr/hyprland.conf`.

## Startup apps

On Hyprland startup, [`hypr/scripts/startup_apps.sh`](../hypr/scripts/startup_apps.sh)
unconditionally runs the `normal_setup` flow:

- Spotify spawns and lands on workspace 3 (windowrule pinned)
- Brave opens the daily tabs (Gmail x3, lab-ocp, Claude, WhatsApp) on workspace 1
- Kitty opens on workspace 2 via `[workspace 2 silent]` dispatch

Other modes (`learn_rust`, `musescore`, `uoc`) are kept in the file as
ready-to-use functions — to switch flows, change the last line of the script
from `normal_setup` to one of those.

To change the daily browser tab list, edit the `open_web` function.

## Wallpaper

The `set-wallpaper` runit user service (see
[`system.md`](system.md#user)) runs `awww` and rotates the wallpaper every
180 s. It waits for the Wayland socket before touching anything, so launch
order doesn't matter.
