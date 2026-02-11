#!/bin/bash
# tmux-rig-status-setup.sh — Enable the second tmux status line for Gas Town rigs
#
# Run once to enable, or add to your tmux.conf / shell profile.
# To disable: tmux set-option -g status 1

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATUS_SCRIPT="$SCRIPT_DIR/tmux-rig-status.sh"
FILTER_SCRIPT="$SCRIPT_DIR/tmux-status-right.sh"

# Enable 2 status lines
tmux set-option -g status 2

# Fix fill color for both lines (prevents brown background on some terminals)
tmux set-option -g 'status-format[0]' "#[fill=colour232]$(tmux show-option -gv 'status-format[0]')"
tmux set-option -g 'status-format[1]' \
  "#[fill=colour232,align=left,bg=colour232,fg=colour245]#($STATUS_SCRIPT)"

# Remove rig LEDs from first line (rigs shown on second line instead)
# Apply to mayor session — adjust session name if needed
if tmux has-session -t hq-mayor 2>/dev/null; then
  tmux set-option -t hq-mayor status-right "#($FILTER_SCRIPT hq-mayor) %H:%M"
fi

# Hide window list (redundant with single window)
tmux set-option -g window-status-current-format ""
tmux set-option -g window-status-format ""

echo "✓ Second status line enabled"
echo "  Line 1: agent counts, hooked work, mail (no rig LEDs, no window list)"
echo "  Line 2: rig names with status icons"
echo "  Refresh: every $(tmux show-option -gv status-interval 2>/dev/null || echo 5)s"
echo ""
echo "Icons:"
echo "  🔨 = working (has polecats)"
echo "  🟢 = operational (witness + refinery running)"
echo "  🟡 = partial (only one agent running)"
echo "  ⚫ = stopped"
echo ""
echo "To disable: tmux set-option -g status 1"
