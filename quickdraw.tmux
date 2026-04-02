#!/usr/bin/env bash
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

default_key="M-e"
key=$(tmux show-option -gqv "@quickdraw-key" 2>/dev/null)
[ -z "$key" ] && key="$default_key"

tmux bind-key -n "$key" run-shell -b "$CURRENT_DIR/scripts/quickdraw.sh"
