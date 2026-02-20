#!/bin/bash
# tmux-rig-status-setup.sh — Enable the second tmux status line for Gas Town rigs
#
# Run once to enable, or add to your tmux.conf / shell profile.
# To disable: tmux set-option -g status 1
#
# Script location detection (in priority order):
#   1. GT_TMUX_DIR env var (custom location)
#   2. Same directory as this script (for direct execution)
#   3. ~/.local/share/gt-tmux/ (curl|bash install)
#   4. $GT_HOME/gthelper/ (manual install)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Find the script directory
find_scripts() {
    # Check GT_TMUX_DIR first
    if [ -n "$GT_TMUX_DIR" ] && [ -f "$GT_TMUX_DIR/tmux-rig-status.sh" ]; then
        echo "$GT_TMUX_DIR"
        return
    fi

    # Check same directory as this script
    if [ -f "$SCRIPT_DIR/tmux-rig-status.sh" ]; then
        echo "$SCRIPT_DIR"
        return
    fi

    # Check curl|bash install location
    if [ -f "$HOME/.local/share/gt-tmux/tmux-rig-status.sh" ]; then
        echo "$HOME/.local/share/gt-tmux"
        return
    fi

    # Check GT_HOME fallback
    if [ -n "$GT_HOME" ] && [ -f "$GT_HOME/gthelper/tmux-rig-status.sh" ]; then
        echo "$GT_HOME/gthelper"
        return
    fi

    # Last resort: auto-detect GT_HOME from script location
    if [ -z "$GT_HOME" ]; then
        GT_HOME="$(cd "$SCRIPT_DIR/.." && pwd)"
        if [ -f "$GT_HOME/gthelper/tmux-rig-status.sh" ]; then
            echo "$GT_HOME/gthelper"
            return
        fi
    fi

    # Not found
    echo ""
}

SCRIPTS_DIR="$(find_scripts)"
if [ -z "$SCRIPTS_DIR" ]; then
    echo "Error: Could not find tmux-rig-status.sh"
    echo "Run install-tmux.sh first, or set GT_HOME or GT_TMUX_DIR"
    exit 1
fi

# Export GT_HOME if we detected it (for telegram bot path)
if [ -z "$GT_HOME" ] && [ -d "$SCRIPT_DIR/.." ]; then
    GT_HOME="$(cd "$SCRIPT_DIR/.." && pwd)"
    export GT_HOME
fi

STATUS_SCRIPT="$SCRIPTS_DIR/tmux-rig-status.sh"
FILTER_SCRIPT="$SCRIPTS_DIR/tmux-status-right.sh"

# Enable 2 status lines
tmux set-option -g status 2

# Explicitly set text and background colors for all status bar elements
# Without these, text color inherits terminal default (yellow in Terminator, grey in GNOME Terminal, etc.)
tmux set-option -g status-style "fg=colour245,bg=colour232,none"
tmux set-option -g status-left-style "fg=colour245,bg=colour232,none"
tmux set-option -g status-right-style "fg=colour245,bg=colour232,none"

# Fix fill color for both lines (prevents brown background on some terminals)
tmux set-option -g 'status-format[0]' "#[fill=colour232]$(tmux show-option -gv 'status-format[0]')"
tmux set-option -g 'status-format[1]' \
  "#[fill=colour232,align=left,bg=colour232,fg=colour245]#($STATUS_SCRIPT)"

# Clear any stale session-level overrides that shadow global config
# BUG FIX: Previously this script set session-level options (-t hq-mayor) which
# baked in static values at setup time. These shadowed the global tmux.conf
# settings that use #() for dynamic evaluation. Session options always win over
# global, so the tmux.conf was effectively ignored for hq-mayor.
if tmux has-session -t hq-mayor 2>/dev/null; then
  tmux set-option -t hq-mayor -u status-left 2>/dev/null
  tmux set-option -t hq-mayor -u status-right 2>/dev/null
  tmux set-option -t hq-mayor -u status-left-length 2>/dev/null
fi

# Hide window list (redundant with single window)
tmux set-option -g window-status-current-format ""
tmux set-option -g window-status-format ""

echo "✓ Second status line enabled"
echo "  Scripts: $SCRIPTS_DIR/"
echo "  Line 1: configured by tmux.conf (dynamic — mayor name, user, folder, filtered status)"
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
