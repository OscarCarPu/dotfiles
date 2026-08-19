#!/bin/bash

# User-level symlinks (config files and dirs)
declare -A DOTFILES=(
    ["bash/.bash_profile"]="$HOME/.bash_profile"
    ["bash/.bashrc"]="$HOME/.bashrc"
    ["home/Makefile"]="$HOME/Makefile"
    ["hypr"]="$HOME/.config/hypr"
    ["nvim"]="$HOME/.config/nvim"
    ["kitty/kitty.conf"]="$HOME/.config/kitty/kitty.conf"
    ["ssh/config"]="$HOME/.ssh/config"
    ["waybar"]="$HOME/.config/waybar"
    ["wofi"]="$HOME/.config/wofi"
    ["swaync"]="$HOME/.config/swaync"
    ["wireplumber"]="$HOME/.config/wireplumber"
    ["git/.gitconfig"]="$HOME/.gitconfig"
    ["configs/user-places.xbel"]="$HOME/.local/share/user-places.xbel"
    ["configs/user-dirs.dirs"]="$HOME/.config/user-dirs.dirs"
    ["configs/mimeapps.list"]="$HOME/.config/mimeapps.list"
    ["configs/sqlfluff"]="$HOME/.sqlfluff"
    ["configs/gtk-3.0/bookmarks"]="$HOME/.config/gtk-3.0/bookmarks"
    ["configs/gtk-3.0/settings.ini"]="$HOME/.config/gtk-3.0/settings.ini"
    ["configs/OrcaSlicer/user/default/filament"]="$HOME/.config/OrcaSlicer/user/default/filament"
    ["configs/OrcaSlicer/user/default/machine"]="$HOME/.config/OrcaSlicer/user/default/machine"
    ["configs/OrcaSlicer/user/default/process"]="$HOME/.config/OrcaSlicer/user/default/process"
    ["configs/OpenSCAD/libraries"]="$HOME/.local/share/OpenSCAD/libraries"
    # Whole dir, not per-bundle: any new .lv2 preset bundle dropped in here
    # (or saved by Ardour, which writes to ~/.lv2) is tracked automatically.
    ["configs/lv2"]="$HOME/.lv2"
    # NOTE: Ardour's config is NOT here — it is seeded, not symlinked. See
    # SEED_FILES below.
    ["configs/applications/autofirma.desktop"]="$HOME/.local/share/applications/autofirma.desktop"
    ["configs/applications/nvim-kitty.desktop"]="$HOME/.local/share/applications/nvim-kitty.desktop"
    ["configs/applications/ardour9.desktop"]="$HOME/.local/share/applications/ardour9.desktop"
    ["claude/skills"]="$HOME/.claude/skills"
    ["claude/settings.json"]="$HOME/.claude/settings.json"
    ["claude/statusline.sh"]="$HOME/.claude/statusline.sh"
    ["configs/librewolf.overrides.cfg"]="$HOME/.librewolf/librewolf.overrides.cfg"
)

# Files COPIED rather than symlinked, because the app rewrites them with
# temp-file + rename — which replaces a symlink with a real file and silently
# detaches it from this repo (Ardour did exactly that between 2026-08-15 and
# 2026-08-16, and the live file had grown 48 -> 102 lines of window geometry).
#
# Seeded only when the target is missing, so a re-run never clobbers settings
# you changed in the app. To promote the live version back into the repo after
# tuning something worth keeping:
#
#   bash install.sh --capture
#
# which copies target -> repo so you can review the diff and commit the parts
# you want. Expect UI noise (window positions, recent files) in that diff.
declare -A SEED_FILES=(
    ["configs/ardour9/config"]="$HOME/.config/ardour9/config"
    ["configs/ardour9/ui_config"]="$HOME/.config/ardour9/ui_config"
)

# User-level runit services. Only `run` and `log/run` are symlinked into each
# service dir so that runtime state (supervise/, log/main/) lives outside the repo.
USER_RUNIT_SERVICES=(
    pipewire
    wireplumber
    pipewire-pulse
    set-wallpaper
    battery-notify
    waybar
    obsidian-theme
    seafile
    seafile-watch
)

