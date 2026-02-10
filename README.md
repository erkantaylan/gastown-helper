# gastown-helper

Setup scripts, tools, and docs for [Gas Town](https://github.com/steveyegge/gastown).

## Contents

| Path | Description |
|------|-------------|
| `setup-town.sh` | Bootstrap a Gas Town instance on fresh Ubuntu/Debian |
| `telegram-bot/` | Telegram bot for mobile Gas Town control |
| `docs/` | Guides and reference docs |

## Setup Script

### One-Liner

```bash
curl -fsSL https://raw.githubusercontent.com/erkantaylan/gastown-helper/master/setup-town.sh | sudo bash
```

### Quick Start

```bash
git clone https://github.com/erkantaylan/gastown-helper.git
cd gastown-helper
sudo ./setup-town.sh
```

### What It Does

1. **Creates a new OS user** with home directory and docker group
2. **Installs dependencies** — git, tmux, curl, jq
3. **Installs Gas Town binaries** (`gt` and `bd`) — from latest GitHub release or built from source
4. **Configures PATH** and `gts` alias in `.bashrc`
5. **Optionally installs** Claude Code, GitHub CLI (`gh`), and migrates SSH keys from the invoking user

### Options

| Flag | Description |
|------|-------------|
| `--dry-run` | Show what would happen without making changes |
| `-h, --help` | Show usage information |

## Telegram Bot

Mobile interface to Gas Town — send instructions, check status, talk to agents from your phone.

See [telegram-bot/README.md](telegram-bot/README.md) for setup.

**Quick overview:**
- Just type a message → it goes to the mayor as mail + nudge
- `/status` → town overview with agents, rigs, crew
- `/crew bender <msg>` → talk directly to a crew member
- `/version` → Gas Town version
- Agents reply back to Telegram with `gt-telegram "message"`

## Docs

| Doc | Description |
|-----|-------------|
| [tmux-statusbar.md](docs/tmux-statusbar.md) | Customize the Gas Town tmux status bar |
| [dev-sandbox-setup.md](docs/dev-sandbox-setup.md) | Run Gas Town from source in isolation |

## Requirements

- Ubuntu or Debian Linux
- Root access for setup script
- Go 1.21+ for building the Telegram bot
