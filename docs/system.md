[&#11013; Back to main README](../README.md)

# System description

## Git Workflow

Branches follow a three-tier model: `feature/*` → `develop` → `main`.

- **Feature branches** are where new work happens (`feature/my-thing`)
- **develop** is the integration branch — features land here
- **main** is production — only deploy from develop

### Commands

All three commands are available both as `git <cmd>` (via `git-<cmd>` scripts in PATH) and as explicit aliases in `~/.gitconfig`.

| Command | Description |
|---|---|
| `git finish-feature` | Merges current `feature/*` branch into `develop`, pushes, deletes branch locally and remotely |
| `git deploy` | Merges `develop` into `main`, pushes, returns to `develop` |
| `git ai [hint]` | AI-assisted commit message generation with optional context hint. Blocks commits missing doc updates for user-facing changes. |

#### `git ai` flags

| Flag | Description |
|---|---|
| `-A`, `--add` | Run `git add .` before committing |
| `-C`, `--check` | Run pre-commit hooks and doc check only — no commit is made. Pre-commit runs first, then doc check; both always run even if one fails |
| `-D`, `--no-doc-check` | Skip the documentation completeness check |
| `-Y`, `--auto-accept` | Auto-accept the commit message (skip editor) |
| `-P`, `--push` | Push to remote after committing |

Short flags can be combined (e.g., `-AC`, `-DAY`, `-APY`). Pre-commit hooks are skipped gracefully if no hook is configured.

### Aliases (`~/.gitconfig`)

```ini
[alias]
    ai = !git-ai
    finish-feature = !git-finish-feature
    deploy = !git-deploy
```

The `~/.gitconfig` is tracked in `git/.gitconfig` and symlinked by `install.sh`.

### Scripts

Scripts live in `scripts/` (symlinked to `~/.local/bin/`):

- `scripts/git-ai`
- `scripts/git-finish-feature`
- `scripts/git-deploy`

## Personal Makefile (`~/Makefile`)

Shortcuts for daily tasks (`make <target>` from `$HOME`). Sourced from
[`home/Makefile`](../home/Makefile) and symlinked by `install.sh`.

| Target | Action |
|---|---|
| `axeigo-forms-2026` | Run obradoiros forms generator with `uv` |
| `ssh-lab` | SSH into the lab box |
| `gv-api-pgcli` | Open `pgcli` against the gv-api DB through the lab box |
| `rescan-wifi` | `nmcli` Wi-Fi rescan |
| `wifi-oscar` | Rescan and connect to the `Oscar` SSID |

Add more targets directly in `home/Makefile`; the symlink picks them up.

## File Manager Bookmarks

Custom sidebar locations (Dev, Edu) appear in both Dolphin and GTK file dialogs (Chrome save/open).

- `configs/user-places.xbel` → Dolphin sidebar and KDE/Qt dialogs
- `configs/gtk-3.0/bookmarks` → GTK dialogs (Chrome, Firefox, etc.)

To add a new location, edit both files.

## Bluetooth Spotify Auto-Switch

`scripts/bt-spotify-switch` listens for new PipeWire sinks via `pactl subscribe`,
matches against known speaker MACs (`VTIN R2`, `Royaler`), and moves Spotify's
sink-input to that speaker as it connects.

It is a manual tool — run it from a terminal when you want it active:

```bash
bt-spotify-switch &
```

To wrap it as a runit user service, mirror one of the entries under
`runit/user/` and add the service name to `USER_RUNIT_SERVICES` in
[`install.sh`](../install.sh).

### Adding a new speaker

Edit `scripts/bt-spotify-switch` and add the MAC address (underscores instead
of colons) to the `KNOWN_SPEAKERS` array.

### Useful commands

| Command | Description |
|---|---|
| `pactl list short sinks` | List available audio sinks |
| `pactl list sink-inputs` | List active streams |

### Things installed

- imagemagick: editing images

## Boot timeline

`scripts/boot-bench` prints a per-process and per-service timeline relative to
kernel boot. Useful when adding/removing `exec-once` entries or tuning
`startup_apps.sh`.

```bash
boot-bench           # user processes + user runit services
sudo boot-bench      # also reads /run/runit/service/*/supervise/status
```

See [`docs/artix.md`](artix.md) for the full Artix bring-up and post-install
fixes (elogind dedup, GRUB default, DisplayLink activation).