# System-level files (require sudo). Run with --system flag to apply.
declare -A SYSTEM_DOTFILES=(
    ["configs/sysctl.d/90-disable-ipv6.conf"]="/etc/sysctl.d/90-disable-ipv6.conf"
    ["configs/modules-load.d/evdi.conf"]="/etc/modules-load.d/evdi.conf"
    ["configs/NetworkManager/dispatcher.d/10-eth-no-offloads"]="/etc/NetworkManager/dispatcher.d/10-eth-no-offloads"
    ["configs/udev/rules.d/50-dock-usb-no-autosuspend.rules"]="/etc/udev/rules.d/50-dock-usb-no-autosuspend.rules"
    ["runit/system-overrides/elogind-run"]="/etc/runit/sv/elogind/run"
    ["runit/system-overrides/agetty-tty1-conf"]="/etc/runit/sv/agetty-tty1/conf"
    ["configs/pacman.conf"]="/etc/pacman.conf"
    ["configs/chrony.conf"]="/etc/chrony.conf"
)

# Sudoers drop-ins. Cannot be symlinked — sudo refuses files not owned by
# root with mode > 0440, and validation walks symlinks to the target.
declare -A SYSTEM_SUDOERS=(
    ["configs/sudoers.d/10-cpu-governor"]="/etc/sudoers.d/10-cpu-governor"
)

# System-level runit services (require sudo). Symlinked into /etc/runit/sv/.
# Use this for services whose run script lives in this repo
# (`runit/system/<svc>/run`).
SYSTEM_RUNIT_SERVICES=(
    displaylink
)

# System-level runit services to activate at boot. Each entry is symlinked
# from /etc/runit/runsvdir/current/<svc> -> /etc/runit/sv/<svc>. Use this for
# both repo-provided services (above) and package-provided services
# (e.g. docker-runit ships /etc/runit/sv/docker).
SYSTEM_RUNIT_ACTIVATE=(
    displaylink
    docker
    chrony
    bluetoothd
    cupsd
)

# Groups the invoking user (`$SUDO_USER`) should belong to. Applied in
# --system mode via `gpasswd -a` (idempotent).
SYSTEM_GROUPS=(
    docker
    uucp
    adbusers
    realtime
)

DOTFILES_DIR=$(pwd)

if [ "$DOTFILES_DIR" != "$HOME/.dotfiles" ]; then
    echo "Dotfiles are not on .dotfiles, you are in $DOTFILES_DIR"
    read -p "Continue? [y/N] " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || exit 1
fi

# --- helpers --------------------------------------------------------------

link_file() {
    local src="$1" target="$2"
    mkdir -p "$(dirname "$target")"
    if [ -L "$target" ]; then
        # A symlink carries no data of its own — safe to replace outright.
        rm -f "$target"
    elif [ -e "$target" ]; then
        # A real file or directory is somebody's data: an app's presets, a
        # config written before this repo existed. `rm -rf` here is the one way
        # this script can destroy something unrecoverable (first run on a
        # machine that already has ~/.lv2 presets or OrcaSlicer profiles), so
        # move it aside instead and let the user decide.
        local backup="$target.pre-dotfiles.$(date +%Y%m%d%H%M%S)"
        echo " Backing up existing: $target -> $backup"
        mv "$target" "$backup"
    fi
    echo " Symlinking: $src -> $target"
    ln -sf "$src" "$target"
}

sudo_link_file() {
    local src="$1" target="$2"
    sudo mkdir -p "$(dirname "$target")"
    if sudo test -e "$target" || sudo test -L "$target"; then
        echo " Removing existing: $target"
        sudo rm -rf "$target"
    fi
    echo " Symlinking (sudo): $src -> $target"
    sudo ln -sf "$src" "$target"
}

sudo_install_sudoers() {
    local src="$1" target="$2"
    sudo mkdir -p "$(dirname "$target")"
    echo " Installing (sudo, 0440 root): $src -> $target"
    sudo install -m 0440 -o root -g root "$src" "$target"
    sudo visudo -cf "$target" >/dev/null
}

