#!/bin/bash
set -euo pipefail

REPO_URL="https://github.com/AndyBettger/Plexamp-NFC-Listener.git"
REPO_DIR="$HOME/Plexamp-NFC-Listener"
PLEXAMP_URL="http://localhost:32500"
AIRPLAY_OUTPUT_DEVICE="${AIRPLAY_OUTPUT_DEVICE:-default}"

prompt_yes_no() {
  local prompt="$1"
  local default_answer="${2:-no}"
  local env_answer="${3:-}"
  local answer=""

  if [ -n "$env_answer" ]; then
    answer="$env_answer"
  elif [ -t 0 ]; then
    read -r -p "$prompt" answer
  else
    answer="$default_answer"
  fi

  case "${answer,,}" in
    y|yes|true|1) return 0 ;;
    *) return 1 ;;
  esac
}

configure_airplay() {
  echo "🍏 Optional AirPlay receiver setup..."

  if ! prompt_yes_no "Install and configure AirPlay audio receiver using Shairport Sync? [y/N]: " "no" "${INSTALL_AIRPLAY:-}"; then
    echo "⏭️  Skipping AirPlay setup."
    return 0
  fi

  echo "💾 Installing AirPlay packages..."
  sudo apt install -y shairport-sync avahi-daemon curl sudo

  local default_airplay_name
  local airplay_name_input=""
  local airplay_name
  default_airplay_name="$(hostname | sed 's/-/ /g')"

  if [ -n "${AIRPLAY_NAME:-}" ]; then
    airplay_name="$AIRPLAY_NAME"
  elif [ -t 0 ]; then
    read -r -p "AirPlay display name [$default_airplay_name]: " airplay_name_input
    airplay_name="${airplay_name_input:-$default_airplay_name}"
  else
    airplay_name="$default_airplay_name"
  fi

  # Keep the Shairport Sync config simple and avoid breaking quoted strings.
  airplay_name="${airplay_name//\"/}"

  local systemctl_cmd
  systemctl_cmd="$(command -v systemctl)"

  echo "🤝 Installing Plexamp/AirPlay handover hooks..."
  sudo tee /usr/local/bin/plexamp-airplay-start >/dev/null <<EOF
#!/bin/bash
set -euo pipefail

# Pause Plexamp first so its UI/state is clean, then stop the service so
# Shairport Sync can take the audio device without fighting Plexamp.
curl --silent --fail --max-time 2 "$PLEXAMP_URL/player/playback/pause" >/dev/null 2>&1 || true
sleep 1
sudo $systemctl_cmd stop plexamp.service >/dev/null 2>&1 || true
EOF

  sudo tee /usr/local/bin/plexamp-airplay-stop >/dev/null <<EOF
#!/bin/bash
set -euo pipefail

# Bring Plexamp Headless back after the AirPlay session has fully ended.
sudo $systemctl_cmd start plexamp.service >/dev/null 2>&1 || true
EOF

  sudo chmod +x /usr/local/bin/plexamp-airplay-start /usr/local/bin/plexamp-airplay-stop

  if id shairport-sync >/dev/null 2>&1; then
    echo "🔐 Allowing Shairport Sync to start/stop only the Plexamp service..."
    sudo tee /etc/sudoers.d/shairport-sync-plexamp >/dev/null <<EOF
shairport-sync ALL=(root) NOPASSWD: $systemctl_cmd stop plexamp.service, $systemctl_cmd start plexamp.service
EOF
    sudo chmod 0440 /etc/sudoers.d/shairport-sync-plexamp
    sudo visudo -cf /etc/sudoers.d/shairport-sync-plexamp >/dev/null
  else
    echo "⚠️  Could not find a shairport-sync user; skipping sudoers handover rule."
  fi

  if [ -f /etc/shairport-sync.conf ]; then
    sudo cp /etc/shairport-sync.conf "/etc/shairport-sync.conf.backup.$(date +%Y%m%d-%H%M%S)"
  fi

  echo "⚙️  Writing Shairport Sync configuration..."
  sudo tee /etc/shairport-sync.conf >/dev/null <<EOF
general = {
  name = "$airplay_name";
  output_backend = "alsa";
};

sessioncontrol = {
  run_this_before_play_begins = "/usr/local/bin/plexamp-airplay-start";
  run_this_after_play_ends = "/usr/local/bin/plexamp-airplay-stop";
  active_state_timeout = 10.0;
  wait_for_completion = "yes";
};

alsa = {
  output_device = "$AIRPLAY_OUTPUT_DEVICE";
};
EOF

  echo "🚦 Enabling AirPlay services..."
  sudo systemctl daemon-reload
  sudo systemctl enable avahi-daemon
  sudo systemctl restart avahi-daemon
  sudo systemctl enable shairport-sync
  sudo systemctl restart shairport-sync

  if systemctl list-unit-files plexamp.service >/dev/null 2>&1; then
    sudo systemctl start plexamp.service || true
  else
    echo "⚠️  plexamp.service was not found. Install Plexamp Headless before relying on AirPlay handover."
  fi

  echo "✅ AirPlay setup complete. Look for '$airplay_name' in the iOS/macOS AirPlay picker after reboot."
}

echo "📦 Updating system..."
sudo apt update && sudo apt upgrade -y

echo "💾 Installing required packages..."
sudo apt install -y python3 python3-pip python3-venv python3-lgpio git i2c-tools curl

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

configure_airplay

echo "✅ Setup complete!"
echo "🔁 Please reboot your Pi so group changes, the NFC listener service, kiosk UI, and optional AirPlay setup all start cleanly."
