[⬅ Back to main README](../README.md)

# Seafile sync

Two-way file sync via `seaf-cli` to a self-hosted Seafile
(`cloud.lab-ocp.com`, behind Cloudflare). Replaced Syncthing. Package:
`seafile` (AUR).

Libraries are listed in
[`configs/seafile-cli/libraries`](../configs/seafile-cli/libraries) — currently
`~/edu`, `~/docs`, `~/downloads`, `~/media` (~26 GB). That file is the single
source of truth: both `seafile-setup` and the `seafile-watch` service read it,
so adding a line and re-running `seafile-setup` is the whole procedure.

`~/dev` is deliberately **not** synced — those are git repos, backed by Gitea
and GitHub. `install.sh --check` flags any repo there without a remote.

## Setup

```bash
yay -S seafile
cp configs/seafile-cli/credentials.example ~/.config/seafile-cli/credentials
chmod 600 ~/.config/seafile-cli/credentials   # fill in server/user/pass
bash install.sh && seafile-setup
```

`seafile-setup` inits the daemon, drops `seafile-ignore.txt` in each library,
and creates + syncs each folder (re-runnable). `seaf-cli status` to monitor.

## Monitoring — `seafile-watch`

The `seafile` service restarts a dead daemon every 30 s and says nothing, and
`seaf-cli` never complains on its own. So a library that stops syncing is
silent, and 26 GB quietly stops being backed up. The `seafile-watch` user runit
service ([`hypr/scripts/seafile_watch.sh`](../hypr/scripts/seafile_watch.sh))
polls every 5 min and sends a **critical** desktop notification when:

| Condition | Grace period |
|---|---|
| daemon unreachable | none |
| a library from `libraries` is absent from `seaf-cli status` | none |
| a library stuck in a non-`synchronized` state | 30 min |

The 30-minute window is deliberate: `uploading` / `committing` / `downloading`
are normal for minutes at a time, and alerting on them would train you to
ignore the notification. Each episode alerts **once**, and you get a
recovery notice when it clears.

```bash
SVDIR=~/.local/share/runit/sv sv status seafile-watch
tail -f ~/.local/share/runit/sv/seafile-watch/log/main/current
```

Tunable via env in the service's `run`: `SEAFILE_STALE_AFTER` (seconds),
`SEAFILE_LIB_LIST`, `SEAFILE_WATCH_STATE`.

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
