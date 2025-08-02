# Plexamp NFC Listener

This project turns your Raspberry Pi and PN532 NFC reader into a physical controller for Plexamp headless.

## 🧰 What You Need
- Raspberry Pi - Any model with GPIO and Internet access, I would suggest that a Raspberry Pi 4 Model B or faster is used if you are planning on using Plexamp to scroll through and browse your artist and album collections, it does work but it can be quite slow to scroll and respond, the Now Playing and NFC playback feature are fine, but there is sometimes a delay of a few seconds
- PN532 NFC HAT - In I2C mode - The one that is tested and working is (https://www.waveshare.com/wiki/PN532_NFC_HAT) available from here (https://thepihut.com/products/nfc-hat-for-raspberry-pi-pn532)
- Chromium browser (preinstalled on Raspberry Pi OS)
- A Plex Pass account so you can use Plexamp Headless

## 📦 Installation (Step-by-step)

### 1. Hardware Setup
- Prepare the SD card with a fresh install of Raspberry Pi OS using the instructions [here](https://www.raspberrypi.com/documentation/computers/getting-started.html#raspberry-pi-imager) choosing the correct Pi version you have and the 64-bit version of Raspberry Pi OS
- Configure the DIP switches on the NFC hat to work in I2C mode with the instructions [here](https://www.waveshare.com/wiki/PN532_NFC_HAT).
- Once the SD card is prepared and the NFC hat is set to I2C mode and seated on the Pi as per the instructions, insert the SD card into the Pi and power on.


### 2. Update System
```bash
sudo apt update && sudo apt upgrade -y
```

### 3. Install Required Packages
```bash
sudo apt install -y python3 python3-pip python3-venv chromium-browser git i2c-tools
```

### 4. Enable I2C on the Pi
```bash
sudo raspi-config
# Navigate to: Interfacing Options > I2C > Enable
sudo reboot
```

### 5. Set Up Python Virtual Environment
```bash
cd ~
git clone https://github.com/AndyBettger/Plexamp-NFC-Listener.git
cd Plex-NFC-Listener
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install adafruit-circuitpython-pn532 requests RPi.GPIO adafruit-blinka
```

### 6. Install Plexamp Headless
Use the installer provided by tgp-2, more details are available [here](https://gist.github.com/tgp-2/fc34c5389bc3e4ef332e28d9430b0ebf), but wgetting the installer and running it, should work.
```bash
wget https://gist.githubusercontent.com/tgp-2/65e6f2f637bc81df2c9fd9ba33f73bc6/raw/79dfa75db81be185bcc84faa54b38604b185a619/plexamp-install.sh
bash ./plexamp-install.sh
```
- Enter the plex.tv claim code ... copy from a web browser, paste it `ctrl-V` into your Pi SSH session and enter
- Enter a name for your player
- After install completes, `sudo reboot` to restart the Pi ... Plexamp auto-starts after reboot
- In a web browser, go to `hostname:32500`, login to Plex, and configure playback settings for your Pi
- From the browser or from the Plexamp app on another device (your phone, laptop, etc.), tap the Cast icon and select your Pi from the list of players 
- Now play some music!


### 7. Autostart Plexamp UI (Kiosk Mode)
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

### 8. Set Up Service to Run at Boot
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