# --- capture mode -------------------------------------------------------------
# The reverse of seeding: pull an app-owned config back into the repo so its
# changes can be reviewed and committed. Never runs automatically — the live
# file carries UI state you usually do not want tracked.

if [ "${1:-}" = "--capture" ]; then
    for src in "${!SEED_FILES[@]}"; do
        target="${SEED_FILES[$src]}"
        [ -f "$target" ] || { echo " Skipping $src: $target does not exist"; continue; }
        echo " Capturing: $target -> $src"
        cp "$target" "$DOTFILES_DIR/$src"
    done
    echo
    echo "Review before committing — the live files carry window geometry:"
    echo "  git -C $DOTFILES_DIR diff -- configs/"
    exit 0
fi

# --- check mode -------------------------------------------------------------
# Read-only drift report: everything this repo claims to govern, verified
# against the machine. The repo is additive — it links what it declares and
# never notices what it stopped declaring, or what was installed behind its
# back — so without this the two silently diverge. Exits non-zero on drift so
# it can gate a script.

if [ "${1:-}" = "--check" ]; then
    drift=0
    section() { printf '\n\033[1m%s\033[0m\n' "$1"; }
    ok() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
    bad()  { printf '  \033[31m✗\033[0m %s\n' "$1"; drift=$((drift + 1)); }
    warn() { printf '  \033[33m!\033[0m %s\n' "$1"; drift=$((drift + 1)); }

    section "User symlinks"
    missing=0
    for src in "${!DOTFILES[@]}"; do
        target="${DOTFILES[$src]}"
        want="$DOTFILES_DIR/$src"
        if [ ! -L "$target" ]; then
            bad "$target is not a symlink (expected -> $want)"
            missing=$((missing + 1))
        elif [ "$(readlink "$target")" != "$want" ]; then
            bad "$target -> $(readlink "$target") (expected $want)"
            missing=$((missing + 1))
        elif [ ! -e "$target" ]; then
            bad "$target is a broken symlink"
            missing=$((missing + 1))
        fi
    done
    [ "$missing" -eq 0 ] && ok "${#DOTFILES[@]} entries linked"

    section "Seeded config files"
    before=$drift
    for src in "${!SEED_FILES[@]}"; do
        target="${SEED_FILES[$src]}"
        if [ ! -e "$target" ]; then
            bad "$target missing (run: bash install.sh)"
        elif [ -L "$target" ]; then
            bad "$target is a symlink — should be a real copy (run: bash install.sh)"
        elif ! cmp -s "$target" "$DOTFILES_DIR/$src"; then
            # Expected and harmless: the app has been running. Informational
            # only, so it does not count as drift.
            printf '  \033[2m·\033[0m %s differs from the repo (bash install.sh --capture to save)\n' "$target"
        fi
    done
    [ "$drift" -eq "$before" ] && ok "${#SEED_FILES[@]} files seeded as real copies"

    section "Scripts in ~/.local/bin"
    missing=0
    for script in "$DOTFILES_DIR/scripts"/*; do
        [ -e "$script" ] || continue
        target="$HOME/.local/bin/$(basename "$script")"
        if [ ! -L "$target" ] || [ "$(readlink "$target")" != "$script" ]; then
            bad "$(basename "$script") not linked into ~/.local/bin"
            missing=$((missing + 1))
        fi
    done
    [ "$missing" -eq 0 ] && ok "all scripts linked"

    section "User runit services"
    svdir="$HOME/.local/share/runit/sv"
    before=$drift
    for svc in "${USER_RUNIT_SERVICES[@]}"; do
        if [ ! -e "$svdir/$svc/run" ]; then
            bad "$svc declared but not installed"
        elif ! SVDIR="$svdir" sv status "$svc" 2>/dev/null | grep -q '^run:'; then
            bad "$svc is not running: $(SVDIR="$svdir" sv status "$svc" 2>&1 | head -1)"
        fi
    done
    for dir in "$svdir"/*/; do
        [ -d "$dir" ] || continue
        svc=$(basename "$dir")
        declared=0
        for d in "${USER_RUNIT_SERVICES[@]}"; do [ "$d" = "$svc" ] && declared=1; done
        # Orphan: install.sh created it, then the declaration went away. runit
        # keeps supervising it forever.
        [ "$declared" -eq 0 ] && warn "$svc is installed but no longer declared (--prune removes it)"
    done
    [ "$drift" -eq "$before" ] && ok "${#USER_RUNIT_SERVICES[@]} services installed and running"

    section "System files"
    for src in "${!SYSTEM_DOTFILES[@]}"; do
        target="${SYSTEM_DOTFILES[$src]}"
        want="$DOTFILES_DIR/$src"
        [ -L "$target" ] && [ "$(readlink "$target")" = "$want" ] ||
            bad "$target not linked to $want (run: bash install.sh --system)"
    done
    # /etc/sudoers.d is 0750 root:root, so a plain test always fails as a
    # normal user. Only report when passwordless sudo can actually look.
    for src in "${!SYSTEM_SUDOERS[@]}"; do
        target="${SYSTEM_SUDOERS[$src]}"
        if sudo -n true 2>/dev/null; then
            sudo -n test -e "$target" || bad "$target missing"
        else
            printf '  \033[2m·\033[0m %s (needs sudo to verify)\n' "$target"
        fi
    done
    for svc in "${SYSTEM_RUNIT_ACTIVATE[@]}"; do
        [ -e "/etc/runit/runsvdir/default/$svc" ] ||
            bad "$svc not activated in /etc/runit/runsvdir/default"
    done
    [ -e /etc/runit/runsvdir/default/logind ] &&
        bad "duplicate logind service present (run: bash install.sh --system)"

    section "Groups"
    before=$drift
    for grp in "${SYSTEM_GROUPS[@]}"; do
        if ! getent group "$grp" >/dev/null; then
            warn "group $grp does not exist (package not installed?)"
        elif ! id -nG "$USER" | tr ' ' '\n' | grep -qx "$grp"; then
            bad "$USER not in group $grp (run: bash install.sh --system, then re-login)"
        fi
    done
    [ "$drift" -eq "$before" ] && ok "member of all ${#SYSTEM_GROUPS[@]} groups"

    section "Packages"
    pkgs_md="$DOTFILES_DIR/docs/packages.md"
    declared=$(mktemp) && unmanaged=$(mktemp) && installed=$(mktemp)
    trap 'rm -f "$declared" "$unmanaged" "$installed"' EXIT
    awk -f "$DOTFILES_DIR/lib/packages.awk" "$pkgs_md" | sort -u >"$declared"
    awk -v want_unmanaged=1 -f "$DOTFILES_DIR/lib/packages.awk" "$pkgs_md" | sort -u >"$unmanaged"
    pacman -Qqe | sort -u >"$installed"

    undocumented=$(comm -23 "$installed" <(sort -u "$declared" "$unmanaged"))
    if [ -n "$undocumented" ]; then
        warn "installed explicitly but not in packages.md — a rebuild would not get these:"
        printf '      %s\n' $undocumented
    fi
    # Declared-but-absent is only real drift when nothing provides it at all:
    # plenty of entries are pulled in as dependencies rather than explicitly.
    while read -r p; do
        [ -n "$p" ] && ! pacman -Qq "$p" >/dev/null 2>&1 &&
            bad "declared in packages.md but not installed: $p"
    done <"$declared"
    [ -z "$undocumented" ] && ok "$(wc -l <"$declared") declared packages accounted for"

    section "Credential filters"
    if [ "$(git -C "$DOTFILES_DIR" config --get filter.orcasecret.clean)" ]; then
        staged=$(git -C "$DOTFILES_DIR" show \
            ":configs/OrcaSlicer/user/default/machine/core-one.json" 2>/dev/null |
            grep -c 'printhost_password": "[^"]' || true)
        [ "${staged:-0}" -eq 0 ] && ok "orcasecret filter active, no credential in the index" ||
            bad "a credential is staged in an OrcaSlicer preset"
    else
        bad "orcasecret git filter not registered (run: bash install.sh)"
    fi
    [ -f "$HOME/.config/dotfiles/secrets.env" ] ||
        bad "$HOME/.config/dotfiles/secrets.env missing"

    section "File sync"
    lib_list="$DOTFILES_DIR/configs/seafile-cli/libraries"
    if ! sync_status=$(timeout 30 seaf-cli status 2>/dev/null); then
        bad "seaf-cli status failed — daemon down?"
    else
        while read -r lib; do
            [ -z "$lib" ] && continue
            line=$(printf '%s\n' "$sync_status" | grep -E "^$lib[[:space:]]" || true)
            if [ -z "$line" ]; then
                bad "library '$lib' is not being synced"
            elif ! printf '%s' "$line" | grep -q 'synchronized'; then
                warn "library '$lib': $(printf '%s' "$line" | awk '{print $2}')"
            fi
        done < <(sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$lib_list" | grep -v '^$')
        ok "$(printf '%s\n' "$sync_status" | grep -c synchronized) libraries synchronized"
    fi

    section "Git repos in ~/dev"
    # Not synced by Seafile on purpose — the remote IS the backup. So a repo
    # without one, or with work that never left the machine, has no backup.
    found=0
    while read -r gitdir; do
        repo="${gitdir%/.git}"
        rel="${repo#"$HOME"/}"
        if ! git -C "$repo" remote get-url origin >/dev/null 2>&1; then
            bad "$rel has no remote — it exists only on this disk"
            found=1
            continue
        fi
        unpushed=$(git -C "$repo" log --branches --not --remotes --oneline 2>/dev/null | wc -l)
        dirty=$(git -C "$repo" status --porcelain 2>/dev/null | wc -l)
        [ "$unpushed" -gt 0 ] && { warn "$rel has $unpushed unpushed commit(s)"; found=1; }
        [ "$dirty" -gt 0 ] && { warn "$rel has $dirty uncommitted change(s)"; found=1; }
    done < <(find "$HOME/dev" -maxdepth 4 -name .git -type d 2>/dev/null)
    [ "$found" -eq 0 ] && ok "every repo has a remote and is fully pushed"

    section "Stale links"
    stale=$(find "$HOME" "$HOME/.config" "$HOME/.local/share" "$HOME/.local/bin" \
        -maxdepth 2 -xtype l 2>/dev/null |
        while read -r l; do
            case "$(readlink "$l")" in "$DOTFILES_DIR"*) echo "$l" ;; esac
        done)
    if [ -n "$stale" ]; then
        warn "broken symlinks pointing into the repo (--prune removes them):"
        printf '      %s\n' $stale
    else
        ok "no broken links into the repo"
    fi

    printf '\n'
    if [ "$drift" -eq 0 ]; then
        printf '\033[32mNo drift: the machine matches the repo.\033[0m\n'
        exit 0
    fi
    printf '\033[33m%d item(s) of drift.\033[0m\n' "$drift"
    exit 1
