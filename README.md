# Plexamp NFC Listener

A lightweight Python script for Raspberry Pi that reads NFC tags via a Waveshare PN532 HAT and triggers playback on Plexamp headless.  
Each NFC tag contains a pre-encoded Plexamp playback URL which is resolved and sent to the local Plexamp instance.

- Designed for Raspberry Pi 4 with Raspberry Pi OS
- Uses Adafruit's CircuitPython PN532 and Blinka libraries
- Compatible with Plexamp headless running on `http://localhost:32500`
- Full startup automation with systemd and Chromium kiosk mode

## Use Case

Perfect for kiosks, jukeboxes, man caves, or DIY smart audio stations. Tap an NFC tag to instantly queue and play an album in Plexamp!

## 🧰 What You Need / Requirements

- Raspberry Pi – Any model with GPIO and internet access. A Raspberry Pi 4 Model B or faster is recommended for smoother Plexamp browsing performance.  
  The NFC tap-to-play and Now Playing screen are fast, but general Plexamp UI can lag on slower models.
- PN532 NFC HAT – In I2C mode. The tested working version is available [here](https://thepihut.com/products/nfc-hat-for-raspberry-pi-pn532)  
  with documentation [here](https://www.waveshare.com/wiki/PN532_NFC_HAT)
- Chromium browser (preinstalled on Raspberry Pi OS)
- A Plex Pass account to use Plexamp Headless
- Python 3.9+ and pip
- Internet access to install dependencies

## Credits

- [Adafruit](https://www.adafruit.com/) for the `adafruit-circuitpython-pn532` library  
- [Plex](https://www.plex.tv/) for Plexamp and Plexamp Headless  
- [Waveshare](https://www.waveshare.com/) for the PN532 hardware  
- Inspiration from [tgp-2's Plexamp setup gist](https://gist.github.com/tgp-2/fc34c5389bc3e4ef332e28d9430b0ebf)

---

## Hardware Setup

- Prepare the SD card with a fresh install of Raspberry Pi OS using the instructions [here](https://www.raspberrypi.com/documentation/computers/getting-started.html#raspberry-pi-imager), choosing the correct Pi version and the 64-bit OS.
- Configure the DIP switches on the NFC HAT for I2C mode using [this guide](https://www.waveshare.com/wiki/PN532_NFC_HAT)
- Insert the SD card and power on the Pi

## 🔧 Quick Setup (Optional `setup.sh` Script)

Once the hardware is setup with a fresh install of Raspberry Pi OS, and for most cleanish Raspberry Pi setups, you can use the provided [`setup.sh`](./setup.sh) script to automate the entire installation process.  
This is especially helpful for fresh installs or if you want to get up and running quickly.

### 🛠️ What the script does

The `setup.sh` script performs the following actions:

- ✅ Updates the system using `apt update && apt upgrade`
- 💾 Installs required packages:
  - `python3`, `python3-pip`
  - `git`, `i2c-tools`
  - `chromium-browser`
- 🔧 Enables I2C via `raspi-config` (non-interactively)
- 🔐 Enables SSH to allow remote access
- 📂 Clones this GitHub repo to `~/Plexamp-NFC-Listener` (if not already cloned)
- 📦 Installs Python dependencies from `requirements.txt`
- 🧩 Copies and enables the `nfc-listener.service` systemd unit so it runs at boot
- 🌐 Configures Chromium to open `http://localhost:32500` in full-screen kiosk mode on startup

📢 If you're installing remotely via SSH, you will need to complete the Plexamp login by visiting:  
`http://localhost:32500` from the Chromium on your Raspberry Pi.

### 🚀 To run the automated setup:

```bash
wget https://raw.githubusercontent.com/AndyBettger/Plexamp-NFC-Listener/main/setup.sh
bash setup.sh
```

---

## 📦 Full Manual Installation (Step-by-step)

### 1. Hardware Setup

- Prepare the SD card with a fresh install of Raspberry Pi OS using the instructions [here](https://www.raspberrypi.com/documentation/computers/getting-started.html#raspberry-pi-imager), choosing the correct Pi version and the 64-bit OS.
- Configure the DIP switches on the NFC HAT for I2C mode using [this guide](https://www.waveshare.com/wiki/PN532_NFC_HAT)
- Insert the SD card and power on the Pi

### 2. Enable SSH and I2C on the Pi

If you didn't enable SSH using Raspberry Pi Imager, do this via terminal:
```bash
sudo raspi-config
# Navigate to: Interfacing Options > SSH > Enable
# Navigate to: Interfacing Options > I2C > Enable
sudo reboot
```

### 3. Update System

```bash
sudo apt update && sudo apt upgrade -y
```

### 4. Install Required Packages

```bash
sudo apt install -y python3 python3-pip python3-venv chromium-browser git i2c-tools
```

### 5. Set Up Python Virtual Environment

```bash
cd ~
git clone https://github.com/AndyBettger/Plexamp-NFC-Listener.git
cd Plexamp-NFC-Listener
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

### 6. Install Plexamp Headless

Use the installer provided by tgp-2:

```bash
wget https://gist.githubusercontent.com/tgp-2/65e6f2f637bc81df2c9fd9ba33f73bc6/raw/79dfa75db81be185bcc84faa54b38604b185a619/plexamp-install.sh
bash ./plexamp-install.sh
```

- Enter the plex.tv claim code (copy from browser, paste into SSH with `Ctrl+V`)
- Enter a name for your player
- After install completes, reboot the Pi:
```bash
sudo reboot
```

- After reboot, open `http://localhost:32500` in a Chromium on the Raspberry Pi to complete Plex login and config

### 7. Autostart Plexamp UI (Kiosk Mode)

```bash
mkdir -p ~/.config/autostart
nano ~/.config/autostart/kiosk.desktop
```

Paste:

```ini
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

Check the status:

```bash
systemctl status nfc-listener.service
```

---

## ✨ Done!

Scan an NFC tag written with a Plexamp sharing link and enjoy physical control of your music.

---

## License

This project is licensed under the [MIT License](LICENSE).