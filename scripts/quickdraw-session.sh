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

CACHE_FILE="/tmp/quickdraw-dir-cache"
CACHE_TTL=300  # 5 minutes

get_dir_cache() {
  local now
  now=$(date +%s)
  local cache_age=0

  if [ -f "$CACHE_FILE" ]; then
    local cache_mtime
    cache_mtime=$(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null)
    cache_age=$((now - cache_mtime))
  fi

  # Regenerate cache if expired or missing
  if [ "$cache_age" -gt "$CACHE_TTL" ] || [ ! -f "$CACHE_FILE" ]; then
    local tmpfile
    tmpfile=$(mktemp)
    for search_dir in $SEARCH_DIRS; do
      [ -d "$search_dir" ] || continue
      find "$search_dir" -mindepth 1 -maxdepth 3 -type d -not -path '*/\.*' 2>/dev/null
    done | sed '/^$/d' | sed "s|^$HOME|~|" > "$tmpfile"
    mv "$tmpfile" "$CACHE_FILE"
  fi

  cat "$CACHE_FILE"
}

# Truncate a ~/... path: show first 2 dirs + last dir
truncate_path() {
  local path=$1
  local segments
  IFS='/' read -ra segments <<< "$path"
  local count=${#segments[@]}

  if [ "$count" -le 4 ]; then
    echo "$path"
    return
  fi

  echo "${segments[0]}/${segments[1]}/${segments[2]}/.../${segments[-1]}"
}

session_inner() {
  # 1. Existing sessions (shown first)
  local sessions
  sessions=$(tmux list-sessions -F '#{session_name}' 2>/dev/null)

  # 2. Directories from cache
  local dirs
  dirs=$(get_dir_cache)

  # Combined: sessions first, then directories
  local candidates
  candidates=$(printf '%s\n%s' "$sessions" "$dirs" | sed '/^$/d' | awk '!seen[$0]++')

  [ -z "$candidates" ] && exit 0

  # Add numbers to first 9 items
  local numbered_candidates
  numbered_candidates=$(echo "$candidates" | awk '{
    if (NR <= 9) printf "%d: %s\n", NR, $0
    else print
  }')

  local selected
  selected=$(echo "$numbered_candidates" | sed 's/^/  /' | fzf \
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
    --color='current-fg:#ebdbb2,current-bg:#282828,pointer:15,gutter:#282828' \
    --tiebreak=begin,length \
    --bind '1:pos(0)+accept' \
    --bind '2:pos(1)+accept' \
    --bind '3:pos(2)+accept' \
    --bind '4:pos(3)+accept' \
    --bind '5:pos(4)+accept' \
    --bind '6:pos(5)+accept' \
    --bind '7:pos(6)+accept' \
    --bind '8:pos(7)+accept' \
    --bind '9:pos(8)+accept' \
    2>/dev/null)

  # Strip padding and number prefix
  selected=$(echo "$selected" | sed 's/^  //' | sed 's/^[1-9]: //')

  [ $? -ne 0 ] && exit 0
  [ -z "$selected" ] && exit 0

  # Resolve: session? directory? new name?
  if tmux has-session -t="$selected" 2>/dev/null; then
    tmux switch-client -t "$selected"
    exit 0
  fi

  # It's a path — derive session name from basename
  local selected_name
  selected_name=$(basename "$selected" | tr . _)

  # Expand ~ to $HOME for tmux
  local selected_path="${selected/#\~/$HOME}"

  if tmux has-session -t="$selected_name" 2>/dev/null; then
    tmux switch-client -t "$selected_name"
    exit 0
  fi

  # Create new session and switch to it
  tmux new-session -ds "$selected_name" -c "$selected_path"
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
