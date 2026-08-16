#!/bin/bash
# Power menu (wofi) + guarded Artix update flow. Bound to $mainMod+V.
#
# The read-only half of the update flow needs no root: repo databases are
# synced into a private copy under fakeroot (the `checkupdates` trick), so the
# first password prompt happens at the actual upgrade, after you have said yes.
# Every slow call — Arch news, upstream release notes, tracked-blocker
# assessments — is fired into the background at t=0 and collected later, so the
# proceed/abort decision is never behind a network round-trip.

SCRIPTS_DIR="$(dirname "$(readlink -f "$0")")"

# --- Single instance -------------------------------------------------------
# Held for the lifetime of the script, kitty included: two update terminals
# would race each other on the pacman database lock.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/hypr-shutdown.lock"
if ! flock -n 9; then
    notify-send "System" "A power / update session is already open."
    exit 0
fi

# --- Power menu ------------------------------------------------------------
# Pango markup (--allow-markup) makes the icon glyph bigger than the label text.
ICON='<span size="xx-large" rise="-2000">'
entry() { printf '%s%s</span>  %s\n' "$ICON" "$1" "$2"; }

# Row order is deliberate: the power actions keep the positions they have
# always had, new entries are appended, and Cancel stays last. wofi has no way
# to preselect a row, so Shutdown stays on row 1.
LOCKER=$(command -v hyprlock || command -v swaylock)
MENU=$(
    entry '󰐥' 'Shutdown'
    entry '󰜉' 'Reboot'
    entry '󰚰' 'Update + Shutdown'
    entry '󰚰' 'Update + Reboot'
    entry '󰚰' 'Update Only'
    [ -n "$LOCKER" ] && entry '󰌾' 'Lock'
    entry '󰤄' 'Suspend'
    entry '󰅖' 'Cancel'
)

CHOICE=$(wofi --dmenu --allow-markup --prompt "System" --cache-file /dev/null \
    --lines "$(grep -c '' <<< "$MENU")" --insensitive <<< "$MENU" 2>/dev/null)

# Match on the label alone. Labels are unique and contain no double space,
# so this cannot confuse "Shutdown" with "Update + Shutdown" the way a
# glob against the whole marked-up line did.
case "${CHOICE##*  }" in
    'Lock')             exec "$LOCKER" ;;
    'Suspend')          exec loginctl suspend ;;
    'Shutdown')         "$SCRIPTS_DIR/graceful_quit.sh"; exec loginctl poweroff ;;
    'Reboot')           "$SCRIPTS_DIR/graceful_quit.sh"; exec loginctl reboot ;;
    'Update + Shutdown') POWER_ACTION=poweroff ;;
    'Update + Reboot')   POWER_ACTION=reboot   ;;
    'Update Only')       POWER_ACTION=none     ;;
    *)                   exit 0 ;;
esac

