#!/usr/bin/env python3
"""Look up upstream PR/issue refs for currently-pinned (IgnorePkg) packages.

Reads `tracked_prs.json` (next to this script). Each entry binds a list of
pacman packages to one or more GitHub PRs/issues that need to merge/close
before the pin can be lifted.

Modes:
  tracked_prs.py pkg1 pkg2 ...           Print live status block
  tracked_prs.py --refs pkg1 pkg2 ...    Print `pkg<TAB>repo#num` (offline, fast)
Both modes also accept package names on stdin.
"""

from __future__ import annotations

import json
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from urllib.error import URLError
from urllib.request import Request, urlopen

UA = {"User-Agent": "arch-update-helper/1.0"}
TIMEOUT = 8

BOLD = "\033[1m"
CYAN = "\033[1;36m"
GREEN = "\033[1;32m"
YELLOW = "\033[1;33m"
RED = "\033[1;31m"
GRAY = "\033[0;90m"
RESET = "\033[0m"

DATA_FILE = Path(__file__).with_name("tracked_prs.json")


def fetch_github(repo: str, number: int, kind: str) -> dict | None:
    path = "pulls" if kind == "pr" else "issues"
    url = f"https://api.github.com/repos/{repo}/{path}/{number}"
    try:
        return json.loads(urlopen(Request(url, headers=UA), timeout=TIMEOUT).read())
    except (URLError, json.JSONDecodeError, TimeoutError, OSError):
        return None


def fmt_date(s: str | None) -> str:
    return s[:10] if s else "?"


def render_pr(repo: str, number: int, data: dict | None) -> tuple[str, bool]:
    """Return (line, is_resolved)."""
    label = f"PR    {repo}#{number}"
    if data is None:
        return f"  {label}  {GRAY}(fetch failed){RESET}", False
    state = data.get("state", "?")
    merged = bool(data.get("merged"))
    updated = fmt_date(data.get("updated_at"))
    if merged:
        merged_at = fmt_date(data.get("merged_at"))
        return (
            f"  {label}  {GREEN}MERGED {merged_at}{RESET}  → ready to unpin",
            True,
        )
    if state == "closed":
        return (
            f"  {label}  {YELLOW}closed without merge{RESET}  updated {updated}",
            False,
        )
    draft = " (draft)" if data.get("draft") else ""
    mergeable = data.get("mergeable_state", "?")
    return (
        f"  {label}  {YELLOW}open{draft}{RESET}  mergeable={mergeable}  updated {updated}",
        False,
    )


def render_issue(repo: str, number: int, data: dict | None) -> tuple[str, bool]:
    label = f"Issue {repo}#{number}"
    if data is None:
        return f"  {label}  {GRAY}(fetch failed){RESET}", False
    state = data.get("state", "?")
    updated = fmt_date(data.get("updated_at"))
    if state == "closed":
        closed_at = fmt_date(data.get("closed_at"))
        return f"  {label}  {GREEN}closed {closed_at}{RESET}", True
    return f"  {label}  {YELLOW}open{RESET}  updated {updated}", False


def collect_skipped(argv: list[str]) -> set[str]:
    if argv:
        return set(argv)
    return {line.strip() for line in sys.stdin if line.strip()}


def load_entries() -> list[dict]:
    return json.loads(DATA_FILE.read_text())


def primary_ref(entry: dict) -> dict | None:
    """Pick the most actionable tracking ref: prefer PR over issue."""
    return next((t for t in entry["tracking"] if t["kind"] == "pr"), None) \
        or next(iter(entry.get("tracking", [])), None)


def cmd_refs(skipped: set[str]) -> int:
    for entry in load_entries():
        ref = primary_ref(entry)
        if not ref:
            continue
        label = f"{ref['repo']}#{ref['number']}"
        for pkg in entry["packages"]:
            if pkg in skipped:
                print(f"{pkg}\t{label}")
    return 0


def main() -> int:
    argv = sys.argv[1:]
    if argv and argv[0] == "--refs":
        return cmd_refs(collect_skipped(argv[1:]))

    skipped = collect_skipped(argv)
    if not skipped:
        return 0
    try:
        entries = load_entries()
    except (OSError, json.JSONDecodeError) as e:
        print(f"{RED}tracked_prs: cannot read {DATA_FILE}: {e}{RESET}", file=sys.stderr)
        return 1

    relevant = [e for e in entries if set(e.get("packages", [])) & skipped]
    if not relevant:
        return 0

    refs = [(t["kind"], t["repo"], t["number"]) for e in relevant for t in e["tracking"]]
    with ThreadPoolExecutor(max_workers=8) as pool:
        futs = {pool.submit(fetch_github, repo, num, kind): (kind, repo, num)
                for kind, repo, num in refs}
        results: dict[tuple, dict | None] = {}
        for f in as_completed(futs, timeout=30):
            key = futs[f]
            try:
                results[key] = f.result()
            except Exception:
                results[key] = None

    print(f"\n{BOLD}[ Tracked blockers ]{RESET}")
    for entry in relevant:
        covered = sorted(set(entry["packages"]) & skipped)
        print(f"{CYAN}▸ {entry['name']}{RESET}")
        if entry.get("reason"):
            print(f"  {GRAY}Why: {entry['reason']}{RESET}")
        print(f"  {GRAY}Pins covered: {', '.join(covered)}{RESET}")
        for ref in entry["tracking"]:
            key = (ref["kind"], ref["repo"], ref["number"])
            data = results.get(key)
            if ref["kind"] == "pr":
                line, _ = render_pr(ref["repo"], ref["number"], data)
            else:
                line, _ = render_issue(ref["repo"], ref["number"], data)
            print(line)
        print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
