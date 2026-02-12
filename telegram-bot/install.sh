#!/usr/bin/env bash
set -euo pipefail

# Build and install gt-bot to the town's services/ directory.
# Run from anywhere — the script detects the town root automatically.
# Service name is unique per town: gt-bot-<town-dir>.service

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOWN_ROOT="$(cd "$SCRIPT_DIR/../../../../" && pwd)"
TOWN_NAME="$(basename "$TOWN_ROOT")"
SERVICE_DIR="$TOWN_ROOT/services/telegram-bot"
SERVICE_NAME="gt-bot-${TOWN_NAME}"

echo "==> Town root: $TOWN_ROOT"
echo "==> Town name: $TOWN_NAME"
echo "==> Service dir: $SERVICE_DIR"
echo "==> Service name: $SERVICE_NAME"

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

# 5. Detect paths for gt and bd (needed in systemd PATH since it won't have user's shell PATH)
GT_PATH="$(dirname "$(command -v gt 2>/dev/null || echo /usr/local/bin/gt)")"
BD_PATH="$(dirname "$(command -v bd 2>/dev/null || echo /usr/local/bin/bd)")"
EXTRA_PATHS=""
for p in "$GT_PATH" "$BD_PATH"; do
    case ":$EXTRA_PATHS:" in
        *":$p:"*) ;;  # already included
        *) EXTRA_PATHS="${EXTRA_PATHS:+$EXTRA_PATHS:}$p" ;;
    esac
done
SVC_PATH="${EXTRA_PATHS}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/snap/bin"
SVC_USER="$(whoami)"
SVC_HOME="$HOME"

# 6. Generate systemd service file (town-specific name to avoid conflicts)
# - User/HOME: runs as the installing user, not root (root would corrupt sqlite WAL ownership)
# - PATH: includes gt and bd directories (systemd doesn't inherit user shell PATH)
cat > "$SERVICE_DIR/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=Gas Town Telegram Bot ($TOWN_NAME)
After=network.target

[Service]
Type=simple
User=$SVC_USER
ExecStart=$SERVICE_DIR/gt-bot
WorkingDirectory=$TOWN_ROOT
EnvironmentFile=$SERVICE_DIR/.env
Environment=PATH=$SVC_PATH
Environment=HOME=$SVC_HOME
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF
echo "    Generated: $SERVICE_DIR/${SERVICE_NAME}.service"

echo ""
echo "==> Install complete!"
echo ""
echo "To activate the service:"
echo "  sudo cp $SERVICE_DIR/${SERVICE_NAME}.service /etc/systemd/system/${SERVICE_NAME}.service"
echo "  sudo systemctl daemon-reload"
echo "  sudo systemctl enable --now $SERVICE_NAME"
echo ""
echo "To check status:"
echo "  systemctl status $SERVICE_NAME"
