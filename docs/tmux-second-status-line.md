# Tmux Second Status Line — Rig Overview

A second status line at the bottom of tmux showing all Gas Town rigs with live status indicators. Rig LEDs are removed from the first line to avoid duplication.

## What It Looks Like

```
─── 🎩 Mayor    2/2 🦉 2/2 🏭 | 14:30 ──────────────────
─── 🔨listen  🟢livemd  ⚫gthelper ────────────────────────
```

Line 1: Agent counts, hooked work, mail, clock (no rig LEDs)
Line 2: All rigs with status icons

## Icons

| Icon | Meaning |
|------|---------|
| 🔨 | Working — has active polecats |
| 🟢 | Operational — witness + refinery running |
| 🟡 | Partial — only one agent running |
| ⚫ | Stopped |

## Setup

The second bar is configured by the installer:

```bash
curl -fsSL https://raw.githubusercontent.com/erkantaylan/gastown-helper/master/install-tmux.sh | bash
```

When prompted "Enable second bar with rig overview?", answer Y (the default).

To toggle later, re-run the installer and change the setting.

## How It Works

- `tmux-rig-status.sh` (installed to `~/.local/share/gt-tmux/`) calls `gt status --json` and formats rig names with status icons
- `tmux-status-right.sh` wraps `gt status-line`, filtering out rig LED entries so they only appear on line 2
- Tmux runs both scripts every `status-interval` seconds (default 5s)
- `fill=colour232` ensures the background covers the entire line width
- Window list is hidden since it's redundant with a single window

## Disable

```bash
# Remove second line
tmux set-option -g status 1

# Or re-run the installer and answer 'n' to second bar
```

## Terminal Compatibility

The `fill=colour232` fix is needed for terminals that don't default to black for empty status bar areas (e.g. Ubuntu default terminal with dark purple theme). Without it, empty areas show the terminal's background color instead of the status bar color.

## Requirements

- tmux 3.4+
- python3
- `gt` binary in PATH or `GT_BIN` env var set
