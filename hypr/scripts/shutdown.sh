#!/bin/bash

# --- Power menu via wofi ---
# Pango markup (--allow-markup) makes the icon glyph bigger than the label text.
ICON='<span size="xx-large" rise="-2000">'
CHOICE=$(printf "%s󰐥</span>  Shutdown\n%s󰜉</span>  Reboot\n%s󰚰</span>  Update + Shutdown\n%s󰚰</span>  Update + Reboot\n%s󰚰</span>  Update Only\n%s󰅖</span>  Cancel" \
    "$ICON" "$ICON" "$ICON" "$ICON" "$ICON" "$ICON" | \
    wofi --dmenu --allow-markup --prompt "System" --cache-file /dev/null --lines 6 --insensitive 2>/dev/null) || true

case "$CHOICE" in
    *"Update + Shutdown"*) POWER_ACTION=poweroff ;;
    *"Update + Reboot"*)   POWER_ACTION=reboot   ;;
    *"Update Only"*)       POWER_ACTION=none     ;;
    *"Shutdown"*)          loginctl poweroff; exit 0 ;;
    *"Reboot"*)            loginctl reboot; exit 0   ;;
    *)                     exit 0 ;;
esac

# --- Update workflow in Kitty (only reached for Update variants) ---
INNER_SCRIPT=$(cat << 'INNEREOF'
set -uo pipefail

# Critical packages on Artix where a careful look (and usually a reboot) is
# warranted. Note: no systemd — Artix uses runit + elogind.
CRITICAL_PKGS="^(linux|linux-lts|linux-zen|linux-hardened|nvidia|nvidia-dkms|mesa|lib32-mesa|glibc|lib32-glibc|pacman|runit|elogind|elogind-runit)$"

power_action() {
    if [ -n "${UPDATE_FAILED:-}" ]; then
        echo -e "\n\033[1;31m✗ Update failed — staying on. Resolve the errors above and re-run.\033[0m"
        read -rp $'\nPress Enter to close: '
        return
    fi
    case "${POWER_ACTION:-none}" in
        poweroff)
            read -rp $'\nReady to shut down. Press Enter to confirm (Ctrl+C to cancel): '
            loginctl poweroff
            ;;
        reboot)
            read -rp $'\nReady to reboot. Press Enter to confirm (Ctrl+C to cancel): '
            loginctl reboot
            ;;
        *)
            read -rp $'\nDone. Press Enter to close: '
            ;;
    esac
}
trap power_action EXIT

echo -e "\033[1;34m=== Artix System Update ===\033[0m"

# --- Step 1: Arch news (Artix tracks Arch packages) ---
echo -e "\n\033[1;33m[ Latest Arch Linux News ]\033[0m"
python3 -c "
import xml.etree.ElementTree as ET
from urllib.request import urlopen
try:
    rss = urlopen('https://archlinux.org/feeds/news/', timeout=5).read()
    root = ET.fromstring(rss)
    for item in list(root.findall('.//item'))[:3]:
        t = item.find('title')
        print(' -', t.text if t is not None else '?')
except Exception as e:
    print(' Unable to fetch news:', e)
" 2>/dev/null || echo "  Unable to fetch news."

# --- Step 2: Calculate updates ---
# Sync repos once with sudo, then query locally with `pacman -Qu` (no sudo
# needed). Avoids depending on `checkupdates` from pacman-contrib.
echo -e "\n\033[1;33m[ Calculating Updates... ]\033[0m"
echo "Syncing package databases..."
sudo pacman -Sy >/dev/null

