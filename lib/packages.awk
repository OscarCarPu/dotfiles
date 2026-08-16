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

    # A long list wraps onto the next line. Only follow the wrap when the line
    # ends in a comma — that is the one unambiguous signal the list is
    # unfinished. Continuation lines that are prose (`- `pkg` — text that
    # mentions `other-pkg`') never end in a comma, so their backticks stay
    # references rather than becoming phantom packages.
    #
    # Missing this used to silently drop 4 of the 7 texlive collections, so a
    # rebuilt machine got a LaTeX install that could not knit a PDF.
    while (line ~ /,[ \t]*$/) {
        if ((getline nextline) <= 0) break
        sub(/^[ \t]+/, "", nextline)
        line = line " " nextline
    }

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
