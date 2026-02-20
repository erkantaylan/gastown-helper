# Gas Town Tmux Status Bar

## Overview

The Gas Town tmux status bar has two lines:
- **Line 1**: Mayor name (left) + optional user/folder/telegram + agent counts, mail, hooked work (right) + clock
- **Line 2**: Rig names with status icons

## Install / Update

```bash
curl -fsSL https://raw.githubusercontent.com/erkantaylan/gastown-helper/master/install-tmux.sh | bash
```

The installer asks 4 questions and generates everything. Re-run the same command to update.

## What You See

### Line 1 (left side)

Full config (user/folder + telegram enabled):
```
🎩 Kael  kamyon gt-01  @gastown_mine_bot
```
- Gold background on mayor name
- Blue background on username + folder
- Dark grey background on bot name

Minimal config (both disabled):
```
🎩 Kael
```

### Line 1 (right side)
```
1/1 🦉 2/2 🏭 | 📬 📱 Telegram | 10:30
```
- Agent counts (witness, refinery)
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

## Configuration Files

| File | Purpose |
|------|---------|
| `~/.config/gt-tmux/config` | Installer preferences (re-used on update) |
| `~/.gt-mayor-name` | Mayor display name |
| `~/.gt-bot-name` | Telegram bot username |
| `~/.config/tmux/tmux.conf` | Generated tmux config |

## How the Anti-Override Works

Gas Town's daemon sets session-level `status-left`/`status-right` on `hq-mayor` every time it creates or restarts a session. These session-level options shadow the global tmux.conf.

The `tmux-anti-override.sh` script is called via `#()` in `status-right`, so it runs every `status-interval` (5s). It checks for session-level overrides on `hq-mayor` and clears them, letting the global config win. This is invisible (returns empty string).

## For Other Towns

Just run the installer on the new machine:

```bash
curl -fsSL https://raw.githubusercontent.com/erkantaylan/gastown-helper/master/install-tmux.sh | bash
```

It auto-detects the town directory and configures paths accordingly.

## Disable

```bash
# Remove second line
tmux set-option -g status 1

# Restore window list
tmux set-option -gu window-status-current-format
tmux set-option -gu window-status-format
```

## Requirements

- tmux 3.4+
- python3
- `gt` binary in PATH
