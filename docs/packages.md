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
backticked package names (`` - `pkg1`, `pkg2` — prose ``). Backticks in the
prose after the em-dash are references, not packages.

A list too long for one line may wrap, but **only while the line ends in a
comma** — that trailing comma is the sole signal that the list continues. A
continuation line that starts with a backtick but follows a line ending in
prose is read as prose, not as packages. (Getting this wrong is not
theoretical: it silently dropped 4 of the 7 `texlive-*` collections.)

The parser lives in [`lib/packages.awk`](../lib/packages.awk) and is shared by
`install-packages.sh` and `install.sh --check`, so what gets installed and what
gets audited can never disagree.

To verify this file against reality, use the real parser — never a throwaway
`grep`, which is exactly how the wrapped-list bug went unnoticed:

```bash
bash install.sh --check          # full report, packages included
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

Power:

- `powertop` — diagnoses what is draining the battery (per-device wakeups and
  power states). Read-only inspection; the actual governor switching is
  `hypr/scripts/power_profile.sh` + `configs/sudoers.d/10-cpu-governor`

## Network

- `networkmanager`, `networkmanager-runit`
- `openssh`
- `cloudflared-bin` (AUR) — homelab tunnel client; `~/.ssh/config` routes
  `ssh.lab-ocp.com` and `git-ssh.lab-ocp.com` through it via `ProxyCommand`
- `nss` — provides `certutil`, which `install.sh` uses to trust the AutoFirma
  root CA in the LibreWolf profile. Pulled in as a dependency by every browser,
  but listed because the install step breaks without it
- `chrony`, `chrony-runit` — NTP client; nothing else disciplines the clock, so
  without it the laptop drifts (minutes per week). `install.sh --system`
  symlinks `configs/chrony.conf` to `/etc/chrony.conf` and activates the
  `chrony` runit service

## Bluetooth

Used by `scripts/bt-spotify-switch` and the lab Spotify auto-switch flow.

- `bluez`, `bluez-runit`, `bluez-utils`
- `blueman` — tray applet

## Audio

- `pipewire`, `pipewire-pulse`, `pipewire-alsa`, `pipewire-jack`, `wireplumber`
- `pavucontrol` — GUI mixer

`pipewire-alsa` redirects ALSA's `default` PCM through PipeWire. Without it,
ALSA-only apps (e.g. MuseScore AppImage) grab the hardware device directly and
never appear as streams in the mixer.

`pipewire-jack` conflicts with `jack2` and replaces it. Ardour links against
`libjack`; with real jack2 installed it starts its own JACK server and fights
PipeWire for the card.

## Music production

- `ardour` — DAW: multitrack recording, overdub, mixing, metronome
- `lsp-plugins`, `x42-plugins` — LV2 suites (parametric EQ, compressor, gate,
  tuner, meters)
- `realtime-privileges` — rtprio 98 / memlock limits for the audio engine
- `fmit` (AUR) — standalone chromatic instrument tuner

`realtime-privileges` drops limits in `/etc/security/limits.d/` that only apply
to members of the `realtime` group, added by `install.sh --system`. Without
them the engine loses cycles and drops out mid-take.

Launch Ardour via [`scripts/ardour`](../scripts/ardour), which restores the
short name (the binary is `ardour9`) and wraps it in `pw-jack -p 256` so the
graph quantum drops from 1024 (~45 ms round-trip, audible when overdubbing) to
256 (~12 ms) while it runs.

Ardour's `config` and `ui_config` are **copied** from `configs/ardour9/`, not
symlinked. Ardour saves via temp-file + rename, which replaces a symlink with a
real file — it silently detached itself once already, and the live file had
grown from 48 to 102 lines of window geometry by the time `--check` noticed.

So `install.sh` seeds them only when missing, and never overwrites what Ardour
has since written. To promote the live version back into the repo:

```bash
bash install.sh --capture     # copies live -> repo, then review the diff
git diff -- configs/ardour9/  # expect UI noise; commit only real settings
```

The rest of `~/.config/ardour9/` is cache (`plugin_metadata`, `sfdb`, `recent`)
and stays untracked.

### LV2 presets

`~/.lv2` is a symlink to `configs/lv2/`, so every preset bundle in there is
tracked — including ones Ardour saves itself, since that is where it writes.

`gaita-aire-libre.lv2` is a preset for the LSP Parametric Equalizer, built from
a measured 75 s sample of the punteiro played without the roncón (34.7 dB S/N).
The measurements behind each band are in the preset's comments.

An LV2 preset binds to a plugin URI, and LSP ships **12** equalizer variants
(x8/x16/x32 × mono/stereo/lr/ms) — a preset naming only one is invisible from
the other eleven. Since they share port symbols, the preset lists all twelve in
`lv2:appliesTo`. After editing a preset, check what a host will actually see
with [`scripts/lv2-presets`](../scripts/lv2-presets), which queries liblilv —
the same library Ardour uses — and so tells a broken bundle apart from a host
that cached an old plugin list:

```
lv2-presets para_equalizer      # all 12 variants, with their presets
```

Two things the profile assumes, both from that sample:

- **No roncón.** Below 400 Hz the sample was pure noise, so band 0 high-passes
  at 300 Hz. With a drone sounding, drop that to ~90 Hz or the roncón goes with
  it.
- **Punteiro in Do.** The fundamental measured 527 Hz (Do5, +13 cents).

## Printing

Driverless IPP queue for the network Epson ET-3850 — see
[`printing.md`](printing.md).

- `cups`, `cups-filters`, `cups-runit`

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
- `dosfstools` — `mkfs.fat` / `fsck.fat`. Needed to create the ESP during a
  from-scratch install (see [`bootstrap.md`](bootstrap.md)) and to repair FAT
  USB sticks that `udisks2` refuses to mount
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
- `gopls`, `gofumpt`, `go-tools` — Go LSP + formatters for nvim (`go-tools`
  provides `goimports`)
- `pgformatter` — provides `pg_format`, SQL formatter for nvim's
  format-on-save. Indent width comes from `configs/pg_format`, symlinked to
  `~/.pg_format`; a project `.pg_format` overrides it
- `uv` — Python package and project manager
- `tk` — Tcl/Tk toolkit, provides `tkinter` for Python GUIs
- `r` — R statistical computing language
- `rstudio-desktop-bin` (AUR) — R IDE
- `texlive-basic`, `texlive-latex`, `texlive-latexrecommended`,
  `texlive-latexextra`, `texlive-fontsrecommended`, `texlive-xetex`,
  `texlive-plaingeneric` — the LaTeX toolchain behind **PDF export**, used by
  `rmarkdown`/`knitr` in RStudio and by `jupyter-nbconvert --to pdf`. See
  [Why all seven](#why-all-seven-texlive-collections) below.
### Why all seven texlive collections

Arch splits TeX Live into collections, and "render a document to PDF" is not
one of them — both `rmarkdown` and `nbconvert` shell out to `pandoc`, which
generates LaTeX from a template and hands it to an engine. The template pulls
packages from across the split, so a partial install fails at *compile* time
with a `! LaTeX Error: File 'xxx.sty' not found`, long after everything looked
installed.

| Collection | What it provides here |
|---|---|
| `texlive-basic` | the TeX engine itself, `kpathsea`, `tlmgr` — nothing renders without it |
| `texlive-latex` | the LaTeX format and its core packages |
| `texlive-latexrecommended` | the packages pandoc's default template assumes exist (`booktabs`, `caption`, `hyperref`, …) |
| `texlive-latexextra` | the long tail the template also reaches for — `framed`, used by knitr for every shaded code chunk |
| `texlive-fontsrecommended` | Latin Modern and the standard font set the template selects |
| `texlive-xetex` | the **XeLaTeX** engine, which is pandoc's default PDF engine — needed for any non-ASCII character, so effectively every document in Spanish |
| `texlive-plaingeneric` | plain-TeX generic packages the template pulls in (`ulem`, for strikethrough) |

**Do not split this entry across lines carelessly.** It is the one multi-line
package list in this file, and it is what caught the parser bug fixed in
`lib/packages.awk`: only the first line was read, so a rebuilt machine got 3 of
the 7 and could not knit a single PDF — with no error until someone tried. The
parser now follows the wrap, but only while a line ends in a comma. Keep it
that way.

Verify a working install end to end rather than by package name:

```bash
echo 'test' | pandoc -o /tmp/t.pdf   # exits 0 and writes a PDF, or names the missing .sty
```

- `git`, `github-cli`
- `git-filter-repo` — history rewriting. Kept installed because this repo is
  mirrored to a public GitHub remote, so a credential committed by accident has
  to be purged from every commit, not just removed in a new one. The guard
  against needing it is the clean/smudge filter in
  [`printing.md`](printing.md#prusalink-password); this is the cleanup when the
  guard was not there yet
- `docker`, `docker-runit`, `docker-compose`, `docker-buildx` — container
  runtime + BuildKit CLI plugin. `install.sh --system` activates the `docker`
  runit service and adds the invoking user to the `docker` group

## CLI tooling

- `fd`, `fzf`, `ripgrep` — search
- `htop`, `ncdu`, `tree` — inspection
- `unzip` — `.zip` archive extraction
- `pgcli` — PostgreSQL client with autocompletion and syntax highlighting
- `pacman-contrib` — provides `pacdiff`, used by `shutdown.sh` both to list
  files pending a merge (`pacdiff -o`) and to merge them. The script falls
  back to listing `.pacnew` paths under `/etc` if it is missing.
- `fakeroot` (pulled in by `base-devel`/`yay`) — lets `shutdown.sh` sync repo
  databases into a private copy, so listing updates needs no password and the
  real database is never left in a partial-upgrade state.
- `python-pyotp` — TOTP code generation library
- `python-seaborn` — statistical data visualisation library
- `python-scipy` — scientific computing library (optimization, signal processing, stats)
- `marp-cli` (AUR: `marp-cli`) — Markdown to presentation slides converter (HTML/PDF/PPTX)

## Apps (AUR unless noted)

- `librewolf-bin` — daily browser, opened by `startup_apps.sh`
- Violentmonkey (LibreWolf add-on) — userscript manager; hosts `configs/uoc-aula-autosubmit.user.js` (submits the UOC Shibboleth login form on `id-provider.uoc.edu` once LibreWolf autofills it)
- `chromium` — lightweight Chromium for checking web rendering
- `firefox` — kept alongside LibreWolf as the stock-behaviour reference: when a
  site breaks, it tells you whether it is LibreWolf's hardening or the site
- `google-chrome` — the Blink build some sites (and DRM/proctoring flows)
  require and refuse to accept Chromium for
- `smowlcm` (AUR) — SMOWL proctoring client for UOC exams. Launched through
  `scripts/smowlcm-launch`, which clears the `Singleton*` locks it leaves
  behind when killed instead of closed — otherwise it refuses to start,
  mid-exam
- `discord` — voice/text chat
- `stremio-enhanced-bin` (AUR) — Stremio client with plugin/theme support
- `spotify` — runs on workspace 3
- `seafile` (AUR) — Seafile command-line sync client (`seaf-cli`)
- `musescore-bin` — sheet music editor
- `jre-openjdk` — Java runtime
- `jdk21-openjdk` — Java 21 development kit
- `android-tools` — standalone `adb`/`fastboot`/`mkbootimg` in `/usr/bin` (Arch
  `[extra]`). This is all you need to talk to a phone. The full Android SDK
  (`android-sdk`, `android-sdk-platform-tools`,
  `android-sdk-cmdline-tools-latest`) was **removed 2026-08-16**: its setup step
  assumed an `android-sdk` group the AUR package never creates, so it skipped
  silently on every run and no platform was ever installed. Reinstall those
  three and run `sdkmanager` by hand if you ever build Android apps
- `android-udev` — udev rules so non-root users (in `adbusers`) can reach connected devices
- `obsidian` — markdown notes / knowledge base (Arch `[extra]`). Moved off
  the AUR `obsidian-bin` **2026-08-31**: from 1.13.x the upstream `.deb`
  renamed its desktop entry to `md.obsidian.Obsidian.desktop`, so the
  PKGBUILD's `sed` on `obsidian.desktop` fails and `package_obsidian-bin()`
  aborts. The repo package tracks the same version and uses system
  `electron43` instead of a bundled one
- `openscad-git` — programmers' 3D CAD modeller. The BOSL2 library is vendored
  as a git submodule under `configs/OpenSCAD/libraries/BOSL2` and the whole
  `configs/OpenSCAD/libraries` dir is symlinked to
  `~/.local/share/OpenSCAD/libraries` by `install.sh`, so any `.scad` can
  `include <BOSL2/std.scad>`. `install.sh` runs `git submodule update --init`
  to populate it. To bump the pinned version:
  `git -C configs/OpenSCAD/libraries/BOSL2 pull` then commit the submodule.
- `orca-slicer-bin` (AUR) — 3D-print slicer (Bambu Studio / PrusaSlicer fork).
  User presets (migrated from PrusaSlicer) are tracked as native Orca JSON in
  `configs/OrcaSlicer/user/default/{machine,process,filament}/`, symlinked into
  `~/.config/OrcaSlicer/user/default/`. Each is named "personal-ender" and
  inherits the Creality Ender-3 0.4 system presets.
  Note: Orca loads `libwebkit2gtk-4.1`, so it inherits the `libjxl` 0.11 pin.
  `webkit2gtk-4.1` is held at 2.52.4 in `IgnorePkg` (see `configs/pacman.conf`)
  because 2.52.5 links `libjxl.so.0.12` and fails to load under the pin.
- `libreoffice-still` — office suite (stable branch)
- `python-pyqt6`, `python-pyqt6-webengine` — Qt6 Python bindings + WebEngine
  module
- `obs-studio` — screen/video capture and streaming
- `teams-for-linux` (AUR) — Microsoft Teams unofficial client
- `vlc` — multimedia player and framework
- `okular` — PDF viewer
- `zeal` — offline documentation browser (Dash-compatible docsets; Go, Rust, Python, etc.)
- `autofirma-bin` — Spanish gov e-signature client (FNMT/DNIe,
  XAdES/PAdES/CAdES); use the `-bin` AUR (official .deb repackaged) rather
  than `autofirma`, which the Xunta de Galicia sede rejects with `SAF_21`.
  Pulls `jdk17-openjdk` automatically (its launcher hardcodes Java 17). The
  `.desktop` override in `configs/applications/autofirma.desktop` injects
  `DISPLAY=:0` so the Swing GUI works when launched from Wayland clients
  (Librewolf passes only `WAYLAND_DISPLAY`, so AutoFirma dies with
  `HeadlessException`).

## Games

Launchers, plus the runtimes their games need.

- `prismlauncher` — Minecraft launcher with instance management
- `curseforge` (AUR) — CurseForge client, for Minecraft modpacks

## AUR helper

- `yay-bin`
- `debtap` (AUR) — converts `.deb` packages to Arch packages

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
