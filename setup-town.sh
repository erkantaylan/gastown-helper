#!/usr/bin/env bash
# setup-town.sh — Automated Gas Town instance setup for Ubuntu/Debian
# https://github.com/erkantaylan/gastown-helper
set -euo pipefail

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ─── Globals ──────────────────────────────────────────────────────────────────
DRY_RUN=false
GT_USER=""
GT_PASS=""
TOWN_NAME=""
INSTALL_METHOD="release"
INSTALL_CLAUDE="n"
INSTALL_GH="n"
COPY_SSH="n"

# ─── TTY for interactive prompts (supports curl | bash) ───────────────────────
# When piped via curl|bash, stdin is the script itself. Read from /dev/tty instead.
if [[ -t 0 ]]; then
    TTY_IN=/dev/stdin
else
    TTY_IN=/dev/tty
fi

prompt() {
    # Usage: prompt "prompt text" VARNAME
    # Like read -rp but reads from TTY even when piped
    local text="$1" var="$2"
    echo -ne "$text" >&2
    IFS= read -r "$var" < "$TTY_IN"
}

prompt_secret() {
    # Usage: prompt_secret "prompt text" VARNAME
    # Like read -rsp but reads from TTY even when piped
    local text="$1" var="$2"
    echo -ne "$text" >&2
    IFS= read -rs "$var" < "$TTY_IN"
    echo "" >&2
}

# ─── Helpers ──────────────────────────────────────────────────────────────────

info()    { echo -e "${GREEN}[✓]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
err()     { echo -e "${RED}[✗]${NC} $*" >&2; }
step()    { echo -e "\n${BLUE}${BOLD}>>> $*${NC}"; }
run()     {
    if $DRY_RUN; then
        echo -e "${YELLOW}[dry-run]${NC} $*"
    else
        "$@"
    fi
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        err "This script must be run as root (or with sudo)."
        exit 1
    fi
}

user_home() {
    eval echo "~${GT_USER}"
}

run_as_user() {
    if $DRY_RUN; then
        echo -e "${YELLOW}[dry-run]${NC} su - ${GT_USER} -c \"$*\""
    else
        su - "${GT_USER}" -c "$*"
    fi
}

# ─── Interactive Prompts ──────────────────────────────────────────────────────

gather_inputs() {
    step "Gas Town Setup — Configuration"
    echo ""

    # Username
    prompt "$(echo -e "${YELLOW}Username${NC} for the new OS user: ")" GT_USER
    if [[ -z "$GT_USER" ]]; then
        err "Username cannot be empty."
        exit 1
    fi

    # Password
    prompt_secret "$(echo -e "${YELLOW}Password${NC} for ${GT_USER}: ")" GT_PASS
    if [[ -z "$GT_PASS" ]]; then
        err "Password cannot be empty."
        exit 1
    fi

    # Town name
    prompt "$(echo -e "${YELLOW}Town name${NC} [default: ${GT_USER}]: ")" TOWN_NAME
    TOWN_NAME="${TOWN_NAME:-$GT_USER}"

    # Install method
    echo ""
    echo -e "${YELLOW}Install method:${NC}"
    echo "  1) Latest GitHub release (default)"
    echo "  2) Build from source"
    local method_choice
    prompt "Choose [1/2]: " method_choice
    case "${method_choice:-1}" in
        2) INSTALL_METHOD="source" ;;
        *) INSTALL_METHOD="release" ;;
    esac

    # Claude Code
    prompt "$(echo -e "Install ${YELLOW}Claude Code${NC}? [y/N]: ")" INSTALL_CLAUDE
    INSTALL_CLAUDE="${INSTALL_CLAUDE,,}"  # lowercase

    # GitHub CLI
    prompt "$(echo -e "Install ${YELLOW}GitHub CLI (gh)${NC}? [y/N]: ")" INSTALL_GH
    INSTALL_GH="${INSTALL_GH,,}"

    # SSH key migration
    if [[ -n "${SUDO_USER:-}" ]] && [[ -d "/home/${SUDO_USER}/.ssh" ]]; then
        prompt "$(echo -e "Copy ${YELLOW}SSH keys${NC} from ${SUDO_USER} to ${GT_USER}? [y/N]: ")" COPY_SSH
        COPY_SSH="${COPY_SSH,,}"
    fi

    # Summary
    echo ""
    step "Configuration Summary"
    echo "  User:           ${GT_USER}"
    echo "  Town name:      ${TOWN_NAME}"
    echo "  Install method: ${INSTALL_METHOD}"
    echo "  Claude Code:    ${INSTALL_CLAUDE}"
    echo "  GitHub CLI:     ${INSTALL_GH}"
    echo "  SSH migration:  ${COPY_SSH}"
    echo ""
    local confirm
    prompt "Proceed? [Y/n]: " confirm
    if [[ "${confirm,,}" == "n" ]]; then
        echo "Aborted."
        exit 0
    fi
}

