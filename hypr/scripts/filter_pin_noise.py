#!/usr/bin/env python3
"""Drop pacman/yay 'ignoring package' warnings without breaking interactivity.

Pacman writes both warnings and prompts to stderr, and prompts are partial-line
writes (no trailing newline). A plain `grep -v` buffers the whole stream until
a newline appears, so prompts disappear until pacman closes the stream — at
which point it's far too late to type a response.

Strategy: read bytes one at a time. Lines that could match the noise prefix
(`advertencia:` / `warning:`) are buffered until newline, then matched/dropped.
Anything else is recognised after the first byte and switches to passthrough
(immediate per-char flush) for the rest of the line. Prompts always start with
`::` or other non-`warning` prefixes, so they reach the user instantly.

Designed for: `cmd 2> >(filter_pin_noise.py >&2)`.
"""

from __future__ import annotations

import re
import sys

NOISE = re.compile(rb"^(advertencia|warning):\s*(\S+:\s*)?ignor(and|ing)")
NOISE_PREFIXES = (b"advertencia:", b"warning:")


def could_be_noise(buf: bytes) -> bool:
    """True while `buf` is still a viable prefix of a noise line."""
    return any(p.startswith(buf) or buf.startswith(p) for p in NOISE_PREFIXES)


def main() -> int:
    out = sys.stderr.buffer
    buf = bytearray()
    passthrough = False

    while True:
        c = sys.stdin.buffer.read(1)
        if not c:
            if buf:
                out.write(bytes(buf))
                out.flush()
            return 0

        if passthrough:
            out.write(c)
            out.flush()
            if c == b"\n":
                passthrough = False
                buf = bytearray()
            continue

        buf += c
        if c == b"\n":
            if not NOISE.match(bytes(buf)):
                out.write(bytes(buf))
                out.flush()
            buf = bytearray()
        elif not could_be_noise(bytes(buf)):
            out.write(bytes(buf))
            out.flush()
            buf = bytearray()
            passthrough = True


if __name__ == "__main__":
    sys.exit(main())
