#!/bin/bash
# install-tmux.sh — Single-file installer for Gas Town tmux configuration
#
# Install:  curl -fsSL https://raw.githubusercontent.com/erkantaylan/gastown-helper/master/install-tmux.sh | bash
# Update:   Same command. Detects existing config and offers to keep settings.
# Auto:     curl ... | bash -s -- --yes   (use existing config / defaults, no prompts)
#
# tmux scripts are embedded. Telegram bot source is cloned on demand if needed.
# Runtime scripts are written to ~/.local/share/gt-tmux/
# Config goes to ~/.config/tmux/tmux.conf

set -e

INSTALL_DIR="${GT_TMUX_DIR:-$HOME/.local/share/gt-tmux}"
CONFIG_DIR="$HOME/.config/tmux"
PREFS_DIR="$HOME/.config/gt-tmux"
PREFS_FILE="$PREFS_DIR/config"
AUTO_YES=false

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# ─── TTY for interactive prompts (supports curl | bash) ───────────────────────
if [[ -t 0 ]]; then
    TTY_IN=/dev/stdin
else
    TTY_IN=/dev/tty
fi

prompt() {
    local text="$1" var="$2"
    if $AUTO_YES; then
        # In auto mode, use whatever default is already set
        return
    fi
    echo -ne "$text" >&2
    IFS= read -r "$var" < "$TTY_IN"
}

info() { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[x]${NC} $*" >&2; }
step() { echo -e "\n${BLUE}${BOLD}>>> $*${NC}"; }

# ─── Dependency check ─────────────────────────────────────────────────────────
check_deps() {
    local missing=()
    for cmd in python3 tmux; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing required tools: ${missing[*]}"
        exit 1
    fi
}

# ─── Configuration ────────────────────────────────────────────────────────────

MAYOR_NAME=""
SHOW_USER_FOLDER="y"
SETUP_TELEGRAM="n"
TELEGRAM_BOT_NAME=""
TELEGRAM_TOKEN=""
TELEGRAM_CHAT_ID=""
ENABLE_SECOND_BAR="y"

load_existing_config() {
    if [[ -f "$PREFS_FILE" ]]; then
        source "$PREFS_FILE"
        return 0
    fi
    return 1
}

gather_inputs() {
    echo -e "${BOLD}"
    echo "=========================================="
    echo "  Gas Town tmux configuration installer"
    echo "=========================================="
    echo -e "${NC}"

    # Check for existing config (update flow)
    if load_existing_config; then
        echo -e "  Found existing config at ${YELLOW}$PREFS_FILE${NC}"
        echo "  Mayor name:   ${MAYOR_NAME}"
        echo "  User/folder:  ${SHOW_USER_FOLDER}"
        echo "  Telegram:     ${SETUP_TELEGRAM}"
        echo "  Second bar:   ${ENABLE_SECOND_BAR}"
        echo ""

        if $AUTO_YES; then
            info "Using existing settings (--yes)"
            return
        fi

        local reuse
        prompt "$(echo -e "Keep these settings? [Y/n]: ")" reuse
        if [[ "${reuse,,}" != "n" ]]; then
            info "Updating with existing settings"
            return
        fi
        echo ""
    elif $AUTO_YES; then
        info "No existing config — using defaults (--yes)"
        MAYOR_NAME="${MAYOR_NAME:-Mayor}"
        return
    fi

    # Step 1: Mayor name
    step "Step 1: Mayor Name"
    prompt "$(echo -e "What name for the status bar? [${YELLOW}${MAYOR_NAME:-Mayor}${NC}]: ")" MAYOR_NAME
    MAYOR_NAME="${MAYOR_NAME:-Mayor}"

    # Step 2: Display preferences
    step "Step 2: Display Preferences"
    prompt "$(echo -e "Show ${YELLOW}username${NC} and ${YELLOW}folder${NC} on status bar? [Y/n]: ")" SHOW_USER_FOLDER
    SHOW_USER_FOLDER="${SHOW_USER_FOLDER:-y}"
    SHOW_USER_FOLDER="${SHOW_USER_FOLDER,,}"

    # Step 3: Telegram setup
    step "Step 3: Telegram Notifications"
    prompt "$(echo -e "Set up ${YELLOW}Telegram${NC} notifications? [y/N]: ")" SETUP_TELEGRAM
    SETUP_TELEGRAM="${SETUP_TELEGRAM:-n}"
    SETUP_TELEGRAM="${SETUP_TELEGRAM,,}"

    if [[ "$SETUP_TELEGRAM" == "y" ]]; then
        prompt "  Bot username (e.g. my_gastown_bot): " TELEGRAM_BOT_NAME
        prompt "  Bot token from @BotFather: " TELEGRAM_TOKEN
        prompt "  Your Telegram chat ID: " TELEGRAM_CHAT_ID
        if [[ -z "$TELEGRAM_BOT_NAME" || -z "$TELEGRAM_TOKEN" || -z "$TELEGRAM_CHAT_ID" ]]; then
            warn "Bot name, token, or chat ID empty — skipping Telegram setup."
            SETUP_TELEGRAM="n"
        fi
    fi

    # Step 4: Second status bar
    step "Step 4: Second Status Bar"
    prompt "$(echo -e "Enable ${YELLOW}second bar${NC} with rig overview? [Y/n]: ")" ENABLE_SECOND_BAR
    ENABLE_SECOND_BAR="${ENABLE_SECOND_BAR:-y}"
    ENABLE_SECOND_BAR="${ENABLE_SECOND_BAR,,}"

    # Summary
    echo ""
    step "Configuration Summary"
    echo "  Mayor name:   ${MAYOR_NAME}"
    echo "  User/folder:  ${SHOW_USER_FOLDER}"
    echo "  Telegram:     ${SETUP_TELEGRAM}"
    echo "  Second bar:   ${ENABLE_SECOND_BAR}"
    echo ""
    local confirm
    prompt "Proceed? [Y/n]: " confirm
    if [[ "${confirm,,}" == "n" ]]; then
        echo "Aborted."
        exit 0
    fi
}

# ─── Save preferences ─────────────────────────────────────────────────────────

save_config() {
    mkdir -p "$PREFS_DIR"

    cat > "$PREFS_FILE" << EOF
# Gas Town tmux preferences (generated by install-tmux.sh)
MAYOR_NAME=${MAYOR_NAME}
SHOW_USER_FOLDER=${SHOW_USER_FOLDER}
SETUP_TELEGRAM=${SETUP_TELEGRAM}
TELEGRAM_BOT_NAME=${TELEGRAM_BOT_NAME}
ENABLE_SECOND_BAR=${ENABLE_SECOND_BAR}
INSTALL_DIR=${INSTALL_DIR}
EOF

    echo "$MAYOR_NAME" > "$HOME/.gt-mayor-name"

    if [[ "$SETUP_TELEGRAM" == "y" ]]; then
        if [[ -n "$TELEGRAM_BOT_NAME" ]]; then
            echo "${TELEGRAM_BOT_NAME}" > "$HOME/.gt-bot-name"
        fi
        # Only write telegram.env if we have fresh values (don't wipe on update)
        if [[ -n "$TELEGRAM_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
            cat > "$PREFS_DIR/telegram.env" << EOF
TELEGRAM_BOT_TOKEN=${TELEGRAM_TOKEN}
TELEGRAM_CHAT_ID=${TELEGRAM_CHAT_ID}
EOF
            chmod 600 "$PREFS_DIR/telegram.env"
        fi
    fi

    info "Config saved"
}

# ─── Write runtime scripts ────────────────────────────────────────────────────

install_scripts() {
    mkdir -p "$INSTALL_DIR"

    # --- tmux-anti-override.sh ---
    cat > "$INSTALL_DIR/tmux-anti-override.sh" << 'SCRIPT'
#!/bin/bash
# Clears Gas Town session-level overrides on hq-mayor.
# Called via tmux #() in status-format[1] every status-interval (5s).
# Lives in line 2 because Gas Town overrides session-level status-right
# (which shadows line 1's #() calls) but does NOT touch status-format[1].
# Returns empty string (invisible side-effect only).
if tmux show-options -t hq-mayor status-left 2>/dev/null | grep -q "status-left"; then
    tmux set-option -t hq-mayor -u status-left 2>/dev/null
    tmux set-option -t hq-mayor -u status-right 2>/dev/null
    tmux set-option -t hq-mayor -u status-left-length 2>/dev/null
    tmux set-option -t hq-mayor -u status-right-length 2>/dev/null
    tmux set-option -t hq-mayor -u status-style 2>/dev/null
    tmux set-option -t hq-mayor -u status-interval 2>/dev/null
fi
SCRIPT

    # --- tmux-status-right.sh ---
    cat > "$INSTALL_DIR/tmux-status-right.sh" << 'SCRIPT'
#!/bin/bash
# Filtered status-right for first tmux line.
# Strips rig LEDs (shown on second line instead).
SESSION="${1:-hq-mayor}"
GT_BIN="${GT_BIN:-$(command -v gt 2>/dev/null || echo /usr/local/bin/gt)}"
MAYOR_NAME=$(cat ~/.gt-mayor-name 2>/dev/null || echo "Mayor")

line=$("$GT_BIN" status-line --session="$SESSION" 2>/dev/null)

echo "$line" | python3 -c "
import sys, re
line = sys.stdin.read().strip()
mayor_name = '$MAYOR_NAME'
line = line.replace('🎩 Mayor', '')
parts = [p.strip() for p in line.split(' | ') if p.strip()]
rig_icons = {'🟢','🟡','⚫','🔨','🅿️','🛑'}
filtered = []
for p in parts:
    tokens = p.split()
    if tokens and tokens[0] in rig_icons:
        continue
    filtered.append(p)
result = ' | '.join(filtered)
result = result.rstrip(' |').rstrip()
if result:
    result += ' |'
print(result)
"
SCRIPT

    # --- tmux-rig-status.sh ---
    cat > "$INSTALL_DIR/tmux-rig-status.sh" << 'SCRIPT'
#!/bin/bash
# Second tmux status line showing rig overview.
GT_BIN="${GT_BIN:-$(command -v gt 2>/dev/null || echo /usr/local/bin/gt)}"
export NO_COLOR=1

json=$("$GT_BIN" status --json 2>/dev/null)
if [ -z "$json" ]; then
    echo "gt: offline"
    exit 0
fi

python3 -c "
import json, sys

data = json.loads(sys.stdin.read())
rigs = data.get('rigs', [])

if not rigs:
    print(' No rigs')
    sys.exit(0)

rigs.sort(key=lambda r: r['name'])

parts = []
for rig in rigs:
    name = rig['name']
    polecats = rig.get('polecat_count', 0)

    agents = rig.get('agents', [])
    witness_up = False
    refinery_up = False
    for a in agents:
        if a.get('role') == 'witness' and a.get('running'):
            witness_up = True
        if a.get('role') == 'refinery' and a.get('running'):
            refinery_up = True

    if polecats > 0:
        icon = '🔨'
    elif witness_up and refinery_up:
        icon = '🟢'
    elif witness_up or refinery_up:
        icon = '🟡'
    else:
        icon = '⚫'

    parts.append(f'{icon}{name}')

print(' '.join(parts))
" <<< "$json"
SCRIPT

    # --- claude-statusline.sh ---
    cat > "$INSTALL_DIR/claude-statusline.sh" << 'SCRIPT'
#!/bin/bash
# Claude Code status line for Gas Town Mayor.
# Shows: mayor name, agent counts, hooked work, mail (NO rig LEDs)
MAYOR_NAME=$(cat ~/.gt-mayor-name 2>/dev/null || echo "Mayor")
GT_BIN="${GT_BIN:-$(command -v gt 2>/dev/null || echo gt)}"

line=$("$GT_BIN" status-line --session=hq-mayor 2>/dev/null)

filtered=$(echo "$line" | python3 -c "
import sys
line = sys.stdin.read().strip()
parts = [p.strip() for p in line.split(' | ') if p.strip()]
rig_icons = {'🟢','🟡','⚫','🔨','🅿️','🛑'}
filtered = []
for p in parts:
    tokens = p.split()
    if tokens and tokens[0] in rig_icons:
        continue
    filtered.append(p)
result = ' | '.join(filtered)
result = result.rstrip(' |').rstrip()
print(result)
" 2>/dev/null)

if [ -n "$filtered" ]; then
    echo "🎩 $MAYOR_NAME $filtered"
else
    echo "🎩 $MAYOR_NAME"
fi
SCRIPT

    chmod +x "$INSTALL_DIR"/*.sh
    info "Runtime scripts installed to $INSTALL_DIR/"
}

# ─── Generate tmux.conf ───────────────────────────────────────────────────────

generate_tmux_conf() {
    mkdir -p "$CONFIG_DIR"

    # Backup existing
    if [ -f "$CONFIG_DIR/tmux.conf" ]; then
        local backup="$CONFIG_DIR/tmux.conf.backup.$(date +%Y%m%d_%H%M%S)"
        warn "Backing up existing tmux.conf to $backup"
        cp "$CONFIG_DIR/tmux.conf" "$backup"
    fi

    # Build status-left segments
    # Detect town name for folder display
    local town_name=""
    if [[ -n "$GT_HOME" ]]; then
        town_name="$(basename "$GT_HOME")"
    else
        for dir in "$HOME"/*/mayor; do
            if [[ -d "$dir" ]]; then
                town_name="$(basename "$(dirname "$dir")")"
                break
            fi
        done
    fi
    town_name="${town_name:-gt}"

    local left_segments=""
    if [[ "$SHOW_USER_FOLDER" == "y" ]]; then
        left_segments+="#[fg=colour220,bg=colour24]#[fg=colour255,bg=colour24,bold] 👤#(whoami) 📁${town_name} "
        if [[ "$SETUP_TELEGRAM" == "y" ]]; then
            left_segments+='#[fg=colour24,bg=colour238]#[fg=colour250,bg=colour238] 📱@#(cat ~/.gt-bot-name 2>/dev/null) #[fg=colour238,bg=colour232]'
        else
            left_segments+='#[fg=colour24,bg=colour232]'
        fi
    elif [[ "$SETUP_TELEGRAM" == "y" ]]; then
        left_segments+='#[fg=colour220,bg=colour238]#[fg=colour250,bg=colour238] 📱@#(cat ~/.gt-bot-name 2>/dev/null) #[fg=colour238,bg=colour232]'
    fi

    local status_count="2"
    if [[ "$ENABLE_SECOND_BAR" != "y" ]]; then
        status_count="1"
    fi

    local D="$INSTALL_DIR"  # shorthand for readability

    cat > "$CONFIG_DIR/tmux.conf" << TMUXCONF
# Gas Town tmux config — generated by install-tmux.sh
# Re-run the installer to update: curl -fsSL <repo>/install-tmux.sh | bash

set -g default-terminal "screen-256color"
set -s escape-time 10
set -g history-limit 5000
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -g mouse on
set -g status-interval 5

# -- status bar ----------------------------------------------------------------

set -g status ${status_count}
set -g status-style "fg=colour245,bg=colour232"
set -g status-left-length 200
set -g status-right-length 200

# Line 1 left: mayor badge + segments
set -g status-left "\\
#[fg=colour232,bg=colour220,bold] 🎩 #(cat ~/.gt-mayor-name 2>/dev/null || echo Mayor) \\
${left_segments} "

# Line 1 right: gt status (filtered) + time
set -g status-right "\\
#(${D}/tmux-status-right.sh hq-mayor) \\
#[fg=colour245]%H:%M %d %b "

# Line 2: rig overview + anti-override (runs here because Gas Town
# overrides session-level status-right but NOT status-format[1])
set -g status-format[1] "\\
#(${D}/tmux-anti-override.sh)\\
#[fill=colour232,align=left,bg=colour232,fg=colour245]\\
#(${D}/tmux-rig-status.sh)"

# Hide window list
setw -g window-status-format ""
setw -g window-status-current-format ""

# -- navigation ----------------------------------------------------------------

set -g prefix C-b
bind r source-file ~/.config/tmux/tmux.conf \\; display "Config reloaded"
bind - split-window -v -c "#{pane_current_path}"
bind | split-window -h -c "#{pane_current_path}"
bind -r h select-pane -L
bind -r j select-pane -D
bind -r k select-pane -U
bind -r l select-pane -R
TMUXCONF

    info "tmux.conf generated at $CONFIG_DIR/tmux.conf"
}

# ─── Telegram bot installation ─────────────────────────────────────────────────

install_telegram_bot() {
    if [[ "$SETUP_TELEGRAM" != "y" ]]; then
        return
    fi

    # Need token and chat ID
    if [[ -z "$TELEGRAM_TOKEN" && -f "$PREFS_DIR/telegram.env" ]]; then
        source "$PREFS_DIR/telegram.env"
        TELEGRAM_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
        TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"
    fi
    if [[ -z "$TELEGRAM_TOKEN" || -z "$TELEGRAM_CHAT_ID" ]]; then
        warn "No Telegram credentials — skipping bot installation"
        return
    fi

    # Detect town root
    local town_root=""
    if [[ -n "$GT_HOME" ]]; then
        town_root="$GT_HOME"
    else
        for dir in "$HOME"/*/mayor; do
            if [[ -d "$dir" ]]; then
                town_root="$(dirname "$dir")"
                break
            fi
        done
    fi
    if [[ -z "$town_root" ]]; then
        warn "Could not detect town directory — skipping bot installation"
        return
    fi

    local town_name
    town_name="$(basename "$town_root")"
    local svc_dir="$town_root/services/telegram-bot"
    local svc_name="gt-bot-${town_name}"
    local bot_src=""
    local cloned_tmp=""

    # Look for bot source locally first (rig may already be set up)
    for candidate in \
        "$town_root/gthelper/mayor/rig/telegram-bot" \
        "$town_root"/gthelper/*/rig/telegram-bot; do
        if [[ -f "$candidate/main.go" ]]; then
            bot_src="$candidate"
            break
        fi
    done

    # Not found locally — clone the repo to a temp dir
    if [[ -z "$bot_src" ]]; then
        if ! command -v git &>/dev/null; then
            warn "git not installed — cannot fetch bot source"
            return
        fi
        local repo_url="git@github.com:erkantaylan/gastown-helper.git"
        cloned_tmp="$(mktemp -d)"
        info "Bot source not found locally — cloning from $repo_url..."
        if ! git clone --depth 1 "$repo_url" "$cloned_tmp/gastown-helper" 2>&1; then
            warn "Failed to clone $repo_url — skipping bot installation"
            rm -rf "$cloned_tmp"
            return
        fi
        if [[ -f "$cloned_tmp/gastown-helper/telegram-bot/main.go" ]]; then
            bot_src="$cloned_tmp/gastown-helper/telegram-bot"
        else
            warn "Cloned repo does not contain telegram-bot/main.go — skipping"
            rm -rf "$cloned_tmp"
            return
        fi
    fi

    # Check for go
    if ! command -v go &>/dev/null; then
        warn "Go not installed — skipping bot build"
        return
    fi

    # Check if already running with same version
    if systemctl is-active --quiet "$svc_name" 2>/dev/null; then
        if [[ -f "$svc_dir/gt-bot" ]]; then
            local running_ver
            running_ver=$("$svc_dir/gt-bot" --version 2>/dev/null || echo "")
            info "Bot $svc_name already running ($running_ver) — rebuilding"
            sudo systemctl stop "$svc_name" 2>/dev/null || true
        fi
    fi

    # Build
    info "Building telegram bot..."
    (cd "$bot_src" && go build -o gt-bot . 2>&1) || { warn "Bot build failed"; return; }

    # Install binary
    mkdir -p "$svc_dir"
    cp "$bot_src/gt-bot" "$svc_dir/gt-bot"
    chmod +x "$svc_dir/gt-bot"

    # Install gt-telegram helper
    if [[ -f "$bot_src/gt-telegram" ]]; then
        cp "$bot_src/gt-telegram" "$svc_dir/gt-telegram"
        chmod +x "$svc_dir/gt-telegram"
        mkdir -p "$HOME/.local/bin"
        ln -sf "$svc_dir/gt-telegram" "$HOME/.local/bin/gt-telegram"
    fi

    # Detect binary paths
    local gt_path bd_path
    gt_path="$(command -v gt 2>/dev/null || echo gt)"
    bd_path="$(command -v bd 2>/dev/null || echo bd)"

    # Write .env (only if it doesn't exist or credentials changed)
    if [[ ! -f "$svc_dir/.env" ]] || ! grep -q "$TELEGRAM_TOKEN" "$svc_dir/.env" 2>/dev/null; then
        cat > "$svc_dir/.env" << ENVEOF
TELEGRAM_BOT_TOKEN=${TELEGRAM_TOKEN}
TELEGRAM_CHAT_ID=${TELEGRAM_CHAT_ID}
GT_TOWN_ROOT=${town_root}
GT_BIN=${gt_path}
BD_BIN=${bd_path}
GT_ROLE=mayor
BD_ACTOR=mayor
POLL_INTERVAL=10
STATE_FILE=${svc_dir}/state.json
ENVEOF
        chmod 600 "$svc_dir/.env"
        info "Bot .env written to $svc_dir/.env"
    else
        info "Bot .env already exists — keeping"
    fi

    # Generate and install systemd service
    local svc_path_env
    svc_path_env="$(dirname "$gt_path"):$(dirname "$bd_path"):/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/snap/bin"

    cat > "$svc_dir/${svc_name}.service" << SVCEOF
[Unit]
Description=Gas Town Telegram Bot ($town_name)
After=network.target

[Service]
Type=simple
User=$(whoami)
ExecStart=${svc_dir}/gt-bot
WorkingDirectory=${town_root}
EnvironmentFile=${svc_dir}/.env
Environment=PATH=${svc_path_env}
Environment=HOME=${HOME}
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
SVCEOF

    info "Installing systemd service (needs sudo)..."
    sudo cp "$svc_dir/${svc_name}.service" "/etc/systemd/system/${svc_name}.service"
    sudo systemctl daemon-reload
    sudo systemctl enable --now "$svc_name" 2>/dev/null

    # Verify
    sleep 2
    if systemctl is-active --quiet "$svc_name" 2>/dev/null; then
        local ver
        ver=$("$svc_dir/gt-bot" --version 2>/dev/null || echo "?")
        info "Bot $ver running as $svc_name (@${TELEGRAM_BOT_NAME:-bot})"
    else
        warn "Bot service failed to start — check: journalctl -u $svc_name"
    fi

    # Clean up temp clone if we made one
    if [[ -n "$cloned_tmp" && -d "$cloned_tmp" ]]; then
        rm -rf "$cloned_tmp"
    fi
}

# ─── Apply live (second bar setup + override clearing + reload) ───────────────

apply_live() {
    if ! tmux list-sessions &>/dev/null; then
        info "tmux not running — config will apply on next start"
        return
    fi

    # Clear any session-level overrides immediately
    "$INSTALL_DIR/tmux-anti-override.sh" 2>/dev/null || true

    if [[ "$ENABLE_SECOND_BAR" == "y" ]]; then
        # Apply second-bar styles for consistent colors across terminals
        tmux set-option -g status-style "fg=colour245,bg=colour232,none" 2>/dev/null
        tmux set-option -g status-left-style "fg=colour245,bg=colour232,none" 2>/dev/null
        tmux set-option -g status-right-style "fg=colour245,bg=colour232,none" 2>/dev/null
        tmux set-option -g window-status-current-format "" 2>/dev/null
        tmux set-option -g window-status-format "" 2>/dev/null
    fi

    # Reload config
    tmux source-file "$CONFIG_DIR/tmux.conf" 2>/dev/null || warn "Could not reload tmux"
    info "tmux configuration reloaded"
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
    for arg in "$@"; do
        case "$arg" in
            --yes|-y) AUTO_YES=true ;;
        esac
    done

    check_deps
    gather_inputs

    step "Installing"
    save_config
    install_scripts
    generate_tmux_conf

    if [[ "$SETUP_TELEGRAM" == "y" ]]; then
        step "Telegram Bot"
        install_telegram_bot
    fi

    step "Applying"
    apply_live

    echo ""
    echo -e "${GREEN}${BOLD}==========================================${NC}"
    echo -e "${GREEN}${BOLD} Done!${NC}"
    echo -e "${GREEN}${BOLD}==========================================${NC}"
    echo ""
    echo "  Scripts: $INSTALL_DIR/"
    echo "  Config:  $CONFIG_DIR/tmux.conf"
    echo "  Prefs:   $PREFS_FILE"
    echo ""
    echo "  To update:  re-run this installer"
    echo "  To reload:  tmux source-file $CONFIG_DIR/tmux.conf"
    if [[ "$ENABLE_SECOND_BAR" != "y" ]]; then
        echo "  To enable second bar: re-run and change setting"
    fi
}

main "$@"
