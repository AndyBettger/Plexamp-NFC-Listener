# Plexamp NFC Listener

A lightweight Python script for Raspberry Pi that reads NFC tags via a Waveshare PN532 HAT and triggers playback on Plexamp Headless.  
Each NFC tag contains a pre-encoded Plexamp playback URL which is resolved and sent to the local Plexamp instance.

- Designed for Raspberry Pi 4 or newer with Raspberry Pi OS
- Uses Adafruit's CircuitPython PN532 and Blinka libraries
- Compatible with Plexamp Headless running on `http://localhost:32500`
- Full startup automation with systemd and Chromium kiosk mode
- Tested on current Raspberry Pi OS releases using Python 3.13, where `python3-lgpio` and a venv created with `--system-site-packages` are required

## Use Case

Perfect for kiosks, jukeboxes, man caves, or DIY smart audio stations. Tap an NFC tag to instantly queue and play an album in Plexamp!

## 🧰 What You Need / Requirements

- Raspberry Pi – Any model with GPIO and internet access. A Raspberry Pi 4 Model B or faster is recommended for smoother Plexamp browsing performance.  
  The NFC tap-to-play and Now Playing screen are fast, but general Plexamp UI can lag on slower models.
- PN532 NFC HAT – In I2C mode. The tested working version is available [here](https://thepihut.com/products/nfc-hat-for-raspberry-pi-pn532)  
  with documentation [here](https://www.waveshare.com/wiki/PN532_NFC_HAT)
- Chromium browser (usually preinstalled on Raspberry Pi OS)
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

Once the hardware is set up with a fresh install of Raspberry Pi OS, install Plexamp Headless first, then run the provided [`setup.sh`](./setup.sh) script to automate the NFC listener and kiosk setup.

This is especially helpful for fresh installs or if you want to get up and running quickly.

### 🛠️ What the quick setup script does

The `setup.sh` script performs the following actions:

- ✅ Updates the system using `apt update && apt upgrade`
- 💾 Installs required packages:
  - `python3`, `python3-pip`, `python3-venv`
  - `python3-lgpio`
  - `git`, `i2c-tools`
  - `chromium` or `chromium-browser`, depending on the Raspberry Pi OS release
- 🔧 Enables I2C via `raspi-config` (non-interactively)
- 🔐 Enables SSH via `raspi-config` to allow remote access
- 👤 Adds the current user to available hardware access groups such as `i2c`, `gpio`, and `spi`
- 📂 Clones this GitHub repo to `~/Plexamp-NFC-Listener` (or updates it if already cloned)
- 🐍 Creates the Python virtual environment using `--system-site-packages`
- 📦 Installs Python dependencies from `requirements.txt`
- 🧪 Checks that `lgpio`, `board`, and `busio` can be imported
- 🧩 Creates and enables the `nfc-listener.service` systemd unit so it runs at boot
- 🌐 Configures Chromium to open `http://localhost:32500` in full-screen kiosk mode on startup
  - Current Raspberry Pi OS releases use `~/.config/labwc/autostart`
  - Older X11/LXDE releases use `~/.config/autostart/kiosk.desktop`

📢 If you're installing remotely via SSH, you will need to complete the Plexamp login by visiting:  
`http://localhost:32500` from Chromium on your Raspberry Pi.

## 🚀 To run the automated and quick setup:

### 1. Install Plexamp Headless (Required First Step)

Use the official community installer (requires interactive input):

```bash
wget https://gist.githubusercontent.com/tgp-2/65e6f2f637bc81df2c9fd9ba33f73bc6/raw/plexamp-install.sh
bash ./plexamp-install.sh
```

- Paste the claim code from https://plex.tv/claim
- Enter a unique name for your Plexamp player
- After installation, reboot:

```bash
sudo reboot
```

- After reboot, open `http://localhost:32500` in Chromium on the Raspberry Pi to complete the Plexamp login and configuration.

### 2. Run the Plexamp NFC Listener setup script

Download and run the setup script:

```bash
wget https://raw.githubusercontent.com/AndyBettger/Plexamp-NFC-Listener/main/setup.sh
bash setup.sh
sudo reboot
```

---

## 📦 Full Manual Installation (Step-by-step)

Use this method if you are not comfortable running the setup script or if you have issues running it.

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

### 4. Install Plexamp Headless

Use the installer provided by tgp-2:

```bash
wget https://gist.githubusercontent.com/tgp-2/65e6f2f637bc81df2c9fd9ba33f73bc6/raw/79dfa75db81be185bcc84faa54b38604b185a619/plexamp-install.sh
bash ./plexamp-install.sh
```

- Enter the plex.tv claim code
- Enter a name for your player
- After install completes, reboot the Pi:

```bash
sudo reboot
```

- After reboot, open `http://localhost:32500` in Chromium on the Raspberry Pi to complete the Plexamp login and configuration.

### 5. Install Required Packages

```bash
sudo apt install -y python3 python3-pip python3-venv python3-lgpio git i2c-tools
sudo apt install -y chromium || sudo apt install -y chromium-browser
sudo usermod -aG i2c,gpio,spi "$USER"
```

`python3-lgpio` is required by Adafruit Blinka on newer Raspberry Pi OS releases. The virtual environment must be created with access to system site packages so the `lgpio` module can be imported.

### 6. Set Up Python Virtual Environment

```bash
cd ~
git clone https://github.com/AndyBettger/Plexamp-NFC-Listener.git
cd Plexamp-NFC-Listener

python3 -m venv venv --system-site-packages
source venv/bin/activate

python -m pip install --upgrade pip setuptools wheel
python -m pip install -r requirements.txt
```

Check the key hardware imports:

```bash
python - <<'PY'
import lgpio
import board
import busio
print("lgpio OK")
print("board/busio OK")
PY
```

### 7. Check the PN532 HAT on I2C

```bash
ls -l /dev/i2c-1
i2cdetect -y 1
```

When the Waveshare PN532 HAT is in I2C mode, you should usually see a device at `0x24`.

### 8. Autostart Plexamp UI (Kiosk Mode)

Current Raspberry Pi OS releases use labwc/Wayland. Create this file:

```bash
mkdir -p ~/.config/labwc
nano ~/.config/labwc/autostart
```

Paste:

```bash
sleep 10
chromium --kiosk --start-maximized --noerrdialogs --disable-infobars --no-first-run "http://localhost:32500" &
```

For older Raspberry Pi OS releases using X11/LXDE, use the legacy autostart file instead:

```bash
mkdir -p ~/.config/autostart
nano ~/.config/autostart/kiosk.desktop
```

Paste:

```ini
[Desktop Entry]
Type=Application
Name=Plexamp Kiosk
Exec=bash -c 'sleep 10 && chromium --kiosk --start-maximized --noerrdialogs --disable-infobars --no-first-run "http://localhost:32500"'
X-GNOME-Autostart-enabled=true
```

If your OS only provides the old command name, replace `chromium` with `chromium-browser`.

### 9. Set Up Service to Run at Boot

```bash
sudo cp nfc-listener.service /etc/systemd/system/nfc-listener.service
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable nfc-listener.service
sudo systemctl restart nfc-listener.service
```

Check the status:

```bash
systemctl status nfc-listener.service
```

View detailed logs:

```bash
sudo journalctl -u nfc-listener.service -b -n 100 --no-pager
```

---

## Troubleshooting

### `ModuleNotFoundError: No module named 'lgpio'`

On newer Raspberry Pi OS releases, rebuild the venv using system site packages:

```bash
cd ~/Plexamp-NFC-Listener
deactivate 2>/dev/null || true
rm -rf venv

sudo apt update
sudo apt install -y python3-venv python3-lgpio i2c-tools

python3 -m venv venv --system-site-packages
source venv/bin/activate

python -m pip install --upgrade pip setuptools wheel
python -m pip install -r requirements.txt
```

Then test:

```bash
python - <<'PY'
import lgpio
import board
import busio
print("lgpio OK")
print("board/busio OK")
PY
```

### Service starts too quickly and then fails

Reset the failed service state and inspect the logs:

```bash
sudo systemctl reset-failed nfc-listener.service
sudo systemctl restart nfc-listener.service
sudo journalctl -u nfc-listener.service -b -n 100 --no-pager
```

### Chromium does not start on boot

For current Raspberry Pi OS releases, check:

```bash
cat ~/.config/labwc/autostart
command -v chromium
```

For older releases, check:

```bash
cat ~/.config/autostart/kiosk.desktop
command -v chromium-browser
```

---

## ✨ Done!

Scan an NFC tag written with a Plexamp sharing link and enjoy physical control of your music.

---

## License

This project is licensed under the [MIT License](LICENSE).