# ─── System Setup ─────────────────────────────────────────────────────────────

create_user() {
    step "Creating OS user: ${GT_USER}"

    if id "${GT_USER}" &>/dev/null; then
        warn "User ${GT_USER} already exists, skipping creation."
    else
        run useradd -m -s /bin/bash "${GT_USER}"
        info "User ${GT_USER} created."
    fi

    echo "${GT_USER}:${GT_PASS}" | run chpasswd
    info "Password set."

    # Hide from GDM login screen (service account, not a human user)
    local acct_file="/var/lib/AccountsService/users/${GT_USER}"
    if [[ ! -f "$acct_file" ]] || ! grep -q "SystemAccount=true" "$acct_file" 2>/dev/null; then
        if $DRY_RUN; then
            echo -e "${YELLOW}[dry-run]${NC} Write SystemAccount=true to ${acct_file}"
        else
            mkdir -p /var/lib/AccountsService/users
            printf '[User]\nSystemAccount=true\n' > "$acct_file"
        fi
        info "Hidden ${GT_USER} from login screen."
    fi

    if getent group docker &>/dev/null; then
        run usermod -aG docker "${GT_USER}"
        info "Added ${GT_USER} to docker group."
    else
        warn "Docker group does not exist — skipping. Install Docker later and run: usermod -aG docker ${GT_USER}"
    fi
}

install_base_deps() {
    step "Installing base dependencies"

    run apt-get update -qq
    run apt-get install -y -qq git tmux curl jq
    info "Base dependencies installed (git, tmux, curl, jq)."
}

# ─── Gas Town Binaries ────────────────────────────────────────────────────────

