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

ORDER_FILE="$HOME/.tmux/quickdraw-order"

get_ordered_sessions() {
  mapfile -t all_sessions < <(tmux list-sessions -F '#{session_name}' 2>/dev/null | sort)

  # Build a set of live sessions for O(1) lookup
  declare -A session_set
  for s in "${all_sessions[@]}"; do session_set["$s"]=1; done

  # Read order file, keeping only sessions that still exist
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

  # Append new sessions not yet in the order file
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

show_list() {
  local current_session=$1
  local selected_idx=$2
  shift 2
  local sessions=("$@")
  [ ${#sessions[@]} -eq 0 ] && exit 0

  local output=""
  output+=$'\033[H'
  output+=$'\033[?25l'
  output+=$'\033[K\n'

  for i in "${!sessions[@]}"; do
    local name="${sessions[$i]}"
    local num=$((i + 1))
    local marks=""
    [ "$name" = "$current_session" ] && marks="*"

    if [ "$i" -eq "$selected_idx" ]; then
      output+="> ${num}: ${name} ${marks}"$'\033[K\n'
    else
      output+="  ${num}: ${name} ${marks}"$'\033[K\n'
    fi
  done

  output+=$'\033[J'
  printf '%s' "$output"
}

# Move the current session up/down in the list.
# Uses namerefs (bash 5+) to modify the caller's sessions array and selected_idx in-place.
# Usage: move_session sessions_ref new_idx_ref direction current_session_name
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

# Move the selected session to a specific numbered slot (i3-style).
# Uses namerefs (bash 5+) to modify the caller's sessions array and selected_idx in-place.
# Usage: move_to_slot sessions_ref new_idx_ref target_slot selected_idx
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

open_in_terminal() {
  local session_name=$1
  local terminal
  terminal=$(tmux show-option -gqv "@quickdraw-terminal" 2>/dev/null)

  if [ -z "$terminal" ]; then
    tmux display-message "quickdraw: set @quickdraw-terminal (ghostty|alacritty|wezterm|kitty|iterm2|terminal|xterm|gnome-terminal|konsole)"
    return 1
  fi

  # POSIX-safe quoting: wrap in single quotes, escape embedded single quotes
  local safe_name="'${session_name//\'/\'\\\'\'}'"
  local attach="tmux attach-session -t $safe_name"

  case "$terminal" in
    ghostty)
      if [[ "$OSTYPE" == darwin* ]]; then
        # Open new window in existing Ghostty instance via Cmd+N, then run tmux command
        local escaped="${session_name//\"/\\\"}"
        local cmd="tmux attach-session -t $escaped"
        tmux run-shell -b "osascript \
          -e 'tell application \"Ghostty\" to activate' \
          -e 'tell application \"System Events\" to tell process \"Ghostty\" to keystroke \"n\" using command down' \
          -e 'delay 0.3' \
          -e 'tell application \"System Events\" to tell process \"Ghostty\" to keystroke \"$cmd\"' \
          -e 'tell application \"System Events\" to tell process \"Ghostty\" to key code 36'"
      else
        tmux run-shell -b "ghostty -e $attach"
      fi
      ;;
    alacritty)
      tmux run-shell -b "alacritty -e $attach"
      ;;
    wezterm)
      tmux run-shell -b "wezterm start -- $attach"
      ;;
    kitty)
      tmux run-shell -b "kitty $attach"
      ;;
    iterm2)
      tmux run-shell -b "osascript -e 'tell application \"iTerm2\" to create window with default profile command \"$attach\"'"
      ;;
    terminal)
      tmux run-shell -b "osascript -e 'tell application \"Terminal\" to do script \"$attach\"'"
      ;;
    xterm)
      tmux run-shell -b "xterm -e $attach"
      ;;
    gnome-terminal)
      tmux run-shell -b "gnome-terminal -- $attach"
      ;;
    konsole)
      tmux run-shell -b "konsole -e $attach"
      ;;
    *)
      tmux display-message "quickdraw: unsupported terminal '$terminal'"
      return 1
      ;;
  esac
}

inner() {
  trap 'tput cnorm' EXIT

  current_session=$(tmux display-message -p '#S')
  mapfile -t sessions < <(get_ordered_sessions)

  selected_idx=0
  for i in "${!sessions[@]}"; do
    if [ "${sessions[$i]}" = "$current_session" ]; then
      selected_idx=$i; break
    fi
  done

  # Shift+number → slot number
  declare -A SLOT_MAP=([!]=1 [@]=2 ['#']=3 ['$']=4 [%]=5 ['^']=6 [&]=7 ['*']=8 ['(']=9 [')']=10)

  while true; do
    current_session=$(tmux display-message -p '#S')
    show_list "$current_session" "$selected_idx" "${sessions[@]}"

    IFS= read -rsn1 key
    [ $? -ne 0 ] && exit 0

    # Enter — switch to highlighted session
    if [ -z "$key" ]; then
      [ "${sessions[$selected_idx]}" != "$current_session" ] && \
        tmux switch-client -t "${sessions[$selected_idx]}"
      exit 0
    fi

    if [ "$key" = $'\x1b' ]; then
      read -rsn1 -t 0.01 key2

      if [ "$key2" = $'\x1b' ]; then
        # Option modifier: ESC ESC [ ...
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
          [ "$selected_idx" -gt 0 ] && selected_idx=$((selected_idx - 1))
        elif [ "$key3" = "B" ]; then
          [ "$selected_idx" -lt $((${#sessions[@]} - 1)) ] && selected_idx=$((selected_idx + 1))
        fi
        continue

      else
        # Plain Escape
        exit 0
      fi
    fi

    case "$key" in
      [1-9]|0)
        local sel=$key
        [ "$sel" = "0" ] && sel=10
        if [ "$((sel - 1))" -lt "${#sessions[@]}" ]; then
          local target="${sessions[$((sel-1))]}"
          [ -n "$target" ] && [ "$target" != "$current_session" ] && \
            tmux switch-client -t "$target"
        fi
        exit 0
        ;;
      j)
        [ "$selected_idx" -lt $((${#sessions[@]} - 1)) ] && selected_idx=$((selected_idx + 1))
        ;;
      k)
        [ "$selected_idx" -gt 0 ] && selected_idx=$((selected_idx - 1))
        ;;
      o)
        if open_in_terminal "${sessions[$selected_idx]}"; then
          exit 0
        fi
        ;;
      q)
        exit 0
        ;;
      *)
        if [[ -n "${SLOT_MAP[$key]+_}" ]]; then
          move_to_slot sessions selected_idx "${SLOT_MAP[$key]}" "$selected_idx"
        fi
        ;;
    esac
  done
}

if [ "${1:-}" = "--inner" ]; then
  inner
  exit 0
fi

# Calculate popup dimensions from current session list
mapfile -t all_sessions < <(tmux list-sessions -F '#{session_name}' 2>/dev/null)
session_count=${#all_sessions[@]}
[ "$session_count" -eq 0 ] && exit 0

max_width=20
for session in "${all_sessions[@]}"; do
  # "> N: name *" = 7 + name_length
  len=$((${#session} + 7))
  [ "$len" -gt "$max_width" ] && max_width=$len
done

popup_width=$((max_width + 4))
[ "$popup_width" -lt 25 ] && popup_width=25
[ "$popup_width" -gt 80 ] && popup_width=80

popup_height=$((session_count + 4))
[ "$popup_height" -lt 6  ] && popup_height=6
[ "$popup_height" -gt 22 ] && popup_height=22

{ tmux display-popup -E -w "$popup_width" -h "$popup_height" "$0 --inner"; } &>/dev/null &
exit 0
