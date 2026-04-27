[⬅ Back to main README](../README.md)

# Artix bring-up

End-to-end steps to take a fresh Artix Linux install and reach the same desktop
this repo describes: Hyprland on Wayland, Waybar, SwayNC, PipeWire stack as
runit user services, DisplayLink dock for the three-screen setup.

## 1. Base packages

Install from the official repos:

```bash
sudo pacman -S \
    hyprland xdg-desktop-portal-hyprland \
    waybar swaync wofi kitty \
    pipewire pipewire-audio pipewire-pulse wireplumber \
    elogind elogind-runit \
    rclone jq grim slurp wl-clipboard \
    socat
```

`elogind-runit` provides the `elogind` service used for `loginctl poweroff/reboot`
and seat management.

An AUR helper (this repo assumes `yay`):

```bash
sudo pacman -S --needed base-devel git
git clone https://aur.archlinux.org/yay.git /tmp/yay && (cd /tmp/yay && makepkg -si)
```

## 2. AUR packages

```bash
yay -S displaylink evdi-dkms
```

`displaylink` ships the userspace `DisplayLinkManager` daemon. `evdi-dkms`
provides the kernel module that exposes DisplayLink-attached panels as DRM
connectors. Both are required for the dock — without them only `eDP-1` shows
up in `hyprctl monitors`.

## 3. Clone and link the dotfiles

```bash
git clone https://github.com/OscarCarPu/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
bash install.sh           # user symlinks
bash install.sh --system  # /etc symlinks (sudo)
```

