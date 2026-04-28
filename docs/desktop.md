[⬅ Back to main README](../README.md)

# Desktop layer

Hyprland + Waybar + SwayNC + Wofi + Kitty, plus the monitor / startup / power
flows that sit on top of them. For the system layer below this (kernel,
runit, drivers) see [`system.md`](system.md).

Package list lives in [`packages.md`](packages.md).

## Keybindings

Modifier `$mainMod = SUPER`. Source: [`hypr/hyprland.conf`](../hypr/hyprland.conf).

### Apps

| Key | Action |
|-----|--------|
| `SUPER + E` | Kitty terminal |
| `SUPER + R` | Wofi launcher (drun) |
| `SUPER + F` | Brave |
| `SUPER + P` | Spotify |
| `SUPER + S` | SoundCloud (Brave PWA) |
| `SUPER + Q` | Kill active window |
| `SUPER + V` | Power menu — shutdown, reboot, update |
| `SUPER + N` | Toggle SwayNC notification panel |
| `SUPER + W` | Rotate wallpaper (`set_wallpaper.sh`) |
| `SUPER + SHIFT + V` | Clipboard history (cliphist + wofi) |

### Window / focus

| Key | Action |
|-----|--------|
| `SUPER + ←/→/↑/↓` | Move focus |
| `SUPER + Tab` | Cycle through windows |
| `SUPER + drag LMB` | Move floating window |
| `SUPER + drag RMB` | Resize floating window |

### Workspaces

| Key | Action |
|-----|--------|
| `SUPER + 1..9, 0` | Switch to workspace 1–10 |
| `SUPER + SHIFT + 1..8` | Move active window to workspace 1–8 |
| `SUPER + scroll` | Cycle through workspaces |
| `CTRL + ALT + SUPER + ,` / `.` | Move current workspace to left / right monitor |

### System

| Key | Action |
|-----|--------|
| `Print` | Region screenshot → clipboard (`grim -g "$(slurp)" \| wl-copy`) |
| `XF86MonBrightnessUp/Down` | Brightness ±1% |
| `XF86AudioRaiseVolume/LowerVolume` | Volume ±5% |
| `XF86AudioMute` | Toggle sink mute |

## Theme & visuals

