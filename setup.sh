#!/bin/bash
set -euo pipefail

REPO_URL="https://github.com/AndyBettger/Plexamp-NFC-Listener.git"
REPO_DIR="$HOME/Plexamp-NFC-Listener"
PLEXAMP_URL="http://localhost:32500"

echo "📦 Updating system..."
sudo apt update && sudo apt upgrade -y

echo "💾 Installing required packages..."
sudo apt install -y python3 python3-pip python3-venv python3-lgpio git i2c-tools

echo "🌐 Installing Chromium if needed..."
if ! command -v chromium >/dev/null 2>&1 && ! command -v chromium-browser >/dev/null 2>&1; then
  sudo apt install -y chromium || sudo apt install -y chromium-browser
fi

CHROMIUM_CMD="$(command -v chromium 2>/dev/null || command -v chromium-browser 2>/dev/null || true)"
if [ -z "$CHROMIUM_CMD" ]; then
  echo "❌ Chromium was not found after installation."
  echo "   Try installing it manually with: sudo apt install chromium"
  exit 1
fi

echo "🔧 Enabling I2C and SSH..."
sudo raspi-config nonint do_i2c 0
sudo raspi-config nonint do_ssh 0

echo "👤 Adding current user to hardware access groups..."
for group in i2c gpio spi; do
  if getent group "$group" >/dev/null; then
    sudo usermod -aG "$group" "$USER"
  fi
done

echo "📁 Cloning or updating Plexamp-NFC-Listener repository..."
if [ ! -d "$REPO_DIR/.git" ]; then
  git clone "$REPO_URL" "$REPO_DIR"
else
  git -C "$REPO_DIR" pull --ff-only
fi
cd "$REPO_DIR"

echo "🐍 Creating Python virtual environment..."
rm -rf venv
python3 -m venv venv --system-site-packages
source venv/bin/activate

echo "📦 Installing Python dependencies..."
python -m pip install --upgrade pip setuptools wheel
python -m pip install -r requirements.txt

echo "🧪 Checking hardware Python imports..."
python - <<'PY'
import lgpio
import board
import busio
print("✅ lgpio OK")
print("✅ board/busio OK")
PY

echo "📄 Installing and enabling systemd service..."
sudo tee /etc/systemd/system/nfc-listener.service >/dev/null <<EOF
[Unit]
Description=Plexamp NFC Listener
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$REPO_DIR
Environment=PYTHONUNBUFFERED=1
ExecStart=$REPO_DIR/venv/bin/python -u $REPO_DIR/nfc_listener.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable nfc-listener.service
sudo systemctl restart nfc-listener.service

echo "🌐 Configuring Chromium to start in kiosk mode..."

# Raspberry Pi OS Bookworm/Trixie uses labwc/Wayland by default.
mkdir -p ~/.config/labwc
cat > ~/.config/labwc/autostart <<EOF
sleep 10
$CHROMIUM_CMD --kiosk --start-maximized --noerrdialogs --disable-infobars --no-first-run "$PLEXAMP_URL" &
EOF
chmod +x ~/.config/labwc/autostart

# Legacy X11/LXDE autostart fallback for older Raspberry Pi OS releases.
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/kiosk.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Plexamp Kiosk
Exec=bash -c 'sleep 10 && $CHROMIUM_CMD --kiosk --start-maximized --noerrdialogs --disable-infobars --no-first-run "$PLEXAMP_URL"'
X-GNOME-Autostart-enabled=true
EOF

echo "✅ Setup complete!"
echo "🔁 Please reboot your Pi so group changes, the NFC listener service, and kiosk UI all start cleanly."
