#!/bin/bash

# --- Power menu via wofi ---
CHOICE=$(printf "⏻  Shutdown\n↺  Reboot\n⟳  Update + Shutdown\n⟳  Update + Reboot\n⟳  Update Only\n×  Cancel" | \
    wofi --dmenu --prompt "System" --cache-file /dev/null --lines 6 --insensitive 2>/dev/null) || true

case "$CHOICE" in
    *"Update + Shutdown"*) POWER_ACTION=poweroff ;;
    *"Update + Reboot"*)   POWER_ACTION=reboot   ;;
    *"Update"*)            POWER_ACTION=none      ;;
    *"Shutdown"*)          systemctl poweroff; exit 0 ;;
    *"Reboot"*)            systemctl reboot; exit 0   ;;
    *)                     exit 0 ;;
esac

# --- Update workflow in Kitty (only reached for Update variants) ---
INNER_SCRIPT=$(cat << 'INNEREOF'
set -euo pipefail

eval "$(grep -E "^export " ~/.bashrc 2>/dev/null || true)"

CRITICAL_PKGS="^(linux|linux-lts|linux-zen|nvidia|mesa|systemd|grub|postgresql|python|glibc|pacman)$"
TMPFILE=""
AI_PID=""

trap 'kill "${AI_PID:-}" 2>/dev/null || true; rm -f "${TMPFILE:-}"' EXIT

echo -e "\033[1;34m=== System Update ===\033[0m"

# --- Step 0: Get package list & start AI fetch in background immediately ---
echo -e "\n\033[1;33m[ Calculating Updates... ]\033[0m"
REPO_UPDATES=$(checkupdates --nocolor 2>/dev/null || true)
AUR_UPDATES=""
if command -v yay &>/dev/null; then
    AUR_UPDATES=$(yay -Qu --color never 2>/dev/null || true)
fi
ALL_UPDATES=$(printf "%s\n%s\n" "$REPO_UPDATES" "$AUR_UPDATES" | sed '/^\s*$/d')

if [ -n "$ALL_UPDATES" ] && [ -n "${GROQ_API_KEY:-}" ] && command -v jq &>/dev/null; then
    TMPFILE=$(mktemp /tmp/ai_summary_XXXXXX)
    PKG_LIST="$ALL_UPDATES"
    (
        SYSTEM_PROMPT="You are a concise Arch Linux sysadmin assistant. The user has pending package updates.
Using your training knowledge, briefly summarize what is notable about these version changes.
Highlight: security fixes, breaking changes, kernel/driver updates, whether a reboot is needed.
Be concise: 1-2 sentences per package. Skip trivial patch bumps entirely."

        JSON_PAYLOAD=$(jq -n \
            --arg sys "$SYSTEM_PROMPT" \
            --arg usr "Packages updating:
${PKG_LIST}" \
            '{
                model: "llama-3.3-70b-versatile",
                messages: [
                    {role: "system", content: $sys},
                    {role: "user", content: $usr}
                ],
                temperature: 0.2,
                max_tokens: 600
            }')

        RESPONSE=$(curl -s --max-time 20 -X POST "https://api.groq.com/openai/v1/chat/completions" \
            -H "Authorization: Bearer ${GROQ_API_KEY}" \
            -H "Content-Type: application/json" \
            -d "$JSON_PAYLOAD" 2>/dev/null)

        MSG=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
        if [ -n "$MSG" ] && [ "$MSG" != "null" ]; then
            printf "%s" "$MSG"
        else
            echo "(AI summary unavailable)"
        fi
    ) > "$TMPFILE" 2>&1 &
    AI_PID=$!
fi

# --- Step 1: Arch Linux News (fixed with Python XML parser) ---
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

# --- Step 2: Package list ---
if [ -z "$ALL_UPDATES" ]; then
    echo -e "\n\033[1;32m✓ System is already up to date.\033[0m"
else
    echo -e "\n\033[1;34m[ Incoming Updates ]\033[0m"
    CRITICAL_FOUND=false

    while IFS= read -r line; do
        [ -z "$line" ] && continue
        pkg_name=$(echo "$line" | awk '{print $1}')
        old_ver=$(echo "$line" | awk '{print $2}')
        new_ver=$(echo "$line" | awk '{print $4}')

        if [[ "$pkg_name" =~ $CRITICAL_PKGS ]]; then
            echo -e "\033[1;31m!! $pkg_name : $old_ver -> $new_ver\033[0m"
            CRITICAL_FOUND=true
        else
            echo -e "\033[0;90m   $pkg_name : $old_ver -> $new_ver\033[0m"
        fi
    done <<< "$ALL_UPDATES"

    echo -e "------------------------"
    if [ "$CRITICAL_FOUND" = "true" ]; then
        echo -e "\033[1;31mWARNING: Critical system components are updating.\033[0m"
    fi

    # --- Step 3: AI summary (opt-in, fetched in background since step 0) ---
    if [ -n "$AI_PID" ]; then
        echo
        read -rp "Show AI summary? [y/N]: " AI_CHOICE
        if [[ "${AI_CHOICE:-}" =~ ^[Yy]$ ]]; then
            echo -e "\n\033[1;35m[ AI Update Summary ]\033[0m"
            wait "$AI_PID" 2>/dev/null || true
            AI_PID=""
            echo -e "\033[0;36m$(cat "$TMPFILE")\033[0m"
        fi
    fi

    # --- Step 4: Confirm & run update ---
    echo
    read -rp "Proceed with update? [y/N]: " CONFIRM
    if [[ "${CONFIRM:-}" =~ ^[Yy]$ ]]; then
        echo -e "\n\033[1;32m[ Updating System ]\033[0m"
        sudo pacman -Syu

        if [ -n "$AUR_UPDATES" ]; then
            echo -e "\n\033[1;32m[ Updating AUR ]\033[0m"
            yay -Su
        fi

        if command -v pacdiff &>/dev/null; then
            PACNEW_COUNT=$(sudo find /etc -name "*.pacnew" 2>/dev/null | wc -l)
            if [ "$PACNEW_COUNT" -gt 0 ]; then
                echo -e "\n\033[1;33m[ Configuration Merge Check ]\033[0m"
                echo -e "\033[1;31mFound $PACNEW_COUNT .pacnew files.\033[0m"
                read -rp "Run pacdiff now? [y/N]: " DIFF_CONFIRM
                if [[ "${DIFF_CONFIRM:-}" =~ ^[Yy]$ ]]; then
                    sudo pacdiff
                fi
            fi
        fi
    else
        echo "Update skipped."
    fi
fi

# --- Step 5: Power action ---
case "${POWER_ACTION:-none}" in
    poweroff)
        echo -e "\nShutting down..."
        sudo systemctl poweroff
        ;;
    reboot)
        echo -e "\nRebooting..."
        sudo systemctl reboot
        ;;
    *)
        echo -e "\nDone. Press Enter to close."
        read -r
        ;;
esac
INNEREOF
)

POWER_ACTION="$POWER_ACTION" kitty --title "System Update" bash -c "$INNER_SCRIPT"
