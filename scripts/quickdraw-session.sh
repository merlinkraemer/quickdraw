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
ORDER_FILE="$HOME/.tmux/quickdraw-order"

SEARCH_DIRS=$(tmux show-option -gqv "@quickdraw-session-dirs" 2>/dev/null)
[ -z "$SEARCH_DIRS" ] && SEARCH_DIRS="$HOME/dev"

CACHE_FILE="/tmp/quickdraw-dir-cache"
CACHE_TTL=300

get_dir_cache() {
  local now
  now=$(date +%s)
  local cache_age=0
  if [ -f "$CACHE_FILE" ]; then
    local cache_mtime
    cache_mtime=$(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null)
    cache_age=$((now - cache_mtime))
  fi
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

get_ordered_sessions() {
  mapfile -t all_sessions < <(tmux list-sessions -F '#{session_name}' 2>/dev/null | sort)
  declare -A session_set
  for s in "${all_sessions[@]}"; do session_set["$s"]=1; done
  declare -A seen
  local result=()
  if [ -f "$ORDER_FILE" ]; then
    while IFS= read -r s; do
      if [[ -n "${session_set[$s]+_}" && -z "${seen[$s]+_}" ]]; then
        result+=("$s")
        seen["$s"]=1
      fi
    done < "$ORDER_FILE"
  fi
  for s in "${all_sessions[@]}"; do
    if [[ -z "${seen[$s]+_}" ]]; then
      result+=("$s")
    fi
  done
  printf '%s\n' "${result[@]}"
}

save_order() {
  mkdir -p "$(dirname "$ORDER_FILE")"
  printf '%s\n' "$@" > "$ORDER_FILE"
}

# Unified display: search bar at top, items below
# Args: query current_session selected_idx show_numbers item1 item2 ...
show_view() {
  local query=$1
  local current_session=$2
  local selected_idx=$3
  local show_numbers=$4
  shift 4
  local items=("$@")

  local output=""
  output+=$'\033[H'
  output+=$'\033[?25l'

  # Search bar
  output+="> ${query}_"$'\033[K\n'

  # Items
  for i in "${!items[@]}"; do
    local name="${items[$i]}"
    local marks=""
    [ "$name" = "$current_session" ] && marks=" *"

    if [ "$show_numbers" = "1" ] && [ "$i" -lt 9 ]; then
      local num=$((i + 1))
      if [ "$i" -eq "$selected_idx" ]; then
        output+="> ${num}: ${name}${marks}"$'\033[K\n'
      else
        output+="  ${num}: ${name}${marks}"$'\033[K\n'
      fi
    else
      if [ "$i" -eq "$selected_idx" ]; then
        output+="> ${name}${marks}"$'\033[K\n'
      else
        output+="  ${name}${marks}"$'\033[K\n'
      fi
    fi
  done

  output+=$'\033[J'
  printf '%s' "$output"
}

move_session() {
  declare -n _mv_sessions=$1
  declare -n _mv_idx=$2
  local direction=$3
  local current=$4
  local current_idx=-1
  for i in "${!_mv_sessions[@]}"; do
    if [ "${_mv_sessions[$i]}" = "$current" ]; then
      current_idx=$i; break
    fi
  done
  [ "$current_idx" -eq -1 ] && return 1
  local target_idx=$current_idx
  if   [ "$direction" = "up"   ] && [ "$current_idx" -gt 0 ]; then
    target_idx=$((current_idx - 1))
  elif [ "$direction" = "down" ] && [ "$current_idx" -lt $((${#_mv_sessions[@]} - 1)) ]; then
    target_idx=$((current_idx + 1))
  else
    return 1
  fi
  local temp="${_mv_sessions[$current_idx]}"
  _mv_sessions[$current_idx]="${_mv_sessions[$target_idx]}"
  _mv_sessions[$target_idx]="$temp"
  save_order "${_mv_sessions[@]}"
  _mv_idx=$target_idx
}

move_to_slot() {
  declare -n _sl_sessions=$1
  declare -n _sl_idx=$2
  local target_slot=$3
  local selected_idx=$4
  local max_idx=$((${#_sl_sessions[@]} - 1))
  local target_idx=$((target_slot - 1))
  [ "$target_idx" -lt 0 ]        && target_idx=0
  [ "$target_idx" -gt "$max_idx" ] && target_idx=$max_idx
  [ "$target_idx" -eq "$selected_idx" ] && return 1
  local session_to_move="${_sl_sessions[$selected_idx]}"
  local tmp=()
  for i in "${!_sl_sessions[@]}"; do
    [ "$i" -ne "$selected_idx" ] && tmp+=("${_sl_sessions[$i]}")
  done
  local result=()
  local inserted=false
  for i in "${!tmp[@]}"; do
    if [ "$i" -eq "$target_idx" ] && [ "$inserted" = false ]; then
      result+=("$session_to_move"); inserted=true
    fi
    result+=("${tmp[$i]}")
  done
  [ "$inserted" = false ] && result+=("$session_to_move")
  _sl_sessions=("${result[@]}")
  save_order "${_sl_sessions[@]}"
  _sl_idx=$target_idx
}

resolve_selection() {
  local selected=$1
  if tmux has-session -t="$selected" 2>/dev/null; then
    tmux switch-client -t "$selected"
    exit 0
  fi
  local selected_path="${selected/#\~/$HOME}"
  if [ -d "$selected_path" ]; then
    local selected_name
    selected_name=$(basename "$selected" | tr . _)
    if tmux has-session -t="$selected_name" 2>/dev/null; then
      tmux switch-client -t "$selected_name"
      exit 0
    fi
    tmux new-session -ds "$selected_name" -c "$selected_path"
    tmux switch-client -t "$selected_name"
    exit 0
  fi
  [ -n "$selected" ] && tmux new-session -s "$selected" -c ~ \; switch-client -t "$selected"
  exit 0
}

filter_results() {
  local query=$1
  shift
  local all=("$@")
  local results=()
  local qlower
  qlower=$(echo "$query" | tr '[:upper:]' '[:lower:]')
  for item in "${all[@]}"; do
    local ilower
    ilower=$(echo "$item" | tr '[:upper:]' '[:lower:]')
    [[ "$ilower" == *"$qlower"* ]] && results+=("$item")
  done
  printf '%s\n' "${results[@]}"
}

inner() {
  trap 'tput cnorm' EXIT

  current_session=$(tmux display-message -p '#S')
  mapfile -t sessions < <(get_ordered_sessions)

  # Build full candidate list: sessions + directories
  local dirs
  dirs=$(get_dir_cache)
  local all_candidates=()
  for s in "${sessions[@]}"; do
    all_candidates+=("$s")
  done
  declare -A seen_names
  for s in "${sessions[@]}"; do seen_names["$s"]=1; done
  while IFS= read -r d; do
    [ -z "$d" ] && continue
    local bname
    bname=$(basename "$d" | tr . _)
    [ -n "${seen_names[$bname]+_}" ] && continue
    seen_names["$bname"]=1
    all_candidates+=("$d")
  done <<< "$dirs"

  selected_idx=0
  for i in "${!sessions[@]}"; do
    if [ "${sessions[$i]}" = "$current_session" ]; then
      selected_idx=$i; break
    fi
  done

  declare -A SLOT_MAP=([!]=1 [@]=2 ["#"]=3 ["\$"]=4 [%]=5 ["^"]=6 [&]=7 ["*"]=8 ["("]=9 [")"]=10)

  local query=""
  local search_results=()
  local search_idx=0
  local typing=0  # 0 = browsing session list, 1 = typing search

  while true; do
    current_session=$(tmux display-message -p '#S')

    if [ "$typing" = "0" ]; then
      show_view "" "$current_session" "$selected_idx" "1" "${sessions[@]}"
    else
      show_view "$query" "$current_session" "$search_idx" "0" "${search_results[@]}"
    fi

    IFS= read -rsn1 key
    [ $? -ne 0 ] && exit 0

    # Enter
    if [ -z "$key" ]; then
      if [ "$typing" = "0" ]; then
        [ "${sessions[$selected_idx]}" != "$current_session" ] && \
          tmux switch-client -t "${sessions[$selected_idx]}"
        exit 0
      else
        if [ ${#search_results[@]} -gt 0 ]; then
          resolve_selection "${search_results[$search_idx]}"
        elif [ -n "$query" ]; then
          resolve_selection "$query"
        fi
        exit 0
      fi
    fi

    # Backspace
    if [ "$key" = $'\x7f' ]; then
      if [ "$typing" = "1" ]; then
        if [ ${#query} -gt 0 ]; then
          query="${query:0:-1}"
          mapfile -t search_results < <(filter_results "$query" "${all_candidates[@]}")
          search_idx=0
        fi
        if [ -z "$query" ]; then
          typing=0
        fi
      fi
      continue
    fi

    if [ "$key" = $'\x1b' ]; then
      read -rsn1 -t 0.01 key2

      if [ "$key2" = $'\x1b' ]; then
        read -rsn1 -t 0.01 key3
        if [ "$key3" = "[" ]; then
          read -rsn1 -t 0.01 key4
          if [ "$key4" = "1" ]; then
            read -rsn3 -t 0.01 key5
            case "$key5" in
              ";2A") move_session sessions selected_idx "up"   "$current_session" ;;
              ";2B") move_session sessions selected_idx "down" "$current_session" ;;
            esac
          elif [ "$key4" = "A" ]; then
            move_session sessions selected_idx "up"   "$current_session"
          elif [ "$key4" = "B" ]; then
            move_session sessions selected_idx "down" "$current_session"
          fi
        fi
        continue

      elif [ "$key2" = "[" ]; then
        read -rsn1 -t 0.01 key3

        if [ "$key3" = "1" ]; then
          read -rsn3 -t 0.01 key4
          case "$key4" in
            ";2A") move_session sessions selected_idx "up"   "$current_session" ;;
            ";2B") move_session sessions selected_idx "down" "$current_session" ;;
          esac
        elif [ "$key3" = "A" ]; then
          if [ "$typing" = "0" ]; then
            if [ "$selected_idx" -gt 0 ]; then
              selected_idx=$((selected_idx - 1))
            else
              selected_idx=$((${#sessions[@]} - 1))
            fi
          else
            if [ "$search_idx" -gt 0 ]; then
              search_idx=$((search_idx - 1))
            else
              [ ${#search_results[@]} -gt 0 ] && search_idx=$((${#search_results[@]} - 1))
            fi
          fi
        elif [ "$key3" = "B" ]; then
          if [ "$typing" = "0" ]; then
            if [ "$selected_idx" -lt $((${#sessions[@]} - 1)) ]; then
              selected_idx=$((selected_idx + 1))
            else
              selected_idx=0
            fi
          else
            if [ "$search_idx" -lt $((${#search_results[@]} - 1)) ]; then
              search_idx=$((search_idx + 1))
            else
              search_idx=0
            fi
          fi
        fi
        continue

      else
        exit 0
      fi
    fi

    case "$key" in
      [1-9]|0)
        if [ "$typing" = "0" ]; then
          local sel=$key
          [ "$sel" = "0" ] && sel=10
          if [ "$((sel - 1))" -lt "${#sessions[@]}" ]; then
            local target="${sessions[$((sel-1))]}"
            [ -n "$target" ] && [ "$target" != "$current_session" ] && \
              tmux switch-client -t "$target"
          fi
          exit 0
        else
          query+="$key"
          mapfile -t search_results < <(filter_results "$query" "${all_candidates[@]}")
          search_idx=0
        fi
        ;;
      j)
        if [ "$typing" = "0" ]; then
          if [ "$selected_idx" -lt $((${#sessions[@]} - 1)) ]; then
            selected_idx=$((selected_idx + 1))
          else
            selected_idx=0
          fi
        else
          if [ "$search_idx" -lt $((${#search_results[@]} - 1)) ]; then
            search_idx=$((search_idx + 1))
          else
            search_idx=0
          fi
        fi
        ;;
      k)
        if [ "$typing" = "0" ]; then
          if [ "$selected_idx" -gt 0 ]; then
            selected_idx=$((selected_idx - 1))
          else
            selected_idx=$((${#sessions[@]} - 1))
          fi
        else
          if [ "$search_idx" -gt 0 ]; then
            search_idx=$((search_idx - 1))
          else
            [ ${#search_results[@]} -gt 0 ] && search_idx=$((${#search_results[@]} - 1))
          fi
        fi
        ;;
      q)
        exit 0
        ;;
      *)
        if [ "$typing" = "0" ]; then
          if [[ -n "${SLOT_MAP[$key]+_}" ]]; then
            move_to_slot sessions selected_idx "${SLOT_MAP[$key]}" "$selected_idx"
          elif [[ "$key" =~ [a-zA-Z0-9_./-] ]]; then
            typing=1
            query="$key"
            mapfile -t search_results < <(filter_results "$query" "${all_candidates[@]}")
            search_idx=0
          fi
        else
          query+="$key"
          mapfile -t search_results < <(filter_results "$query" "${all_candidates[@]}")
          search_idx=0
        fi
        ;;
    esac
  done
}

if [ "${1:-}" = "--inner" ]; then
  inner
  exit 0
fi

# Calculate popup dimensions
mapfile -t all_sessions < <(tmux list-sessions -F '#{session_name}' 2>/dev/null)
session_count=${#all_sessions[@]}
[ "$session_count" -eq 0 ] && exit 0

max_width=20
for session in "${all_sessions[@]}"; do
  len=$((${#session} + 7))
  [ "$len" -gt "$max_width" ] && max_width=$len
done

popup_width=$((max_width + 4))
[ "$popup_width" -lt 25 ] && popup_width=25
[ "$popup_width" -gt 80 ] && popup_width=80

popup_height=$((session_count + 5))
[ "$popup_height" -lt 8  ] && popup_height=8
[ "$popup_height" -gt 25 ] && popup_height=25

{ tmux display-popup -E -w "$popup_width" -h "$popup_height" "$0 --inner"; } &>/dev/null &
exit 0
