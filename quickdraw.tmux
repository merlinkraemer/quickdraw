#!/usr/bin/env bash
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

default_key="M-e"
key=$(tmux show-option -gqv "@quickdraw-key" 2>/dev/null)
[ -z "$key" ] && key="$default_key"

default_session_key="M-n"
session_key=$(tmux show-option -gqv "@quickdraw-session-key" 2>/dev/null)
[ -z "$session_key" ] && session_key="$default_session_key"

tmux bind-key -n "$key" run-shell -b "$CURRENT_DIR/scripts/quickdraw.sh"
tmux bind-key -n "$session_key" run-shell -b "$CURRENT_DIR/scripts/quickdraw-session.sh"
