# gastown-helper

Setup scripts, tools, and docs for [Gas Town](https://github.com/steveyegge/gastown).

## Contents

| Path | Description |
|------|-------------|
| `setup-town.sh` | Bootstrap a Gas Town instance on fresh Ubuntu/Debian |
| `telegram-bot/` | Telegram bot for mobile Gas Town control |
| `tmux-rig-status.sh` | Second tmux status line showing rig overview |
| `tmux-status-right.sh` | First line filter — strips rig LEDs (shown on second line) |
| `tmux-rig-status-setup.sh` | One-time setup for the second status line |
| **`claude-usage.sh.template`** | **Claude usage tracker (inspired by [claude-counter](https://github.com/she-llac/claude-counter))** |
| **`install-claude-usage.sh`** | **Installer for Claude usage tracking** |
| `docs/` | Guides and reference docs |

## Claude Usage Tracking

**NEW:** Inspired by [claude-counter](https://github.com/she-llac/claude-counter) by [@she-llac](https://github.com/she-llac)

Display Claude usage metrics in your Gas Town tmux status bar:

```
🟢abp 🔨listen          🤖 5h:45% 7d:12% | 6333msg 21k↑60k↓
└─ rigs (left)          └─ claude usage (right)
```

### Quick Start

```bash
bash install-claude-usage.sh
```

### Documentation

See [CLAUDE_USAGE_TRACKING.md](CLAUDE_USAGE_TRACKING.md) for complete documentation.

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
| [tmux-second-status-line.md](docs/tmux-second-status-line.md) | Add a rig overview second status line |
| **[CLAUDE_USAGE_TRACKING.md](CLAUDE_USAGE_TRACKING.md)** | **Claude usage tracking (adapted from claude-counter)** |
| [dev-sandbox-setup.md](docs/dev-sandbox-setup.md) | Run Gas Town from source in isolation |

## Requirements

- Ubuntu or Debian Linux
- Root access for setup script
- Go 1.21+ for building the Telegram bot

## Credits

Claude usage tracking inspired by and adapted from [claude-counter](https://github.com/she-llac/claude-counter) by [@she-llac](https://github.com/she-llac).
