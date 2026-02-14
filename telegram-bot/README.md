# Gas Town Telegram Bot

Mobile interface to Gas Town — check status, read mail, dispatch work, and get notifications from your phone.

## Setup

### 1. Create the bot

1. Open Telegram and message [@BotFather](https://t.me/BotFather)
2. Send `/newbot` and follow prompts
3. Copy the bot token

### 2. Get your chat ID

1. Start a chat with your new bot
2. Send `/start`
3. The bot will reply with your chat ID

### 3. Configure

```bash
cd /home/gastown/gastown-helper/telegram-bot
cp .env.example .env
# Edit .env with your token and chat ID
```

### 4. Build

```bash
go build -o gt-bot .
```

### 5. Test

```bash
./gt-bot
```

Send `/status` from Telegram to verify.

### 6. Install as service

```bash
mkdir -p ~/.config/systemd/user

ln -s /home/gastown/gastown-helper/telegram-bot/gt-bot.service \
      ~/.config/systemd/user/gt-bot.service

systemctl --user daemon-reload
systemctl --user enable gt-bot
systemctl --user start gt-bot

# Check status
systemctl --user status gt-bot

# View logs
journalctl --user -u gt-bot -f
```

## Commands

### Read-only
| Command | Description |
|---------|-------------|
| `/status` | Town overview (agents, rigs) |
| `/mail` | Show inbox (unread highlighted) |
| `/read <id>` | Read a specific message |
| `/rigs` | List all rigs |
| `/polecats` | List active polecats |
| `/ready` | Issues ready to work |
| `/hook` | Check what's hooked |
| `/convoys` | Convoy dashboard |
| `/version` | Gas Town version |

### Actions (with confirmation prompt)
| Command | Description |
|---------|-------------|
| `/sling <bead> <rig>` | Spawn polecat with work |
| `/nudge <target> <msg>` | Nudge an agent |
| `/send <addr> <msg>` | Send mail |
| `/markread <id>` | Mark mail as read |

## Notifications

The bot polls for new mail every `POLL_INTERVAL` seconds (default: 120) and pushes a Telegram notification when new unread messages arrive. Set `POLL_INTERVAL=0` in `.env` to disable.

## Security

- Only configured `TELEGRAM_CHAT_ID` can interact with the bot
- Action commands require inline keyboard confirmation before executing
- `NO_COLOR=1` is set to strip ANSI escapes from CLI output
