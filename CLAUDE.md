# Gas Town Helper - Agent Instructions

This repository contains setup scripts for Gas Town tmux configuration.

## Quick Reference

### Install tmux config (one-liner)

```bash
curl -fsSL https://raw.githubusercontent.com/erkantaylan/gastown-helper/master/install-tmux.sh | bash
```

This downloads scripts to `~/.local/share/gt-tmux/` and installs `~/.config/tmux/tmux.conf`.

### Enable second status line

After installing, enable the rig overview status line:

```bash
~/.local/share/gt-tmux/tmux-rig-status-setup.sh
```

### Set mayor name

```bash
echo 'YourName' > ~/.gt-mayor-name
```

### Reload tmux config

```bash
tmux source-file ~/.config/tmux/tmux.conf
```

## Files

| File | Purpose |
|------|---------|
| `install-tmux.sh` | curl\|bash installer for standalone tmux config |
| `tmux.conf` | Main tmux configuration with Gas Town status bar |
| `tmux-rig-status.sh` | Second status line showing rig overview |
| `tmux-status-right.sh` | First line filter (strips rig LEDs) |
| `tmux-rig-status-setup.sh` | One-time setup for second status line |
| `claude-statusline.sh` | Claude Code status line helper |

## Installation Paths

Scripts detect their location in this priority:

1. `GT_TMUX_DIR` env var (custom location)
2. `~/.local/share/gt-tmux/` (curl|bash install)
3. `$GT_HOME/gthelper/` (manual install)

## Requirements

- `tmux` (terminal multiplexer)
- `curl` (for installer)
- `python3` (for status parsing)
- `gt` CLI (Gas Town binary - for status display)

## Troubleshooting

### Scripts not found

If you see "Could not find tmux-rig-status.sh", either:
- Run `install-tmux.sh` to install scripts
- Set `GT_HOME` to your Gas Town directory
- Set `GT_TMUX_DIR` to your scripts location

### Status bar shows "gt: offline"

The `gt` CLI is not running or not in PATH. Ensure Gas Town is set up.

### Colors wrong

Run `tmux-rig-status-setup.sh` to fix color settings for your terminal.
