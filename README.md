# gastown-helper

Setup script for bootstrapping a [Gas Town](https://github.com/steveyegge/gastown) instance on a fresh Ubuntu/Debian machine.

## Quick Start

```bash
git clone https://github.com/erkantaylan/gastown-helper.git
cd gastown-helper
sudo ./setup-town.sh
```

## What It Does

1. **Creates a new OS user** with home directory and docker group
2. **Installs dependencies** — git, tmux, curl, jq
3. **Installs Gas Town binaries** (`gt` and `bd`) — from latest GitHub release or built from source
4. **Configures PATH** and `gts` alias in `.bashrc`
5. **Optionally installs** Claude Code, GitHub CLI (`gh`), and migrates SSH keys from the invoking user

## Options

| Flag | Description |
|------|-------------|
| `--dry-run` | Show what would happen without making changes |
| `-h, --help` | Show usage information |

## Dry Run

Preview all actions without modifying the system:

```bash
sudo ./setup-town.sh --dry-run
```

## Requirements

- Ubuntu or Debian Linux
- Root access (run with `sudo`)
- Internet connection (to download binaries / packages)

## Interactive Prompts

The script asks for everything up front before making changes:

- **Username** — OS user to create
- **Password** — password for the new user
- **Town name** — name for the Gas Town instance (defaults to username)
- **Install method** — latest GitHub release (default) or build from source
- **Claude Code** — whether to install `@anthropic-ai/claude-code`
- **GitHub CLI** — whether to install and set up `gh`
- **SSH key migration** — whether to copy SSH keys from the current user
