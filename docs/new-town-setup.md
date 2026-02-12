# New Town Setup — Tmux Status Bar & Telegram Bot

Instructions for setting up the tmux status bar and telegram bot on a new Gas Town.

## 1. Tmux Status Bar

Two-line status bar: mayor name + agent counts + mail on line 1, rig status icons on line 2.

### Prerequisites

- `python3` on PATH
- `gt` on PATH
- tmux session named `hq-mayor`

### Setup

```bash
# Pick your mayor name
echo "YourName" > ~/.gt-mayor-name

# Run setup from your gthelper rig directory
cd <your-town>/gthelper/refinery/rig/
bash tmux-rig-status-setup.sh

# Make persistent — add to tmux.conf
echo 'run-shell "bash <your-town>/gthelper/refinery/rig/tmux-rig-status-setup.sh"' >> ~/.config/tmux/tmux.conf
```

### What You Get

**Line 1 (left):** `🎩 YourName  user[town-dir]`
**Line 1 (right):** agent counts, mail notifications, hooked work, clock
**Line 2:** `🔨rigA 🟢rigB ⚫rigC`

### Status Icons

| Icon | Meaning |
|------|---------|
| 🔨 | Working (has polecats) |
| 🟢 | Operational (witness + refinery running) |
| 🟡 | Partial (only one agent running) |
| ⚫ | Stopped |

### Files Involved

All in `gthelper/refinery/rig/`:

- `tmux-rig-status-setup.sh` — one-time setup (or run from tmux.conf)
- `tmux-status-right.sh` — filters gt status-line for line 1 (strips rig LEDs)
- `tmux-rig-status.sh` — generates line 2 (rig names with icons)

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

This builds the binary and copies it to `<your-town>/services/telegram-bot/`.

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
POLL_INTERVAL=120
STATE_FILE=<your-town>/services/telegram-bot/state.json
```

#### Enable the service

```bash
sudo cp <your-town>/services/telegram-bot/gt-bot.service /etc/systemd/system/gt-bot.service
sudo systemctl daemon-reload
sudo systemctl enable --now gt-bot
```

#### Verify

```bash
systemctl status gt-bot
```

Then send `/status` from Telegram — the bot should respond with your town overview.

### Bot Commands

| Command | Description |
|---------|-------------|
| `/status` | Town overview (agents, rigs) |
| `/version` | Gas Town version |
| `/nudge` | Wake the mayor |
| `/crew <name> <msg>` | Talk to a crew member |
| `/help` | List commands |
| _(plain text)_ | Sends message to mayor |

### Updating the Bot

After source code changes in gthelper:

```bash
cd <your-town>/gthelper/refinery/rig/telegram-bot/
bash install.sh
sudo systemctl restart gt-bot
```
