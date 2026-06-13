[⬅ Back to main README](../README.md)

# Seafile sync

Two-way file sync via `seaf-cli` to a self-hosted Seafile
(`cloud.lab-ocp.com`, behind Cloudflare). Replaced Syncthing. Package:
`seafile` (AUR). Libraries: `~/edu`, `~/docs`, `~/downloads`, `~/media`.

## Setup

```bash
yay -S seafile
cp configs/seafile-cli/credentials.example ~/.config/seafile-cli/credentials
chmod 600 ~/.config/seafile-cli/credentials   # fill in server/user/pass
bash install.sh && seafile-setup
```

`seafile-setup` inits the daemon, drops `seafile-ignore.txt` in each library,
and creates + syncs each folder (re-runnable). `seaf-cli status` to monitor.

## Gotchas

- **Cloudflare 403**: blocks `seaf-cli`'s `Python-urllib` UA. The
  `scripts/seaf-cli` wrapper (ahead of `/usr/bin` in PATH) re-runs it with a
  patched UA; the C daemon's own UA already passes.
- **Slow upload**: per-file overhead makes tiny files crawl, so the ignore
  excludes `.venv/`, `__pycache__/`, `target/`, `node_modules/`, etc. Only
  applies to not-yet-synced files — add before first sync.
- **Don't reorganize during the initial upload**: the daemon reverts local
  moves to match the in-progress server snapshot. Wait for `synchronized`.

## Moving files safely — `smv`

`smv SOURCE DEST` is a drop-in for `mv` inside synced libraries. The daemon
treats a plain `mv` as a delete + recreate, which can create conflict copies.
`smv` stops the daemon before the rename and restarts it on exit, so Seafile
sees a clean state.

```bash
smv ~/docs/old-name.md ~/docs/new-name.md   # same library
smv ~/docs/report.pdf ~/edu/report.pdf      # cross-library: daemon stopped for the move
```

If neither path is inside a synced library, `smv` falls back to a plain `mv`.
