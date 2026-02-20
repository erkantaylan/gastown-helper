# New Town Setup — Tmux Status Bar & Telegram Bot

Instructions for setting up the tmux status bar and telegram bot on a new Gas Town.

## 1. Tmux Status Bar

Two-line status bar configured directly in `~/.config/tmux/tmux.conf` (no oh-my-tmux or other frameworks needed):
- **Line 1 left**: mayor name + optional user/folder + optional telegram bot name
- **Line 1 right**: agent counts, mail, hooked work (no rig LEDs) + time
- **Line 2**: rig names with status icons

### Prerequisites

- `python3` on PATH
- `gt` on PATH
- tmux session named `hq-mayor`

### Setup

```bash
curl -fsSL https://raw.githubusercontent.com/erkantaylan/gastown-helper/master/install-tmux.sh | bash
```

The installer asks 4 questions (mayor name, user/folder display, Telegram, second bar) and generates everything. Re-run the same command to update — it detects existing config and offers to keep settings.

### Layout

```
🎩 Kael  kamyon gt-01  @gastown_mine_bot     📬 2 | 12:20 13 Feb
⚫abp 🟢scs ⚫gthelper
```

Line 1 left segments:
- **Yellow bg**: mayor name (from `~/.gt-mayor-name`)
- **Blue bg**: username + folder (optional, set during install)
- **Dark grey bg**: @bot username (optional, set during install)

Line 1 right:
- Filtered gt status (no rig LEDs) + time/date

Line 2:
- Rig names with status icons on dark background

### Status Icons

| Icon | Meaning |
|------|---------|
| 🔨 | Working (has polecats) |
| 🟢 | Operational (witness + refinery running) |
| 🟡 | Partial (only one agent running) |
| ⚫ | Stopped |

### Files Involved

- `~/.config/tmux/tmux.conf` — generated tmux config
- `~/.config/gt-tmux/config` — saved installer preferences
- `~/.gt-mayor-name` — mayor display name
- `~/.gt-bot-name` — cached Telegram bot username
- `~/.local/share/gt-tmux/*.sh` — runtime scripts (embedded by installer)

---

## 2. Telegram Bot

Mobile interface to Gas Town — check status, read mail, send messages to mayor/crew, push notifications for new mail.

### Prerequisites

- Go (to build the binary)
- A Telegram account

### Setup

#### Create the bot

1. Open Telegram, message [@BotFather](https://t.me/BotFather)
2. Send `/newbot`, follow prompts, copy the bot token
3. Start a chat with your new bot, send `/start` — it replies with your chat ID

#### Build and install

```bash
cd <your-town>/gthelper/refinery/rig/telegram-bot/
bash install.sh
```

This stops any running service, builds the binary, deploys it to `<your-town>/services/telegram-bot/`, installs the systemd service, and starts it.

The install script auto-detects the town directory name and creates a **town-specific** service file: `gt-bot-<town-dir>.service`. This prevents conflicts when multiple towns run on the same machine.

#### Configure

```bash
vim <your-town>/services/telegram-bot/.env
```

Fill in:

```
TELEGRAM_BOT_TOKEN=<token from BotFather>
TELEGRAM_CHAT_ID=<your chat ID>
GT_TOWN_ROOT=<absolute path to your town>
GT_BIN=<path to gt binary>
BD_BIN=<path to bd binary>
GT_ROLE=mayor
BD_ACTOR=mayor
POLL_INTERVAL=10
STATE_FILE=<your-town>/services/telegram-bot/state.json
```

**CRITICAL**: `GT_ROLE=mayor` and `BD_ACTOR=mayor` are required. Without them, `gt mail inbox` returns `null` under systemd because it doesn't know which identity's inbox to check.

#### Enable the service

`install.sh` automatically installs and starts the service (requires sudo). The service name includes your town directory name (e.g. `gt-bot-antik` for a town at `/home/gastown/antik`).

**IMPORTANT**: Do NOT use a generic name like `gt-bot.service` — if multiple towns share a machine, they'll overwrite each other's service.

#### Verify

```bash
systemctl status gt-bot-<town-dir>
```

Then send `/status` from Telegram — the bot should respond with your town overview.

### Bot Commands

| Command | Description |
|---------|-------------|
| `/status` | Town overview (agents, rigs) |
| `/version` | Gas Town + bot version |
| `/bot_version` | Bot version only |
| `/nudge` | Wake the mayor |
| `/crew <name> <msg>` | Talk to a crew member |
| `/mayor_status` | Check if mayor agent is running |
| `/mayor_start` | Start mayor agent |
| `/mayor_stop` | Stop mayor agent |
| `/mayor_restart` | Restart mayor agent |
| `/help` | List commands |
| _(plain text)_ | Sends message to mayor and nudges |

### Mayor Power Commands

Remote control the mayor agent from Telegram:

- `/mayor_status` — check if the mayor is running, stopped, etc.
- `/mayor_start` — start the mayor agent (handles "already running" gracefully)
- `/mayor_stop` — stop the mayor agent
- `/mayor_restart` — stop + start the mayor agent

These run `gt mayor status|start|stop|restart` under the hood.

### How Telegram Communication Works

**User → Mayor (Telegram to terminal):**
1. User sends `/mayor <msg>` or plain text on Telegram
2. Bot sends mail to mayor's inbox (`gt mail send mayor/`)
3. Bot nudges the mayor (`gt nudge mayor`) — mayor session wakes up
4. Nudge shows: `[From 📱 Telegram] <message text>`
5. Mayor reads the mail and acts on it

**Mayor → User (terminal to Telegram):**
1. Mayor sends mail: `gt mail send mayor/ -s "Your reply here" -m "reply"`
2. Bot's poller detects the new unread message
3. Telegram notification shows the **subject** as the message text
4. Subject must NOT be exactly "📱 Telegram" (those are filtered — they're self-sent from the bot)

**Important for mayors:** When the user writes from Telegram, always reply via mail so they see the response on Telegram. They are not looking at the terminal. Put the reply content in the **subject** field — that's what shows in the Telegram notification.

### Updating the Bot

After source code changes in gthelper:

```bash
cd <your-town>/gthelper/refinery/rig/telegram-bot/
bash install.sh
```

`install.sh` handles the full deploy cycle: stop service, build, copy binary, regenerate service file, reload systemd, and restart. It prints the deployed version when done.

### Versioning

The bot has a version constant (`BotVersion`) in `main.go`. The binary supports `--version`:

```bash
./gt-bot --version   # prints e.g. "v1"
```

The version is shown in:
- Startup log: `Gas Town Bot v1 — Authorized as @...`
- `/version` command: shows both Gas Town and bot versions
- `/bot_version` command: bot version only
- `/help` header: `Gas Town Bot v1`
- tmux status bar: `📱v1 @botname` badge on dark grey background
