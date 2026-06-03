#!/usr/bin/env python3
"""Check pinned package blockers via parallel claude CLI calls.

Reads `tracked_blockers.json` (next to this script). Each entry binds a list
of pacman packages to a human reason and optionally one or more GitHub
PRs/issues. Blockers without upstream refs (e.g. repo lag) get pacman repo
data passed to Claude instead.

Modes:
  tracked_blockers.py pkg1 pkg2 ...           Print live Claude assessment block
  tracked_blockers.py --refs pkg1 pkg2 ...    Print `pkg<TAB>repo#num` (offline, fast)
Both modes also accept package names on stdin.
"""

from __future__ import annotations

import json
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from urllib.request import Request, urlopen

DATA_FILE = Path(__file__).with_name("tracked_blockers.json")
UA = {"User-Agent": "arch-update-helper/1.0"}
TIMEOUT = 10

BOLD   = "\033[1m"
CYAN   = "\033[1;36m"
YELLOW = "\033[1;33m"
GRAY   = "\033[0;90m"
RED    = "\033[1;31m"
RESET  = "\033[0m"


def fetch_text(url: str) -> str:
    try:
        return urlopen(Request(url, headers=UA), timeout=TIMEOUT).read().decode()
    except Exception:
        return ""


def fetch_pacman_info(packages: list[str]) -> str:
    try:
        result = subprocess.run(
            ["pacman", "-Si"] + packages,
            capture_output=True, text=True, timeout=10,
        )
        return result.stdout.strip()
    except Exception:
        return ""


def assess_blocker(entry: dict, skipped: dict[str, str]) -> str:
    ref_sections = []
    for ref in entry.get("tracking", []):
        kind, repo, number = ref["kind"], ref["repo"], ref["number"]
        path = "pulls" if kind == "pr" else "issues"
        url = f"https://api.github.com/repos/{repo}/{path}/{number}"
        html_url = f"https://github.com/{repo}/{'pull' if kind == 'pr' else 'issues'}/{number}"

        raw = fetch_text(url)
        try:
            data = json.loads(raw)
            meta: dict[str, object] = {
                "url":             html_url,
                "state":           data.get("state"),
                "merged":          data.get("merged"),
                "title":           data.get("title"),
                "body":            (data.get("body") or "")[:600],
                "updated_at":      data.get("updated_at"),
                "mergeable_state": data.get("mergeable_state"),
            }
        except Exception:
            meta: dict[str, object] = {"url": html_url, "error": "fetch failed"}

        if kind == "pr":
            comments_url = (
                f"https://api.github.com/repos/{repo}/issues/{number}"
                f"/comments?per_page=5&direction=desc"
            )
            try:
                comments = json.loads(fetch_text(comments_url))
                meta["recent_comments"] = [
                    {"author": c["user"]["login"], "body": c["body"][:200]}
                    for c in comments[-3:]
                ]
            except Exception:
                pass

        ref_sections.append(meta)

    incoming = "\n".join(
        f"  {pkg}  {ver}" for pkg, ver in skipped.items() if ver
    ) or "  (none)"

    if ref_sections:
        context = f"Live upstream PR/issue data:\n{json.dumps(ref_sections, indent=2)}"
    else:
        pacman_info = fetch_pacman_info(list(entry.get("packages", [])))
        context = (
            f"No upstream PR/issue tracked. Current pacman repo state for pinned packages:\n"
            f"{pacman_info or '(pacman -Si returned nothing)'}"
        )

    prompt = (
        f"You are checking whether a pinned Arch Linux package blocker is resolved.\n\n"
        f"Blocker: {entry['name']}\n"
        f"Reason pinned: {entry['reason']}\n"
        f"Pinned packages with available upstream versions:\n{incoming}\n\n"
        f"{context}\n\n"
        f"Is this blocker resolved or still active?\n"
        f"Give a 1-2 sentence direct assessment.\n"
        f"If resolved: say which version contains the fix and whether it is in the incoming list.\n"
        f"If still active: say why, and whether there has been recent activity or it looks stalled."
    )

    claude_bin = (
        subprocess.run(["which", "claude"], capture_output=True, text=True).stdout.strip()
        or "/home/ocp/.local/bin/claude"
    )
    try:
        result = subprocess.run(
            [claude_bin, "--print", prompt],
            capture_output=True, text=True, timeout=60,
        )
        return result.stdout.strip() or result.stderr.strip() or "(no response)"
    except FileNotFoundError:
        return "(claude CLI not found)"
    except subprocess.TimeoutExpired:
        return "(claude timed out)"
    except Exception as e:
        return f"(error: {e})"


def collect_skipped(argv: list[str]) -> dict[str, str]:
    raw = argv if argv else [line.rstrip("\n") for line in sys.stdin]
    out: dict[str, str] = {}
    for it in raw:
        if not it.strip():
            continue
        toks = it.replace("\t", " ").split(None, 1)
        out[toks[0]] = toks[1].strip() if len(toks) > 1 else ""
    return out


def load_entries() -> list[dict]:
    return json.loads(DATA_FILE.read_text())


def primary_ref(entry: dict) -> dict | None:
    return next((t for t in entry["tracking"] if t["kind"] == "pr"), None) \
        or next(iter(entry.get("tracking", [])), None)


def cmd_refs(skipped: dict[str, str]) -> int:
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
        print(f"{RED}tracked_blockers: cannot read {DATA_FILE}: {e}{RESET}", file=sys.stderr)
        return 1

    skipped_set = set(skipped)
    relevant = [e for e in entries if set(e.get("packages", [])) & skipped_set]
    if not relevant:
        return 0

    with ThreadPoolExecutor(max_workers=8) as pool:
        futs = {
            pool.submit(
                assess_blocker,
                entry,
                {p: skipped[p] for p in entry["packages"] if p in skipped},
            ): entry["name"]
            for entry in relevant
        }
        assessments: dict[str, str] = {}
        for f in as_completed(futs, timeout=90):
            name = futs[f]
            try:
                assessments[name] = f.result()
            except Exception:
                assessments[name] = "(error)"

    print(f"\n{BOLD}[ Tracked blockers ]{RESET}")
    for entry in relevant:
        covered = sorted(set(entry["packages"]) & skipped_set)
        print(f"{CYAN}▸ {entry['name']}{RESET}")
        if entry.get("reason"):
            print(f"  {GRAY}Why: {entry['reason']}{RESET}")
        if covered and any(skipped[p] for p in covered):
            width = max(len(p) for p in covered)
            print(f"  {GRAY}Pins covered ({len(covered)}):{RESET}")
            for p in covered:
                ver = skipped[p]
                print(f"  {GRAY}  {p:<{width}}  {ver}{RESET}")
        else:
            print(f"  {GRAY}Pins covered: {', '.join(covered)}{RESET}")
        assessment = assessments.get(entry["name"], "")
        if assessment:
            print(f"  {YELLOW}{assessment}{RESET}")
        print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
