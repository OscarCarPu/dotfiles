# OPENSPEC:START
# OpenSpec shell completions configuration
if [ -d '/home/ocp/.local/share/bash-completion/completions' ]; then
  for f in '/home/ocp/.local/share/bash-completion/completions'/*; do
    [ -f "$f" ] && . "$f"
  done
fi
# OPENSPEC:END

#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/go/bin:$PATH"
export SVDIR="$HOME/.local/share/runit/sv"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

eval "$(direnv hook bash)"
