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

# Explicitly set text and background colors for all status bar elements
# Without these, text color inherits terminal default (yellow in Terminator, grey in GNOME Terminal, etc.)
tmux set-option -g status-style "fg=colour245,bg=colour232,none"
tmux set-option -g status-left-style "fg=colour245,bg=colour232,none"
tmux set-option -g status-right-style "fg=colour245,bg=colour232,none"

# Fix fill color for both lines (prevents brown background on some terminals)
tmux set-option -g 'status-format[0]' "#[fill=colour232]$(tmux show-option -gv 'status-format[0]')"
tmux set-option -g 'status-format[1]' \
  "#[fill=colour232,align=left,bg=colour232,fg=colour245]#($STATUS_SCRIPT)"

# Mayor name, username, and town directory
MAYOR_NAME=$(cat ~/.gt-mayor-name 2>/dev/null || echo "Mayor")
USERNAME=$(whoami)
TOWN_DIR=$(basename "$(cd "$SCRIPT_DIR/../../.." 2>/dev/null && pwd)")

# Detect bot version and name from deployed binary + .env
TOWN_ROOT="$(cd "$SCRIPT_DIR/../../.." 2>/dev/null && pwd)"
BOT_BIN="$TOWN_ROOT/services/telegram-bot/gt-bot"
BOT_ENV="$TOWN_ROOT/services/telegram-bot/.env"
BOT_VERSION=$("$BOT_BIN" --version 2>/dev/null || echo "")
BOT_NAME=$(grep '^TELEGRAM_BOT_TOKEN=' "$BOT_ENV" 2>/dev/null | cut -d= -f2 | xargs -I{} curl -s "https://api.telegram.org/bot{}/getMe" 2>/dev/null | grep -o '"username":"[^"]*"' | cut -d'"' -f4)
BOT_BADGE=""
if [ -n "$BOT_VERSION" ]; then
    BOT_LABEL="📱${BOT_VERSION}"
    [ -n "$BOT_NAME" ] && BOT_LABEL="📱${BOT_VERSION} @${BOT_NAME}"
    BOT_BADGE="#[fg=colour236,bg=colour238,none] #[fg=colour250,bg=colour238] ${BOT_LABEL} #[fg=colour238,bg=default,none]"
fi

# Apply to mayor session
if tmux has-session -t hq-mayor 2>/dev/null; then
  # Ensure status-left is long enough for mayor name + user[town] + bot badge
  tmux set-option -t hq-mayor status-left-length 80
  # Left: mayor name (bold yellow bg) + user[town] + bot badge
  tmux set-option -t hq-mayor status-left "#[fg=colour232,bg=colour220,bold] 🎩 $MAYOR_NAME #[fg=colour220,bg=colour24,none] #[fg=colour255,bg=colour24,bold] 👤${USERNAME} 📁${TOWN_DIR} ${BOT_BADGE} "
  # Right: filtered gt status (no rig LEDs) + time
  tmux set-option -t hq-mayor status-right "#($FILTER_SCRIPT hq-mayor) %H:%M"
fi

# Hide window list (redundant with single window)
tmux set-option -g window-status-current-format ""
tmux set-option -g window-status-format ""

echo "✓ Second status line enabled"
echo "  Mayor: $MAYOR_NAME (from ~/.gt-mayor-name)"
echo "  User: ${USERNAME}[${TOWN_DIR}]${BOT_BADGE}"
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
