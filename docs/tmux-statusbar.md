# Gas Town Tmux Status Bar Setup

## Overview

The Gas Town tmux status bar has two lines:
- **Line 1**: Mayor name (left) + agent counts, mail, hooked work (right) + clock
- **Line 2**: Rig names with status icons

## Quick Setup

```bash
# 1. Set your mayor name
echo "YourName" > ~/.gt-mayor-name

# 2. Run the setup script
bash ~/Desktop/projects/gt-01/gthelper/refinery/rig/tmux-rig-status-setup.sh

# 3. (Optional) Add to tmux.conf for persistence
echo 'run-shell "bash ~/Desktop/projects/gt-01/gthelper/refinery/rig/tmux-rig-status-setup.sh"' >> ~/.config/tmux/tmux.conf
```

## What It Does

The setup script configures six things:

1. **Enables 2 status lines** (`status 2`)
2. **Status-left**: `🎩 MayorName` (bold, yellow background) + `username[town-dir]` (bold white on blue) + `📱v1` bot version badge (dark grey)
3. **Status-right**: Filtered `gt status-line` (agent counts, mail, hooked work — no rig LEDs) + clock
4. **Second line**: Rig names with status icons via `tmux-rig-status.sh`
5. **Hides window list** (redundant with single window)
6. **Fixes fill color** for both lines (prevents brown background on some terminals)

## What You See

### Line 1 (left side)
```
🎩 Kael  kamyon[gt-01] 📱v1
```
- Gold background on mayor name — bold, always visible
- Blue background on username[town] — bold white, most prominent element
- Dark grey background on bot version badge

### Line 1 (right side)
```
1/1 🦉 2/2 🏭 | 📬 📱 Telegram | 10:30
```
- Agent counts (witness 🦉, refinery 🏭)
- Mail notifications
- Hooked work indicators
- Clock

### Line 2
```
🔨gthelper 🟢listen 🅿️livemd
```
- Compact rig names with status icons

## Status Icons

| Icon | Meaning |
|------|---------|
| 🔨 | Working (has polecats) |
| 🟢 | Operational (witness + refinery running) |
| 🟡 | Partial (only one agent running) |
| 🅿️ | Parked |
| ⚫ | Stopped |

## Files

| File | Purpose |
|------|---------|
| `tmux-rig-status-setup.sh` | One-time setup script (or run from tmux.conf) |
| `tmux-status-right.sh` | Filters gt status-line for first line (strips rig LEDs) |
| `tmux-rig-status.sh` | Generates second line (rig status icons) |
| `~/.gt-mayor-name` | Mayor name config (one line, e.g. `Kael`) |

## For Other Towns

To set up the same status bar on another town:

```bash
# 1. Pick a mayor name
echo "TheirName" > ~/.gt-mayor-name

# 2. Copy the gthelper scripts to your rig (or use git)
# Needed: tmux-rig-status-setup.sh, tmux-status-right.sh, tmux-rig-status.sh

# 3. Run setup
bash /path/to/tmux-rig-status-setup.sh

# 4. Make persistent
echo 'run-shell "bash /path/to/tmux-rig-status-setup.sh"' >> ~/.config/tmux/tmux.conf
```

The script auto-detects:
- Mayor name from `~/.gt-mayor-name`
- Username from `whoami`
- Town directory name from the script's location

## Disable

```bash
# Remove second line
tmux set-option -g status 1

# Restore window list
tmux set-option -gu window-status-current-format
tmux set-option -gu window-status-format

# Restore default status-left
tmux set-option -t hq-mayor status-left "🎩 Mayor "

# Remove from tmux.conf
# Delete the run-shell line for tmux-rig-status-setup.sh
```
