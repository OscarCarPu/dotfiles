#!/bin/bash
set -euo pipefail

# Run in Kitty
kitty --title "System Update Auditor" bash -c '
set -e

# Source env vars from bashrc (bypasses interactive guard)
eval "$(grep -E "^export " ~/.bashrc 2>/dev/null || true)"

# --- Configuration ---
# Only flag these EXACT package names as critical (regex)
CRITICAL_PKGS="^(linux|linux-lts|linux-zen|nvidia|mesa|systemd|grub|postgresql|python|glibc|pacman)$"

echo "=== System Update Auditor ==="
echo "1. Shutdown after update (or straight away)"
echo "2. Update only"
echo "3. Reboot after update (or straight away)"
echo
read -p "Select action (1/2/3): " ACTION_CHOICE

# --- Step 1: Check Arch News ---
# We check news regardless, just in case there is a global alert
echo -e "\n\033[1;33m[ Latest Arch Linux News ]\033[0m"
if command -v curl &>/dev/null; then
    curl -s "https://archlinux.org/feeds/news/" | \
    grep -oP "(?<=<title>).*?(?=</title>)" | \
    head -n 4 | tail -n 3 | \
    sed "s/^/  - /" || echo "  Unable to parse news."
else
    echo "  Curl not found, skipping news."
fi

# --- Step 2: Calculate Updates ---
echo -e "\n\033[1;33m[ Calculating Updates... ]\033[0m"
REPO_UPDATES=$(checkupdates --nocolor 2>/dev/null || true)
AUR_UPDATES=""
if command -v yay &> /dev/null; then
    AUR_UPDATES=$(yay -Qu --color never 2>/dev/null || true)
fi

ALL_UPDATES="$REPO_UPDATES
$AUR_UPDATES"
ALL_UPDATES=$(echo "$ALL_UPDATES" | sed "/^\s*$/d")

# --- Step 3: Logic Split ---
if [ -z "$ALL_UPDATES" ]; then
    # CASE A: No Updates
    echo -e "\n\033[1;32m✓ System is already up to date.\033[0m"
    sleep 1
else
    # CASE B: Updates Found - Run the Audit & Install
    
    echo -e "\n\033[1;34m=== Incoming Updates ===\033[0m"
    CRITICAL_FOUND=false

    while read -r line; do
        pkg_name=$(echo "$line" | awk "{print \$1}")
        old_ver=$(echo "$line" | awk "{print \$2}")
        new_ver=$(echo "$line" | awk "{print \$4}")
        
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

    # --- AI Update Summary via Groq ---
    if [ -z "${GROQ_API_KEY:-}" ]; then
        echo -e "\n\033[0;90m  (Skipping AI summary: GROQ_API_KEY not set)\033[0m"
    elif ! command -v jq &>/dev/null; then
        echo -e "\n\033[0;90m  (Skipping AI summary: jq not installed)\033[0m"
    else
        echo -e "\n\033[1;35m[ AI Update Summary ]\033[0m"
        echo -n "Fetching changelogs..."
        (while :; do for c in / - \\ \|; do
            echo -ne "\b$c"
            sleep 0.1
        done; done) &
        SPINNER_PID=$!

        # --- Fetch real changelogs from upstream ---
        CHANGELOG_DATA=""
        while read -r line; do
            pkg_name=$(echo "$line" | awk "{print \$1}")
            old_ver=$(echo "$line" | awk "{print \$2}")
            new_ver=$(echo "$line" | awk "{print \$4}")

            # Strip Arch pkgrel suffix (e.g. 0.9.4-1 -> 0.9.4)
            old_strip=$(echo "$old_ver" | sed "s/-[0-9]*$//")
            new_strip=$(echo "$new_ver" | sed "s/-[0-9]*$//")

            # Get upstream URL from pacman
            PKG_URL=$(pacman -Si "$pkg_name" 2>/dev/null | grep -m1 "^URL" | awk "{print \$3}")

            NOTES=""
            if [[ "${PKG_URL:-}" == *"github.com"* ]]; then
                # Extract owner/repo from GitHub URL
                GH_REPO=$(echo "$PKG_URL" | sed "s|https\{0,1\}://github.com/||;s|/$||;s|#.*||;s|/tree/.*||;s|/wiki.*||")

                # Try common tag formats for the new version release notes
                for tag in "v${new_strip}" "${new_strip}" "${pkg_name}-${new_strip}"; do
                    NOTES=$(curl -s --max-time 5 \
                        "https://api.github.com/repos/${GH_REPO}/releases/tags/${tag}" \
                        | jq -r ".body // empty" 2>/dev/null)
                    [ -n "$NOTES" ] && break
                done

                # If no tagged release, try latest release
                if [ -z "$NOTES" ]; then
                    NOTES=$(curl -s --max-time 5 \
                        "https://api.github.com/repos/${GH_REPO}/releases/latest" \
                        | jq -r "if .tag_name then \"[\(.tag_name)] \" + (.body // \"\") else empty end" 2>/dev/null)
                fi
            fi

            # Cap per-package notes to avoid token bloat
            if [ -n "$NOTES" ]; then
                NOTES=$(echo "$NOTES" | head -c 1500)
            fi

            CHANGELOG_DATA="${CHANGELOG_DATA}
=== ${pkg_name} ${old_strip} -> ${new_strip} ===
Upstream: ${PKG_URL:-unknown}
${NOTES:-No release notes found.}
"
        done <<< "$ALL_UPDATES"

        kill $SPINNER_PID 2>/dev/null
        echo -ne "\b \n"

        # --- Send changelogs to Groq for summarization ---
        echo -n "Summarizing with AI..."
        (while :; do for c in / - \\ \|; do
            echo -ne "\b$c"
            sleep 0.1
        done; done) &
        SPINNER_PID=$!

        SYSTEM_PROMPT="You are a concise Arch Linux system administrator assistant.
