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

cleanup_and_power() {
    kill "${AI_PID:-}" 2>/dev/null || true
    rm -f "${TMPFILE:-}"
    case "${POWER_ACTION:-none}" in
        poweroff) echo -e "\nShutting down..."; sudo systemctl poweroff ;;
        reboot)   echo -e "\nRebooting...";     sudo systemctl reboot   ;;
        *)        echo -e "\nDone. Press Enter to close."; read -r      ;;
    esac
}
trap cleanup_and_power EXIT

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
        # All data gathering done in one Python script for speed
        export PKG_LIST_ENV="$PKG_LIST"
        GATHERED_DATA=$(python3 << 'PYEOF'
import json, os, re, sys, subprocess
from urllib.request import urlopen, Request
from urllib.error import URLError
from concurrent.futures import ThreadPoolExecutor, as_completed

pkg_list_raw = os.environ.get("PKG_LIST_ENV", "").strip()
if not pkg_list_raw:
    sys.exit(0)

# Parse package updates
updates = []
for line in pkg_list_raw.splitlines():
    parts = line.split()
    if len(parts) >= 4:
        updates.append({"name": parts[0], "old": parts[1], "new": parts[3]})
    elif len(parts) >= 2:
        updates.append({"name": parts[0], "old": parts[1], "new": "?"})

pkg_names = {u["name"] for u in updates}

# Classify: version bump vs pkgrel-only rebuild
def is_rebuild(old_ver, new_ver):
    """pkgrel-only change like 1.28.1-1 -> 1.28.1-2"""
    old_base = re.sub(r'-\d+$', '', old_ver)
    new_base = re.sub(r'-\d+$', '', new_ver)
    return old_base == new_base

rebuilds = []
version_bumps = []
for u in updates:
    if is_rebuild(u["old"], u["new"]):
        rebuilds.append(u)
    else:
        version_bumps.append(u)

# Fetch security advisories - only Vulnerable (unpatched) or recently Fixed
security_matches = []
try:
    req = Request("https://security.archlinux.org/json", headers={"User-Agent": "arch-updater/1.0"})
    data = json.loads(urlopen(req, timeout=10).read())
    for adv in data:
        overlap = set(adv.get("packages", [])) & pkg_names
        if not overlap:
            continue
        status = adv.get("status", "")
        # Only show Vulnerable (active!) or Fixed with the version being installed
        if status == "Vulnerable":
            cves = ", ".join(adv.get("issues", [])[:3]) or "no CVE"
            severity = adv.get("severity", "?")
            security_matches.append(
                f"  !! {adv['name']} [{severity}] ACTIVE: {', '.join(overlap)} - {adv.get('type','')} ({cves})")
        elif status == "Fixed" and adv.get("fixed"):
            # Check if the fix version matches what we're updating TO
            fixed_ver = adv.get("fixed", "")
            for u in updates:
                if u["name"] in overlap and fixed_ver and fixed_ver in u["new"]:
                    cves = ", ".join(adv.get("issues", [])[:3]) or "no CVE"
                    security_matches.append(
                        f"  FIXED in this update: {', '.join(overlap)} - {adv.get('type','')} ({cves})")
                    break
except Exception:
    security_matches.append("  (failed to fetch)")

# For version bumps, fetch upstream release info (GitHub + known security pages)
def fetch_upstream_info(pkg_name, new_ver):
    """Try GitHub releases, then Arch GitLab packaging commits"""
    try:
        si = subprocess.run(["pacman", "-Si", pkg_name], capture_output=True, text=True, timeout=3)
        upstream_url = ""
        url_match = re.search(r'URL\s*:\s*(\S+)', si.stdout)
        if url_match:
            upstream_url = url_match.group(1).rstrip('/')

        # Try GitHub releases API
        gh_match = re.match(r'https://github\.com/([^/]+/[^/]+)', upstream_url)
        if gh_match:
            owner_repo = gh_match.group(1)
            api_url = f"https://api.github.com/repos/{owner_repo}/releases/latest"
            req = Request(api_url, headers={"User-Agent": "arch-updater/1.0"})
            rel = json.loads(urlopen(req, timeout=5).read())
            body = rel.get("body", "") or ""
            body = re.sub(r'\r\n', '\n', body)
            stripped = re.sub(r'https?://\S+', '', body).strip()
            if len(stripped) >= 30 and not re.search(r'(see|found in|details in).{0,20}(changelog|release notes)', stripped, re.I):
                body = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', body)
                body = re.sub(r'https?://\S+', '', body)
                body = re.sub(r'\n{3,}', '\n\n', body).strip()[:500]
                tag = rel.get("tag_name", "")
                return f"  {pkg_name} ({tag}): {body}"

        # Try Arch GitLab packaging commits for packages without GitHub releases
        arch_api = f"https://gitlab.archlinux.org/api/v4/projects/archlinux%2Fpackaging%2Fpackages%2F{pkg_name}/repository/commits?per_page=3"
        req = Request(arch_api, headers={"User-Agent": "arch-updater/1.0"})
        commits = json.loads(urlopen(req, timeout=5).read())
        if commits:
            msgs = [c.get("title", "") for c in commits[:3]]
            return f"  {pkg_name}: recent packaging commits: {'; '.join(msgs)}"

        return None
    except Exception:
        return None

# Check known security bulletin pages for major packages
def fetch_security_bulletins(version_bumps_list):
    """Check upstream security pages for packages known to publish them"""
    bulletins = []
    # Map package name -> (index page URL, detail page URL template using version)
    known_security_pages = {
        "vlc": {
            "detail": lambda v: f"https://www.videolan.org/security/sb-vlc{v.replace('.', '')}.html",
        },
        "firefox": {
            "index": "https://www.mozilla.org/en-US/security/advisories/",
        },
        "chromium": {
            "index": "https://chromereleases.googleblog.com/",
        },
        "thunderbird": {
            "index": "https://www.mozilla.org/en-US/security/advisories/",
        },
    }
    bump_names = {u["name"] for u in version_bumps_list}
    for pkg, urls in known_security_pages.items():
        if pkg not in bump_names:
            continue
        try:
            ver = next(u["new"] for u in version_bumps_list if u["name"] == pkg)
            clean_ver = re.sub(r'^\d+:', '', ver)
            clean_ver = re.sub(r'-\d+$', '', clean_ver)

            # Try detail page first (has actual CVE info)
            page_url = None
            if "detail" in urls:
                page_url = urls["detail"](clean_ver)
            elif "index" in urls:
                page_url = urls["index"]

            if not page_url:
                continue

            req = Request(page_url, headers={"User-Agent": "arch-updater/1.0"})
            page = urlopen(req, timeout=8).read().decode("utf-8", errors="replace")
            text = re.sub(r'<[^>]+>', ' ', page)
            text = re.sub(r'\s+', ' ', text)

            cves = list(set(re.findall(r'CVE-\d{4}-\d+', text)))
            vuln_types = list(set(re.findall(
                r'(buffer overflow|out.of.bound\S*|heap\S*|stack\S*|arbitrary code|invalid free|'
                r'denial of service|information leak|code execution|use.after.free|integer overflow)',
                text, re.I)))

            if cves or vuln_types:
                parts = []
                if cves:
                    parts.append(f"{len(cves)} CVE(s): {', '.join(sorted(cves)[:5])}")
                if vuln_types:
                    clean_types = list(set(t.lower() for t in vuln_types))
                    parts.append(f"types: {', '.join(clean_types[:6])}")
                bulletins.append(f"  {pkg} {clean_ver}: SECURITY RELEASE - {'; '.join(parts)}")
        except Exception:
            pass

    # Also check Arch GitLab commit messages for security-related rebuilds
    for u in version_bumps_list:
        if u["name"] in known_security_pages:
            continue  # already checked above
        try:
            arch_api = f"https://gitlab.archlinux.org/api/v4/projects/archlinux%2Fpackaging%2Fpackages%2F{u['name']}/repository/commits?per_page=3"
            req = Request(arch_api, headers={"User-Agent": "arch-updater/1.0"})
            commits = json.loads(urlopen(req, timeout=4).read())
            for c in commits[:3]:
                msg = c.get("title", "").lower()
                if any(w in msg for w in ["cve", "security", "vulnerability", "exploit", "overflow"]):
                    bulletins.append(f"  {u['name']}: Arch packaging commit: {c['title']}")
                    break
        except Exception:
            pass

    return bulletins

release_notes = []
security_bulletins = []
# Fetch in parallel: upstream info + security bulletins
with ThreadPoolExecutor(max_workers=8) as pool:
    # Release notes
    note_futures = {pool.submit(fetch_upstream_info, u["name"], u["new"]): u["name"]
               for u in version_bumps[:15]}
    # Security bulletins (runs once, not per-package)
    bulletin_future = pool.submit(fetch_security_bulletins, version_bumps)

    for f in as_completed(note_futures, timeout=20):
        try:
            result = f.result()
            if result:
                release_notes.append(result)
        except Exception:
            pass

    try:
        security_bulletins = bulletin_future.result(timeout=15)
    except Exception:
        pass

# Fetch Arch news
arch_news = []
try:
    import xml.etree.ElementTree as ET, html
    rss = urlopen("https://archlinux.org/feeds/news/", timeout=5).read()
    root = ET.fromstring(rss)
    for item in list(root.findall(".//item"))[:3]:
        t = item.find("title").text or "?"
        d = item.find("description")
        text = re.sub("<[^>]+>", "", html.unescape(d.text or ""))[:300] if d is not None else ""
        arch_news.append(f"  {t}: {text}")
except Exception:
    pass

# Determine reboot need
reboot_pkgs = {"linux", "linux-lts", "linux-zen", "linux-hardened", "nvidia", "nvidia-lts",
               "nvidia-dkms", "mesa", "lib32-mesa", "glibc", "lib32-glibc"}
reboot_updating = pkg_names & reboot_pkgs
needs_reboot = bool(reboot_updating)

# Output structured report
print("=== ACTUAL VERSION BUMPS ===")
for u in version_bumps:
    print(f"  {u['name']}: {u['old']} -> {u['new']}")
print(f"\n=== REBUILDS (pkgrel only, {len(rebuilds)} packages) ===")
rebuild_groups = {}
for u in rebuilds:
    base = re.sub(r'-\d+$', '', u['name'])  # group vlc-plugin-* etc
    prefix = u['name'].split('-')[0]
    rebuild_groups.setdefault(prefix, []).append(u['name'])
for prefix, pkgs in rebuild_groups.items():
    if len(pkgs) > 3:
        print(f"  {prefix}-* ({len(pkgs)} packages): rebuild")
    else:
        for p in pkgs:
            print(f"  {p}: rebuild")
print(f"\n=== ARCH SECURITY ADVISORIES (from security.archlinux.org) ===")
print("\n".join(security_matches) if security_matches else "  None matching")
print(f"\n=== UPSTREAM SECURITY BULLETINS (from project websites) ===")
print("\n".join(security_bulletins) if security_bulletins else "  None found")
print(f"\n=== UPSTREAM RELEASE NOTES ===")
print("\n".join(release_notes) if release_notes else "  None found")
print(f"\n=== ARCH NEWS ===")
print("\n".join(arch_news) if arch_news else "  None")
print(f"\n=== REBOOT NEEDED: {'YES (' + ', '.join(reboot_updating) + ')' if needs_reboot else 'NO'} ===")
PYEOF
        )

        if [ -z "$GATHERED_DATA" ]; then
            echo "(Failed to gather update data)"
            exit 0
        fi

        SYSTEM_PROMPT="You are a concise Arch Linux sysadmin. Write a bullet-point summary of this update report. One bullet per notable item.

