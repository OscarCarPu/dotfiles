#!/bin/bash
set -euo pipefail

# Run in Kitty
kitty --title "System Update Auditor" bash -c '
set -e

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