# --- Update workflow in Kitty (only reached for Update variants) ------------
INNER_SCRIPT=$(cat << 'INNEREOF'
set -uo pipefail

RUN_DIR=$(mktemp -d)

# Critical packages on Artix where a careful look (and usually a reboot) is
# warranted. Note: no systemd — Artix uses runit + elogind. The hypr/DisplayLink
# stack is in here because that is what actually breaks this machine.
CRITICAL_PKGS="^(linux|linux-lts|linux-zen|linux-hardened|linux-firmware|nvidia|nvidia-dkms|nvidia-utils|mesa|lib32-mesa|glibc|lib32-glibc|openssl|dbus|wayland|pipewire|pacman|runit|elogind|elogind-runit|hyprland|aquamarine|hyprutils|hyprlang|hyprgraphics|hyprcursor|evdi|displaylink)$"

POWER_TIMEOUT=30

# --- Exit handling ---------------------------------------------------------
# Enter or the timeout proceeds; Ctrl+C and Ctrl+D both cancel. Previously
# neither did: with no `set -e`, a failed `read` fell straight through to
# loginctl, so the prompt's own "Ctrl+C to cancel" was a lie.
confirm_power() {
    local verb=$1 rc
    # The handler echoes before returning: a bare `return 1` would skip the
    # message below, leaving a bare ^C as the only feedback.
    trap 'echo -e "\n\033[1;90mCancelled — staying on.\033[0m"; return 1' INT
    printf '\n\033[1;33mReady to %s. Enter = now, Ctrl+C = cancel (auto in %ss): \033[0m' \
        "$verb" "$POWER_TIMEOUT"
    read -r -t "$POWER_TIMEOUT"; rc=$?
    trap - INT
    [ "$rc" -gt 128 ] && { echo; return 0; }   # timed out -> walked away -> proceed
    [ "$rc" -eq 0 ]   && return 0              # bare Enter -> proceed
    echo -e "\n\033[1;90mCancelled — staying on.\033[0m"
    return 1
}

# Assessment of held-back packages runs in the background from step 2; this
# renders it wherever it is first needed. Defined before the EXIT trap because
# power_action calls it to catch the early-exit paths.
PID_BLOCK=""
print_blockers() {
    [ -n "$PID_BLOCK" ] || return 0
    if kill -0 "$PID_BLOCK" 2>/dev/null; then
        echo -e "\n\033[0;90mWaiting for the tracked-blocker report...\033[0m"
    fi
    wait "$PID_BLOCK" 2>/dev/null
    PID_BLOCK=""
    [ -s "$RUN_DIR/blockers" ] && cat "$RUN_DIR/blockers"
    return 0
}

power_action() {
    print_blockers                            # catches the early-exit paths

    if [ -n "${UPDATE_FAILED:-}" ]; then
        echo -e "\n\033[1;31m✗ Update failed — staying on. Resolve the errors above and re-run.\033[0m"
        read -rp $'\nPress Enter to close: '
        rm -rf "$RUN_DIR"
        return
    fi

    case "${POWER_ACTION:-none}" in
        poweroff|reboot)
            if confirm_power "${POWER_ACTION/poweroff/shut down}"; then
                "$SCRIPTS_DIR/graceful_quit.sh"
                rm -rf "$RUN_DIR"
                loginctl "$POWER_ACTION"
                return
            fi
            read -rp $'\nPress Enter to close: '
            ;;
        *)
            read -rp $'\nDone. Press Enter to close: '
            ;;
    esac
    rm -rf "$RUN_DIR"
}
trap power_action EXIT

# --- Slow calls, all launched before anything is printed -------------------
# Private database sync: no root, and no partial-upgrade window. `pacman -Sy`
# against the real database left it newer than the installed set every time you
# answered "no" here, arming the next `pacman -S <anything>`.
CHECKUP_DB="${TMPDIR:-/tmp}/checkup-db-${UID}"

sync_repo_db() {
    mkdir -p "$CHECKUP_DB"
    rm -f "$CHECKUP_DB/db.lck"
    ln -sfn "$(pacman-conf DBPath)/local" "$CHECKUP_DB/local" 2>/dev/null
    fakeroot -- pacman -Sy --disable-sandbox-filesystem \
        --dbpath "$CHECKUP_DB" --logfile /dev/null &>/dev/null
    # LC_ALL=C keeps the "[ignored]" marker parseable under a Spanish locale.
    LC_ALL=C pacman -Qu --dbpath "$CHECKUP_DB" 2>/dev/null > "$RUN_DIR/repo"
}

# The authoritative resolved transaction, which `-Qu` cannot give: it also
# contains packages about to be installed fresh — new dependencies and
# replacements. Since the upgrade runs --noconfirm, this is the only place they
# can still be shown. Unprivileged: --print resolves and prints, nothing else.
# Runs concurrently with the package listing, whose data it does not need.
resolve_targets() {
    LC_ALL=C pacman -Su --print --dbpath "$CHECKUP_DB" 2>/dev/null \
        | sed 's|.*/||; s|-[^-]*-[^-]*-[^-]*\.pkg\.tar\..*$||' \
        | sort -u > "$RUN_DIR/targets"
}

