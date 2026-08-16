#!/usr/bin/env bash
# Claude Code status line: model · effort · context usage bar + percentage
# Receives the status line JSON payload on stdin.
set -uo pipefail

input=$(cat)

# One jq pass, one value per line (model names contain spaces).
{
  read -r model
  read -r effort
  read -r pct
} < <(jq -r '
  (.model.display_name // "?"),
  (.effort.level // "-"),
  (.context_window.used_percentage // 0)
' <<<"$input")

[[ $pct =~ ^[0-9]+$ ]] || pct=0

esc=$'\033'
reset="${esc}[0m"; dim="${esc}[2m"; bold="${esc}[1m"
cyan="${esc}[36m"; magenta="${esc}[35m"
green="${esc}[32m"; yellow="${esc}[33m"; red="${esc}[31m"

if   (( pct >= 80 )); then col=$red
elif (( pct >= 60 )); then col=$yellow
else                       col=$green
fi

width=12
filled=$(( (pct * width + 50) / 100 ))
(( filled > width )) && filled=$width
(( filled < 0 )) && filled=0
empty=$(( width - filled ))

bar=""; for ((i = 0; i < filled; i++)); do bar+="█"; done
rest=""; for ((i = 0; i < empty;  i++)); do rest+="░"; done

out="${cyan}${bold}${model}${reset}"
[[ $effort != "-" ]] && out+="  ${dim}·${reset}  ${magenta}effort ${effort}${reset}"
out+="  ${dim}·${reset}  ${col}${bar}${reset}${dim}${rest}${reset} ${col}${pct}%${reset} ${dim}ctx${reset}"

printf '%s' "$out"
