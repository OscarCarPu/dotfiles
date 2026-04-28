#!/usr/bin/env python3
"""Print upstream release notes for the given packages.

Strategy: read each package's URL from `pacman -Si`. If it points to GitHub,
fetch the latest release via the API. Falls back to recent Arch packaging
commit titles (from gitlab.archlinux.org) when there is no GitHub release.

Usage: release_notes.py pkg1 pkg2 pkg3 ...
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from urllib.error import URLError
from urllib.request import Request, urlopen

UA = {"User-Agent": "arch-update-helper/1.0"}
TIMEOUT = 8

CYAN = "\033[1;36m"
GRAY = "\033[0;90m"
RESET = "\033[0m"


def pacman_url(pkg: str) -> str | None:
    try:
        r = subprocess.run(
            ["pacman", "-Si", pkg], capture_output=True, text=True, timeout=3
        )
    except Exception:
        return None
    m = re.search(r"^URL\s*:\s*(\S+)", r.stdout, re.M)
    return m.group(1).rstrip("/") if m else None


def fetch_github(repo: str) -> str | None:
    try:
        req = Request(
            f"https://api.github.com/repos/{repo}/releases/latest", headers=UA
        )
        rel = json.loads(urlopen(req, timeout=TIMEOUT).read())
    except (URLError, json.JSONDecodeError, TimeoutError, OSError):
        return None
    tag = rel.get("tag_name") or ""
    body = (rel.get("body") or "").strip()
    body = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", body)  # [text](url) -> text
    body = re.sub(r"<!--.*?-->", "", body, flags=re.S)
    body = re.sub(r"\n{3,}", "\n\n", body).strip()
    if not body:
        return f"{tag} (no release notes)" if tag else None
    # First non-empty paragraph, capped
    paras = [p.strip() for p in re.split(r"\n\n+", body) if p.strip()]
    first = paras[0][:500] if paras else body[:500]
    return f"{tag}\n{first}"


def fetch_arch_commits(pkg: str) -> str | None:
    api = (
        f"https://gitlab.archlinux.org/api/v4/projects/"
        f"archlinux%2Fpackaging%2Fpackages%2F{pkg}/repository/commits?per_page=3"
    )
    try:
        commits = json.loads(urlopen(Request(api, headers=UA), timeout=TIMEOUT).read())
    except (URLError, json.JSONDecodeError, TimeoutError, OSError):
        return None
    titles = [c.get("title", "").strip() for c in commits[:3] if c.get("title")]
    if not titles:
        return None
    return "recent packaging commits:\n" + "\n".join(f"  - {t}" for t in titles)


def fetch_one(pkg: str) -> tuple[str, str | None]:
    url = pacman_url(pkg)
    if url:
        m = re.match(r"https?://github\.com/([^/]+/[^/]+)", url)
        if m:
            note = fetch_github(m.group(1))
            if note:
                return pkg, note
    note = fetch_arch_commits(pkg)
    return pkg, note


def main() -> int:
    pkgs = sys.argv[1:]
    if not pkgs:
        return 0
    with ThreadPoolExecutor(max_workers=8) as pool:
        futures = {pool.submit(fetch_one, p): p for p in pkgs}
        results: dict[str, str | None] = {}
        for f in as_completed(futures, timeout=30):
            try:
                pkg, note = f.result()
                results[pkg] = note
            except Exception:
                pass
    # Print in original order so the eye matches the listing above.
    for pkg in pkgs:
        note = results.get(pkg)
        if note:
            print(f"{CYAN}▸ {pkg}{RESET} {note}")
        else:
            print(f"{GRAY}▸ {pkg} — no notes{RESET}")
        print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
