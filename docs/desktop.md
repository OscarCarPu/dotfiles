[⬅ Back to main README](../README.md)

# Desktop layer

Hyprland + Waybar + SwayNC + Wofi + Kitty, plus the monitor / startup / power
flows that sit on top of them. For the system layer below this (kernel,
runit, drivers) see [`system.md`](system.md).

Package list lives in [`packages.md`](packages.md).

## Keybindings

Modifier `mainMod = "SUPER"`. Source: [`hypr/hyprland.lua`](../hypr/hyprland.lua).

> **Config format:** hyprlang (`hyprland.conf`) is deprecated since Hyprland
> 0.55. The config is now Lua — see [Config format](#config-format) below.

### Apps

| Key | Action |
|-----|--------|
| `SUPER + E` | Kitty terminal |
| `SUPER + R` | Wofi launcher (drun) |
| `SUPER + F` | Librewolf |
| `SUPER + P` | Spotify |
| `SUPER + S` | SoundCloud (Librewolf) |
| `SUPER + Q` | Kill active window |
| `SUPER + V` | Power menu — lock, suspend, logout, shutdown, reboot, update |
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
| `Print` | Region screenshot → clipboard |
| `Shift+Print` | Active monitor screenshot → clipboard |
| `XF86MonBrightnessUp/Down` | Brightness ±1% |
| `XF86AudioRaiseVolume/LowerVolume` | Volume ±5% |
| `XF86AudioMute` | Toggle sink mute |

## Config format

Hyprland deprecated hyprlang (`hyprland.conf`) in 0.55. From 0.56 it loads
`~/.config/hypr/hyprland.lua` when present and only falls back to the legacy
file otherwise — the startup log line to check is:

```
[cfg] Lua config not found, using legacy config at ~/.config/hypr/hyprland.conf
```

`hypr/hyprland.conf` is kept in the repo as a rollback only; delete
`hyprland.lua` and restart Hyprland to fall back to it.

**The provider is chosen at launch.** `hyprctl reload` re-reads the format the
session started with, so it cannot switch hyprlang → Lua. Confirm which one a
running session uses with:

```bash
hyprctl systeminfo | grep configProvider     # -> "lua" or "hyprlang"
```

Do not delete `hyprland.conf` while a hyprlang session is live: Hyprland
notices the file vanish and regenerates a 6-bind *stub* in its place, which a
later reload would then adopt.

### Validating a change

`--verify-config` parses the config without starting a compositor, and catches
both unknown option keys and bad dispatcher names:

```bash
Hyprland --verify-config -c ~/.config/hypr/hyprland.lua   # -> "config ok"
```

### `hyprctl` from scripts

Switching the config to Lua also changes the **CLI**, which is what actually
broke the startup flow after the migration:

- `hyprctl dispatch` now evaluates its argument as **Lua**. The positional
  form is a parse error and exits **7**:
  ```
  $ hyprctl dispatch workspace 3
  error: [string "return hl.dispatch(workspace 3)"]:1: ')' expected near '3'
  $ hyprctl dispatch 'hl.dsp.focus({workspace = 3})'
  ok
  ```
- `hyprctl keyword` refuses to run at all — and still **exits 0**, so the
  failure is silent:
  ```
  $ hyprctl keyword general:border_size 2
  keyword can't work with non-legacy parsers. Use eval.
  ```
  Use `hyprctl eval '<lua>'` instead. This also replaces `hyprctl --batch` of
  `keyword` lines: several statements in one `eval` chunk apply atomically.
- Query subcommands (`monitors`, `clients`, `activewindow`, `devices`) are
  unchanged.
- `hl.dsp.exec_cmd` still runs through a shell — pipes, redirects and
  `$(...)` all work, so the `grim -g "$(slurp)" | wl-copy` binds are fine.
- Warnings (`Workspace not found`, `window not found`) exit **0**; only a Lua
  parse/type error exits 7.

Script call sites already migrated: `startup_apps.sh` (`go_workspace` /
`exec_on_workspace` helpers), `setup_monitors_by_serial.sh`,
`monitor_watcher.sh`, `touchpad.sh`, `install-packages.sh`.

Anything under `set -e` that calls `hyprctl dispatch` dies on the spot if the
syntax is stale — that is exactly how `startup_apps.sh` failed while every
other autostart entry kept running.

### API cheat sheet

Full reference: <https://wiki.hypr.land/Configuring/Start/>.

| Legacy hyprlang | Lua |
|-----------------|-----|
| `monitor = desc:…,1920x1080@60,0x0,1` | `hl.monitor({ output = "desc:…", mode = "1920x1080@60", position = "0x0", scale = 1 })` |
| `general { gaps_in = 5 }` | `hl.config({ general = { gaps_in = 5 } })` |
| `exec-once = foo` | `hl.on("hyprland.start", function() hl.exec_cmd("foo") end)` |
| `exec = foo` | `hl.on("config.reloaded", function() hl.exec_cmd("foo") end)` |
| `bezier = name, …` | `hl.curve("name", { type = "bezier", points = {…} })` |
| `animation = windows, 1, 7, name` | `hl.animation({ leaf = "windows", enabled = true, speed = 7, bezier = "name" })` |
| `bind = SUPER, Q, killactive` | `hl.bind("SUPER + Q", hl.dsp.window.close())` |
| `binde = …` | `hl.bind(…, { repeating = true })` |
| `bindm = …` | `hl.bind(…, { mouse = true })` |
| `movefocus, l` | `hl.dsp.focus({ direction = "l" })` |
| `workspace, 3` | `hl.dsp.focus({ workspace = 3 })` |
| `movetoworkspace, 3` | `hl.dsp.window.move({ workspace = 3 })` |
| `cyclenext` | `hl.dsp.window.cycle_next({})` |
| `movecurrentworkspacetomonitor, l` | `hl.dsp.workspace.move({ monitor = "l" })` |
| `windowrule { … }` | `hl.window_rule({ name = …, match = { … }, … })` |

Gotchas found during the port:

- `config.reloaded` also fires on the **initial** parse. Anything registered
  under both it and `hyprland.start` runs twice at boot.
- Directions are `l` / `r` / `u` / `d`. The upstream example config writes
  `"left"`, which only works because the parser reads the first character.
- Colors stay strings (`"rgb(fab387)"`); gradients become
  `{ colors = { … }, angle = 45 }`.

## Theme & visuals

Unified [Catppuccin Mocha](https://catppuccin.com/palette) palette across
the desktop layer — the same hex values appear in:

- `hypr/hyprland.lua` — active border gradient (`peach` → `blue`),
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
an autostart entry in `hyprland.lua`. Two reasons:

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

`gaps_out = { top = 10, right = 5, bottom = 10, left = 5 }` in
`hypr/hyprland.lua`. The 5px gutters on the sides make tiled windows align
almost flush with the full-width waybar; vertical gaps stay at 10px so the
bar visibly floats above the tiling area. The Lua type is `css_gaps` — an
integer, or a table with any of `top`/`right`/`bottom`/`left`, so the old
"comma syntax vs spaces" footgun is gone. Verify with
`hyprctl getoption general:gaps_out -j` (prints `"css": "10 5 10 5"`).

## Power menu (Super+V)

A wofi selection menu for power actions and system updates.

| Option | Behavior |
|--------|----------|
| `󰐥  Shutdown` | Immediate shutdown — no terminal opens |
| `󰜉  Reboot` | Immediate reboot — no terminal opens |
| `󰚰  Update + Shutdown` | Opens update terminal, then shuts down |
| `󰚰  Update + Reboot` | Opens update terminal, then reboots |
| `󰚰  Update Only` | Opens update terminal, no power action |
| `󰌾  Lock` | Runs `hyprlock`/`swaylock`; hidden if neither is installed |
| `󰤄  Suspend` | `loginctl suspend` |
| `󰅖  Cancel` | Dismiss menu |

The power actions keep the positions they have always had, new entries are
appended rather than inserted, and `Cancel` stays last, so the order stays
predictable under muscle memory. Only one power session can be open at a time
(`flock`) — two update terminals would race on the pacman database lock.

**Update terminal flow** (Artix-aware — no `systemd` in the critical list,
includes `runit`/`elogind`):

1. Every slow call is launched before anything is printed: the database sync,
   the Arch news fetch and `yay -Qua`. The proceed/abort decision is never
   behind a network round-trip.
2. Repo databases are synced into a **private copy** under `fakeroot` (the
   `checkupdates` trick), so listing updates needs no password, and the real
   database is never left synced-but-not-upgraded — a bare `pacman -Sy`
   arms the next `pacman -S` for a partial upgrade every time you answer "no".
3. Held-back packages are split out first. `pacman` marks its own with
   `[ignored]` (it has already resolved globs and `IgnoreGroup`); AUR lines
   are matched against `pacman-conf IgnorePkg`. Each is annotated with its
   upstream `repo#num` from [`tracked_blockers.py --refs`](../hypr/scripts/tracked_blockers.py)
   (offline, instant).
4. Prints every package with three colors:
   - `!!` red — critical (`linux`, `nvidia`, `mesa`, `glibc`, `pacman`,
     `runit`, `elogind`, plus the `hyprland`/`aquamarine`/`evdi` stack)
   - `**` yellow — explicitly installed by the user (`pacman -Qe`)
   - dim gray — pulled in as a dependency
   And a footer with the highlighted / dep counts. Below it, `++` magenta —
   packages in the resolved transaction that are **not** upgrades of anything
   installed: new dependencies and replacements. `pacman -Qu` cannot see
   these, so they come from `pacman -Su --print` against the private database
   (unprivileged, and overlapped with the listing so it costs no wall time).
5. Arch news, filtered to items **published since the last upgrade**
   (timestamp from `/var/log/pacman.log`). The same three headlines on every
   run is how a warning banner becomes invisible.
6. Release notes for the highlighted packages via
   [`release_notes.py`](../hypr/scripts/release_notes.py) — parallel fetches
   against the GitHub Releases API with a fallback to recent Arch GitLab
   packaging commits. No LLM, no API keys. Prefetched during step 4, so they
   are already on screen when the confirm prompt appears.
7. Confirms **once**, then runs `sudo pacman -Syu --noconfirm` — the first
   password prompt of the flow — and `yay -Sua --noconfirm`. This is where
   sync and upgrade happen atomically. `--noconfirm` because the `y/N` above
   already is the decision: asking twice for the same thing only trains you to
   hit Enter without reading. The tradeoff is that pacman no longer asks about
   replacements or provider choices either, which is what step 4's `++` block
   exists to surface beforehand.
8. Live assessment of the held-back packages from
   [`tracked_blockers.py`](../hypr/scripts/tracked_blockers.py) (one `claude`
   call per blocker) is started back at step 3 and rendered here: it informs
   "should I unpin?", not "should I update?". Results are cached on the
   content they were derived from — blocker definition, incoming versions,
   upstream issue state — so `claude` only runs when something upstream moved.
   `--refresh` forces a re-assessment.
9. Resolves the `.pacnew` config files — the ones pacman refuses to overwrite
   because you edited them — via
   [`merge_pacnew.py`](../hypr/scripts/merge_pacnew.py). See below. Anything it
   declines to touch is listed via `pacdiff -o`, which asks the package
   database and so also covers `.pacnew`/`.pacsave` outside `/etc`; `pacdiff`
   is offered for those.
10. The power action confirms with a 30s timer: Enter goes now, **Ctrl+C or
    Ctrl+D cancels**, and walking away lets it proceed — which is the point
    of picking `Update + Shutdown` in the first place.

### Automatic `.pacnew` merging

[`merge_pacnew.py`](../hypr/scripts/merge_pacnew.py) makes the decision
`pacdiff` would otherwise walk you through file by file.

It is a real 3-way merge first: the pristine **old** default is extracted from
the previously installed package in `/var/cache/pacman/pkg` (newest cached
version strictly older than the installed one), and `git merge-file`
reconciles your edits against upstream's. Most `.pacnew` files resolve that way
with no model involved at all. `claude --print` is asked only for the hunks git
leaves conflicted — it receives the merge output with the conflict markers in
place — and for files with no cached base, where there is no third point to
triangulate from. Local values win on a genuine collision: that is the edit you
made on purpose.

Never merged automatically, because this runs unattended and often right
before a shutdown: `fstab`, `crypttab`, `mkinitcpio.conf`, `default/grub`,
`/boot/*`, `passwd`/`shadow`/`group`, `sudoers*`, `pam.d/*`, `nsswitch.conf`,
`sshd_config`, `securetty`, `shells`, `runit/*`. A bad merge there is a broken
boot or a login you cannot pass. Those are left as `.pacnew` for `pacdiff`.

Before anything is written: the result must carry no leftover conflict
markers, must not be suspiciously short (truncation guard), and must pass a
syntax check where one exists (`pacman-conf --config` for `pacman.conf`).
Symlinks are resolved first — several `/etc` files here point into this repo,
so the merge lands in the repo and shows up in `git diff`. The previous
contents are saved to `$XDG_STATE_HOME/hypr/pacnew-backups/` and a diff of
every applied change is printed.

Run it standalone with `--dry-run` to see what it would do, or `--no-claude`
to restrict it to merges git can settle alone.

Source: [`hypr/scripts/shutdown.sh`](../hypr/scripts/shutdown.sh). Apps that
should exit cleanly before a power action are listed in
[`graceful_quit.sh`](../hypr/scripts/graceful_quit.sh) (10s cap, shared across
the whole list), shared by both halves of the script.

The actual shutdown / reboot calls go through `loginctl` (provided by
`elogind` on Artix); see [`system.md`](system.md#7-power--shutdown).

## Monitors

`hypr/scripts/setup_monitors_by_serial.sh` identifies the two external panels
by EDID serial (`LXLEE0524282`, `PC3M665802149`) and pins them to absolute
positions, regardless of which DisplayLink port the dock assigned. If you
swap monitors, update the serials in that script. On boot it polls
`hyprctl monitors -j` until Hyprland answers with a populated list (10s cap,
mirrors waybar's "wait for the compositor" pattern) before reading serials,
so the `config.reloaded` hook in `hyprland.lua` doesn't lose the race against
DisplayLink enumeration.

`hypr/scripts/monitor_watcher.sh` listens to Hyprland's event socket (via
`socat` + `jq`) and re-runs the setup script whenever monitors are added or
removed (KVM switching, unplugging the dock, etc.). It also persists the
workspace → monitor mapping under `$XDG_STATE_HOME/hypr/` so workspaces
return to the same physical screen after a replug.

Both are launched from the `hyprland.start` hook in `hypr/hyprland.lua`.

## Startup apps

On Hyprland startup, [`hypr/scripts/startup_apps.sh`](../hypr/scripts/startup_apps.sh)
unconditionally runs the `normal_setup` flow:

- Switches to workspace 3, spawns Spotify, waits for the window via
  `hyprctl clients` (no blind `sleep`)
- Switches to workspace 1 and opens the daily tabs in Librewolf (Gmail x3,
  lab-ocp, Claude, WhatsApp). Before launching Librewolf, `wait_for_internet`
  polls `https://mail.google.com/generate_204` (or `getent hosts` if curl
  is missing) until reachable, 30s cap — keeps the daily tabs from cold-
  booting into "no internet" pages while NetworkManager is still connecting.
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

Rotation walks `~/media/images/main` in filename order rather than picking at
random, so every image gets shown once per cycle instead of the same handful
recurring while others never come up. The cursor lives in
`~/.cache/wallpaper_index` (override with `WALLPAPER_INDEX_FILE`) and is shared
by the service and `SUPER + W`, so a manual rotate advances the same sequence.
With no index file — a cold start, or after deleting it — the starting point is
random, so a fresh boot doesn't always open on the same image. On a multi-head
setup each monitor is offset one step from the previous one.

To jump the sequence somewhere specific, write a 0-based index (`echo 42 >
~/.cache/wallpaper_index`) or delete the file to reroll a random start.

## Launcher (Wofi)

Themed to match waybar (Catppuccin Mocha + peach accent). Config and CSS
live in [`wofi/`](../wofi/). Triggered by `SUPER + R` (drun mode) and reused
by the clipboard history binding below.

## Clipboard history

`cliphist` stores every clipboard entry that `wl-paste --watch` sees. Two
watchers are launched from the `hyprland.start` hook in `hyprland.lua` — one for text,
one for images.

| Key | Action |
|-----|--------|
| `SUPER + SHIFT + V` | Show history in wofi → selection is re-copied to clipboard |

History lives at `~/.cache/cliphist/db`. Wipe it with `cliphist wipe`.

## Notifications (SwayNC)

`swaync` runs from the `hyprland.start` hook and is exposed in waybar as the
`custom/notification` module (between the USB indicator and the CPU
block):

- Left click → toggle the notification panel
- Right click → toggle Do Not Disturb
- `SUPER + N` does the same as left click

The module reads state via `swaync-client -swb` (subscribed JSON output)
so the icon updates immediately when notifications arrive or DND is
toggled. Display:

- 0 unread → module is collapsed out of the bar entirely (zero padding,
  zero margin, no clickable area). Driven by the `.none` / `.dnd-none`
  / `.inhibited-none` / `.dnd-inhibited-none` CSS rules in
  `waybar/style.css`.
- ≥1 unread → yellow pill with the count and a bell glyph, e.g. `5 `.
  In DND it stays the same shape but turns peach.

The bell glyph in `format` is `` (Nerd Font
`nf-fa-bell`, U+F0F3). If a future edit strips it (some editors mangle
private-use BMP characters), restore it with the JSON Unicode escape
`` — JSON parsers (waybar's included) treat both forms
identically.
Config + theme live in [`swaync/`](../swaync/).

## Removable media (USB)

Auto-mount stack so a USB stick "just appears" when plugged in:

- `udiskie -a -n` runs from the `hyprland.start` hook in `hyprland.lua`. It listens
  for udev events and asks `udisks2` to mount removable devices under
  `/run/media/$USER/<label>/`. `polkit` already grants the active-session
  user passwordless mount, so no custom rule is needed.
- `gvfs` provides the virtual-filesystem layer that `thunar` (the file
  manager) uses for sidebar mounts and the trash.

The waybar `custom/usb` module is the visible UI. Driver:
[`hypr/scripts/usb_status.sh`](../hypr/scripts/usb_status.sh) globs
`/run/media/$USER/*` and emits JSON for waybar:

- Nothing mounted → empty text, module hidden.
- ≥1 mount → green pill `󰕓 N` (USB icon + mount count). Tooltip lists
  the labels.
- Left click → `udiskie-umount -a` unmounts every removable device
  (also powers them off via udisks2 so it's safe to pull).
- Right click → opens Thunar at `/run/media/$USER`.

To mount a device that was already plugged in before udiskie started:

```bash
udisksctl mount -b /dev/sdX
```

## Hypr state files

The compositor writes a few runtime files into `~/.config/hypr/` (the
symlinked repo). They are intentionally **not** tracked:

- `wallpaper_index.json` — listed in `.gitignore`. Old leftover from a
  previous wallpaper rotator; unrelated to the current rotator's cursor, which
  lives in `~/.cache/wallpaper_index`. Safe to ignore if it reappears.
- `monitors.conf`, `workspaces.conf` — used to live here as nwg-displays
  output and an empty placeholder. Removed: nothing in `hyprland.lua`
  sources them. If you reintroduce one, add a `source = …` directive.
