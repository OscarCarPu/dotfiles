#!/bin/sh
# git clean/smudge filter for OrcaSlicer machine profiles.
#
# OrcaSlicer stores the PrusaLink password inline in the printer preset, and
# `~/.config/OrcaSlicer/user/default/machine` is a symlink into this repo — so
# the file the slicer reads and writes IS the tracked file. A plain .gitignore
# would drop the whole profile; stripping the field by hand would break
# uploads. A filter pair solves both:
#
#   clean  (working tree -> index):  blanks printhost_password
#   smudge (index -> working tree):  injects it from secrets.env
#
# Net effect: the slicer always sees the real password, git only ever sees "".
# Edits to any other setting still diff and commit normally.
#
# Registered in the repo-local git config by install.sh (never committed, so a
# fresh clone checks out the blank placeholder until install.sh runs).
#
# Usage: secret-filter.sh clean|smudge   (content on stdin, result on stdout)
set -eu

FIELD='printhost_password'
SECRETS="${DOTFILES_SECRETS:-$HOME/.config/dotfiles/secrets.env}"

case "${1:-}" in
clean)
    # Never let a value reach the index, whatever is in the working tree.
    exec sed -E "s|(\"$FIELD\"[[:space:]]*:[[:space:]]*\")[^\"]*(\")|\1\2|"
    ;;
smudge)
    value=""
    if [ -r "$SECRETS" ]; then
        # shellcheck source=/dev/null
        . "$SECRETS"
        value="${ORCA_PRINTHOST_PASSWORD:-}"
    fi
    # No secrets file (or empty value): pass through untouched so a fresh clone
    # still checks out cleanly instead of failing the checkout.
    [ -n "$value" ] || exec cat
    # `sed` special characters in a password would corrupt the replacement, so
    # escape the delimiter and backslashes.
    esc=$(printf '%s' "$value" | sed -e 's/[\\|&]/\\&/g')
    exec sed -E "s|(\"$FIELD\"[[:space:]]*:[[:space:]]*\")[^\"]*(\")|\1$esc\2|"
    ;;
*)
    echo "usage: $0 clean|smudge" >&2
    exit 2
    ;;
esac