install_from_release() {
    step "Installing Gas Town binaries (latest release)"

    local home
    home="$(user_home)"
    run_as_user "mkdir -p ~/.local/bin ~/go/bin"

    # gt binary
    info "Fetching latest gt release..."
    local gt_url
    gt_url=$(curl -sL "https://api.github.com/repos/steveyegge/gastown/releases/latest" \
        | jq -r '.assets[] | select(.name | test("linux.*amd64|gt.*linux")) | .browser_download_url' \
        | head -1)

    if [[ -z "$gt_url" || "$gt_url" == "null" ]]; then
        err "Could not find gt binary in latest gastown release."
        err "Falling back to build-from-source for gt."
        install_gt_from_source
    else
        if $DRY_RUN; then
            echo -e "${YELLOW}[dry-run]${NC} curl -sL ${gt_url} → ${home}/.local/bin/gt"
        else
            local tmp
            tmp=$(mktemp)
            curl -sL "$gt_url" -o "$tmp"
            # Handle tarball vs raw binary
            if file "$tmp" | grep -q "gzip\|tar"; then
                tar xzf "$tmp" -C "${home}/.local/bin/" 2>/dev/null || {
                    # Try extracting any binary named gt
                    local extract_dir
                    extract_dir=$(mktemp -d)
                    tar xzf "$tmp" -C "$extract_dir"
                    find "$extract_dir" -name "gt" -type f -exec cp {} "${home}/.local/bin/gt" \;
                    rm -rf "$extract_dir"
                }
            else
                cp "$tmp" "${home}/.local/bin/gt"
            fi
            chmod +x "${home}/.local/bin/gt"
            chown "${GT_USER}:${GT_USER}" "${home}/.local/bin/gt"
            rm -f "$tmp"
        fi
        info "gt installed to ~/.local/bin/gt"
    fi

    # bd binary
    info "Fetching latest bd release..."
    local bd_url
    bd_url=$(curl -sL "https://api.github.com/repos/steveyegge/beads/releases/latest" \
        | jq -r '.assets[] | select(.name | test("linux.*amd64|bd.*linux")) | .browser_download_url' \
        | head -1)

    if [[ -z "$bd_url" || "$bd_url" == "null" ]]; then
        err "Could not find bd binary in latest beads release."
        err "Falling back to build-from-source for bd."
        install_bd_from_source
    else
        if $DRY_RUN; then
            echo -e "${YELLOW}[dry-run]${NC} curl -sL ${bd_url} → ${home}/go/bin/bd"
        else
            local tmp
            tmp=$(mktemp)
            curl -sL "$bd_url" -o "$tmp"
            if file "$tmp" | grep -q "gzip\|tar"; then
                tar xzf "$tmp" -C "${home}/go/bin/" 2>/dev/null || {
                    local extract_dir
                    extract_dir=$(mktemp -d)
                    tar xzf "$tmp" -C "$extract_dir"
                    find "$extract_dir" -name "bd" -type f -exec cp {} "${home}/go/bin/bd" \;
                    rm -rf "$extract_dir"
                }
            else
                cp "$tmp" "${home}/go/bin/bd"
            fi
            chmod +x "${home}/go/bin/bd"
            chown "${GT_USER}:${GT_USER}" "${home}/go/bin/bd"
            rm -f "$tmp"
        fi
        info "bd installed to ~/go/bin/bd"
    fi
}

install_go_if_needed() {
    if run_as_user "command -v go" &>/dev/null; then
        info "Go already installed."
        return
    fi

    step "Installing Go"
    local go_version
    go_version=$(curl -sL "https://go.dev/VERSION?m=text" | head -1)
    local go_tar="${go_version}.linux-amd64.tar.gz"

    if $DRY_RUN; then
        echo -e "${YELLOW}[dry-run]${NC} Download and install ${go_tar}"
    else
        curl -sL "https://go.dev/dl/${go_tar}" -o "/tmp/${go_tar}"
        rm -rf /usr/local/go
        tar -C /usr/local -xzf "/tmp/${go_tar}"
        rm -f "/tmp/${go_tar}"
    fi
    info "Go ${go_version} installed to /usr/local/go"
}

install_gt_from_source() {
    local home
    home="$(user_home)"
    local src_dir="${home}/src/gastown"

    info "Building gt from source..."
    if $DRY_RUN; then
        echo -e "${YELLOW}[dry-run]${NC} git clone + go build gastown → ${home}/.local/bin/gt"
    else
        run_as_user "mkdir -p ~/src"
        if [[ -d "$src_dir" ]]; then
            run_as_user "cd ~/src/gastown && git pull"
        else
            run_as_user "git clone https://github.com/steveyegge/gastown.git ~/src/gastown"
        fi
        run_as_user "cd ~/src/gastown && export PATH=\$PATH:/usr/local/go/bin && go build -o ~/.local/bin/gt ./cmd/gt"
        info "gt built and installed to ~/.local/bin/gt"
    fi
}

