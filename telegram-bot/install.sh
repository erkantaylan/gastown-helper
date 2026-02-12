#!/usr/bin/env bash
set -euo pipefail

# Build and install gt-bot to the town's services/ directory.
# Run from anywhere — the script detects the town root automatically.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOWN_ROOT="$(cd "$SCRIPT_DIR/../../../../" && pwd)"
SERVICE_DIR="$TOWN_ROOT/services/telegram-bot"

echo "==> Town root: $TOWN_ROOT"
echo "==> Service dir: $SERVICE_DIR"

# 1. Build
echo "==> Building gt-bot..."
cd "$SCRIPT_DIR"
go build -o gt-bot .
echo "    Built: $SCRIPT_DIR/gt-bot"

# 2. Create service directory
mkdir -p "$SERVICE_DIR"

# 3. Copy binary
cp gt-bot "$SERVICE_DIR/gt-bot"
echo "    Installed: $SERVICE_DIR/gt-bot"

# 4. Copy .env from .env.example if no .env exists
if [ ! -f "$SERVICE_DIR/.env" ]; then
    if [ -f "$SCRIPT_DIR/.env.example" ]; then
        cp "$SCRIPT_DIR/.env.example" "$SERVICE_DIR/.env"
        echo "    Created .env from template — edit $SERVICE_DIR/.env with your values"
    else
        echo "    WARNING: No .env.example found, skipping .env creation"
    fi
else
    echo "    .env already exists, skipping"
fi

# 5. Generate systemd service file
cat > "$SERVICE_DIR/gt-bot.service" <<EOF
[Unit]
Description=Gas Town Telegram Bot
After=network.target

[Service]
Type=simple
ExecStart=$SERVICE_DIR/gt-bot
WorkingDirectory=$TOWN_ROOT
EnvironmentFile=$SERVICE_DIR/.env
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF
echo "    Generated: $SERVICE_DIR/gt-bot.service"

echo ""
echo "==> Install complete!"
echo ""
echo "To activate the service:"
echo "  sudo cp $SERVICE_DIR/gt-bot.service /etc/systemd/system/gt-bot.service"
echo "  sudo systemctl daemon-reload"
echo "  sudo systemctl enable --now gt-bot"
echo ""
echo "To check status:"
echo "  systemctl status gt-bot"
