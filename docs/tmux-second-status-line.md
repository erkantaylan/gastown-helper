# Tmux Second Status Line — Rig Overview

Add a second status line to the bottom of your tmux showing all Gas Town rigs with live status indicators.

## What It Looks Like

```
─── main status bar (GT default — identity, work, mail) ───
─── Rigs: 🔨 listen(2p)  🟢 livemd  ⚫ gthelper ───────────
```

## Icons

| Icon | Meaning |
|------|---------|
| 🔨 | Working — has active polecats |
| 🟢 | Operational — witness + refinery running |
| 🟡 | Partial — only one agent running |
| ⚫ | Stopped |

Polecats and crew counts are shown in parentheses when present: `listen(2p|1c)`

## Setup

### One-liner

```bash
./tmux-rig-status-setup.sh
```

### Manual

```bash
# Enable 2 status lines
tmux set-option -g status 2

# Set second line
tmux set-option -g 'status-format[1]' \
  "#[align=left,bg=#1a1a2e,fg=#888888] Rigs: #(/path/to/tmux-rig-status.sh)"
```

### Persistent (add to tmux.conf)

```bash
# Gas Town rig status — second status line
set-option -g status 2
set-option -g status-format[1] "#[align=left,bg=#1a1a2e,fg=#888888] Rigs: #(/path/to/tmux-rig-status.sh)"
```

Replace `/path/to/` with the actual path to `tmux-rig-status.sh`.

## How It Works

- `tmux-rig-status.sh` calls `gt status --json` and parses the output with python3
- Tmux runs the script every `status-interval` seconds (default 5s)
- No modification to the `gt` binary needed — pure tmux configuration

## Files

| File | Purpose |
|------|---------|
| `tmux-rig-status.sh` | Status line script — formats rig data for tmux |
| `tmux-rig-status-setup.sh` | One-time setup — enables the second line |

## Disable

```bash
tmux set-option -g status 1
```

## Customization

Edit `tmux-rig-status.sh` to change what's displayed. The script receives JSON from `gt status --json` with full rig/agent/polecat data.

Colors are set in the `status-format[1]` string using tmux style syntax:
- `bg=#1a1a2e` — background color
- `fg=#888888` — text color

## Requirements

- tmux 3.4+ (supports `status-format[N]` array)
- python3 (for JSON parsing)
- `gt` binary in PATH or set `GT_BIN` env var
