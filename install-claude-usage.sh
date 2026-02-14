#!/bin/bash
# install-claude-usage.sh - Install Claude usage tracking for Gas Town tmux
#
# This script installs the Claude usage tracker adapted from:
# https://github.com/she-llac/claude-counter by @she-llac
#
# Usage: bash install-claude-usage.sh [mayor-rig-path]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MAYOR_RIG_DIR="${1:-}"

echo "═══════════════════════════════════════════════════════════"
echo "  Claude Usage Tracking Installer for Gas Town"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "  Inspired by: https://github.com/she-llac/claude-counter"
echo "  by @she-llac"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""

# Find mayor/rig directory if not provided
if [ -z "$MAYOR_RIG_DIR" ]; then
    # Try common locations
    if [ -d "$HOME/gastown/mayor/rig" ]; then
        MAYOR_RIG_DIR="$HOME/gastown/mayor/rig"
    elif [ -d "$HOME/antik/mayor/rig" ]; then
        MAYOR_RIG_DIR="$HOME/antik/mayor/rig"
    elif [ -d "$SCRIPT_DIR/../mayor/rig" ]; then
        MAYOR_RIG_DIR="$SCRIPT_DIR/../mayor/rig"
    else
        echo "❌ Error: Could not find mayor/rig directory"
        echo ""
        echo "Please provide the path to your Gas Town mayor/rig directory:"
        echo "  bash $0 /path/to/mayor/rig"
        echo ""
        exit 1
    fi
fi

# Verify directory exists
if [ ! -d "$MAYOR_RIG_DIR" ]; then
    echo "❌ Error: Directory not found: $MAYOR_RIG_DIR"
    exit 1
fi

echo "✓ Found Gas Town mayor/rig directory:"
echo "  $MAYOR_RIG_DIR"
echo ""

# Check if claude-usage.sh template exists in gthelper
if [ ! -f "$SCRIPT_DIR/claude-usage.sh.template" ]; then
    echo "❌ Error: claude-usage.sh.template not found in $SCRIPT_DIR"
    echo ""
    echo "This file should contain the Claude usage tracker script."
    echo "Please ensure you have the complete gthelper package."
    exit 1
fi

# Copy the script
echo "📋 Copying claude-usage.sh to mayor/rig..."
cp "$SCRIPT_DIR/claude-usage.sh.template" "$MAYOR_RIG_DIR/claude-usage.sh"
chmod +x "$MAYOR_RIG_DIR/claude-usage.sh"
echo "✓ Script installed"
echo ""

# Test the script
echo "🧪 Testing claude-usage.sh..."
if bash "$MAYOR_RIG_DIR/claude-usage.sh" >/dev/null 2>&1; then
    echo "✓ Script works"
else
    echo "⚠  Script test failed (may work after authentication)"
fi
echo ""

# Check tmux configuration
echo "🔍 Checking tmux configuration..."

# Get current second status bar
current_status=$(tmux show-option -gv 'status-format[1]' 2>/dev/null || echo "")

if [ -z "$current_status" ]; then
    echo "⚠  No second status bar configured"
    echo ""
    echo "You need to set up the two-line tmux status bar first."
    echo "See: https://github.com/steveyegge/gastown-helper"
    echo ""
    exit 1
fi

# Check if claude-usage already in status bar
if echo "$current_status" | grep -q "claude-usage"; then
    echo "✓ Claude usage already in tmux status bar"
    echo ""
else
    echo "📝 Updating tmux second status bar..."

    # Add claude-usage to right side
    new_status="#[fill=colour232,align=left,bg=colour232,fg=colour245]#($MAYOR_RIG_DIR/tmux-rig-status.sh)#[align=right,fg=colour245]#($MAYOR_RIG_DIR/claude-usage.sh)"

    tmux set-option -g 'status-format[1]' "$new_status"
    echo "✓ Tmux configuration updated"
    echo ""
fi

# Verify Claude Code authentication
echo "🔐 Checking Claude Code authentication..."
if [ -f "$HOME/.claude/.credentials.json" ]; then
    echo "✓ Claude credentials found"
else
    echo "⚠  No Claude credentials found"
    echo ""
    echo "Run: claude auth login"
    echo ""
fi

# Summary
echo "═══════════════════════════════════════════════════════════"
echo "  Installation Complete!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Your tmux second status bar now shows:"
echo ""
echo "  [rigs on left]          🤖 5h:XX% 7d:XX% | XXXmsg XXk↑XXk↓"
echo "                          └─ Claude usage (right side)"
echo ""
echo "What the display means:"
echo "  5h/7d  = Claude.ai usage limits (updates every 5min)"
echo "  XXXmsg = Messages sent today"
echo "  XX↑    = Input tokens (thousands)"
echo "  XX↓    = Output tokens (thousands)"
echo ""
echo "Colors (when API data loads):"
echo "  🟢 Green  = Usage < 50%"
echo "  🟡 Yellow = Usage 50-80%"
echo "  🔴 Red    = Usage > 80%"
echo ""
echo "Files installed:"
echo "  $MAYOR_RIG_DIR/claude-usage.sh"
echo ""
echo "Documentation:"
echo "  $SCRIPT_DIR/CLAUDE_USAGE_TRACKING.md"
echo ""
echo "Credits:"
echo "  Original: https://github.com/she-llac/claude-counter"
echo "  by @she-llac"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "To test: bash $MAYOR_RIG_DIR/claude-usage.sh"
echo "To uninstall: See CLAUDE_USAGE_TRACKING.md#uninstallation"
echo ""