You are given real upstream release notes for pending package updates.
Summarize what actually changed based on the provided notes:
- Highlight breaking changes, security fixes, new features, and deprecations.
- Note if a reboot or manual intervention is likely needed.
- If no release notes were found for a package, say so briefly.
- Keep it concise: a few bullet points per package. No markdown code blocks."

        # Split changelog data into chunks (~4000 chars each) for token limits
        CHUNK_SIZE=4000
        TOTAL_CHARS=${#CHANGELOG_DATA}
        OFFSET=0
        CHUNK_NUM=0
        AI_FULL_MSG=""

        while [ "$OFFSET" -lt "$TOTAL_CHARS" ]; do
            CHUNK="${CHANGELOG_DATA:$OFFSET:$CHUNK_SIZE}"
            # Avoid cutting mid-package: extend to next === boundary
            if [ $((OFFSET + CHUNK_SIZE)) -lt "$TOTAL_CHARS" ]; then
                REMAINDER="${CHANGELOG_DATA:$((OFFSET + CHUNK_SIZE)):500}"
                NEXT_BREAK=$(echo "$REMAINDER" | grep -b -m1 "^===" | head -1 | cut -d: -f1)
                if [ -n "$NEXT_BREAK" ]; then
                    CHUNK="${CHANGELOG_DATA:$OFFSET:$((CHUNK_SIZE + NEXT_BREAK))}"
                fi
            fi
            ACTUAL_LEN=${#CHUNK}
            CHUNK_NUM=$((CHUNK_NUM + 1))

            if [ "$TOTAL_CHARS" -gt "$CHUNK_SIZE" ]; then
                CHUNK_LABEL=" (batch $CHUNK_NUM)"
            else
                CHUNK_LABEL=""
            fi

            USER_PROMPT="Package update changelogs${CHUNK_LABEL}:

${CHUNK}"

            JSON_PAYLOAD=$(jq -n \
                --arg sys "$SYSTEM_PROMPT" \
                --arg usr "$USER_PROMPT" \
                "{
                    model: \"llama-3.3-70b-versatile\",
                    messages: [
                        {role: \"system\", content: \$sys},
                        {role: \"user\", content: \$usr}
                    ],
                    temperature: 0.2,
                    max_tokens: 1000
                }")

            AI_RESPONSE=$(curl -s --max-time 15 -X POST "https://api.groq.com/openai/v1/chat/completions" \
                -H "Authorization: Bearer $GROQ_API_KEY" \
                -H "Content-Type: application/json" \
                -d "$JSON_PAYLOAD")

            if [ -z "$AI_RESPONSE" ]; then
                echo -e "\n\033[1;31m  Error: No response from Groq API\033[0m"
                break
            fi

            API_ERROR=$(echo "$AI_RESPONSE" | jq -r ".error.message // empty" 2>/dev/null)
            if [ -n "$API_ERROR" ]; then
                echo -e "\n\033[1;31m  Groq API error: $API_ERROR\033[0m"
                break
            fi

            AI_MSG=$(echo "$AI_RESPONSE" | jq -r ".choices[0].message.content // empty")
            if [ -n "$AI_MSG" ] && [ "$AI_MSG" != "null" ]; then
                AI_FULL_MSG="${AI_FULL_MSG}${AI_MSG}
"
            else
                echo -e "\n\033[1;31m  Error: Empty response from model\033[0m"
                echo -e "\033[0;90m  Response: $(echo "$AI_RESPONSE" | head -c 200)\033[0m"
                break
            fi

            OFFSET=$((OFFSET + ACTUAL_LEN))
        done

        kill $SPINNER_PID 2>/dev/null
        echo -ne "\b \n"

        if [ -n "$AI_FULL_MSG" ]; then
            echo -e "\033[0;36m$AI_FULL_MSG\033[0m"
        fi
    fi

    # Confirm Update
    echo
    read -p "Proceed with FULL system update (-Syu)? [y/N]: " CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo -e "\n\033[1;32m[ Updating Repositories ]\033[0m"
        sudo pacman -Syu

        if [ -n "$AUR_UPDATES" ]; then
            echo -e "\n\033[1;32m[ Updating AUR ]\033[0m"
            yay -Su
        fi

        # Check for config merges (only relevant if updates happened)
        if command -v pacdiff &>/dev/null; then
            PACNEW_COUNT=$(sudo find /etc -name "*.pacnew" | wc -l)
            if [ "$PACNEW_COUNT" -gt 0 ]; then
                echo -e "\n\033[1;33m[ Configuration Merge Check ]\033[0m"
                echo -e "\033[1;31mFound $PACNEW_COUNT .pacnew files.\033[0m"
                read -p "Run pacdiff now? [y/N]: " DIFF_CONFIRM
                if [[ "$DIFF_CONFIRM" =~ ^[Yy]$ ]]; then
                    sudo pacdiff
                fi
            fi
        fi
    else
        echo "Update skipped by user."
    fi
fi

# --- Step 4: Power Action ---
# This runs regardless of whether updates were installed or not
echo -e "\nProcessing Power Action..."
case "$ACTION_CHOICE" in
    1) 
        echo "Shutting down..."
        sudo systemctl poweroff 
        ;;
    2) 
        echo "Done. Press Enter to close window."
        read 
        ;;
    3) 
        echo "Rebooting..."
        sudo systemctl reboot 
        ;;
esac
'
