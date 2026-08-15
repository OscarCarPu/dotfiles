#!/usr/bin/env python3
"""Resolve pacman's .pacnew config files automatically.

pacman never overwrites a config file you have edited. It drops the new default
next to it as `<file>.pacnew` and leaves the decision to you — the decision
`pacdiff` walks you through one file at a time. This script makes it instead.

It is a real 3-way merge wherever possible: the pristine *old* default is
extracted from the previously installed package in /var/cache/pacman/pkg, and
`git merge-file` reconciles your edits against the upstream changes. Most
.pacnew files resolve cleanly that way with no model involved. claude is
invoked only for the hunks git cannot reconcile, and for files with no cached
base, where there is no third point to triangulate from.

Nothing boot-critical or login-critical is ever touched automatically (DENY):
a bad merge in those lands you at a broken boot or a login you cannot pass,
and this runs unattended right before a possible shutdown. Everything applied
is backed up first and printed as a diff.

Usage:
  merge_pacnew.py [--dry-run] [--no-claude] [file.pacnew ...]
Discovers via `pacdiff -o` when given no files.
"""

from __future__ import annotations

import difflib
import fnmatch
import os
import pwd
import grp
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

# <name>-<ver>-<rel>-<arch>.pkg.tar.<ext>; name may contain hyphens, ver may
# carry an epoch (ffmpeg-2:9.0.1-1-x86_64.pkg.tar.zst).
PKGFILE = re.compile(r"^(?P<name>.+)-(?P<ver>[^-]+-[^-]+)-(?P<arch>[^-]+)\.pkg\.tar\.\w+$")

BOLD = "\033[1m"
CYAN = "\033[1;36m"
GREEN = "\033[1;32m"
YELLOW = "\033[1;33m"
GRAY = "\033[0;90m"
RED = "\033[1;31m"
MAGENTA = "\033[1;35m"
RESET = "\033[0m"

# Never merged automatically. A wrong merge here does not mean a broken app,
# it means an unbootable system or an account you cannot log into — and there
# is no one watching when this runs.
DENY = [
    "/etc/fstab", "/etc/crypttab*", "/etc/default/grub", "/boot/*",
    "/etc/mkinitcpio.conf", "/etc/mkinitcpio.d/*", "/etc/mkinitcpio.conf.d/*",
    "/etc/passwd", "/etc/shadow", "/etc/group", "/etc/gshadow",
    "/etc/subuid", "/etc/subgid", "/etc/securetty", "/etc/shells",
    "/etc/sudoers", "/etc/sudoers.d/*", "/etc/pam.d/*", "/etc/nsswitch.conf",
    "/etc/ssh/sshd_config", "/etc/runit/*",
]

# Syntax checks worth running before committing to a merge. {} is the file.
VALIDATORS = {
    "/etc/pacman.conf": ["pacman-conf", "--config", "{}"],
    "/etc/pacman.d/mirrorlist": ["pacman-conf", "--config", "{}"],
    "/etc/locale.gen": None,
}

CACHE_DIR = Path("/var/cache/pacman/pkg")
BACKUP_DIR = Path(
    os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")
) / "hypr" / "pacnew-backups"
MAX_SIZE = 256 * 1024
CLAUDE_TIMEOUT = 120


def run(cmd: list[str], **kw) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def denied(path: str) -> bool:
    return any(fnmatch.fnmatch(path, pat) for pat in DENY)


def discover() -> list[str]:
    r = run(["pacdiff", "-o"])
    if r.returncode == 0 and r.stdout.strip():
        return [l for l in r.stdout.split() if l.endswith(".pacnew")]
    out = run(["find", "/etc", "-name", "*.pacnew"]).stdout
    return [l for l in out.split() if l]


def owner_package(live: str) -> str | None:
    r = run(["pacman", "-Qoq", live])
    return r.stdout.strip() or None if r.returncode == 0 else None


