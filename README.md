# quickdraw

> Harpoon-style tmux session switcher. 
Popup with session reorder, number hotkeys and i3 like slot assignment.

<img width="293" height="255" alt="Screenshot 2026-04-02 at 09 50 10" src="https://github.com/user-attachments/assets/7c808ea3-31e2-4755-9fc4-0517da8837cb" />

#### **Requires:** tmux >= 3.2, bash >= 5
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
| `Number` | Jump to session N |
| `Shift+↑/↓` or `Opt/Alt+↑/↓` | Reorder session |
| `Shift`+`Number` | Pin to slot 1–10 |
| `q` / `Esc` | Close |

## Config

```tmux
# Change hotkey (default: M-e aka option-e)
set -g @quickdraw-key 'M-s'

# Use with prefix instead of no-prefix
set -g @quickdraw-key ''
bind-key e run-shell -b "$HOME/.tmux/plugins/quickdraw/scripts/quickdraw.sh"
```

Check for conflicts: `tmux list-keys | grep M-e`

Session order persists in `~/.tmux/quickdraw-order`. Delete to reset.
