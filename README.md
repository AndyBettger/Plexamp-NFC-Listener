# Plexamp NFC Listener

A lightweight Python script for Raspberry Pi that reads NFC tags via a Waveshare PN532 HAT and triggers playback on Plexamp Headless.

Each NFC tag contains a pre-encoded Plexamp playback URL which is resolved and sent to the local Plexamp instance. The listener can run as a standalone NFC-to-Plexamp player, or as the NFC hardware layer for [`A Clockwork Plex`](https://github.com/AndyBettger/A-Clockwork-Plex), the touchscreen dashboard for Plexamp, weather, AirPlay and settings.

- Designed for Raspberry Pi 4 or newer with Raspberry Pi OS
- Uses Adafruit's CircuitPython PN532 and Blinka libraries
- Compatible with Plexamp Headless running on `http://localhost:32500`
- Full startup automation with systemd and Chromium kiosk mode
- Optional AirPlay receiver setup using Shairport Sync, with Plexamp handover hooks
- Optional integration with A Clockwork Plex so NFC scans switch the dashboard to the embedded Plexamp screen
- Tested on current Raspberry Pi OS releases using Python 3.13, where `python3-lgpio` and a venv created with `--system-site-packages` are required

---

## Use Case

Perfect for kiosks, jukeboxes, man caves, bedside music systems, or DIY smart audio stations. Tap an NFC tag to instantly queue and play an album in Plexamp.

With A Clockwork Plex installed as well, the flow becomes:

```text
Scan NFC album tag
  ↓
Read Plexamp playback URL from the tag
  ↓
Convert listen.plex.tv URL to local Plexamp Headless URL
  ↓
Trigger playback on http://localhost:32500
  ↓
Ask A Clockwork Plex to switch the touchscreen display to /plexamp
```

---

## 🧰 What You Need / Requirements

- **Raspberry Pi** – Any model with GPIO and internet access. A Raspberry Pi 4 Model B or faster is recommended for smoother Plexamp browsing performance.
  - NFC tap-to-play is fast.
  - The Plexamp UI is heavier, so slower Pi models can feel sluggish in kiosk mode.
- **PN532 NFC HAT** – In **I2C mode**.
  - Tested working version: [The Pi Hut PN532 NFC HAT](https://thepihut.com/products/nfc-hat-for-raspberry-pi-pn532)
  - Hardware documentation and DIP switch guide: [Waveshare PN532 NFC HAT Wiki](https://www.waveshare.com/wiki/PN532_NFC_HAT)
- **Raspberry Pi OS** – Current 64-bit Raspberry Pi OS is recommended.
- **Chromium browser** – Usually preinstalled on Raspberry Pi OS.
- **Plex Pass account** – Required for Plexamp Headless.
- **Plexamp Headless** – Installed locally and reachable on `http://localhost:32500`.
- **Python 3.9+ and pip**.
- **Internet access** to install dependencies.
- **Optional:** Shairport Sync and Avahi for AirPlay receiver support.
- **Optional:** [`A Clockwork Plex`](https://github.com/AndyBettger/A-Clockwork-Plex) for the touchscreen dashboard, embedded Plexamp page, weather display and hidden navigation drawer.

---

## Credits

- [Adafruit](https://www.adafruit.com/) for the `adafruit-circuitpython-pn532` library
- [Plex](https://www.plex.tv/) for Plexamp and Plexamp Headless
- [Waveshare](https://www.waveshare.com/) for the PN532 hardware
- [The Pi Hut](https://thepihut.com/) for the tested PN532 NFC HAT listing and documentation links
- [Shairport Sync](https://github.com/mikebrady/shairport-sync) for AirPlay audio receiver support
- Inspiration from [tgp-2's Plexamp setup gist](https://gist.github.com/tgp-2/fc34c5389bc3e4ef332e28d9430b0ebf)

---

## Hardware Setup

1. Prepare the SD card with Raspberry Pi OS using [Raspberry Pi Imager](https://www.raspberrypi.com/documentation/computers/getting-started.html#raspberry-pi-imager).
2. Choose the correct Pi version and the 64-bit OS where possible.
3. Configure SSH and Wi-Fi during imaging if you want a headless setup.
4. Configure the DIP switches on the PN532 HAT for **I2C mode** using the [Waveshare PN532 NFC HAT Wiki](https://www.waveshare.com/wiki/PN532_NFC_HAT).
5. Fit the PN532 HAT to the Pi GPIO header.
6. Insert the SD card and power on the Pi.

After boot, check that the I2C device is visible:

```bash
sudo raspi-config
# Interface Options → I2C → Enable
sudo reboot
```

Then:

```bash
ls -l /dev/i2c-1
i2cdetect -y 1
```

When the Waveshare PN532 HAT is correctly configured in I2C mode, you should usually see a device at:

```text
0x24
```

---

## 🔧 Quick Setup (Optional `setup.sh` Script)

Once the hardware is set up with a fresh install of Raspberry Pi OS, install Plexamp Headless first, then run the provided [`setup.sh`](./setup.sh) script to automate the NFC listener and kiosk setup.

This is especially helpful for fresh installs or when you want to get up and running quickly.

### 🛠️ What the quick setup script does

The `setup.sh` script performs these actions:

- Updates the system using `apt update && apt upgrade`
- Installs required packages:
  - `python3`, `python3-pip`, `python3-venv`
  - `python3-lgpio`
  - `git`, `i2c-tools`, `curl`
  - `chromium` or `chromium-browser`, depending on Raspberry Pi OS release
- Enables I2C via `raspi-config`
- Enables SSH via `raspi-config`
- Adds the current user to useful hardware access groups such as `i2c`, `gpio`, and `spi`
- Clones this GitHub repo to `~/Plexamp-NFC-Listener`, or updates it if already cloned
- Creates the Python virtual environment using `--system-site-packages`
- Installs Python dependencies from `requirements.txt`
- Checks that `lgpio`, `board`, and `busio` can be imported
- Creates and enables the `nfc-listener.service` systemd unit so it runs at boot
- Configures Chromium to open Plexamp or the dashboard in full-screen kiosk mode
- Optionally installs Shairport Sync as an AirPlay receiver

### 1. Install Plexamp Headless first

Use the community installer from tgp-2. This requires interactive input:

```bash
wget https://gist.githubusercontent.com/tgp-2/65e6f2f637bc81df2c9fd9ba33f73bc6/raw/plexamp-install.sh
bash ./plexamp-install.sh
```

During the installer:

- Paste a Plex claim code from <https://plex.tv/claim>
- Enter a unique name for your Plexamp player
- Let the installer create/start `plexamp.service`

After installation, reboot:

```bash
sudo reboot
```

After reboot, open Plexamp on the Pi to complete login and configuration:

```text
http://localhost:32500
```

### 2. Run the Plexamp NFC Listener setup script

Download and run the setup script:

```bash
wget https://raw.githubusercontent.com/AndyBettger/Plexamp-NFC-Listener/main/setup.sh
bash setup.sh
sudo reboot
```

The installer asks whether to install AirPlay support. If enabled during an interactive run, it also lists detected ALSA playback devices and asks which one Shairport Sync should use. Pressing Enter accepts the recommended device.

To run non-interactively with AirPlay enabled:

```bash
INSTALL_AIRPLAY=yes AIRPLAY_NAME="Plexamp Bedroom" bash setup.sh
sudo reboot
```

You can also override the ALSA output device used by Shairport Sync:

```bash
INSTALL_AIRPLAY=yes AIRPLAY_NAME="Plexamp Bedroom" AIRPLAY_OUTPUT_DEVICE="plughw:CARD=Pro,DEV=0" bash setup.sh
```

---

## A Clockwork Plex Integration

[`A Clockwork Plex`](https://github.com/AndyBettger/A-Clockwork-Plex) is the touchscreen dashboard that sits around Plexamp. It provides:

- Clock screen
- Detailed weather screen
- Embedded Plexamp iframe page
- Hidden bottom navigation drawer with swipe/tap handle
- AirPlay active screen
- Settings page

When A Clockwork Plex is installed on the same Pi, the NFC listener will try to run this helper after successful playback:

```text
/home/andy/A-Clockwork-Plex/scripts/nfc-plexamp-mode.sh
```

That helper switches the dashboard to Plexamp mode. If `xdotool` is not installed, A Clockwork Plex still has a browser-side mode watcher, so the currently open dashboard page can notice the mode change and move itself to `/plexamp`.

By default, the listener expects:

```text
/home/andy/A-Clockwork-Plex
```

You can override the display switch command with an environment variable in the systemd service:

```ini
Environment=PLEXAMP_DISPLAY_SWITCH_COMMAND=/path/to/nfc-plexamp-mode.sh
```

If the helper does not exist, the listener falls back to this dashboard API call:

```text
http://localhost:8088/api/mode/plexamp
```

You can override that too:

```ini
Environment=PLEXAMP_DASHBOARD_MODE_URL=http://localhost:8088/api/mode/plexamp
```

Then reload and restart the service:

```bash
sudo systemctl daemon-reload
sudo systemctl restart nfc-listener.service
```

---

## 🍏 Optional AirPlay Receiver

AirPlay support is provided by Shairport Sync. Because Plexamp Headless and Shairport Sync can both want the same audio device, this project uses handover hooks instead of letting both services fight for the output.

The handover flow is:

```text
AirPlay starts
  ↓
Pause Plexamp via http://localhost:32500/player/playback/pause
  ↓
Stop plexamp.service so the audio device is released
  ↓
Shairport Sync plays the AirPlay stream
  ↓
AirPlay ends
  ↓
Start plexamp.service again
```

This avoids the common problem where AirPlay appears to connect but no audio plays because Plexamp still has hold of the DAC/audio output.

### Choosing the AirPlay audio output

On Raspberry Pi systems with HDMI plus an audio HAT, the ALSA `default` device may point to HDMI rather than the DAC. During interactive setup, the script lists detected playback devices and lets you choose one by number.

For example, a Raspberry Pi with a DAC Pro may show something like:

```text
1) plughw:CARD=vc4hdmi0,DEV=0 — vc4-hdmi-0 - MAI PCM i2s-hifi-0
2) plughw:CARD=vc4hdmi1,DEV=0 — vc4-hdmi-1 - MAI PCM i2s-hifi-0
3) plughw:CARD=Pro,DEV=0 — RPi DAC Pro - Raspberry Pi DAC Pro HiFi pcm512x-hifi-0  ← recommended
4) default — Default ALSA device
C) Custom ALSA device string
```

For a Raspberry Pi DAC Pro, choose:

```text
plughw:CARD=Pro,DEV=0
```

The `plughw` form is preferred because it targets the actual hardware device while still allowing ALSA to handle useful software conversion.

The setup script creates these helper scripts:

```text
/usr/local/bin/plexamp-airplay-start
/usr/local/bin/plexamp-airplay-stop
```

It also configures Shairport Sync session hooks in:

```text
/etc/shairport-sync.conf
```

and backs up any existing config first.

---

## 📦 Full Manual Installation (Step-by-step)

Use this method if you prefer not to run the automated setup script, or if you need to troubleshoot each stage manually.

### 1. Hardware setup

Prepare Raspberry Pi OS with Raspberry Pi Imager, enable SSH if required, and configure the PN532 HAT DIP switches for **I2C mode** using the [Waveshare PN532 NFC HAT Wiki](https://www.waveshare.com/wiki/PN532_NFC_HAT).

### 2. Enable SSH and I2C

```bash
sudo raspi-config
# Interface Options → SSH → Enable
# Interface Options → I2C → Enable
sudo reboot
```

### 3. Update the system

```bash
sudo apt update && sudo apt upgrade -y
```

### 4. Install Plexamp Headless

Use the installer provided by tgp-2:

```bash
wget https://gist.githubusercontent.com/tgp-2/65e6f2f637bc81df2c9fd9ba33f73bc6/raw/79dfa75db81be185bcc84faa54b38604b185a619/plexamp-install.sh
bash ./plexamp-install.sh
```

During the installer:

- Enter the Plex claim code from <https://plex.tv/claim>
- Enter a unique name for your Plexamp player
- Allow the installer to create `plexamp.service`

After install completes, reboot:

```bash
sudo reboot
```

After reboot, open this in Chromium on the Raspberry Pi to complete Plexamp login and configuration:

```text
http://localhost:32500
```

### 5. Install required packages

```bash
sudo apt install -y python3 python3-pip python3-venv python3-lgpio git i2c-tools curl
sudo apt install -y chromium || sudo apt install -y chromium-browser
sudo usermod -aG i2c,gpio,spi "$USER"
```

`python3-lgpio` is required by Adafruit Blinka on newer Raspberry Pi OS releases. The virtual environment should be created with access to system site packages so the `lgpio` module can be imported.

Log out and back in, or reboot, after changing groups.

### 6. Set up the Python virtual environment

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

### 8. Run the listener manually

```bash
cd ~/Plexamp-NFC-Listener
source venv/bin/activate
python nfc_listener.py
```

Scan a Plexamp NFC tag. A successful scan should show output similar to:

```text
🎯 Parsed Tag URL:
https://listen.plex.tv/player/playback/playMedia?uri=...
🔁 Converted to local: http://localhost:32500/player/playback/playMedia?uri=...
✅ Playback triggered!
🖥️ Dashboard switched to Plexamp mode.
```

If A Clockwork Plex is not installed, playback can still work; you may simply see a warning that the dashboard switch could not be performed.

### 9. Autostart Plexamp UI or A Clockwork Plex kiosk

For standalone Plexamp kiosk mode, open Plexamp directly:

```text
http://localhost:32500
```

For A Clockwork Plex integration, point Chromium at the dashboard instead:

```text
http://localhost:8088/clock
```

Current Raspberry Pi OS releases use labwc/Wayland. Create or edit:

```bash
mkdir -p ~/.config/labwc
nano ~/.config/labwc/autostart
```

For standalone Plexamp:

```bash
sleep 10
chromium --kiosk --start-maximized --noerrdialogs --disable-infobars --no-first-run "http://localhost:32500" &
```

For A Clockwork Plex:

```bash
sleep 10
chromium --kiosk --start-maximized --noerrdialogs --disable-infobars --no-first-run "http://localhost:8088/clock" &
```

For older X11/LXDE releases, use the legacy autostart file instead:

```bash
mkdir -p ~/.config/autostart
nano ~/.config/autostart/kiosk.desktop
```

Standalone Plexamp example:

```ini
[Desktop Entry]
Type=Application
Name=Plexamp Kiosk
Exec=bash -c 'sleep 10 && chromium --kiosk --start-maximized --noerrdialogs --disable-infobars --no-first-run "http://localhost:32500"'
X-GNOME-Autostart-enabled=true
```

A Clockwork Plex example:

```ini
[Desktop Entry]
Type=Application
Name=A Clockwork Plex Kiosk
Exec=bash -c 'sleep 10 && chromium --kiosk --start-maximized --noerrdialogs --disable-infobars --no-first-run "http://localhost:8088/clock"'
X-GNOME-Autostart-enabled=true
```

If your OS only provides the old command name, replace `chromium` with `chromium-browser`.

### 10. Optional: install AirPlay receiver manually

```bash
sudo apt install -y shairport-sync avahi-daemon alsa-utils curl sudo
```

List available playback devices:

```bash
aplay -l
aplay -L
```

Choose the ALSA output device that points to your DAC or audio HAT. For example, the Raspberry Pi DAC Pro is commonly:

```text
plughw:CARD=Pro,DEV=0
```

Create the AirPlay start hook:

```bash
sudo tee /usr/local/bin/plexamp-airplay-start >/dev/null <<'EOF'
#!/bin/bash
set -euo pipefail
curl --silent --fail --max-time 2 "http://localhost:32500/player/playback/pause" >/dev/null 2>&1 || true
sleep 1
sudo systemctl stop plexamp.service >/dev/null 2>&1 || true
EOF
```

Create the AirPlay stop hook:

```bash
sudo tee /usr/local/bin/plexamp-airplay-stop >/dev/null <<'EOF'
#!/bin/bash
set -euo pipefail
sudo systemctl start plexamp.service >/dev/null 2>&1 || true
EOF
```

Make both hooks executable:

```bash
sudo chmod +x /usr/local/bin/plexamp-airplay-start /usr/local/bin/plexamp-airplay-stop
```

Allow the `shairport-sync` user to start and stop only the Plexamp service:

```bash
SYSTEMCTL_CMD="$(command -v systemctl)"
printf 'shairport-sync ALL=(root) NOPASSWD: %s stop plexamp.service, %s start plexamp.service\n' "$SYSTEMCTL_CMD" "$SYSTEMCTL_CMD" | sudo tee /etc/sudoers.d/shairport-sync-plexamp
sudo chmod 0440 /etc/sudoers.d/shairport-sync-plexamp
sudo visudo -cf /etc/sudoers.d/shairport-sync-plexamp
```

Back up and write the Shairport Sync config:

```bash
sudo cp /etc/shairport-sync.conf "/etc/shairport-sync.conf.backup.$(date +%Y%m%d-%H%M%S)"
sudo tee /etc/shairport-sync.conf >/dev/null <<'EOF'
general = {
  name = "Plexamp Bedroom";
  output_backend = "alsa";
};

sessioncontrol = {
  run_this_before_play_begins = "/usr/local/bin/plexamp-airplay-start";
  run_this_after_play_ends = "/usr/local/bin/plexamp-airplay-stop";
  active_state_timeout = 10.0;
  wait_for_completion = "yes";
};

alsa = {
  output_device = "plughw:CARD=Pro,DEV=0";
};
EOF
```

Replace `plughw:CARD=Pro,DEV=0` with the device chosen from `aplay -L` if your DAC uses a different ALSA name.

Enable and restart the services:

```bash
sudo systemctl enable avahi-daemon
sudo systemctl restart avahi-daemon
sudo systemctl enable shairport-sync
sudo systemctl restart shairport-sync
sudo systemctl start plexamp.service
```

### 11. Set up NFC listener service to run at boot

```bash
cd ~/Plexamp-NFC-Listener
sudo cp nfc-listener.service /etc/systemd/system/nfc-listener.service
sudo systemctl daemon-reload
sudo systemctl enable nfc-listener.service
sudo systemctl restart nfc-listener.service
```

Check status:

```bash
systemctl status nfc-listener.service --no-pager
```

View live logs:

```bash
journalctl -u nfc-listener.service -f
```

---

## Plexamp NFC Tag Format

The listener expects tags written by the Plexamp iPhone app or equivalent, containing a URL beginning with:

```text
https://listen.plex.tv/player/playback/playMedia?uri=
```

The script converts that to the local Plexamp Headless endpoint:

```text
http://localhost:32500/player/playback/playMedia?uri=
```

---

## Useful Local Plexamp Endpoints

```bash
curl "http://localhost:32500/player/playback/play"
curl "http://localhost:32500/player/playback/pause"
curl "http://localhost:32500/player/playback/playPause"
curl "http://localhost:32500/player/playback/stop"
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

### PN532 is not detected

Check I2C is enabled and the HAT DIP switches are set for I2C mode:

```bash
sudo raspi-config
ls -l /dev/i2c-1
i2cdetect -y 1
```

Also re-check the [Waveshare PN532 NFC HAT Wiki](https://www.waveshare.com/wiki/PN532_NFC_HAT) for the correct DIP switch positions.

### Playback does not start

Confirm Plexamp Headless is running:

```bash
systemctl status plexamp.service --no-pager
curl "http://localhost:32500/player/playback/playPause"
```

### Tag is read but display does not change

Check the NFC listener logs:

```bash
journalctl -u nfc-listener.service -f
```

If you see:

```text
xdotool is not installed; mode state was updated but browser was not navigated.
```

that is usually fine with the current A Clockwork Plex dashboard, because the browser-side mode watcher should notice the new mode and navigate itself. Make sure A Clockwork Plex has been pulled/restarted and the browser page has been refreshed once.

You can test the dashboard mode endpoint manually:

```bash
curl -X POST http://localhost:8088/api/mode/plexamp
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

### AirPlay device does not appear

Check Shairport Sync and Avahi:

```bash
systemctl status shairport-sync
systemctl status avahi-daemon
journalctl -u shairport-sync -b -n 100 --no-pager
```

Make sure the phone, Mac, or iPad is on the same network/VLAN as the Pi, and that mDNS/Bonjour traffic is not blocked.

### AirPlay connects but no sound plays

First confirm the selected ALSA device points to the real audio output, not HDMI:

```bash
aplay -l
aplay -L
cat /etc/shairport-sync.conf | grep -A3 '^alsa'
```

On a Raspberry Pi DAC Pro, the Shairport Sync output should usually be:

```text
plughw:CARD=Pro,DEV=0
```

You can test the DAC directly with:

```bash
sudo systemctl stop shairport-sync
sudo systemctl stop plexamp.service
speaker-test -D plughw:CARD=Pro,DEV=0 -c 2 -t wav
```

Check that Plexamp is being stopped when AirPlay begins:

```bash
journalctl -u shairport-sync -b -n 100 --no-pager
systemctl status plexamp.service
```

You can manually test the hooks:

```bash
/usr/local/bin/plexamp-airplay-start
systemctl status plexamp.service
/usr/local/bin/plexamp-airplay-stop
systemctl status plexamp.service
```

If the DAC uses a different ALSA device, rerun setup interactively and select the correct output, or force it with:

```bash
INSTALL_AIRPLAY=yes AIRPLAY_OUTPUT_DEVICE="plughw:CARD=Pro,DEV=0" bash setup.sh
```

---

## Updating

```bash
cd ~/Plexamp-NFC-Listener
git pull
python -m py_compile nfc_listener.py
sudo systemctl restart nfc-listener.service
```

---

## ✨ Done!

Scan an NFC tag written with a Plexamp sharing link and enjoy physical control of your music.

---

## License

This project is licensed under the [MIT License](LICENSE).