install_bd_from_source() {
    local home
    home="$(user_home)"
    local src_dir="${home}/src/beads"

    info "Building bd from source..."
    if $DRY_RUN; then
        echo -e "${YELLOW}[dry-run]${NC} git clone + go build beads → ${home}/go/bin/bd"
    else
        run_as_user "mkdir -p ~/src"
        if [[ -d "$src_dir" ]]; then
            run_as_user "cd ~/src/beads && git pull"
        else
            run_as_user "git clone https://github.com/steveyegge/beads.git ~/src/beads"
        fi
        run_as_user "cd ~/src/beads && export PATH=\$PATH:/usr/local/go/bin && go build -o ~/go/bin/bd ./cmd/bd"
        info "bd built and installed to ~/go/bin/bd"
    fi
}

install_from_source() {
    step "Installing Gas Town binaries (build from source)"

    local home
    home="$(user_home)"
    run_as_user "mkdir -p ~/.local/bin ~/go/bin"

    install_go_if_needed
    install_gt_from_source
    install_bd_from_source
}

# ─── PATH & Aliases ──────────────────────────────────────────────────────────

setup_path() {
    step "Configuring PATH and aliases"

    local home
    home="$(user_home)"
    local bashrc="${home}/.bashrc"
    local marker="# --- Gas Town PATH ---"

    if grep -qF "$marker" "$bashrc" 2>/dev/null; then
        warn "PATH block already present in .bashrc, skipping."
        return
    fi

    if $DRY_RUN; then
        echo -e "${YELLOW}[dry-run]${NC} Append PATH + alias block to ${bashrc}"
    else
        cat >> "$bashrc" << 'BASHRC'

# --- Gas Town PATH ---
export PATH="$HOME/.local/bin:$HOME/go/bin:/usr/local/go/bin:$PATH"
alias gts='gt'
# --- End Gas Town PATH ---
BASHRC
        chown "${GT_USER}:${GT_USER}" "$bashrc"
    fi
    info "PATH and gts alias configured in .bashrc"
}

# ─── Optional: Claude Code ────────────────────────────────────────────────────

install_claude_code() {
    [[ "$INSTALL_CLAUDE" != "y" ]] && return

    step "Installing Claude Code"

    # Install Node.js if not present
    if ! command -v node &>/dev/null; then
        info "Installing Node.js via nodesource..."
        if $DRY_RUN; then
            echo -e "${YELLOW}[dry-run]${NC} Install Node.js LTS via nodesource"
        else
            curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
            apt-get install -y -qq nodejs
        fi
        info "Node.js installed."
    else
        info "Node.js already installed: $(node --version)"
    fi

    if $DRY_RUN; then
        echo -e "${YELLOW}[dry-run]${NC} npm install -g @anthropic-ai/claude-code"
    else
        npm install -g @anthropic-ai/claude-code
    fi
    info "Claude Code installed."
}

# ─── Optional: GitHub CLI ─────────────────────────────────────────────────────

install_github_cli() {
    [[ "$INSTALL_GH" != "y" ]] && return

    step "Installing GitHub CLI (gh)"

    if command -v gh &>/dev/null; then
        info "gh already installed: $(gh --version | head -1)"
    else
        if $DRY_RUN; then
            echo -e "${YELLOW}[dry-run]${NC} Install gh via apt repository"
        else
            curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
                | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
            chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
                | tee /etc/apt/sources.list.d/github-cli-stable.list > /dev/null
            apt-get update -qq
            apt-get install -y -qq gh
        fi
        info "gh installed."
    fi

    echo ""
    warn "To authenticate, run as ${GT_USER}:"
    warn "  su - ${GT_USER} -c 'gh auth login'"
}

# ─── Optional: SSH Key Migration ──────────────────────────────────────────────

