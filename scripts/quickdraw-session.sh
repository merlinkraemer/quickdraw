#!/bin/bash
# Only re-exec if NOT already in bash 5+ (avoid infinite loop)
if [[ ! "$BASH_VERSION" =~ ^[5-9]\. ]]; then
  if [ -x /opt/homebrew/bin/bash ]; then
    exec /opt/homebrew/bin/bash "$0" "$@"
  elif [ -x /usr/local/bin/bash ]; then
    exec /usr/local/bin/bash "$0" "$@"
  fi
fi
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configurable search directories (space-separated)
SEARCH_DIRS=$(tmux show-option -gqv "@quickdraw-session-dirs" 2>/dev/null)
[ -z "$SEARCH_DIRS" ] && SEARCH_DIRS="$HOME/dev"

session_inner() {
  # 1. Existing sessions (shown first)
  local sessions
  sessions=$(tmux list-sessions -F '#{session_name}' 2>/dev/null)

  # 2. Directories from search paths
  local dirs=""
  for search_dir in $SEARCH_DIRS; do
    [ -d "$search_dir" ] || continue
    dirs+="$(find "$search_dir" -mindepth 1 -maxdepth 5 -type d -not -path '*/\.*' 2>/dev/null)"$'\n'
  done

  # Combined: sessions first, then directories
  local candidates
  candidates=$(printf '%s\n%s' "$sessions" "$dirs" | sed '/^$/d' | awk '!seen[$0]++')

  [ -z "$candidates" ] && exit 0

  local selected
  selected=$(echo "$candidates" | fzf \
    --layout=reverse \
    --prompt='' \
    --pointer='>' \
    --marker='' \
    --gutter=' ' \
    --info=hidden \
    --no-multi \
    --border=none \
    --no-scrollbar \
    --no-separator \
    --tiebreak=begin,length \
    2>/dev/null)

  [ $? -ne 0 ] && exit 0
  [ -z "$selected" ] && exit 0

  # Resolve: session? directory? new name?
  if tmux has-session -t="$selected" 2>/dev/null; then
    # It's an existing session — switch to it
    tmux switch-client -t "$selected"
    exit 0
  fi

  # It's a path — derive session name from basename
  local selected_name
  selected_name=$(basename "$selected" | tr . _)

  if tmux has-session -t="$selected_name" 2>/dev/null; then
    tmux switch-client -t "$selected_name"
    exit 0
  fi

  # Create new session and switch to it
  tmux new-session -ds "$selected_name" -c "$selected"
  tmux switch-client -t "$selected_name"
  exit 0
}

if [ "${1:-}" = "--inner" ]; then
  session_inner
  exit 0
fi

# Calculate popup dimensions
popup_width=50
popup_height=15

{ tmux display-popup -E -w "$popup_width" -h "$popup_height" "$0 --inner"; } &>/dev/null &
exit 0
