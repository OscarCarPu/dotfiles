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

### Things installed

- imagemagick: editing images