fetch_news() {
    # Only news published since the last upgrade is worth reading; the same
    # three titles on every run is how a warning banner becomes invisible.
    local since
    since=$(awk '/\[ALPM\] upgraded/ {t=$1} END {gsub(/[][]/,"",t); print t}' \
        /var/log/pacman.log 2>/dev/null)
    python3 -c "
import sys, xml.etree.ElementTree as ET
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
from urllib.request import urlopen

since = sys.argv[1] if len(sys.argv) > 1 else ''
try:
    cutoff = datetime.fromisoformat(since) if since else None
except ValueError:
    cutoff = None

try:
    root = ET.fromstring(urlopen('https://archlinux.org/feeds/news/', timeout=5).read())
except Exception as e:
    print(' Unable to fetch news:', e); sys.exit(0)

items = []
for item in root.findall('.//item'):
    title = getattr(item.find('title'), 'text', None) or '?'
    raw = getattr(item.find('pubDate'), 'text', None)
    try:
        pub = parsedate_to_datetime(raw) if raw else None
    except Exception:
        pub = None
    items.append((pub, title))

fresh = [i for i in items if cutoff and i[0] and i[0] > cutoff]
if fresh:
    print('\033[1;31m %d item(s) published since your last upgrade:\033[0m' % len(fresh))
    for pub, title in fresh:
        print('\033[1;33m ! %s  %s\033[0m' % (pub.date().isoformat(), title))
elif cutoff:
    print('\033[0;90m Nothing new since your last upgrade (%s).\033[0m' % cutoff.date().isoformat())
    for pub, title in items[:2]:
        print('\033[0;90m   %s  %s\033[0m' % (pub.date().isoformat() if pub else '?', title))
else:
    for pub, title in items[:3]:
        print(' -', title)
" "$since" 2>/dev/null || echo "  Unable to fetch news."
}

sync_repo_db & PID_REPO=$!
fetch_news   > "$RUN_DIR/news" & PID_NEWS=$!
PID_AUR=""
if command -v yay &>/dev/null; then
    yay -Qua --color never > "$RUN_DIR/aur" 2>/dev/null & PID_AUR=$!
fi

echo -e "\033[1;34m=== Artix System Update ===\033[0m"
echo -e "\033[0;90mChecking for updates (no password needed yet)...\033[0m"

# --- Step 1: Calculate updates ---------------------------------------------
wait "$PID_REPO"
# Needs the synced database, but nothing downstream needs it until the
# new-packages block, so it overlaps with rendering the list.
resolve_targets & PID_TARGETS=$!
[ -n "$PID_AUR" ] && wait "$PID_AUR"
REPO_UPDATES=$(cat "$RUN_DIR/repo" 2>/dev/null)
AUR_UPDATES=$(cat "$RUN_DIR/aur" 2>/dev/null)
RAW_UPDATES=$(printf "%s\n%s\n" "$REPO_UPDATES" "$AUR_UPDATES" | sed '/^\s*$/d')

# Held-back packages come from two sources: pacman marks its own with
# "[ignored]" (authoritative — it already resolved IgnoreGroup and globs),
# while AUR lines from yay need matching against the configured patterns.
# `pacman-conf` is used rather than grepping pacman.conf so Include'd files,
# IgnoreGroup and glob patterns are all handled.
mapfile -t IGNORE_PATTERNS < <(
    pacman-conf IgnorePkg
    while read -r grp; do [ -n "$grp" ] && pacman -Sgq "$grp" 2>/dev/null; done \
        < <(pacman-conf IgnoreGroup)
)

is_ignored() {
    local pkg=$1 pat
    for pat in "${IGNORE_PATTERNS[@]}"; do
        [[ "$pkg" == $pat ]] && return 0
    done
    return 1
}

