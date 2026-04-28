[⬅ Back to main README](../README.md)

# System layer

Everything below the desktop: kernel, hardware drivers, runit services,
network, bluetooth, GRUB, and the post-install fixes that have to land before
the rest of the stack works.

For the full package list see [`packages.md`](packages.md).
For Hyprland / Waybar / monitors / startup see [`desktop.md`](desktop.md).
For personal scripts (git, makefile, bt-spotify) see [`workflow.md`](workflow.md).

## 1. First-time bring-up

Install packages from [`packages.md`](packages.md), then:

```bash
git clone https://github.com/OscarCarPu/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
bash install.sh           # user symlinks
bash install.sh --system  # /etc symlinks (sudo)
```

This places everything from the [Symlink list](../README.md#symlink-list).

## 2. AUR helper

```bash
sudo pacman -S --needed base-devel git
git clone https://aur.archlinux.org/yay.git /tmp/yay && (cd /tmp/yay && makepkg -si)
```

## 3. runit services

### System (DisplayLink)

`install.sh --system` puts the service definition under
`/etc/runit/sv/displaylink`. Activate:

```bash
sudo ln -s /etc/runit/sv/displaylink /run/runit/service/      # now
sudo ln -s /etc/runit/sv/displaylink /etc/runit/runsvdir/default/   # on every boot
```

`evdi.conf` in `/etc/modules-load.d/` autoloads the `evdi` kernel module so
`DisplayLinkManager` finds it ready.

The DisplayLink binary lives at `/usr/lib/displaylink/DisplayLinkManager` (not
`/usr/bin/`); the runit service `cd`s into that directory before exec because
the daemon loads firmware (`*.spkg`) by relative path.

### User

`runsvdir` for the user is launched from `~/.bash_profile` inside the same
`dbus-run-session` as `start-hyprland`, so all user services inherit the
session DBus address. Defined under `runit/user/`:

| Service          | Purpose                                       |
|------------------|-----------------------------------------------|
| `pipewire`       | Audio server                                  |
| `wireplumber`    | PipeWire session manager (waits for socket)   |
| `pipewire-pulse` | PulseAudio compatibility layer                |
| `set-wallpaper`  | Rotates wallpaper every 180 s via `awww`      |
| `battery-notify` | Polls battery every 60 s, alerts via DBus     |
| `waybar`         | Status bar — waits for Wayland socket + Hyprland IPC, auto-restarts on crash |

`set-wallpaper` and `waybar` wait for the Wayland socket before doing
anything, so they can start before Hyprland and runit will keep retrying
until the compositor is up. `waybar` also waits for the Hyprland IPC
signature so the `hyprland/*` modules can find the socket.

Start them now without re-logging in:

```bash
SVDIR=~/.local/share/runit/sv sv up pipewire wireplumber pipewire-pulse set-wallpaper battery-notify waybar
```

Status / logs:

```bash
SVDIR=~/.local/share/runit/sv sv status pipewire wireplumber pipewire-pulse
tail -f ~/.local/share/runit/sv/pipewire/log/main/current
```

`hypr/scripts/refresh_audio.sh` (bound to KVM-switch flow) restarts the three
audio services via `sv restart`.

## 4. Login flow

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
cause of `wireplumber` / `pipewire-pulse` failing with "Failed to connect to
session bus" during the migration.)

`start-hyprland` is Hyprland's recommended wrapper (watchdog + clean
shutdown); without it Hyprland logs a warning at every launch.

## 5. Post-install fixes

These are one-time corrections on top of stock Artix.

### Disable the duplicate `logind` runit service

`elogind-runit` ships two service entries in `/etc/runit/sv/` (`elogind` and
`logind` — the latter is a symlink to the former). Both get linked into
`/etc/runit/runsvdir/default/`, so two supervisors race for the same daemon
on every cold boot.

```bash
sudo rm /etc/runit/runsvdir/default/logind
sudo pkill -f "runsv logind"
```

### `elogind` run script that respawns forever

Stock `/etc/runit/sv/elogind/run` does `exec /usr/lib/elogind/elogind`, but
the binary forks-and-detaches by default — so the foreground process exits,
runit respawns the script, the new instance bails out with `elogind is
already running as PID …`, and the loop repeats every second forever.

`install.sh --system` overrides that file with
[`runit/system-overrides/elogind-run`](../runit/system-overrides/elogind-run),
which starts elogind once and then blocks on the daemon's PID file, so runit
only respawns when the actual daemon dies.

After running `install.sh --system`, restart the supervisor once:

```bash
sudo sv restart elogind
```

A future `pacman -Syu` of `elogind-runit` may overwrite the file (or drop a
`.pacnew`). Re-run `install.sh --system` after such an update.

### eth0 (USB-dock) offload watchdog

USB-Ethernet adapters in DisplayLink-class docks (cdc_ncm + Realtek) hit
`NETDEV WATCHDOG: transmit queue 0 timed out` every ~30 s with default
offloads enabled. `install.sh --system` installs
[`configs/NetworkManager/dispatcher.d/10-eth-no-offloads`](../configs/NetworkManager/dispatcher.d/10-eth-no-offloads)
which turns them off via `ethtool -K` whenever an `eth*` interface comes up.

### GRUB default

If you dual-boot and Arch's GRUB is the bootloader on the ESP, set Artix as
the default from inside Arch (or a chroot from Artix):

```bash
# Arch root: /etc/default/grub must have GRUB_DEFAULT=saved
grub-set-default 'Artix Linux (on /dev/nvme0n1pX)'
grub-editenv list   # verify
```

Use `boot_arch` (in `~/.local/bin`) to one-shot reboot into Arch from Artix
without changing the default.

## 6. Verifying the install

```bash
# Hyprland sees evdi as a DRM card and the dock's panels are connected
ls /sys/class/drm/                       # should include card2-... entries
hyprctl monitors                         # should list eDP-1 + 2 dock panels

# User services running
SVDIR=~/.local/share/runit/sv sv status pipewire wireplumber pipewire-pulse set-wallpaper battery-notify

# DisplayLink daemon running
pgrep -a DisplayLinkManager
```

If `hyprctl monitors` only shows `eDP-1`, check:

1. `lsmod | grep evdi` — module loaded?
2. `pgrep -af DisplayLinkManager` — daemon up?
3. `sudo sv status displaylink` — service active?
4. `dmesg | grep -i evdi` — module errors?

## 7. Power / shutdown

| Action            | Command                          |
|-------------------|----------------------------------|
| Shutdown / reboot | `loginctl poweroff` / `loginctl reboot` (no sudo, elogind handles polkit) |
| Restart audio     | `SVDIR=~/.local/share/runit/sv sv restart pipewire wireplumber pipewire-pulse` |

The desktop's Super+V power menu and `hypr/scripts/refresh_audio.sh` use
these. See [`desktop.md`](desktop.md) for the menu itself.
