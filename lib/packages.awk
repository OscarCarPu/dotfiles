# Extract the package list from docs/packages.md.
#
# Shared by install-packages.sh (what to install) and `install.sh --check`
# (what should be installed), so the two can never disagree about what the
# document says.
#
# Convention in packages.md: each list item starts "- `pkg`[, `pkg`]*" followed
# by optional " — prose" where further backticks are just references. Only the
# leading comma-separated run of backticked names is a package.
#
# Sections that are not managed by this repo are skipped:
#   - "Base system"                        (provided by the Artix install medium)
#   - "External programs (not via pacman)" (claude, bun)
#
# Set -v want_unmanaged=1 to invert that and emit only the skipped sections'
# entries instead (used by --check to avoid reporting them as drift).

/^## / {
    heading = substr($0, 4)
    unmanaged = (heading == "Base system" ||
                 heading == "External programs (not via pacman)")
    include = want_unmanaged ? unmanaged : !unmanaged
    next
}

include && /^- `[a-z0-9]/ {
    line = $0
    sub(/^- /, "", line)
    while (match(line, /^`[a-z0-9][a-z0-9._+-]*`/)) {
        print substr(line, RSTART + 1, RLENGTH - 2)
        line = substr(line, RSTART + RLENGTH)
        if (match(line, /^,[ \t]+/)) {
            line = substr(line, RSTART + RLENGTH)
        } else {
            break
        }
    }
}
