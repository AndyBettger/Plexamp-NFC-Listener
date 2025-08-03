#!/bin/bash

echo "📦 Updating system..."
sudo apt update && sudo apt upgrade -y

echo "💾 Installing required packages..."
sudo apt install -y python3 python3-pip python3-venv chromium-browser git i2c-tools

echo "🔧 Enabling I2C and SSH..."
sudo raspi-config nonint do_i2c 0
sudo raspi-config nonint do_ssh 0

echo "📁 Cloning Plexamp-NFC-Listener repository..."
cd ~
if [ ! -d "Plexamp-NFC-Listener" ]; then
  git clone https://github.com/AndyBettger/Plexamp-NFC-Listener.git
fi
cd Plexamp-NFC-Listener

echo "🐍 Creating Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

echo "📦 Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

echo "📄 Installing and enabling systemd service..."
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
Exec=bash -c 'sleep 10 && chromium-browser --kiosk --noerrdialogs --disable-infobars http://localhost:32500'
X-GNOME-Autostart-enabled=true
EOF

echo "✅ Setup complete! Please reboot your Pi to ensure all services and the kiosk UI start properly."