Unified [Catppuccin Mocha](https://catppuccin.com/palette) palette across
the desktop layer — the same hex values appear in:

- `hypr/hyprland.conf` — active border gradient (`peach` → `blue`),
  `dim_inactive`, soft `shadow`
- `waybar/style.css` — module accents and the `tooltip` border
- `wofi/style.css` — launcher window border + selected-entry color
- `swaync/` — notification panel

GTK apps (and wofi's icon column) follow `Papirus-Dark` via
[`configs/gtk-3.0/settings.ini`](../configs/gtk-3.0/settings.ini). Without
that file GTK falls back to Adwaita's small bitmap icons and they look
pixelated inside wofi.

### Waybar lifecycle

Waybar runs as a **runit user service** (`runit/user/waybar/`) instead of
an `exec-once` from `hyprland.conf`. Two reasons:

- The runit run script waits for `$XDG_RUNTIME_DIR/wayland-N` and a live
  Hyprland IPC signature before launching, so an exec-once race against
  `xdg-desktop-portal-hyprland` / `StatusNotifierWatcher` no longer
  silently kills the bar at boot.
- runit auto-restarts the service if waybar crashes or you `sv restart waybar`
  after editing CSS — no need to `pkill && hyprctl dispatch exec …` by hand.

```bash
SVDIR=~/.local/share/runit/sv sv status  waybar
SVDIR=~/.local/share/runit/sv sv restart waybar
tail -f ~/.local/share/runit/sv/waybar/log/main/current
```

### Window gaps

`gaps_out = 10,5,10,5` in `hypr/hyprland.conf` (top, right, bottom, left).
The 5px gutters on the sides make tiled windows align almost flush with the
full-width waybar; vertical gaps stay at 10px so the bar visibly floats
above the tiling area. Use the comma syntax — space-separated values are
silently parsed as a single value applied to all sides.

## Power menu (Super+V)

A wofi selection menu for power actions and system updates.

| Option | Behavior |
|--------|----------|
| `󰐥  Shutdown` | Immediate shutdown — no terminal opens |
| `󰜉  Reboot` | Immediate reboot — no terminal opens |
| `󰚰  Update + Shutdown` | Opens update terminal, then shuts down |
| `󰚰  Update + Reboot` | Opens update terminal, then reboots |
| `󰚰  Update Only` | Opens update terminal, no power action |
| `󰅖  Cancel` | Dismiss menu |

**Update terminal flow** (Artix-aware — no `systemd` in the critical list,
includes `runit`/`elogind`):

1. Shows the latest Arch Linux news (Artix tracks the same packages)
2. Syncs repo DBs once with `sudo pacman -Sy`, then lists pending updates
   via `pacman -Qu` (repos) + `yay -Qua` (AUR). No dependency on
   `checkupdates` from `pacman-contrib`.
3. Prints every package with three colors:
   - `!!` red — critical (`linux`, `nvidia`, `mesa`, `glibc`, `pacman`,
     `runit`, `elogind`, …)
   - `**` yellow — explicitly installed by the user (`pacman -Qe`)
   - dim gray — pulled in as a dependency
   And a footer with the explicit / dep counts.
4. **Optional**: prompts to fetch upstream release notes for the
   highlighted packages via [`release_notes.py`](../hypr/scripts/release_notes.py)
   — parallel fetches against the GitHub Releases API with a fallback
   to recent Arch GitLab packaging commits. No LLM, no API keys.
5. Confirms, then runs `sudo pacman -Su` (DBs already synced) and
   `yay -Sua`.
6. After update, lists any `.pacnew` files under `/etc`. Offers `pacdiff`
   if `pacman-contrib` is installed; otherwise prints the file paths so
   you can merge manually.

Source: [`hypr/scripts/shutdown.sh`](../hypr/scripts/shutdown.sh).

The actual shutdown / reboot calls go through `loginctl` (provided by
`elogind` on Artix); see [`system.md`](system.md#7-power--shutdown).

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

- Switches to workspace 3, spawns Spotify, waits for the window via
  `hyprctl clients` (no blind `sleep`)
- Switches to workspace 1 and opens the daily tabs in Brave (Gmail x3,
  lab-ocp, Claude, WhatsApp)
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

## Launcher (Wofi)

Themed to match waybar (Catppuccin Mocha + peach accent). Config and CSS
live in [`wofi/`](../wofi/). Triggered by `SUPER + R` (drun mode) and reused
by the clipboard history binding below.

## Clipboard history

`cliphist` stores every clipboard entry that `wl-paste --watch` sees. Two
watchers are launched as `exec-once` from `hyprland.conf` — one for text,
one for images.

| Key | Action |
|-----|--------|
| `SUPER + SHIFT + V` | Show history in wofi → selection is re-copied to clipboard |

History lives at `~/.cache/cliphist/db`. Wipe it with `cliphist wipe`.

## Notifications (SwayNC)

`swaync` runs as `exec-once` and is exposed in waybar as the
`custom/notification` module (left of the system blocks):

- Left click → toggle the notification panel
- Right click → toggle Do Not Disturb
- `SUPER + N` does the same as left click

The waybar module reads state via `swaync-client -swb` (subscribed JSON
output) so the icon updates immediately when notifications arrive or DND is
toggled. Config + theme live in [`swaync/`](../swaync/).

## Hypr state files

The compositor writes a few runtime files into `~/.config/hypr/` (the
symlinked repo). They are intentionally **not** tracked:

- `wallpaper_index.json` — listed in `.gitignore`. Old leftover from a
  previous wallpaper rotator; the current `set_wallpaper.sh` does not read
  or write it. Safe to ignore if it reappears.
- `monitors.conf`, `workspaces.conf` — used to live here as nwg-displays
  output and an empty placeholder. Removed: nothing in `hyprland.conf`
  sources them. If you reintroduce one, add a `source = …` directive.
