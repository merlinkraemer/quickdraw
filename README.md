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
| `↑` / `↓` or `j` / `k` | Move cursor |
| `Enter` | Switch to session |
| `o` | Open session in new terminal window |
| `Number` | Jump to session N |
| `Shift+↑/↓` or `Shift+J/K` or `Opt/Alt+↑/↓` | Reorder session |
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

### Open in new terminal window

Press `o` in the quickdraw popup to open the highlighted session in a new terminal window instead of switching to it in the current one.

Set your terminal emulator so quickdraw knows how to open a new window:

```tmux
set -g @quickdraw-terminal 'ghostty'
```

Supported terminals:

| Value | Terminal | Platform |
|-------|----------|----------|
| `ghostty` | [Ghostty](https://ghostty.org) | macOS / Linux |
| `alacritty` | [Alacritty](https://alacritty.org) | macOS / Linux |
| `wezterm` | [WezTerm](https://wezfurlong.org/wezterm) | macOS / Linux |
| `kitty` | [Kitty](https://sw.kovidgoyal.net/kitty) | macOS / Linux |
| `iterm2` | [iTerm2](https://iterm2.com) | macOS |
| `terminal` | Terminal.app | macOS |
| `gnome-terminal` | GNOME Terminal | Linux |
| `konsole` | Konsole | Linux |
| `xterm` | xterm | Linux |

Session order persists in `~/.tmux/quickdraw-order`. Delete to reset.
