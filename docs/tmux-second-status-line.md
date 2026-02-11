# Tmux Second Status Line — Rig Overview

Add a second status line to the bottom of your tmux showing all Gas Town rigs with live status indicators. Rig LEDs are removed from the first line to avoid duplication.

## What It Looks Like

```
─── 🎩 Mayor    2/2 🦉 2/2 🏭 | 14:30 ──────────────────
─── Rigs: 🔨 listen(2p)  🟢 livemd  ⚫ gthelper ─────────
```

Line 1: Agent counts, hooked work, mail, clock (no rig LEDs)
Line 2: All rigs with status icons and worker counts

## Icons

| Icon | Meaning |
|------|---------|
| 🔨 | Working — has active polecats |
| 🟢 | Operational — witness + refinery running |
| 🟡 | Partial — only one agent running |
| ⚫ | Stopped |

Polecat and crew counts shown in parentheses when present: `listen(2p|1c)`

## Setup

### One-liner

```bash
./tmux-rig-status-setup.sh
```

This does three things:
1. Enables 2 status lines (`tmux set-option -g status 2`)
2. Sets the second line with rig overview
3. Removes rig LEDs from the first line
4. Fixes background fill color (prevents brown gaps on some terminals)

### Persistent (add to ~/.bashrc)

```bash
# Gas Town second status line
[ -n "$TMUX" ] && ~/path/to/tmux-rig-status-setup.sh 2>/dev/null
```

## Files

| File | Purpose |
|------|---------|
| `tmux-rig-status.sh` | Second line script — formats rig data from `gt status --json` |
| `tmux-status-right.sh` | First line filter — strips rig LEDs from `gt status-line` |
| `tmux-rig-status-setup.sh` | One-time setup — enables everything |

## How It Works

- `tmux-rig-status.sh` calls `gt status --json` and formats rig names with status icons
- `tmux-status-right.sh` wraps `gt status-line`, filtering out rig LED entries
- Tmux runs both scripts every `status-interval` seconds (default 5s)
- `fill=colour232` ensures the background covers the entire line width
- No modification to the `gt` binary needed

## Disable

```bash
# Remove second line
tmux set-option -g status 1

# Restore rig LEDs on first line (if needed)
tmux set-option -t hq-mayor status-right '#(gt status-line --session=hq-mayor 2>/dev/null) %H:%M'
```

## Terminal Compatibility

The `fill=colour232` fix is needed for terminals that don't default to black for empty status bar areas (e.g. Ubuntu default terminal with dark purple theme). Without it, empty areas show the terminal's background color instead of the status bar color.

## Requirements

- tmux 3.4+
- python3
- `gt` binary in PATH or `GT_BIN` env var set