def installed_version(pkg: str) -> str | None:
    r = run(["pacman", "-Q", pkg])
    parts = r.stdout.split()
    return parts[1] if r.returncode == 0 and len(parts) > 1 else None


def vercmp(a: str, b: str) -> int:
    """<0 if a is older, 0 if equal, >0 if a is newer. pacman's own ordering."""
    try:
        return int(run(["vercmp", a, b]).stdout.strip())
    except ValueError:
        return 0


def cached_base(pkg: str, current: str, live: str) -> bytes | None:
    """Pristine copy of `live` from the newest cached package older than the
    installed one — i.e. the default you originally edited away from."""
    if not CACHE_DIR.is_dir():
        return None
    best, best_ver = None, None
    for f in CACHE_DIR.glob(f"{pkg}-*.pkg.tar*"):
        m = PKGFILE.match(f.name)
        # The glob also catches longer names (`gcc-` matches `gcc-libs-...`),
        # so the parsed name has to match exactly.
        if not m or m.group("name") != pkg:
            continue
        ver = m.group("ver")
        if vercmp(ver, current) >= 0:                 # only strictly older
            continue
        if best_ver is None or vercmp(ver, best_ver) > 0:
            best, best_ver = f, ver
    if best is None:
        return None
    r = subprocess.run(
        ["bsdtar", "-xOf", str(best), live.lstrip("/")],
        capture_output=True, timeout=60,
    )
    return r.stdout if r.returncode == 0 and r.stdout else None


def three_way(live_b: bytes, base_b: bytes, new_b: bytes) -> tuple[int, str]:
    """git merge-file: rc 0 = clean, >0 = that many conflicts left in output."""
    with tempfile.TemporaryDirectory() as td:
        p = {}
        for name, data in (("live", live_b), ("base", base_b), ("new", new_b)):
            p[name] = os.path.join(td, name)
            with open(p[name], "wb") as fh:
                fh.write(data)
        r = subprocess.run(
            ["git", "merge-file", "-p", "--diff3",
             "-L", "yours", "-L", "old package default", "-L", "new package default",
             p["live"], p["base"], p["new"]],
            capture_output=True, text=True,
        )
        return r.returncode, r.stdout