ALL_UPDATES=""
SKIPPED_UPDATES=""
while IFS= read -r line; do
    [ -z "$line" ] && continue
    pname=${line%% *}
    if [[ "$line" == *"[ignored]" ]] || is_ignored "$pname"; then
        SKIPPED_UPDATES+="${line%% \[ignored\]}"$'\n'
    else
        ALL_UPDATES+="${line}"$'\n'
    fi
done <<< "$RAW_UPDATES"
ALL_UPDATES=${ALL_UPDATES%$'\n'}
SKIPPED_UPDATES=${SKIPPED_UPDATES%$'\n'}

# --- Step 2: Held-back packages and their blockers -------------------------
if [ -n "$SKIPPED_UPDATES" ]; then
    TRACKER_SCRIPT="$SCRIPTS_DIR/tracked_blockers.py"

    # Live assessment is the slowest thing in the script (one claude call per
    # blocker), so it starts here and is rendered after the upgrade — it
    # informs "should I unpin?", not "should I update?".
    if [ -x "$TRACKER_SCRIPT" ]; then
        echo "$SKIPPED_UPDATES" | awk '{print $1 "\t" $4}' \
            | "$TRACKER_SCRIPT" > "$RUN_DIR/blockers" 2>/dev/null &
        PID_BLOCK=$!
    fi

    # Offline ref lookup (pkg -> repo#num) is instant; print it right away.
    declare -A SKIP_REF
    if [ -x "$TRACKER_SCRIPT" ]; then
        while IFS=$'\t' read -r pkg ref; do
            [ -n "$pkg" ] && SKIP_REF[$pkg]="$ref"
        done < <(echo "$SKIPPED_UPDATES" | awk '{print $1}' | "$TRACKER_SCRIPT" --refs)
    fi

    echo -e "\n\033[1;90m[ Skipped — IgnorePkg in /etc/pacman.conf ]\033[0m"
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        ref="${SKIP_REF[${line%% *}]:-}"
        if [ -n "$ref" ]; then
            echo -e "\033[0;90m~~ $line\033[0m  \033[0;36m→ $ref\033[0m"
        else
            echo -e "\033[0;90m~~ $line\033[0m"
        fi
    done <<< "$SKIPPED_UPDATES"
fi

if [ -z "$ALL_UPDATES" ]; then
    if [ -z "$SKIPPED_UPDATES" ]; then
        echo -e "\n\033[1;32m✓ System is already up to date.\033[0m"
    else
        echo -e "\n\033[1;32m✓ Nothing to update outside the IgnorePkg list.\033[0m"
    fi
    exit 0
fi

# --- Step 3: Show package list with critical + explicit highlight ----------
# Explicit = installed by the user (pacman -Qe), not pulled in as a dependency.
declare -A EXPLICIT
while read -r p; do EXPLICIT[$p]=1; done < <(pacman -Qeq 2>/dev/null)

echo -e "\n\033[1;34m[ Incoming Updates ]\033[0m"
CRITICAL_FOUND=false
HIGHLIGHT_COUNT=0
DEP_COUNT=0
HIGHLIGHT_PKGS=()
while IFS= read -r line; do
    [ -z "$line" ] && continue
    read -r pkg_name old_ver _ new_ver _ <<< "$line"

    if [[ "$pkg_name" =~ $CRITICAL_PKGS ]]; then
        # bold red
        echo -e "\033[1;31m!! $pkg_name : $old_ver -> $new_ver\033[0m"
        CRITICAL_FOUND=true
        HIGHLIGHT_PKGS+=("$pkg_name")
        ((HIGHLIGHT_COUNT++))
    elif [[ -n "${EXPLICIT[$pkg_name]:-}" ]]; then
        # bold yellow — packages the user explicitly installed
        echo -e "\033[1;33m** $pkg_name : $old_ver -> $new_ver\033[0m"
        HIGHLIGHT_PKGS+=("$pkg_name")
        ((HIGHLIGHT_COUNT++))
    else
        # dim gray — pulled in as a dependency
        echo -e "\033[0;90m   $pkg_name : $old_ver -> $new_ver\033[0m"
        ((DEP_COUNT++))
    fi
