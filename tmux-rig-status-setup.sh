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

# Mayor name, username, and town directory
MAYOR_NAME=$(cat ~/.gt-mayor-name 2>/dev/null || echo "Mayor")
USERNAME=$(whoami)
TOWN_DIR=$(basename "${GT_HOME:-$HOME}" 2>/dev/null || echo "~")

# Detect bot version and name from deployed binary + .env
# Try multiple locations for the bot binary
BOT_VERSION=""
BOT_NAME=""
for bot_path in \
    "$HOME/.local/bin/gt-bot" \
    "${GT_HOME:-/nonexistent}/services/telegram-bot/gt-bot" \
    "$(command -v gt-bot 2>/dev/null)"
do
    if [ -x "$bot_path" ]; then
        BOT_VERSION=$("$bot_path" --version 2>/dev/null || echo "")
        break
    fi
done

# Try to get bot name from .env (if GT_HOME is set)
if [ -n "$GT_HOME" ] && [ -f "$GT_HOME/services/telegram-bot/.env" ]; then
    BOT_NAME=$(grep '^TELEGRAM_BOT_TOKEN=' "$GT_HOME/services/telegram-bot/.env" 2>/dev/null | cut -d= -f2 | xargs -I{} curl -s "https://api.telegram.org/bot{}/getMe" 2>/dev/null | grep -o '"username":"[^"]*"' | cut -d'"' -f4)
fi

BOT_BADGE=""
if [ -n "$BOT_VERSION" ]; then
    BOT_LABEL="📱${BOT_VERSION}"
    [ -n "$BOT_NAME" ] && BOT_LABEL="📱${BOT_VERSION} @${BOT_NAME}"
    BOT_BADGE="#[fg=colour236,bg=colour238,none]#[fg=colour250,bg=colour238]${BOT_LABEL}#[fg=colour238,bg=default,none]"
fi

# Apply to mayor session
if tmux has-session -t hq-mayor 2>/dev/null; then
  # Ensure status-left is long enough for mayor name + user[town] + bot badge
  tmux set-option -t hq-mayor status-left-length 80
  # Left: mayor name (bold yellow bg) + user[town] + bot badge
  tmux set-option -t hq-mayor status-left "#[fg=colour232,bg=colour220,bold] 🎩 $MAYOR_NAME #[fg=colour220,bg=colour24,none]#[fg=colour255,bg=colour24,bold]👶${USERNAME} 📁${TOWN_DIR}${BOT_BADGE}"
  # Right: filtered gt status (no rig LEDs) + time
  tmux set-option -t hq-mayor status-right "#($FILTER_SCRIPT hq-mayor) %H:%M"
fi

# Hide window list (redundant with single window)
tmux set-option -g window-status-current-format ""
tmux set-option -g window-status-format ""

echo "✓ Second status line enabled"
echo "  Scripts: $SCRIPTS_DIR/"
echo "  Mayor: $MAYOR_NAME (from ~/.gt-mayor-name)"
echo "  User: ${USERNAME}[${TOWN_DIR}]"
[ -n "$BOT_VERSION" ] && echo "  Bot: ${BOT_VERSION}${BOT_NAME:+ @$BOT_NAME}"
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
