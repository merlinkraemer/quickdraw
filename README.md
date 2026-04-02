# quickdraw

Harpoon-style session switcher for tmux. Persistent ordered session list, number-jump, reorder with arrow keys, and i3-style slot assignment — all in a popup.

## Requirements

- tmux >= 3.2 (for `display-popup`)
- bash >= 5 (Homebrew bash on macOS)

## Installation

### TPM (recommended)

```tmux
set -g @plugin 'merlinkraemer/quickdraw'
```

Then press `prefix + I` to install.

### Manual

```bash
git clone https://github.com/merlinkraemer/quickdraw ~/.tmux/plugins/quickdraw
~/.tmux/plugins/quickdraw/quickdraw.tmux
```

Add to `~/.tmux.conf`:

```tmux
run-shell ~/.tmux/plugins/quickdraw/quickdraw.tmux
```

## Usage

Press `M-e` (Option+e) to open the session picker popup.

### Keybindings

| Key                  | Action                              |
|----------------------|-------------------------------------|
| `↑` / `↓`           | Move cursor                         |
| `Enter`              | Switch to selected session          |
| `1`–`9`, `0`         | Jump directly to session N          |
| `Shift+↑/↓`          | Reorder current session up/down     |
| `Opt+↑/↓`            | Reorder current session up/down     |
| `!` `@` `#` … `)`   | Move selected session to slot 1–10  |
| `q` / `Esc`          | Close without switching             |

The session order is saved to `~/.tmux/quickdraw-order` and persists across sessions.

## Configuration

Override the trigger key in `~/.tmux.conf`:

```tmux
set -g @quickdraw-key 'M-s'
```

## License

MIT