migrate_ssh_keys() {
    [[ "$COPY_SSH" != "y" ]] && return

    step "Migrating SSH keys from ${SUDO_USER} to ${GT_USER}"

    local src_ssh="/home/${SUDO_USER}/.ssh"
    local home
    home="$(user_home)"
    local dst_ssh="${home}/.ssh"

    if [[ ! -d "$src_ssh" ]]; then
        warn "No .ssh directory found for ${SUDO_USER}, skipping."
        return
    fi

    if $DRY_RUN; then
        echo -e "${YELLOW}[dry-run]${NC} Copy ${src_ssh}/id_* and config → ${dst_ssh}/"
    else
        mkdir -p "$dst_ssh"
        chmod 700 "$dst_ssh"

        # Copy key files
        for f in "$src_ssh"/id_*; do
            [[ -f "$f" ]] || continue
            cp "$f" "$dst_ssh/"
            info "Copied $(basename "$f")"
        done

        # Copy config if it exists
        if [[ -f "$src_ssh/config" ]]; then
            cp "$src_ssh/config" "$dst_ssh/config"
            info "Copied SSH config"
        fi

        # Copy known_hosts if it exists
        if [[ -f "$src_ssh/known_hosts" ]]; then
            cp "$src_ssh/known_hosts" "$dst_ssh/known_hosts"
            info "Copied known_hosts"
        fi

        # Fix ownership and permissions
        chown -R "${GT_USER}:${GT_USER}" "$dst_ssh"
        chmod 700 "$dst_ssh"
        find "$dst_ssh" -name "id_*" ! -name "*.pub" -exec chmod 600 {} \;
        find "$dst_ssh" -name "*.pub" -exec chmod 644 {} \;
        [[ -f "$dst_ssh/config" ]] && chmod 600 "$dst_ssh/config"
        [[ -f "$dst_ssh/known_hosts" ]] && chmod 644 "$dst_ssh/known_hosts"
    fi
    info "SSH keys migrated and permissions set."
}

# ─── Initialize Town ──────────────────────────────────────────────────────────

init_town() {
    step "Initializing Gas Town: ${TOWN_NAME}"

    if $DRY_RUN; then
        echo -e "${YELLOW}[dry-run]${NC} su - ${GT_USER} -c 'gt install --name ${TOWN_NAME}'"
    else
        run_as_user "export PATH=\$HOME/.local/bin:\$HOME/go/bin:/usr/local/go/bin:\$PATH && gt install --name ${TOWN_NAME}"
    fi
    info "Gas Town '${TOWN_NAME}' initialized for ${GT_USER}."
}

# ─── Main ─────────────────────────────────────────────────────────────────────

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Automated setup for a new Gas Town instance on Ubuntu/Debian.

Options:
  --dry-run    Show what would be done without making changes
  -h, --help   Show this help message

Must be run as root (or with sudo).

Example:
  sudo ./setup-town.sh
  sudo ./setup-town.sh --dry-run
EOF
}

main() {
    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            --dry-run) DRY_RUN=true ;;
            -h|--help) usage; exit 0 ;;
            *) err "Unknown option: $arg"; usage; exit 1 ;;
        esac
    done

    echo -e "${BOLD}"
    echo "╔══════════════════════════════════════════╗"
    echo "║       Gas Town Setup Script              ║"
    echo "║       github.com/steveyegge/gastown      ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${NC}"

    if $DRY_RUN; then
        warn "DRY RUN MODE — no changes will be made"
        echo ""
    fi

    check_root
    gather_inputs

    create_user
    install_base_deps

    case "$INSTALL_METHOD" in
        release) install_from_release ;;
        source)  install_from_source ;;
    esac

    setup_path
    install_claude_code
    install_github_cli
    migrate_ssh_keys
    init_town

    echo ""
    echo -e "${GREEN}${BOLD}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD} Gas Town setup complete!${NC}"
    echo -e "${GREEN}${BOLD}════════════════════════════════════════════${NC}"
    echo ""
    echo "  Switch to the new user:  su - ${GT_USER}"
    echo "  Verify installation:     gt --version && bd --version"
    echo "  Check town status:       gts status"
    echo ""
    if [[ "$INSTALL_GH" == "y" ]]; then
        echo -e "  ${YELLOW}Don't forget:${NC} gh auth login"
    fi
}

main "$@"
