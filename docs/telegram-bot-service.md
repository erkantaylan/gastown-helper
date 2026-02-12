# Telegram Bot Service

The telegram bot runs as a town-level service under `services/telegram-bot/`, independent of any rig.

## Why It Moved

Previously the bot binary lived inside `gthelper/refinery/rig/telegram-bot/` — tied to a specific rig. Problems:

- Bot broke if the gthelper rig had issues
- Other towns on the same machine couldn't have independent bots
- The systemd unit pointed deep into a rig directory

Now the compiled binary, config, and state live at the town root under `services/telegram-bot/`. Source code stays in gthelper.

## Fresh Install (New Town)

```bash
# From the gthelper telegram-bot source directory:
cd <town>/gthelper/refinery/rig/telegram-bot/
bash install.sh

# Edit the generated .env:
vim <town>/services/telegram-bot/.env

# Install and start the systemd service:
sudo cp <town>/services/telegram-bot/gt-bot.service /etc/systemd/system/gt-bot.service
sudo systemctl daemon-reload
sudo systemctl enable --now gt-bot
```

## Migrate From Old Setup

If you had the bot running from the rig directory:

```bash
# 1. Stop old service
sudo systemctl stop gt-bot

# 2. Run install script (builds fresh, copies to services/)
cd <town>/gthelper/refinery/rig/telegram-bot/
bash install.sh

# 3. Copy your existing .env values to the new location
#    (install.sh won't overwrite an existing .env)
cp <town>/gthelper/refinery/rig/telegram-bot/.env <town>/services/telegram-bot/.env
#    Update STATE_FILE path in .env to: <town>/services/telegram-bot/state.json

# 4. Install new systemd unit
sudo cp <town>/services/telegram-bot/gt-bot.service /etc/systemd/system/gt-bot.service
sudo systemctl daemon-reload
sudo systemctl start gt-bot

# 5. Verify
systemctl status gt-bot
```

## Updating the Bot

After making changes to the source code:

```bash
cd <town>/gthelper/refinery/rig/telegram-bot/
bash install.sh
sudo systemctl restart gt-bot
```

## Remove Completely

```bash
sudo systemctl stop gt-bot
sudo systemctl disable gt-bot
sudo rm /etc/systemd/system/gt-bot.service
sudo systemctl daemon-reload
rm -rf <town>/services/telegram-bot/
```

## Directory Layout

```
<town>/
├── services/
│   └── telegram-bot/
│       ├── gt-bot          ← compiled binary
│       ├── .env            ← this town's config
│       ├── .env.example    ← template for reference
│       ├── state.json      ← notification tracking state
│       └── gt-bot.service  ← systemd unit template
└── gthelper/
    └── refinery/rig/
        └── telegram-bot/
            ├── main.go     ← source code
            ├── go.mod
            ├── install.sh  ← build & deploy script
            └── ...
```
