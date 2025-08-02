#!/bin/bash

set -e

echo "🔧 Updating system..."
sudo apt update && sudo apt upgrade -y

echo "💾 Installing required packages..."
sudo apt install -y python3 python3-pip python3-venv git i2c-tools chromium-browser

echo "🔐 Enabling SSH..."
sudo raspi-config nonint do_ssh 0

echo "📡 Enabling I2C..."
sudo raspi-config nonint do_i2c 0

echo "📁 Cloning Plexamp-NFC-Listener (if not already cloned)..."
if [ ! -d "$HOME/Plexamp-NFC-Listener" ]; then
  git clone https://github.com/AndyBettger/Plexamp-NFC-Listener.git "$HOME/Plexamp-NFC-Listener"
fi

cd "$HOME/Plexamp-NFC-Listener"

echo "🐍 Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

echo "📦 Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

echo "🧩 Installing systemd service..."
sudo cp nfc-listener.service /etc/systemd/system/nfc-listener.service
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable nfc-listener.service
sudo systemctl start nfc-listener.service

echo "🌐 Configuring Chromium to start in kiosk mode..."
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/kiosk.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Plexamp Kiosk
Exec=bash -c "sleep 10 && chromium-browser --kiosk --noerrdialogs --disable-infobars http://localhost:32500"
X-GNOME-Autostart-enabled=true
EOF

echo "✅ Setup complete. Please reboot your Raspberry Pi."
