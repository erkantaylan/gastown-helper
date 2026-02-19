#!/bin/bash
# install-tmux.sh — curl|bash installer for Gas Town tmux configuration
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/erkantaylan/gastown-helper/master/install-tmux.sh | bash
#
# What it does:
#   1. Downloads tmux scripts to ~/.local/share/gt-tmux/
#   2. Installs tmux.conf to ~/.config/tmux/tmux.conf
#   3. Reloads tmux configuration if tmux is running
#
# The installed config is independent of Gas Town rig structure and persists
# across session restarts.

set -e

INSTALL_DIR="${GT_TMUX_DIR:-$HOME/.local/share/gt-tmux}"
CONFIG_DIR="$HOME/.config/tmux"
REPO_URL="https://raw.githubusercontent.com/erkantaylan/gastown-helper/master"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[info]${NC} $*"; }
warn() { echo -e "${YELLOW}[warn]${NC} $*"; }
error() { echo -e "${RED}[error]${NC} $*" >&2; }

# Check for required tools
check_deps() {
    local missing=()
    for cmd in curl python3; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing required tools: ${missing[*]}"
        error "Install them and try again."
        exit 1
    fi
}

# Download a file from the repo
download() {
    local file="$1"
    local dest="$2"

    if ! curl -fsSL "$REPO_URL/$file" -o "$dest"; then
        error "Failed to download $file"
        return 1
    fi
}

# Main installation
main() {
    info "Installing Gas Town tmux configuration..."

    check_deps

    # Create directories
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$CONFIG_DIR"

    # Download scripts
    info "Downloading tmux scripts to $INSTALL_DIR/"
    download "tmux-rig-status.sh" "$INSTALL_DIR/tmux-rig-status.sh"
    download "tmux-status-right.sh" "$INSTALL_DIR/tmux-status-right.sh"
    download "tmux-rig-status-setup.sh" "$INSTALL_DIR/tmux-rig-status-setup.sh"
    download "claude-statusline.sh" "$INSTALL_DIR/claude-statusline.sh"

    # Make scripts executable
    chmod +x "$INSTALL_DIR"/*.sh

    # Download and install tmux.conf
    info "Installing tmux.conf to $CONFIG_DIR/"

    # Backup existing config if present
    if [ -f "$CONFIG_DIR/tmux.conf" ]; then
        backup="$CONFIG_DIR/tmux.conf.backup.$(date +%Y%m%d_%H%M%S)"
        warn "Backing up existing tmux.conf to $backup"
        cp "$CONFIG_DIR/tmux.conf" "$backup"
    fi

    download "tmux.conf" "$CONFIG_DIR/tmux.conf"

    # Patch tmux.conf to use installed paths
    info "Configuring paths..."
    sed -i "s|\$GT_HOME/gthelper/|$INSTALL_DIR/|g" "$CONFIG_DIR/tmux.conf"
    sed -i "s|\$GT_HOME/services/telegram-bot/|$HOME/.local/bin/|g" "$CONFIG_DIR/tmux.conf"

    # Reload tmux if running
    if tmux list-sessions &>/dev/null; then
        info "Reloading tmux configuration..."
        tmux source-file "$CONFIG_DIR/tmux.conf" 2>/dev/null || warn "Could not reload tmux (you may need to reload manually)"
    fi

    echo ""
    info "Installation complete!"
    echo ""
    echo "Scripts installed to: $INSTALL_DIR/"
    echo "Config installed to:  $CONFIG_DIR/tmux.conf"
    echo ""
    echo "To enable the second status line with rig overview:"
    echo "  $INSTALL_DIR/tmux-rig-status-setup.sh"
    echo ""
    echo "To reload tmux config manually:"
    echo "  tmux source-file $CONFIG_DIR/tmux.conf"
    echo ""
    echo "To set your mayor name (appears in status bar):"
    echo "  echo 'YourName' > ~/.gt-mayor-name"
}

main "$@"