RULES:
- UPSTREAM SECURITY BULLETINS: For each entry, list the package name, CVE ID(s), AND all vulnerability types mentioned (e.g. '* VLC 3.0.22: security release - CVE-2025-51602, buffer overflow, code execution, invalid free, out of bounds'). NEVER omit the vulnerability types.
- ARCH SECURITY ADVISORIES: 'ACTIVE' = NOT fixed by this update, still vulnerable. Say '* systemd: CVE-XXX remains UNFIXED after update (severity, type)'. 'FIXED in this update' = resolved by this update.
- Include ALL items from the security bulletins section - do not skip any.
- Rebuilds: one line with count.
- Copy the REBOOT line exactly as-is from the report.
- Do NOT add info not in the report. Do NOT summarize away vulnerability types.
- Use bullet points (*)."

        JSON_PAYLOAD=$(jq -n \
            --arg sys "$SYSTEM_PROMPT" \
            --arg usr "$GATHERED_DATA" \
            '{
                model: "llama-3.3-70b-versatile",
                messages: [
                    {role: "system", content: $sys},
                    {role: "user", content: $usr}
                ],
                temperature: 0.1,
                max_tokens: 800
            }')

        RESPONSE=$(curl -s --max-time 30 -X POST "https://api.groq.com/openai/v1/chat/completions" \
            -H "Authorization: Bearer ${GROQ_API_KEY}" \
            -H "Content-Type: application/json" \
            -d "$JSON_PAYLOAD" 2>/dev/null)

        MSG=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
        if [ -n "$MSG" ] && [ "$MSG" != "null" ]; then
            printf "%s" "$MSG"
        else
            # Fallback: just show the structured report directly
            echo "$GATHERED_DATA"
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