# Read IgnorePkg from /etc/pacman.conf so we can both filter the listing and
# pass --ignore down to the actual upgrade. pacman -Qu does NOT mark these
# with [ignored], so without this they'd silently slip through.
IGNORED=$(awk -F'=' '
    /^[[:space:]]*IgnorePkg[[:space:]]*=/ {
        sub(/^[[:space:]]*IgnorePkg[[:space:]]*=[[:space:]]*/, "", $0);
        # IgnorePkg may also be a list under "IgnorePkg = a b c"
        for (i=1; i<=NF; i++) print
    }
' /etc/pacman.conf | tr -s ' ' '\n' | sed '/^$/d' | sort -u)

declare -A IGNORED_MAP
while read -r p; do [ -n "$p" ] && IGNORED_MAP[$p]=1; done <<< "$IGNORED"

REPO_UPDATES=$(pacman -Qu 2>/dev/null || true)
AUR_UPDATES=""
if command -v yay &>/dev/null; then
    AUR_UPDATES=$(yay -Qua --color never 2>/dev/null || true)
fi
RAW_UPDATES=$(printf "%s\n%s\n" "$REPO_UPDATES" "$AUR_UPDATES" | sed '/^\s*$/d')

# Split into "will-update" vs "skipped (in IgnorePkg)".
ALL_UPDATES=""
SKIPPED_UPDATES=""
while IFS= read -r line; do
    [ -z "$line" ] && continue
    pname=$(echo "$line" | awk '{print $1}')
    if [[ -n "${IGNORED_MAP[$pname]:-}" ]]; then
        SKIPPED_UPDATES+="${line}"$'\n'
    else
        ALL_UPDATES+="${line}"$'\n'
    fi
done <<< "$RAW_UPDATES"
ALL_UPDATES=${ALL_UPDATES%$'\n'}
SKIPPED_UPDATES=${SKIPPED_UPDATES%$'\n'}

if [ -z "$ALL_UPDATES" ] && [ -z "$SKIPPED_UPDATES" ]; then
    echo -e "\n\033[1;32m✓ System is already up to date.\033[0m"
    exit 0
fi

# Show skipped packages up front so the user knows the IgnorePkg list is
# actually doing its job (e.g. aquamarine 0.11 with the DisplayLink regression).
if [ -n "$SKIPPED_UPDATES" ]; then
    TRACKER_SCRIPT="$HOME/.dotfiles/hypr/scripts/tracked_prs.py"

    # Map each skipped pkg -> "repo#num" via tracked_prs.json (offline, fast).
    declare -A SKIP_REF
    if [ -x "$TRACKER_SCRIPT" ]; then
        while IFS=$'\t' read -r pkg ref; do
            [ -n "$pkg" ] && SKIP_REF[$pkg]="$ref"
        done < <(echo "$SKIPPED_UPDATES" | awk '{print $1}' | "$TRACKER_SCRIPT" --refs || true)
    fi

    echo -e "\n\033[1;90m[ Skipped — IgnorePkg in /etc/pacman.conf ]\033[0m"
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        pname=$(echo "$line" | awk '{print $1}')
        ref="${SKIP_REF[$pname]:-}"
        if [ -n "$ref" ]; then
            echo -e "\033[0;90m~~ $line\033[0m  \033[0;36m→ $ref\033[0m"
        else
            echo -e "\033[0;90m~~ $line\033[0m"
        fi
    done <<< "$SKIPPED_UPDATES"

    # Live status block (network) for the blockers covering these packages.
    # Pass `pkg<TAB>newver` so the report shows the exact upstream version
    # being held (catches patch bumps, not just whole-version releases).
    if [ -x "$TRACKER_SCRIPT" ]; then
        echo "$SKIPPED_UPDATES" | awk '{print $1 "\t" $4}' | "$TRACKER_SCRIPT" || true
    fi
fi

if [ -z "$ALL_UPDATES" ]; then
    echo -e "\n\033[1;32m✓ Nothing to update outside the IgnorePkg list.\033[0m"
    exit 0
fi

# --- Step 3: Show package list with critical + explicit highlight ---
# Explicit = installed by the user (pacman -Qe), not pulled in as a dependency.
declare -A EXPLICIT
while read -r p; do EXPLICIT[$p]=1; done < <(pacman -Qeq 2>/dev/null)

echo -e "\n\033[1;34m[ Incoming Updates ]\033[0m"
CRITICAL_FOUND=false
EXPLICIT_COUNT=0
DEP_COUNT=0
EXPLICIT_PKGS=()
while IFS= read -r line; do
    [ -z "$line" ] && continue
    pkg_name=$(echo "$line" | awk '{print $1}')
    old_ver=$(echo "$line" | awk '{print $2}')
    new_ver=$(echo "$line" | awk '{print $4}')

    if [[ "$pkg_name" =~ $CRITICAL_PKGS ]]; then
        # bold red
        echo -e "\033[1;31m!! $pkg_name : $old_ver -> $new_ver\033[0m"
        CRITICAL_FOUND=true
        EXPLICIT_PKGS+=("$pkg_name")
        ((EXPLICIT_COUNT++))
    elif [[ -n "${EXPLICIT[$pkg_name]:-}" ]]; then
        # bold yellow — packages the user explicitly installed
        echo -e "\033[1;33m** $pkg_name : $old_ver -> $new_ver\033[0m"
        EXPLICIT_PKGS+=("$pkg_name")
        ((EXPLICIT_COUNT++))
    else
        # dim gray — pulled in as a dependency
        echo -e "\033[0;90m   $pkg_name : $old_ver -> $new_ver\033[0m"
        ((DEP_COUNT++))
    fi
done <<< "$ALL_UPDATES"

echo "------------------------"
echo -e "\033[1;33m**\033[0m explicit  \033[0;90m  \033[0mdependency  ($EXPLICIT_COUNT explicit, $DEP_COUNT deps)"
if [ "$CRITICAL_FOUND" = "true" ]; then
    echo -e "\033[1;31mWARNING: Critical system components are updating.\033[0m"
fi

# --- Step 3.5: Optional release notes for explicit / critical packages ---
NOTES_SCRIPT="$HOME/.dotfiles/hypr/scripts/release_notes.py"
if [ "${#EXPLICIT_PKGS[@]}" -gt 0 ] && [ -x "$NOTES_SCRIPT" ]; then
    echo
    read -rp "Fetch release notes for the ${#EXPLICIT_PKGS[@]} highlighted packages? [y/N]: " NOTES_CHOICE
    if [[ "${NOTES_CHOICE:-}" =~ ^[Yy]$ ]]; then
        echo -e "\n\033[1;35m[ Release Notes ]\033[0m"
        "$NOTES_SCRIPT" "${EXPLICIT_PKGS[@]}"
    fi
fi

# --- Step 4: Confirm & run update ---
echo
read -rp "Proceed with update? [y/N]: " CONFIRM
if [[ ! "${CONFIRM:-}" =~ ^[Yy]$ ]]; then
    echo "Update skipped."
    exit 0
fi

echo -e "\n\033[1;32m[ Updating Repos ]\033[0m"
# DBs already synced in step 2; -Su (no -y) avoids a redundant network sync.
# Drop pacman/yay's per-package "ignoring …" warnings (already covered by the
# [ Skipped ] block above) via filter_pin_noise.py. A plain `grep -v` would
# break interactivity because pacman writes prompts to stderr without a
# trailing newline; the helper reads char-by-char and only buffers lines that
# could be the noise pattern, so prompts reach the user instantly.
PIN_FILTER="$HOME/.dotfiles/hypr/scripts/filter_pin_noise.py"
if [ -x "$PIN_FILTER" ]; then
    sudo pacman -Su 2> >("$PIN_FILTER" >&2) || UPDATE_FAILED=1
else
    sudo pacman -Su || UPDATE_FAILED=1
fi

if [ -z "${UPDATE_FAILED:-}" ] && [ -n "$AUR_UPDATES" ] && command -v yay &>/dev/null; then
    echo -e "\n\033[1;32m[ Updating AUR ]\033[0m"
    if [ -x "$PIN_FILTER" ]; then
        yay -Sua 2> >("$PIN_FILTER" >&2) || UPDATE_FAILED=1
    else
        yay -Sua || UPDATE_FAILED=1
    fi
fi

# --- Step 5: pacnew check ---
PACNEW_FILES=$(sudo find /etc -name "*.pacnew" 2>/dev/null)
if [ -n "$PACNEW_FILES" ]; then
    echo -e "\n\033[1;33m[ Configuration Merge Check ]\033[0m"
    echo -e "\033[1;31mFound .pacnew files:\033[0m"
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
INNEREOF
)

POWER_ACTION="$POWER_ACTION" kitty --title "System Update" bash -c "$INNER_SCRIPT"
