[⬅ Back to main README](../README.md)

# Packages

Single source of truth for what should be installed on this machine. Other docs
(`system.md`, `desktop.md`, `workflow.md`) point here instead of duplicating
package lists.

To install everything in this file (skipping the "Base system" and "External
programs" sections), run `bash install-packages.sh` from the repo root. The
script bootstraps `yay` if missing, installs every listed package via
`yay -S --needed`, and finishes by installing the uv-managed Python tooling
(`pyright`, `ruff`) used by nvim.

Convention for parsers: a list item starts with one or more comma-separated
backticked package names (`- \`pkg1\`, \`pkg2\` — prose`). Backticks in the
prose after the em-dash are references, not packages.

To verify against reality:

```bash
diff <(pacman -Qqe | sort) <(grep -E '^- `[a-z]' docs/packages.md | sed 's/^- `//;s/`.*//' | sort -u)
```

## Base system

Provided by the Artix install medium. Listed here for completeness — not
managed by this repo.

- `base`
- `base-devel`
- `linux`
- `linux-firmware`
- `linux-headers` (also needed by `evdi-dkms`)
- `mkinitcpio`
- `runit`
- `sudo`
- `man-db`, `man-pages`
- `bash-completion`

## Hardware

Intel iGPU stack:

- `intel-ucode` — CPU microcode
- `intel-media-driver` — VAAPI for video decode
- `vulkan-intel`
- `intel-gpu-tools` — `intel_gpu_top` etc.

DisplayLink dock (AUR):

- `displaylink` — userspace `DisplayLinkManager` daemon
- `evdi-dkms` — DRM kernel module exposing dock panels as connectors

USB-Ethernet watchdog fix:

- `ethtool` — used by `configs/NetworkManager/dispatcher.d/10-eth-no-offloads`

## Network

- `networkmanager`, `networkmanager-runit`
- `openssh`
- `cloudflared-bin` (AUR) — homelab tunnel client

## Bluetooth

Used by `scripts/bt-spotify-switch` and the lab Spotify auto-switch flow.

- `bluez`, `bluez-runit`, `bluez-utils`
- `blueman` — tray applet

## Audio

- `pipewire`, `pipewire-pulse`, `pipewire-alsa`, `wireplumber`
- `pavucontrol` — GUI mixer

`pipewire-alsa` redirects ALSA's `default` PCM through PipeWire. Without it,
ALSA-only apps (e.g. MuseScore AppImage) grab the hardware device directly and
never appear as streams in the mixer.

## Wayland / Hyprland

- `hyprland`, `xdg-desktop-portal-hyprland`
- `waybar` — status bar
- `swaync` — notifications
- `wofi` — launcher and power menu UI
- `wlogout` — alt logout UI
- `kitty` — terminal
- `swaybg` — wallpaper backend
- `awww` — wallpaper rotator (runit `set-wallpaper` service uses it)
- `brightnessctl` — backlight control, called from waybar/keybinds
- `grim`, `slurp`, `wl-clipboard` — screenshot pipeline
- `cliphist` — clipboard history (paired with `wofi` via `SUPER + SHIFT + V`)
- `papirus-icon-theme` — vector icons used by GTK apps and wofi (set in `configs/gtk-3.0/settings.ini`)
- `socat`, `jq` — used by `monitor_watcher.sh` to consume Hyprland's event socket
- `elogind-runit` — `loginctl poweroff/reboot`, polkit, seat mgmt (pulls `elogind` as a dep)

## Storage

Removable-media stack. `udiskie` runs from Hyprland (`exec-once = udiskie
-a -n`) and uses `udisks2` over D-Bus to auto-mount USB drives on
hotplug; polkit grants the active-session user passwordless mount.
`gvfs` lets `thunar` show the mounts in its sidebar and handle trash.
The waybar `custom/usb` module (see `hypr/scripts/usb_status.sh`) is the
visible UI: shows a green button when something is mounted, left-click
unmounts all, right-click opens Thunar.

- `udisks2` — D-Bus mount service
- `udiskie` — auto-mount daemon (notifies on hotplug)
- `gvfs` — virtual filesystem layer for the file manager
- `thunar` — file manager

## Fonts

- `ttf-cascadia-code-nerd`
- `ttf-firacode-nerd`

## Editor / dev

- `neovim`, `vim`
- `tree-sitter-cli` — parser builds for Neovim
- `rustup` — Rust toolchain manager (installs `rustc`/`cargo`; required by
  `espup` for Xtensa toolchain). `install-packages.sh` runs `rustup default
  stable` to materialize the host toolchain
- `go` — Go toolchain
- `uv` — Python package and project manager
- `tk` — Tcl/Tk toolkit, provides `tkinter` for Python GUIs
- `r` — R statistical computing language
- `rstudio-desktop-bin` (AUR) — R IDE
- `git`, `github-cli`
- `docker`, `docker-runit`, `docker-compose`, `docker-buildx` — container
  runtime + BuildKit CLI plugin. `install.sh --system` activates the `docker`
  runit service and adds the invoking user to the `docker` group

## CLI tooling

- `fd`, `fzf`, `ripgrep` — search
- `htop`, `ncdu`, `tree` — inspection
- `unzip` — `.zip` archive extraction
- `pacman-contrib` — provides `pacdiff` for `.pacnew` merging inside
  `shutdown.sh`. The script falls back to listing `.pacnew` paths if it is
  missing.
- `python-pyotp` — TOTP code generation library

## Apps (AUR unless noted)

- `brave-bin` — daily browser, opened by `startup_apps.sh`
- `spotify` — runs on workspace 3
- `syncthing` — file sync
- `musescore-bin` — sheet music editor
- `jre-openjdk` — Java runtime
- `obsidian-bin` — markdown notes / knowledge base
- `openscad-git` — programmers' 3D CAD modeller
- `prusa-slicer` — 3D-print slicer (Arch `[extra]` repo, enabled via
  `artix-archlinux-support` in `configs/pacman.conf`); profiles tracked
  in `configs/PrusaSlicer/`
- `libreoffice-still` — office suite (stable branch)
- `python-pyqt6`, `python-pyqt6-webengine` — Qt6 Python bindings + WebEngine
  module
- `okular` — PDF viewer

## AUR helper

- `yay-bin`

## Flatpak

- `flatpak` — sandboxed-app package manager, used alongside pacman/AUR

## Image processing

- `imagemagick` — used by ad-hoc image edits (referenced from system docs)

## External programs (not via pacman)

Installed outside the package manager — excluded from the `pacman -Qqe` diff
above and skipped by `install-packages.sh`.

- `claude` — Claude Code CLI, lives at `~/.local/bin/claude`
- `bun` — JavaScript runtime, install via `curl -fsSL https://bun.sh/install | bash`
- `direnv` — per-directory env loader, install via
  `curl -sfL https://direnv.net/install.sh | bash`. Lands in `~/.bun/bin/direnv`.
  `bash/.bashrc` runs `eval "$(direnv hook bash)"`
- `pyright`, `ruff` — Python LSP + formatter for nvim. Installed by
  `install-packages.sh` via `uv tool install`. Pyright auto-detects the
  per-project `.venv` (see `nvim/lua/configs/python.lua`)
- `espup`, `espflash` — ESP32 toolchain installer + flasher. Installed by
  `install-packages.sh` via `cargo install --locked`. `install.sh --system`
  adds the invoking user to the `uucp` group for serial/USB access to
  connected chips
- `ibgateway` — IBKR IB Gateway, installed from the official installer at
  <https://www.interactivebrokers.com/en/trading/ibgateway-stable.php> into
  `~/Jts/ibgateway/1046`