fi

# --- prune mode -------------------------------------------------------------
# Removes what the repo stopped declaring. Only touches things install.sh
# itself created: user services and symlinks pointing into this directory.

if [ "${1:-}" = "--prune" ]; then
    svdir="$HOME/.local/share/runit/sv"
    for dir in "$svdir"/*/; do
        [ -d "$dir" ] || continue
        svc=$(basename "$dir")
        declared=0
        for d in "${USER_RUNIT_SERVICES[@]}"; do [ "$d" = "$svc" ] && declared=1; done
        [ "$declared" -eq 1 ] && continue
        echo "Removing undeclared user service: $svc"
        SVDIR="$svdir" sv down "$svc" >/dev/null 2>&1 || true
        sleep 1
        rm -rf "${svdir:?}/$svc"
    done

    find "$HOME" "$HOME/.config" "$HOME/.local/share" "$HOME/.local/bin" \
        -maxdepth 2 -xtype l 2>/dev/null |
        while read -r l; do
            case "$(readlink "$l")" in
            "$DOTFILES_DIR"*)
                echo "Removing broken link: $l -> $(readlink "$l")"
                rm -f "$l"
                ;;
            esac
        done

    echo "Done (prune). Run 'bash install.sh --check' to confirm."
    exit 0
fi

# --- system mode ----------------------------------------------------------

if [ "${1:-}" = "--system" ]; then
    echo "Installing system files (sudo)..."
    for src in "${!SYSTEM_DOTFILES[@]}"; do
        sudo_link_file "$DOTFILES_DIR/$src" "${SYSTEM_DOTFILES[$src]}"
    done

    echo "Installing sudoers drop-ins (sudo)..."
    for src in "${!SYSTEM_SUDOERS[@]}"; do
        sudo_install_sudoers "$DOTFILES_DIR/$src" "${SYSTEM_SUDOERS[$src]}"
    done

    echo "Installing system runit services (sudo)..."
    for svc in "${SYSTEM_RUNIT_SERVICES[@]}"; do
        target="/etc/runit/sv/$svc"
        sudo mkdir -p "$target/log"
        sudo_link_file "$DOTFILES_DIR/runit/system/$svc/run"     "$target/run"
        sudo_link_file "$DOTFILES_DIR/runit/system/$svc/log/run" "$target/log/run"
    done

    echo "Activating system runit services (sudo)..."
    for svc in "${SYSTEM_RUNIT_ACTIVATE[@]}"; do
        if [ ! -d "/etc/runit/sv/$svc" ]; then
            echo " Skipping $svc: /etc/runit/sv/$svc missing (install the package?)"
            continue
        fi
        sudo_link_file "/etc/runit/sv/$svc" "/etc/runit/runsvdir/current/$svc"
    done

    target_user="${SUDO_USER:-$USER}"
    if [ -n "$target_user" ] && [ "$target_user" != "root" ]; then
        echo "Adding $target_user to system groups (sudo)..."
        for grp in "${SYSTEM_GROUPS[@]}"; do
            if ! getent group "$grp" >/dev/null; then
                echo " Skipping $grp: group does not exist (install the package?)"
                continue
            fi
            echo " gpasswd -a $target_user $grp"
            sudo gpasswd -a "$target_user" "$grp" >/dev/null
        done
    else
        echo "Skipping group setup: no non-root invoking user (set SUDO_USER)."
    fi

    # elogind-runit ships two service entries for the same daemon (`elogind`
    # and `logind`, the latter a symlink to the former) and both get linked
    # into runsvdir, so two supervisors race for it on every cold boot. A
    # package update can relink it, so this runs on every --system pass.
    if [ -e /etc/runit/runsvdir/default/logind ]; then
        echo "Removing duplicate logind service (races with elogind)..."
        sudo rm -f /etc/runit/runsvdir/default/logind
        sudo pkill -f "runsv logind" || true
    fi

    echo "Reloading udev rules (sudo)..."
    sudo udevadm control --reload-rules
    sudo udevadm trigger

    echo "Done (system)."
    exit 0
fi

# --- user mode (default) --------------------------------------------------

# Pull in vendored git submodules (e.g. BOSL2 for OpenSCAD, symlinked below).
echo "Updating git submodules..."
git -C "$DOTFILES_DIR" submodule update --init --recursive

# --- local secrets + git credential filters -------------------------------
# Some tracked configs are symlinked live into an app's config dir, so the file
# the app reads and writes IS the repo file — a credential in it would be
# committed. `.gitattributes` routes those files through a clean/smudge filter
# that blanks the value in the index and re-injects it from secrets.env here.
# The filter is registered in repo-local git config (never committed), so it
# has to be set up on every clone.

SECRETS_FILE="$HOME/.config/dotfiles/secrets.env"
if [ ! -f "$SECRETS_FILE" ]; then
    echo "Creating $SECRETS_FILE from the example (fill in the values)..."
    install -d -m 700 "$(dirname "$SECRETS_FILE")"
    install -m 600 "$DOTFILES_DIR/configs/secrets.env.example" "$SECRETS_FILE"
fi

echo "Registering git credential filters..."
git -C "$DOTFILES_DIR" config filter.orcasecret.clean \
    "configs/OrcaSlicer/secret-filter.sh clean"
git -C "$DOTFILES_DIR" config filter.orcasecret.smudge \
    "configs/OrcaSlicer/secret-filter.sh smudge"
git -C "$DOTFILES_DIR" config filter.orcasecret.required true

# Re-materialise filtered files so smudge injects the real values. Only safe
# when they have no uncommitted changes — otherwise a checkout would discard
# real edits (e.g. a profile the slicer just saved).
filtered_dirty=$(git -C "$DOTFILES_DIR" status --porcelain -- \
    'configs/OrcaSlicer/user/default/machine/*.json')
if [ -z "$filtered_dirty" ]; then
    git -C "$DOTFILES_DIR" checkout -- \
        'configs/OrcaSlicer/user/default/machine/*.json' 2>/dev/null || true
else
    echo " Skipping re-checkout: machine profiles have uncommitted changes."
fi

echo "Symlinking user dotfiles..."
for src in "${!DOTFILES[@]}"; do
    link_file "$DOTFILES_DIR/$src" "${DOTFILES[$src]}"
done

echo "Seeding app-owned config files..."
for src in "${!SEED_FILES[@]}"; do
    target="${SEED_FILES[$src]}"
    if [ -L "$target" ]; then
        # Left over from when these were symlinked. Replace with a real copy.
        echo " Converting symlink to a real file: $target"
        rm -f "$target"
    elif [ -e "$target" ]; then
        echo " Keeping existing: $target (bash install.sh --capture to save it)"
        continue
    fi
    mkdir -p "$(dirname "$target")"
    echo " Seeding: $src -> $target"
    cp "$DOTFILES_DIR/$src" "$target"
done

echo "Symlinking user runit services..."
for svc in "${USER_RUNIT_SERVICES[@]}"; do
    target="$HOME/.local/share/runit/sv/$svc"
    mkdir -p "$target/log/main"
    link_file "$DOTFILES_DIR/runit/user/$svc/run"     "$target/run"
    link_file "$DOTFILES_DIR/runit/user/$svc/log/run" "$target/log/run"
done

# Librewolf user.js: symlink into the install-default profile so session prefs
# survive across restarts. Detects the profile dynamically from profiles.ini.
lw_profile=$(awk -F= '/^\[Install/{found=1} found && /^Default=/{print $2; exit}' \
    "$HOME/.librewolf/profiles.ini" 2>/dev/null)
if [ -n "$lw_profile" ]; then
    link_file "$DOTFILES_DIR/configs/librewolf-user.js" \
        "$HOME/.librewolf/$lw_profile/user.js"
else
    echo " Skipping librewolf user.js: no Librewolf profile found (launch it once first)"
fi

# AutoFirma CA: its launcher only trusts the root CA in Firefox profiles
# (~/.mozilla/firefox), so LibreWolf never gets it and can't reach the local
# signing socket. Trust it in the install-default profile here.
autofirma_ca="$HOME/.afirma/Autofirma/AutoFirma_ROOT.cer"
if [ -n "$lw_profile" ] && [ -r "$autofirma_ca" ]; then
    certutil -d "$HOME/.librewolf/$lw_profile" -D -n "AutoFirma ROOT" >/dev/null 2>&1
    certutil -d "$HOME/.librewolf/$lw_profile" -A -i "$autofirma_ca" -n "AutoFirma ROOT" -t C,,
fi

# Scripts: per-file symlinks so ~/.local/bin stays a real directory
# and external tools (uv, claude, etc.) can write there without polluting this repo.
LOCAL_BIN="$HOME/.local/bin"
SCRIPTS_DIR="$DOTFILES_DIR/scripts"

if [ -L "$LOCAL_BIN" ]; then
    echo " Converting $LOCAL_BIN from directory symlink to real directory..."
    rm "$LOCAL_BIN"
fi
mkdir -p "$LOCAL_BIN"

for script in "$SCRIPTS_DIR"/*; do
    # Skip dangling entries: a tracked symlink whose target has gone away (e.g.
    # a self-updating tool like claude that moved to a new version dir) must
    # not be linked into ~/.local/bin, or it would clobber a working binary.
    if [ ! -e "$script" ]; then
        echo " Skipping $(basename "$script"): broken symlink ($(readlink "$script"))"
        continue
    fi
    script_name=$(basename "$script")
    link_file "$script" "$LOCAL_BIN/$script_name"
done

echo "Done."
echo
echo "Next:"
echo "  bash install.sh --system   # /etc files (requires sudo)"
echo "  bash install-packages.sh   # pacman/AUR packages from docs/packages.md"
