# quickdraw

Harpoon-style session switcher for tmux. Persistent ordered session list, number-jump, reorder with arrow keys, and i3-style slot assignment — all in a popup.

## Requirements

- tmux >= 3.2 (for `display-popup`)
- bash >= 5
  - **macOS**: system bash is 3.2 — install via Homebrew: `brew install bash`
  - **Linux**: system bash is usually 5+, no action needed

## Installation

### TPM (recommended)

```tmux
set -g @plugin 'merlinkraemer/quickdraw'
```

Then press `prefix + I` to install.

### Manual

```bash
git clone https://github.com/merlinkraemer/quickdraw ~/.tmux/plugins/quickdraw
```

Add to `~/.tmux.conf`:

```tmux
run-shell ~/.tmux/plugins/quickdraw/quickdraw.tmux
```

## Usage

Press the trigger key to open the session picker popup.

- **macOS**: `Option+e` by default
- **Linux**: `Alt+e` by default

### Keybindings

| Key                  | Action                              |
|----------------------|-------------------------------------|
| `↑` / `↓`           | Move cursor                         |
| `Enter`              | Switch to selected session          |
| `1`–`9`, `0`         | Jump directly to session N          |
| `Shift+↑/↓`          | Reorder current session up/down     |
| `Opt/Alt+↑/↓`        | Reorder current session up/down     |
| `!` `@` `#` … `)`   | Move selected session to slot 1–10  |
| `q` / `Esc`          | Close without switching             |

The trigger key fires **without** the tmux prefix (`bind -n`). If you'd rather use it with the prefix, see Configuration below.

Session order is saved to `~/.tmux/quickdraw-order`. Delete this file to reset to default (alphabetical) order.

## Configuration

Add any of these to `~/.tmux.conf` before the `run-shell` or TPM `run` line:

```tmux
# Change the trigger key (default: M-e)
set -g @quickdraw-key 'M-s'
```

### Using with the prefix key instead of no-prefix

The plugin binds without a prefix by default. To bind it with your prefix instead, skip the plugin's auto-binding and add your own:

```tmux
# Don't load the plugin's keybinding
set -g @quickdraw-key ''

# Bind manually with prefix
bind-key e run-shell -b "$HOME/.tmux/plugins/quickdraw/scripts/quickdraw.sh"
```

### Conflicts

`M-e` / `Alt+e` may already be bound in your config. Check with:

```bash
tmux list-keys | grep M-e
```

If there's a conflict, change `@quickdraw-key` to something free.

## License

MIT