done <<< "$ALL_UPDATES"

echo "------------------------"
echo -e "\033[1;33m**\033[0m highlighted  \033[0;90m  \033[0mdependency  ($HIGHLIGHT_COUNT highlighted, $DEP_COUNT deps)"
if [ "$CRITICAL_FOUND" = "true" ]; then
    echo -e "\033[1;31mWARNING: Critical system components are updating.\033[0m"
fi

# Anything in the resolved transaction that is not an upgrade of an installed
# package is a fresh install: a new dependency, or a replacement pulled in for
# a package being dropped. pacman would normally ask about replacements; the
# upgrade runs --noconfirm, so this block is where they get seen.
wait "$PID_TARGETS"
NEW_PKGS=$(comm -23 "$RUN_DIR/targets" \
    <(awk '{print $1}' <<< "$ALL_UPDATES" | sort -u) 2>/dev/null)
if [ -n "$NEW_PKGS" ]; then
    echo -e "\n\033[1;35m[ New packages — dependencies or replacements ]\033[0m"
    echo -e "\033[0;90m(not upgrades of anything installed; accepted automatically)\033[0m"
    while IFS= read -r p; do
        [ -n "$p" ] && echo -e "\033[1;35m++ $p\033[0m"
    done <<< "$NEW_PKGS"
fi

# Release notes are fetched, not offered: asking first and *then* waiting for
# the network was the worst of both. They land before the proceed prompt
# because they are what the decision is made on.
NOTES_SCRIPT="$SCRIPTS_DIR/release_notes.py"
PID_NOTES=""
if [ "${#HIGHLIGHT_PKGS[@]}" -gt 0 ] && [ -x "$NOTES_SCRIPT" ]; then
    "$NOTES_SCRIPT" "${HIGHLIGHT_PKGS[@]}" > "$RUN_DIR/notes" 2>/dev/null &
    PID_NOTES=$!
fi

# --- Step 4: Arch news (Artix tracks Arch packages) ------------------------
echo -e "\n\033[1;33m[ Arch Linux News ]\033[0m"
wait "$PID_NEWS"
cat "$RUN_DIR/news"

if [ -n "$PID_NOTES" ]; then
    wait "$PID_NOTES"
    if [ -s "$RUN_DIR/notes" ]; then
        echo -e "\n\033[1;35m[ Release Notes ]\033[0m"
        cat "$RUN_DIR/notes"
    fi
fi

# --- Step 5: Confirm & run update ------------------------------------------
echo
read -rp "Proceed with update? [y/N]: " CONFIRM
if [[ ! "${CONFIRM:-}" =~ ^[Yy]$ ]]; then
    echo "Update skipped."
    exit 0
fi

# Drop pacman/yay's per-package "ignoring ..." warnings (already covered by
# the [ Skipped ] block above) via filter_pin_noise.py. A plain `grep -v`
# would break interactivity because pacman writes prompts to stderr without a
# trailing newline; the helper reads char-by-char and only buffers lines that
# could be the noise pattern, so prompts reach the user instantly. The FIFO
# (rather than a process substitution) is what lets us wait for the filter to
# drain — otherwise its tail could print under the *next* section header.
PIN_FILTER="$SCRIPTS_DIR/filter_pin_noise.py"
run_filtered() {
    if [ ! -x "$PIN_FILTER" ]; then "$@"; return $?; fi
    local fifo rc fpid
    fifo=$(mktemp -u "$RUN_DIR/err.XXXX")
    mkfifo "$fifo"
    "$PIN_FILTER" < "$fifo" >&2 &
    fpid=$!
    "$@" 2> "$fifo"
    rc=$?
    wait "$fpid"
    rm -f "$fifo"
    return $rc
}

