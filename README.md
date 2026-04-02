# quickdraw

Harpoon-style tmux session switcher. Popup with persistent order, number-jump, reorder, and i3-style slot assignment.

**Requires:** tmux >= 3.2, bash >= 5
- macOS: `brew install bash` (system bash is 3.2)
- Linux: system bash is usually 5+, no action needed

## Install

### TPM
```tmux
set -g @plugin 'merlinkraemer/quickdraw'
```
Press `prefix + I` to install.

### Manual
```bash
git clone https://github.com/merlinkraemer/quickdraw ~/.tmux/plugins/quickdraw
echo 'run-shell ~/.tmux/plugins/quickdraw/quickdraw.tmux' >> ~/.tmux.conf
```

## Keys

Default trigger: `Option/Alt+e` (no prefix required)

| Key | Action |
|-----|--------|
| `↑` / `↓` | Move cursor |
| `Enter` | Switch to session |
| `1`–`9`, `0` | Jump to session N |
| `Shift+↑/↓` or `Opt/Alt+↑/↓` | Reorder session |
| `!` `@` `#` `$` `%` `^` `&` `*` `(` `)` | Pin to slot 1–10 |
| `q` / `Esc` | Close |

## Config

```tmux
# Change trigger key (default: M-e = Option/Alt+e)
set -g @quickdraw-key 'M-s'

# Use with prefix instead of no-prefix
set -g @quickdraw-key ''
bind-key e run-shell -b "$HOME/.tmux/plugins/quickdraw/scripts/quickdraw.sh"
```

Check for conflicts: `tmux list-keys | grep M-e`

Session order persists in `~/.tmux/quickdraw-order`. Delete to reset.

## License

MIT
