[⬅ Back to main README](../README.md)

# Packages

Single source of truth for what should be installed on this machine. Other docs
(`system.md`, `desktop.md`, `workflow.md`) point here instead of duplicating
package lists.

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

- `pipewire`, `pipewire-pulse`, `wireplumber`
- `pavucontrol` — GUI mixer

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

## Fonts

- `ttf-cascadia-code-nerd`
- `ttf-firacode-nerd`

## Editor / dev

- `neovim`, `vim`
- `tree-sitter-cli` — parser builds for Neovim
- `rust` — `rustc` + `cargo` toolchain
- `go` — Go toolchain
- `git`, `github-cli`

## CLI tooling

- `fd`, `fzf`, `ripgrep` — search
- `htop`, `ncdu`, `tree` — inspection
- `unzip` — `.zip` archive extraction
- `pacman-contrib` — *optional*. Provides `pacdiff` for `.pacnew` merging
  inside `shutdown.sh`. The script falls back to listing `.pacnew` paths if
  it is missing.

## Apps (AUR unless noted)

- `brave-bin` — daily browser, opened by `startup_apps.sh`
- `spotify` — runs on workspace 3
- `syncthing` — file sync
- `musescore-bin` — sheet music editor

## AUR helper

- `yay-bin`

## Image processing

- `imagemagick` — used by ad-hoc image edits (referenced from system docs)

## External programs (not via pacman)

Installed outside the package manager — excluded from the `pacman -Qqe` diff
above.

- `claude` — Claude Code CLI, lives at `~/.local/bin/claude`
- `bun` — JavaScript runtime, install via `curl -fsSL https://bun.sh/install | bash`
