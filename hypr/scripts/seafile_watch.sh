#!/bin/bash
# Seafile sync health check. One pass; the `seafile-watch` runit service loops.
#
# Why this exists: the `seafile` service restarts a dead daemon every 30 s and
# says nothing, and `seaf-cli` itself never complains. So a library that stops
# syncing — Cloudflare 403ing the token, a full disk, a merge conflict — is
# silent, and ~26 GB of edu/docs/media quietly stops being backed up. The only
# signal today is remembering to run `seaf-cli status` by hand.
#
# Alerts on three things:
#   1. the daemon is unreachable
#   2. a library from configs/seafile-cli/libraries is missing from the status
#   3. a library has been in a non-synchronized state for longer than STALE_AFTER
#
# (3) is time-based on purpose: `uploading`/`committing`/`downloading` are
# perfectly normal for minutes at a time, and alerting on them would train you
# to ignore the notification. Only a state that will not clear is a problem.
set -uo pipefail

LIB_LIST="${SEAFILE_LIB_LIST:-$HOME/.dotfiles/configs/seafile-cli/libraries}"
STATE_FILE="${SEAFILE_WATCH_STATE:-$HOME/.cache/seafile_watch_state}"
STALE_AFTER="${SEAFILE_STALE_AFTER:-1800}" # seconds a library may stay unsynced

notify() {
    # -u critical so it survives do-not-disturb: this is a data-loss warning.
    notify-send -u "$1" -t 15000 "Seafile" "$2" 2>/dev/null || true
}

now=$(date +%s)
mkdir -p "$(dirname "$STATE_FILE")"

# Previous state: "<key> <first-seen-epoch>" per line. Used both to time how
# long a library has been unhealthy and to fire each alert only once.
declare -A since=()
if [ -f "$STATE_FILE" ]; then
    while read -r key ts; do
        [ -n "${key:-}" ] && since["$key"]=$ts
    done <"$STATE_FILE"
fi
declare -A new_since=()

mapfile -t libs < <(sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$LIB_LIST" 2>/dev/null | grep -v '^$')
[ "${#libs[@]}" -gt 0 ] || exit 0

# --- daemon reachable? ------------------------------------------------------
# `seaf-cli status` blocks on the daemon socket, so cap it: a hung daemon is
# itself the failure we are looking for.
if ! status=$(timeout 30 seaf-cli status 2>/dev/null); then
    prev=${since[__daemon__]:-0}
    if [ "$prev" -eq 0 ]; then
        new_since[__daemon__]=$now
        notify critical "Sync daemon is down — nothing is being backed up."
    else
        new_since[__daemon__]=$prev
    fi
    printf '%s %s\n' "__daemon__" "${new_since[__daemon__]}" >"$STATE_FILE"
    exit 0
fi
[ -n "${since[__daemon__]:-}" ] && notify normal "Sync daemon is back up."

# --- per-library state ------------------------------------------------------
declare -A state=()
while IFS=$'\t' read -r name st _rest; do
    [ -z "${name:-}" ] && continue
    case "$name" in '#'*) continue ;; esac
    # Columns are tab-padded; trim.
    name="${name%"${name##*[![:space:]]}"}"
    st="${st%"${st##*[![:space:]]}"}"
    state["$name"]="$st"
done <<<"$status"

problems=()
for lib in "${libs[@]}"; do
    st="${state[$lib]:-}"

    if [ -z "$st" ]; then
        key="missing:$lib"
        prev=${since[$key]:-0}
        new_since[$key]=$((prev == 0 ? now : prev))
        # No grace period: a library vanishing from the list is never transient.
        [ "$prev" -eq 0 ] && problems+=("$lib is not being synced at all")
        continue
    fi

    if [ "$st" = "synchronized" ]; then
        continue # healthy — drop any recorded first-seen so it can alert again later
    fi

    key="unsynced:$lib"
    prev=${since[$key]:-0}
    first=$((prev == 0 ? now : prev))
    new_since[$key]=$first
    elapsed=$((now - first))

    if [ "$elapsed" -ge "$STALE_AFTER" ]; then
        # Alert once per episode: mark it so the next pass stays quiet.
        if [ -z "${since[alerted:$lib]:-}" ]; then
            new_since["alerted:$lib"]=$now
            problems+=("$lib stuck in '$st' for $((elapsed / 60)) min")
        else
            new_since["alerted:$lib"]=${since[alerted:$lib]}
        fi
    fi
done

# Recovery notice for anything that was alerted on and is now synchronized.
for key in "${!since[@]}"; do
    case "$key" in
    alerted:*)
        lib="${key#alerted:}"
        [ "${state[$lib]:-}" = "synchronized" ] && notify normal "$lib is synchronized again."
        ;;
    esac
done

if [ "${#problems[@]}" -gt 0 ]; then
    notify critical "$(printf '%s\n' "${problems[@]}")"
fi

: >"$STATE_FILE"
for key in "${!new_since[@]}"; do
    printf '%s %s\n' "$key" "${new_since[$key]}" >>"$STATE_FILE"
done
