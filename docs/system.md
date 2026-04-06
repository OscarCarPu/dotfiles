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
| `git ai [hint]` | AI-assisted commit message generation with optional context hint. Blocks commits missing doc updates for user-facing changes. Use `-D` / `--no-doc-check` to skip the doc check. |

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

## File Manager Bookmarks

Custom sidebar locations (Dev, Edu) appear in both Dolphin and GTK file dialogs (Chrome save/open).

- `configs/user-places.xbel` → Dolphin sidebar and KDE/Qt dialogs
- `configs/gtk-3.0/bookmarks` → GTK dialogs (Chrome, Firefox, etc.)

To add a new location, edit both files.

## Bluetooth Spotify Auto-Switch

A background service that automatically routes Spotify audio to known Bluetooth speakers (VTIN R2, Royaler) when they connect.

- **Script**: `scripts/bt-spotify-switch` — listens for new PipeWire sinks via `pactl subscribe`, matches against known speaker MACs, and moves Spotify's sink-input
- **Service**: `~/.config/systemd/user/bt-spotify-switch.service` — starts on login, restarts on failure

### Adding a new speaker

Edit `scripts/bt-spotify-switch` and add the MAC address (underscores instead of colons) to the `KNOWN_SPEAKERS` array, then restart the service:

```bash
systemctl --user restart bt-spotify-switch
```

### Useful commands

| Command | Description |
|---|---|
| `journalctl --user -u bt-spotify-switch -f` | Watch live logs |
| `systemctl --user status bt-spotify-switch` | Check service status |
| `pactl list short sinks` | List available audio sinks |

### Things installed

- imagemagick: editing images
