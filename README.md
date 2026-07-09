# Plexamp NFC Listener

A lightweight Python NFC listener for Raspberry Pi that reads Plexamp album tags and triggers playback on Plexamp Headless.

This project is now designed to work either as a **standalone NFC-to-Plexamp player** or as the NFC hardware layer for [`A Clockwork Plex`](https://github.com/AndyBettger/A-Clockwork-Plex), the touchscreen dashboard that wraps Plexamp, Weather, AirPlay and Settings into one kiosk-style appliance.

## What it does

```text
Scan NFC album tag
  ↓
Read Plexamp playback URL from the tag
  ↓
Convert listen.plex.tv URL to local Plexamp Headless URL
  ↓
Trigger playback on http://localhost:32500
  ↓
Optional: ask A Clockwork Plex to switch the display to /plexamp
```

## Current features

- Reads NFC tags using a Waveshare PN532 HAT in I2C mode.
- Parses Plexamp iPhone NFC playback URLs.
- Sends playback commands to local Plexamp Headless.
- Debounces repeated scans of the same tag.
- Runs as a systemd service.
- Optional integration with A Clockwork Plex:
  - after successful playback, runs the dashboard display switch helper;
  - falls back to `/api/mode/plexamp` if the helper is not available;
  - keeps album taps feeling like a physical mini-LP jukebox.

## Hardware and software requirements

- Raspberry Pi with GPIO and I2C support.
- Waveshare PN532 NFC HAT configured for **I2C** mode.
- Raspberry Pi OS.
- Python 3.
- Plexamp Headless running locally, usually at:

```text
http://localhost:32500
```

- Python packages from `requirements.txt`.
- On newer Raspberry Pi OS versions, `python3-lgpio` and a venv created with `--system-site-packages` may be required for Blinka/GPIO access.

## Relationship with A Clockwork Plex

This repository handles the NFC scan and playback trigger.

A Clockwork Plex handles the touchscreen display:

- Clock screen.
- Detailed weather screen.
- Embedded Plexamp iframe page.
- Hidden bottom nav drawer with swipe/tap handle.
- AirPlay handoff screen.
- Settings page.

When both repos are installed on the same Pi, the updated NFC listener will try to run:

```text
/home/andy/A-Clockwork-Plex/scripts/nfc-plexamp-mode.sh
```

That helper switches the dashboard to Plexamp mode. If `xdotool` is not installed, A Clockwork Plex still has a browser-side mode watcher, so the open page can move itself to `/plexamp` after the mode is changed.

## Quick install

Clone the repository:

```bash
cd ~
git clone https://github.com/AndyBettger/Plexamp-NFC-Listener.git
cd Plexamp-NFC-Listener
```

Install system packages:

```bash
sudo apt update
sudo apt install -y python3 python3-pip python3-venv python3-lgpio i2c-tools git curl
```

Create the virtual environment:

```bash
python3 -m venv venv --system-site-packages
source venv/bin/activate
python -m pip install --upgrade pip setuptools wheel
python -m pip install -r requirements.txt
```

Check the key imports:

```bash
python - <<'PY'
import lgpio
import board
import busio
print("lgpio OK")
print("board/busio OK")
PY
```

Check the PN532 on I2C:

```bash
ls -l /dev/i2c-1
i2cdetect -y 1
```

The PN532 HAT in I2C mode usually appears at:

```text
0x24
```

## Running manually

```bash
cd ~/Plexamp-NFC-Listener
source venv/bin/activate
python nfc_listener.py
```

Then scan a Plexamp NFC tag.

A successful scan should show output similar to:

```text
🎯 Parsed Tag URL:
https://listen.plex.tv/player/playback/playMedia?uri=...
🔁 Converted to local: http://localhost:32500/player/playback/playMedia?uri=...
✅ Playback triggered!
🖥️ Dashboard switched to Plexamp mode.
```

If A Clockwork Plex is not installed, playback can still work; you may simply see a warning that the dashboard switch could not be performed.

## Running as a service

Install the bundled service:

```bash
cd ~/Plexamp-NFC-Listener
sudo cp nfc-listener.service /etc/systemd/system/nfc-listener.service
sudo systemctl daemon-reload
sudo systemctl enable --now nfc-listener.service
```

Check status:

```bash
systemctl status nfc-listener.service --no-pager
```

Watch live logs:

```bash
journalctl -u nfc-listener.service -f
```

After pulling updates:

```bash
cd ~/Plexamp-NFC-Listener
git pull
python -m py_compile nfc_listener.py
sudo systemctl restart nfc-listener.service
```

## A Clockwork Plex integration settings

By default, the listener expects A Clockwork Plex to be installed at:

```text
/home/andy/A-Clockwork-Plex
```

and uses this helper:

```text
/home/andy/A-Clockwork-Plex/scripts/nfc-plexamp-mode.sh
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

Then reload and restart:

```bash
sudo systemctl daemon-reload
sudo systemctl restart nfc-listener.service
```

## Plexamp NFC tag format

The listener expects tags written by the Plexamp iPhone app or equivalent, containing a URL beginning with:

```text
https://listen.plex.tv/player/playback/playMedia?uri=
```

The script converts that to the local Plexamp Headless endpoint:

```text
http://localhost:32500/player/playback/playMedia?uri=
```

## Useful local Plexamp endpoints

```bash
curl "http://localhost:32500/player/playback/play"
curl "http://localhost:32500/player/playback/pause"
curl "http://localhost:32500/player/playback/playPause"
curl "http://localhost:32500/player/playback/stop"
```

## Troubleshooting

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

### ModuleNotFoundError: No module named `lgpio`

Rebuild the venv using system site packages:

```bash
cd ~/Plexamp-NFC-Listener
rm -rf venv
sudo apt install -y python3-venv python3-lgpio
python3 -m venv venv --system-site-packages
source venv/bin/activate
python -m pip install --upgrade pip setuptools wheel
python -m pip install -r requirements.txt
```

### PN532 is not detected

Check I2C is enabled and the HAT DIP switches are set for I2C mode:

```bash
sudo raspi-config
ls -l /dev/i2c-1
i2cdetect -y 1
```

### Playback does not start

Confirm Plexamp Headless is running:

```bash
systemctl status plexamp.service --no-pager
curl "http://localhost:32500/player/playback/playPause"
```

## Licence

This project is licensed under the [MIT License](LICENSE).
