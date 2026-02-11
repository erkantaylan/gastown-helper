#!/bin/bash
# tmux-rig-status-setup.sh — Enable the second tmux status line for Gas Town rigs
#
# Run once to enable, or add to your tmux.conf / shell profile.
# To disable: tmux set-option -g status 1

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATUS_SCRIPT="$SCRIPT_DIR/tmux-rig-status.sh"

# Enable 2 status lines
tmux set-option -g status 2

# Set second line: dark background, rig overview
tmux set-option -g 'status-format[1]' \
  "#[align=left,bg=#1a1a2e,fg=#888888] Rigs: #($STATUS_SCRIPT)"

echo "✓ Second status line enabled"
echo "  Showing: rig names with status icons"
echo "  Refresh: every $(tmux show-option -gv status-interval)s"
echo ""
echo "Icons:"
echo "  🔨 = working (has polecats)"
echo "  🟢 = operational (witness + refinery running)"
echo "  🟡 = partial (only one agent running)"
echo "  ⚫ = stopped"
echo ""
echo "To disable: tmux set-option -g status 2"
