# Plexamp NFC Listener

This project turns your Raspberry Pi and PN532 NFC reader into a physical controller for Plexamp headless.

## 🧰 What You Need
- Raspberry Pi (any model with GPIO and Internet access)
- PN532 NFC HAT (I2C mode)
- Chromium browser (preinstalled on Raspberry Pi OS)
- A Plex Pass account so you can use Plexamp Headless and player

## 📦 Installation (Step-by-step)

### 1. Update System
```bash
sudo apt update && sudo apt upgrade -y
```

### 2. Install Required Packages
```bash
sudo apt install -y python3 python3-pip python3-venv chromium-browser git i2c-tools
```

### 3. Enable I2C on the Pi
```bash
sudo raspi-config
# Navigate to: Interfacing Options > I2C > Enable
sudo reboot
```

### 4. Set Up Python Virtual Environment
```bash
cd ~
git clone https://github.com/AndyBettger/Plexamp-NFC-Listener.git
cd Plex-NFC-Listener
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install adafruit-circuitpython-pn532 requests RPi.GPIO adafruit-blinka
```

### 5. Install Plexamp Headless
```bash
wget https://gist.githubusercontent.com/tgp-2/65e6f2f637bc81df2c9fd9ba33f73bc6/raw/79dfa75db81be185bcc84faa54b38604b185a619/plexamp-install.sh
bash ./plexamp-install.sh
```

Login using the terminal prompt after launching once:
```bash
plexamp-headless
```

### 6. Autostart Plexamp UI (Kiosk Mode)
```bash
mkdir -p ~/.config/autostart
nano ~/.config/autostart/kiosk.desktop
```
Paste:
```
[Desktop Entry]
Type=Application
Name=Plexamp Kiosk
Exec=chromium-browser --kiosk --noerrdialogs --disable-infobars http://localhost:32500
X-GNOME-Autostart-enabled=true
```

### 7. Set Up Service to Run at Boot
```bash
sudo cp nfc-listener.service /etc/systemd/system/nfc-listener.service
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable nfc-listener.service
sudo systemctl start nfc-listener.service
```

Check status:
```bash
systemctl status nfc-listener.service
```

## ✨ Done!
Scan an NFC tag written with a Plexamp sharing link and enjoy physical control of your music.