def claude_merge(live: str, yours: str, theirs: str,
                 conflicted: str | None) -> str | None:
    claude_bin = (
        run(["which", "claude"]).stdout.strip() or
        str(Path.home() / ".local/bin/claude")
    )
    if conflicted:
        body = (
            f"A 3-way merge left conflicts. Resolve every conflict marker and "
            f"return the finished file.\n\n"
            f"--- merge output with conflicts ---\n{conflicted}\n"
        )
    else:
        body = (
            f"There is no cached base to diff against, so merge these two "
            f"directly.\n\n"
            f"--- your current file ---\n{yours}\n\n"
            f"--- new package default ---\n{theirs}\n"
        )
    prompt = (
        f"You are merging a pacman .pacnew config file on Artix Linux: {live}\n\n"
        f"Keep every local customization from the current file. Adopt upstream's "
        f"new options, renamed keys, changed defaults and comment updates. When a "
        f"local value and an upstream value collide on the same setting, the local "
        f"value wins — that is the edit the user made on purpose.\n\n"
        f"{body}\n"
        f"Output ONLY the complete merged file. No explanation, no markdown "
        f"fences, no leading or trailing blank commentary. The output is written "
        f"to disk verbatim."
    )
    try:
        r = subprocess.run(
            [claude_bin, "--print", prompt],
            capture_output=True, text=True, timeout=CLAUDE_TIMEOUT,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return None
    if r.returncode != 0 or not r.stdout.strip():
        return None
    return strip_fences(r.stdout)


def strip_fences(text: str) -> str:
    lines = text.split("\n")
    while lines and not lines[0].strip():
        lines.pop(0)
    while lines and not lines[-1].strip():
        lines.pop()
    if lines and lines[0].lstrip().startswith("```"):
        lines.pop(0)
        if lines and lines[-1].strip().startswith("```"):
            lines.pop()
    return "\n".join(lines) + "\n"


def sane(merged: str, yours: str, theirs: str) -> str | None:
    """Cheap guards against a merge that would destroy the file."""
    if not merged.strip():
        return "empty result"
    for marker in ("<<<<<<<", "=======", ">>>>>>>", "|||||||"):
        if any(l.startswith(marker) for l in merged.split("\n")):
            return "conflict markers left in the result"
    floor = 0.4 * max(len(yours.split("\n")), len(theirs.split("\n")))
    if len(merged.split("\n")) < floor:
        return "result is suspiciously short (possible truncation)"
    return None


def validate(path: str, content: str) -> str | None:
    spec = next((v for k, v in VALIDATORS.items() if fnmatch.fnmatch(path, k)), None)
    if not spec:
        return None
    with tempfile.NamedTemporaryFile("w", suffix=".check", delete=False) as fh:
        fh.write(content)
        tmp = fh.name
    try:
        r = run([a.replace("{}", tmp) for a in spec])
        if r.returncode != 0:
            return (r.stderr.strip() or r.stdout.strip() or "validator failed")[:200]
    finally:
        os.unlink(tmp)
    return None


def write_file(target: str, content: str) -> str | None:
    st = os.stat(target)
    with tempfile.NamedTemporaryFile("w", delete=False) as fh:
        fh.write(content)
        tmp = fh.name
    try:
        try:
            shutil.copyfile(tmp, target)
            return None
        except PermissionError:
            pass
        owner = pwd.getpwuid(st.st_uid).pw_name
        group = grp.getgrgid(st.st_gid).gr_name
        r = run(["sudo", "install", "-m", oct(st.st_mode & 0o7777)[2:],
                 "-o", owner, "-g", group, tmp, target])
        return None if r.returncode == 0 else (r.stderr.strip() or "install failed")
    finally:
        os.unlink(tmp)


def backup(target: str, content: str) -> Path:
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    dest = BACKUP_DIR / f"{target.strip('/').replace('/', '_')}.{stamp}"
    dest.write_text(content)
    return dest


def show_diff(path: str, before: str, after: str, limit: int = 30) -> None:
    diff = list(difflib.unified_diff(
        before.split("\n"), after.split("\n"),
        fromfile=f"{path} (yours)", tofile=f"{path} (merged)", lineterm="", n=1,
    ))
    for line in diff[:limit]:
        if line.startswith("+"):
            print(f"  {GREEN}{line}{RESET}")
        elif line.startswith("-"):
            print(f"  {RED}{line}{RESET}")
        else:
            print(f"  {GRAY}{line}{RESET}")
    if len(diff) > limit:
        print(f"  {GRAY}... {len(diff) - limit} more diff lines{RESET}")


def handle(pacnew: str, dry: bool, allow_claude: bool) -> str:
    live = pacnew[: -len(".pacnew")]
    print(f"\n{CYAN}▸ {live}{RESET}")

    if denied(live):
        print(f"  {YELLOW}skipped — on the do-not-touch list; merge it yourself{RESET}")
        return "skipped"
    if not os.path.exists(live):
        print(f"  {YELLOW}skipped — {live} does not exist{RESET}")
        return "skipped"
    if os.path.getsize(pacnew) > MAX_SIZE or os.path.getsize(live) > MAX_SIZE:
        print(f"  {YELLOW}skipped — larger than {MAX_SIZE // 1024} KiB{RESET}")
        return "skipped"

    try:
        yours = Path(live).read_text()
        theirs = Path(pacnew).read_text()
    except (OSError, UnicodeDecodeError) as e:
        print(f"  {YELLOW}skipped — cannot read ({e}){RESET}")
        return "skipped"

    # Writing through a symlink would silently edit whatever it points at, so
    # resolve it: on this machine several /etc configs are symlinks into the
    # dotfiles repo, where the change should land and show up in `git diff`.
    target = os.path.realpath(live)
    if target != os.path.abspath(live):
        print(f"  {GRAY}symlink -> {target}{RESET}")

    if yours == theirs:
        print(f"  {GREEN}identical — dropping the .pacnew{RESET}")
        if not dry:
            run(["sudo", "rm", "-f", pacnew])
        return "merged"

    pkg = owner_package(live)
    base_b = None
    if pkg:
        ver = installed_version(pkg)
        if ver:
            base_b = cached_base(pkg, ver, live)

    source, merged, conflicted = None, None, None
    if base_b is not None:
        try:
            rc, out = three_way(yours.encode(), base_b, theirs.encode())
        except OSError:
            rc, out = -1, ""
        if rc == 0:
            merged, source = out, "3-way merge (clean, no model)"
        elif rc > 0:
            conflicted = out
            print(f"  {GRAY}3-way merge left {rc} conflict(s) — asking claude{RESET}")
    else:
        print(f"  {GRAY}no cached base for {pkg or 'unknown package'}{RESET}")

    if merged is None:
        if not allow_claude:
            print(f"  {YELLOW}skipped — needs claude and --no-claude was given{RESET}")
            return "skipped"
        merged = claude_merge(live, yours, theirs, conflicted)
        source = "claude" + (" (conflicts)" if conflicted else " (no base)")
        if merged is None:
            print(f"  {RED}skipped — claude produced nothing usable{RESET}")
            return "failed"

    why = sane(merged, yours, theirs)
    if why:
        print(f"  {RED}skipped — {why}{RESET}")
        return "failed"
    why = validate(live, merged)
    if why:
        print(f"  {RED}skipped — syntax check failed: {why}{RESET}")
        return "failed"

    if merged == yours:
        print(f"  {GREEN}merge is a no-op — dropping the .pacnew{RESET} {GRAY}[{source}]{RESET}")
        if not dry:
            run(["sudo", "rm", "-f", pacnew])
        return "merged"

    print(f"  {GRAY}[{source}]{RESET}")
    show_diff(live, yours, merged)

    if dry:
        print(f"  {GRAY}dry-run — nothing written{RESET}")
        return "merged"

    b = backup(target, yours)
    err = write_file(target, merged)
    if err:
        print(f"  {RED}write failed: {err}{RESET}")
        return "failed"
    run(["sudo", "rm", "-f", pacnew])
    print(f"  {GREEN}merged{RESET}  {GRAY}backup: {b}{RESET}")
    return "merged"


def main() -> int:
    args = sys.argv[1:]
    dry = "--dry-run" in args
    allow_claude = "--no-claude" not in args
    files = [a for a in args if not a.startswith("--")] or discover()
    files = sorted(set(files))
    if not files:
        return 0

    print(f"\n{BOLD}[ Config files pacman left for you (.pacnew) ]{RESET}")
    counts: dict[str, int] = {}
    for f in files:
        try:
            r = handle(f, dry, allow_claude)
        except Exception as e:                       # never break the update flow
            print(f"  {RED}error: {e}{RESET}")
            r = "failed"
        counts[r] = counts.get(r, 0) + 1

    print()
    parts = []
    if counts.get("merged"):
        parts.append(f"{GREEN}{counts['merged']} merged{RESET}")
    if counts.get("skipped"):
        parts.append(f"{YELLOW}{counts['skipped']} skipped{RESET}")
    if counts.get("failed"):
        parts.append(f"{RED}{counts['failed']} failed{RESET}")
    print("  " + ", ".join(parts))
    if counts.get("skipped") or counts.get("failed"):
        print(f"  {GRAY}Left as .pacnew — run `sudo pacdiff` to handle them.{RESET}")
    if counts.get("merged") and not dry:
        print(f"  {GRAY}Backups in {BACKUP_DIR}{RESET}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
