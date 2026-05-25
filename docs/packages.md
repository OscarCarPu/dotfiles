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
- `inotify-tools` — filesystem watcher; used by the `obsidian-theme` runit service to auto-apply Nord theme and plugins to new vaults
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
- `texlive-basic`, `texlive-latex`, `texlive-latexrecommended`,
  `texlive-latexextra`, `texlive-fontsrecommended`, `texlive-xetex`,
  `texlive-plaingeneric` — LaTeX engine + collections needed by
  `rmarkdown`/`knitr` to knit PDFs from R
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
- `python-seaborn` — statistical data visualisation library
- `python-scipy` — scientific computing library (optimization, signal processing, stats)
- `marp-cli` (AUR: `marp-cli`) — Markdown to presentation slides converter (HTML/PDF/PPTX)

## Apps (AUR unless noted)

- `librewolf-bin` — daily browser, opened by `startup_apps.sh`
- `chromium` — lightweight Chromium for checking web rendering
- `spotify` — runs on workspace 3
- `syncthing` — file sync
- `musescore-bin` — sheet music editor
- `jre-openjdk` — Java runtime
- `jdk21-openjdk` — Java 21 development kit
- `android-sdk`, `android-sdk-platform-tools`, `android-sdk-cmdline-tools-latest` — Android SDK + `adb`/`fastboot` + `sdkmanager`
- `android-tools` — standalone `adb`/`fastboot`/`mkbootimg` in `/usr/bin` (Arch `[extra]`)
- `android-udev` — udev rules so non-root users (in `adbusers`) can reach connected devices
- `obsidian-bin` — markdown notes / knowledge base
- `openscad-git` — programmers' 3D CAD modeller
- `prusa-slicer` — 3D-print slicer (Arch `[extra]` repo, enabled via
  `artix-archlinux-support` in `configs/pacman.conf`); profiles tracked
  in `configs/PrusaSlicer/`
- `libreoffice-still` — office suite (stable branch)
- `python-pyqt6`, `python-pyqt6-webengine` — Qt6 Python bindings + WebEngine
  module
- `obs-studio` — screen/video capture and streaming
- `okular` — PDF viewer
- `autofirma-bin` — Spanish gov e-signature client (FNMT/DNIe,
  XAdES/PAdES/CAdES); use the `-bin` AUR (official .deb repackaged) rather
  than `autofirma`, which the Xunta de Galicia sede rejects with `SAF_21`.
  Pulls `jdk17-openjdk` automatically (its launcher hardcodes Java 17). The
  `.desktop` override in `configs/applications/autofirma.desktop` injects
  `DISPLAY=:0` so the Swing GUI works when launched from Wayland clients
  (Librewolf passes only `WAYLAND_DISPLAY`, so AutoFirma dies with
  `HeadlessException`).

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
- `sqlc` — generates type-safe Go from SQL. Installed by `install-packages.sh`
  via `go install github.com/sqlc-dev/sqlc/cmd/sqlc@latest`. Lands in
  `~/go/bin`, which `bash/.bashrc` adds to `PATH`
- `ibgateway` — IBKR IB Gateway, installed from the official installer at
  <https://www.interactivebrokers.com/en/trading/ibgateway-stable.php> into
  `~/Jts/ibgateway/1046`

## Python notebooks

Classic Jupyter Notebook (`.ipynb` in the browser) is not installed
globally — each project gets its own copy in the venv. Server, kernel, and
project deps share one Python, so there's no `JUPYTER_PATH` or kernelspec
wiring to maintain:

```bash
cd project/                       # contains notebook.ipynb, data/
uv venv
source .venv/bin/activate
uv pip install notebook pandas    # + whatever the notebook needs
jupyter notebook notebook.ipynb   # cwd = project, so data/foo.csv resolves
```

To re-enter later: `source .venv/bin/activate && jupyter notebook …` —
deps persist in `.venv/`.
