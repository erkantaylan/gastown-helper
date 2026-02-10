# Customizing the Gas Town tmux Status Bar

Gas Town sets the tmux status bar automatically when creating sessions. You can override it per-session or persistently via `~/.bashrc`.

## What Gas Town Sets by Default

| Option | Default Value | Description |
|--------|--------------|-------------|
| `status-left` | `🎩 Mayor ` | Role indicator |
| `status-right` | `#(gt status-line --session=hq-mayor 2>/dev/null) %H:%M` | Rig status + clock |
| `status-style` | `bg=#3d3200,fg=#ffd700` | Mad Max gold theme |
| Window list | `0:claude*` | Window index, program name, `*` = active |

## Override: Show user:town in status bar

Add to `~/.bashrc`:

```bash
# Override Gas Town tmux status-left with user:town
[ -n "$TMUX" ] && tmux set-option status-left "🎩 Mayor | $(whoami):antik " 2>/dev/null
```

Replace `antik` with your town name (from `mayor/town.json`).

## Override: Hide the window list

The default window list shows `0:claude*` which is redundant when you only run one window. To hide it, add to `~/.bashrc`:

```bash
# Hide tmux window list (only one window anyway)
[ -n "$TMUX" ] && tmux set-option window-status-current-format "" 2>/dev/null
[ -n "$TMUX" ] && tmux set-option window-status-format "" 2>/dev/null
```

## Result

Before: `🎩 Mayor  0:claude*`
After:  `🎩 Mayor | gastown:antik`

## One-time change (non-persistent)

If you just want to try it without editing bashrc:

```bash
tmux set-option -t hq-mayor status-left "🎩 Mayor | $(whoami):antik "
tmux set-option -t hq-mayor window-status-current-format ""
tmux set-option -t hq-mayor window-status-format ""
```

## Notes

- These overrides run each time a shell starts inside tmux, re-applying after `gt mayor attach`
- The `status-right` is left unchanged — it calls `gt status-line` which shows rig/polecat counts and is useful
- The gold theme (`status-style`) comes from the `mad-max` theme and is left unchanged