echo -e "\n\033[1;32m[ Updating Repos ]\033[0m"
# -Syu, not -Su: the listing above came from the private database copy, so the
# real sync happens here — atomically with the upgrade, which is the whole
# point of never running a bare -Sy.
#
# --noconfirm because the y/N above already is the confirmation; asking twice
# for the same decision only trains you to hit Enter without reading. What
# pacman would otherwise have asked on its own is covered above: the package
# list, the critical highlights, and the fresh installs / replacements.
run_filtered sudo pacman -Syu --noconfirm || UPDATE_FAILED=1

if [ -z "${UPDATE_FAILED:-}" ] && [ -n "$AUR_UPDATES" ] && command -v yay &>/dev/null; then
    echo -e "\n\033[1;32m[ Updating AUR ]\033[0m"
    run_filtered yay -Sua --noconfirm || UPDATE_FAILED=1
fi

# --- Step 6: Tracked blockers (started back at step 2) ---------------------
print_blockers

# --- Step 7: .pacnew config files ------------------------------------------
# The files pacman refuses to overwrite because you edited them, and hands you
# instead as <file>.pacnew. merge_pacnew.py settles them: a 3-way merge against
# the old packaged default pulled from the pacman cache, with claude asked only
# for the hunks git cannot reconcile on its own. Deliberately NOT run under
# sudo — it would look for claude's credentials in root's home; it elevates
# only the individual writes.
MERGE_SCRIPT="$SCRIPTS_DIR/merge_pacnew.py"
if [ -z "${UPDATE_FAILED:-}" ] && [ -x "$MERGE_SCRIPT" ]; then
    "$MERGE_SCRIPT"
fi

# Whatever it declined to touch — boot- and login-critical files — plus
# anything left if the update itself failed. pacdiff -o asks the package
# database, so it also covers .pacnew/.pacsave outside /etc.
if command -v pacdiff &>/dev/null; then
    PACNEW_FILES=$(pacdiff -o 2>/dev/null)
else
    PACNEW_FILES=$(sudo find /etc -name "*.pacnew" 2>/dev/null)
fi
if [ -n "$PACNEW_FILES" ]; then
    echo -e "\n\033[1;33m[ Left for you to merge by hand ]\033[0m"
    echo "$PACNEW_FILES"
    if command -v pacdiff &>/dev/null; then
        read -rp "Run pacdiff now? [y/N]: " DIFF_CONFIRM
        if [[ "${DIFF_CONFIRM:-}" =~ ^[Yy]$ ]]; then
            sudo pacdiff
        fi
    else
        echo "(pacdiff not installed — merge manually or install pacman-contrib)"
    fi
fi

# --- Step 8: dotfiles drift -------------------------------------------------
# An update is exactly when the machine drifts from the repo: a package lands
# that packages.md never heard of, a .pacnew merge unlinks an /etc file, an app
# replaces a symlink with a real file. This is the one flow that already has
# your attention, so the report goes here rather than in a cron job nobody
# reads. Read-only — it never changes anything.
DOTFILES_DIR="$(cd "$SCRIPTS_DIR/../.." && pwd)"
if [ -x "$DOTFILES_DIR/install.sh" ] || [ -f "$DOTFILES_DIR/install.sh" ]; then
    echo -e "\n\033[1;34m[ Dotfiles drift ]\033[0m"
    (cd "$DOTFILES_DIR" && bash install.sh --check) ||
        echo -e "\033[0;90mFix with: cd ~/.dotfiles && bash install.sh [--system|--prune]\033[0m"
fi
# No prompt here on purpose: the EXIT trap's confirm_power already holds the
# terminal for 30 s, which is the window to read this. A blocking read would
# strand the machine on if you walked away.

exit 0
INNEREOF
)

if ! command -v kitty &>/dev/null; then
    notify-send -u critical "System Update" "kitty not found — cannot open the update terminal."
    exit 1
fi

POWER_ACTION="$POWER_ACTION" SCRIPTS_DIR="$SCRIPTS_DIR" \
    kitty --title "System Update" bash -c "$INNER_SCRIPT" \
    || notify-send -u critical "System Update" "The update terminal exited abnormally."