This places everything from the [Symlink list](../README.md#symlink-list).

## 4. Activate runit services

### System (DisplayLink)

`install.sh --system` puts the service definition under `/etc/runit/sv/displaylink`.
Activate it by linking into the live supervision dir:

```bash
sudo ln -s /etc/runit/sv/displaylink /run/runit/service/
```

To have it come up on every boot, also link it under the default runlevel:

```bash
sudo ln -s /etc/runit/sv/displaylink /etc/runit/runsvdir/default/
```

`evdi.conf` in `/etc/modules-load.d/` makes the kernel autoload `evdi` at boot,
so `DisplayLinkManager` finds it ready.

### User services

`runsvdir` for the user is launched from `~/.bash_profile` inside the same
`dbus-run-session` as `start-hyprland`, so all user services inherit the session
DBus address. Defined under `runit/user/`:

| Service                 | Purpose                                       |
|-------------------------|-----------------------------------------------|
| `pipewire`              | Audio server                                  |
| `wireplumber`           | PipeWire session manager (waits for socket)   |
| `pipewire-pulse`        | PulseAudio compatibility layer                |
| `rclone-bisync-arreglos`| Bisync to Google Drive every 5 min             |
| `set-wallpaper`         | Rotates wallpaper every 180 s via `awww`      |
| `battery-notify`        | Polls battery every 60 s, alerts via DBus     |

`set-wallpaper` waits for the Wayland socket before doing anything, so it can
start before Hyprland and runit will keep retrying until the compositor is up.

To start them now without re-logging in:

```bash
SVDIR=~/.local/share/runit/sv sv up pipewire wireplumber pipewire-pulse rclone-bisync-arreglos set-wallpaper battery-notify
```

Status / logs:

```bash
SVDIR=~/.local/share/runit/sv sv status pipewire wireplumber pipewire-pulse
tail -f ~/.local/share/runit/sv/pipewire/log/main/current
```

`hypr/scripts/refresh_audio.sh` (bound to KVM-switch flow) restarts the three
services via `sv restart`, which is the runit equivalent of the old
`systemctl --user restart`.

## 5. Login flow

`bash/.bash_profile` is symlinked to `~/.bash_profile`. On TTY1, when no
display is attached, it:

```bash
exec dbus-run-session bash -c '
    runsvdir "$HOME/.local/share/runit/sv" &
    exec start-hyprland
'
```

`runsvdir` is forked **inside** the dbus-run-session — that way every user
service it supervises inherits `DBUS_SESSION_BUS_ADDRESS` and can talk to
notifications, polkit, etc. (Doing the spawn before `dbus-run-session` was the
cause of `wireplumber`/`pipewire-pulse` failing with "Failed to connect to
session bus" during the migration.)

`start-hyprland` is Hyprland's recommended wrapper (watchdog + clean shutdown);
without it Hyprland logs a warning at every launch.

## 6. Monitors

`hypr/scripts/setup_monitors_by_serial.sh` identifies the two external panels
by EDID serial (`LXLEE0524282`, `PC3M665802149`) and pins them to absolute
positions, regardless of which DisplayLink port the dock assigned. If you
swap monitors, update the serials in that script.

`hypr/scripts/monitor_watcher.sh` listens to Hyprland's event socket and
re-runs the setup script whenever monitors are added or removed (KVM switching,
unplugging the dock, etc.). It also persists the workspace → monitor mapping
under `$XDG_STATE_HOME/hypr/` so workspaces return to the same physical screen
after a replug.

Both are launched as `exec-once` from `hypr/hyprland.conf`.

## 7. Power, audio, screenshots

| Action            | Command                          |
|-------------------|----------------------------------|
| Shutdown / reboot | `loginctl poweroff` / `loginctl reboot` (no sudo, elogind handles polkit) |
| Restart audio     | `SVDIR=~/.local/share/runit/sv sv restart pipewire wireplumber pipewire-pulse` |
| Screenshot        | `Print` → `grim -g "$(slurp)" \| wl-copy` |

The shutdown menu (`Super+V`) and `hypr/scripts/refresh_audio.sh` already use
these.

## 8. Verifying the install

```bash
# Hyprland sees evdi as a DRM card and the dock's panels are connected
ls /sys/class/drm/                       # should include card2-... entries
hyprctl monitors                          # should list eDP-1 + 2 dock panels

# User services running
SVDIR=~/.local/share/runit/sv sv status pipewire wireplumber pipewire-pulse rclone-bisync-arreglos

# DisplayLink daemon running
pgrep -a DisplayLinkManager
```

If `hyprctl monitors` only shows `eDP-1`, check:

1. `lsmod | grep evdi` — module loaded?
2. `pgrep -af DisplayLinkManager` — daemon up?
3. `sudo sv status displaylink` — service active?
4. `dmesg | grep -i evdi` — module errors?

The DisplayLink binary lives at `/usr/lib/displaylink/DisplayLinkManager` (not
`/usr/bin/`); the runit service `cd`s into that directory before exec because
the daemon loads firmware (`*.spkg`) by relative path.

## 9. One-time post-install fixes

### Disable the duplicate `logind` runit service

`elogind-runit` ships two service entries in `/etc/runit/sv/` (`elogind` and
`logind` — the latter is a symlink to the former). Both get linked into
`/etc/runit/runsvdir/default/`, so two supervisors race for the same daemon and
the loser respawns once a second forever, spamming `dmesg` with "elogind is
already running as PID …".

Remove the duplicate:

```bash
sudo rm /etc/runit/runsvdir/default/logind
# kill any orphan supervisor that runsvdir already forked:
sudo pkill -f "runsv logind"
```

A reboot also clears it (the symlink is gone, so `runsvdir` won't recreate it).

### GRUB default

If you dual-boot and Arch's GRUB is the bootloader on the ESP, set Artix as
the default from inside Arch (or a chroot from Artix):

```bash
# Arch root: /etc/default/grub must have GRUB_DEFAULT=saved
grub-set-default 'Artix Linux (on /dev/nvme0n1pX)'   # exact title from grub.cfg
grub-editenv list   # verify
```

Use `boot_arch` (in `~/.local/bin`) to one-shot reboot into Arch from Artix
without changing the default.

## 10. Boot benchmarking

`scripts/boot-bench` (`~/.local/bin/boot-bench` after install) prints a
post-login timeline of seconds-after-kernel-boot for:

- Long-running processes (Hyprland, waybar, swaync, awww-daemon, chromium…)
  via `/proc/<pid>/stat` start times
- runit user services via `supervise/status` mtimes
- runit system services (run with `sudo` to see all)

Use it to spot regressions when adding `exec-once` entries or runit services.
Pair with `sudo dmesg --time-format=reltime | head -100` for the kernel-side
timeline.
