# New Town Setup — Tmux Status Bar & Telegram Bot

Instructions for setting up the tmux status bar and telegram bot on a new Gas Town.

## 1. Tmux Status Bar

Two-line status bar with a clean split:
- **Line 1**: your mayor name (left) + agent counts, mail, hooked work (right) — **no rig LEDs**
- **Line 2**: rig names with status icons — rigs only appear here

**IMPORTANT: Do NOT reimplement this manually. Run the actual `tmux-rig-status-setup.sh` script.** It handles everything including styling that's easy to miss.

The setup script does these things:
1. **Picks up your mayor name** from `~/.gt-mayor-name` (replaces the default "🎩 Mayor")
2. **Sets explicit text colors** — `fg=colour245` (light grey) on `bg=colour232` (dark) for all status elements. Without this, text color inherits the terminal default (yellow in Terminator, different grey in GNOME Terminal, etc.)
3. **Styles line 1 left**: mayor name in **bold on yellow background** (colour220), username[town] on **grey background** (colour236)
4. **Styles line 1 right**: uses `tmux-status-right.sh` to filter `gt status-line` — **strips rig LEDs** so they don't duplicate with line 2
5. **Adds line 2** with dark background (colour232) showing compact rig status icons via `tmux-rig-status.sh`
6. **Hides window list** (redundant with single window setup)
7. **Fixes fill color** on both lines (prevents brown background on some terminals)

Without the setup script you'll see the default `🎩 Mayor` with no bold/colors, rig LEDs duplicated on both lines.

### Prerequisites

- `python3` on PATH
- `gt` on PATH
- tmux session named `hq-mayor`

### Setup

```bash
# IMPORTANT: Pick your mayor name first!
# This replaces the default "🎩 Mayor" in the status bar
echo "YourName" > ~/.gt-mayor-name

# Run setup from your gthelper rig directory
cd <your-town>/gthelper/refinery/rig/
bash tmux-rig-status-setup.sh

# Make persistent — add to tmux.conf
echo 'run-shell "bash <your-town>/gthelper/refinery/rig/tmux-rig-status-setup.sh"' >> ~/.config/tmux/tmux.conf
```

### Before vs After

**Before** (default gt status bar):
```
🎩 Mayor                    0/2 🦉 2/2 🏭 | 🟢 scs | ⚫ abp ⚫ gthelper | 12:20
```

**After** (with setup script):
```
🎩 Kael  kamyon[gt-01]       0/2 🦉 2/2 🏭 | 📬 | 12:20
⚫abp 🟢scs ⚫gthelper
```

Key differences:
- Mayor name in **bold on yellow background** instead of generic "Mayor"
- Username and town on grey background on the left
- Rig LEDs removed from line 1 (no duplication)
- Rigs shown compactly on dark background on line 2
- Window list hidden

### Status Icons

| Icon | Meaning |
|------|---------|
| 🔨 | Working (has polecats) |
| 🟢 | Operational (witness + refinery running) |
| 🟡 | Partial (only one agent running) |
| ⚫ | Stopped |

### Files Involved

All 3 scripts must be in `gthelper/refinery/rig/`:

- `tmux-rig-status-setup.sh` — one-time setup (or run from tmux.conf), configures both lines
- `tmux-status-right.sh` — filters `gt status-line` for line 1 (**strips rig LEDs** so they don't duplicate)
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

The service name includes your town directory name (e.g. `gt-bot-antik` for a town at `/home/gastown/antik`):

```bash
# install.sh prints the exact commands, but the pattern is:
sudo cp <your-town>/services/telegram-bot/gt-bot-<town-dir>.service /etc/systemd/system/gt-bot-<town-dir>.service
sudo systemctl daemon-reload
sudo systemctl enable --now gt-bot-<town-dir>
```

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
| `/version` | Gas Town version |
| `/nudge` | Wake the mayor |
| `/crew <name> <msg>` | Talk to a crew member |
| `/help` | List commands |
| _(plain text)_ | Sends message to mayor and nudges |

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
sudo systemctl restart gt-bot-<town-dir>
```
