#!/bin/bash
set -euo pipefail

REPO_URL="https://github.com/AndyBettger/Plexamp-NFC-Listener.git"
REPO_DIR="$HOME/Plexamp-NFC-Listener"
PLEXAMP_URL="http://localhost:32500"
AIRPLAY_OUTPUT_DEVICE="${AIRPLAY_OUTPUT_DEVICE:-}"

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

get_airplay_output_devices() {
  if ! command -v aplay >/dev/null 2>&1; then
    echo "default|Default ALSA device"
    return 0
  fi

  # Prefer plughw devices for Shairport Sync so ALSA can perform any needed
  # software conversion while still targeting the exact hardware output.
  aplay -l | sed -n 's/^card [0-9]\+: \([^ ]*\) \[\([^]]*\)\], device \([0-9]\+\): \(.*\)$/plughw:CARD=\1,DEV=\3|\2 - \4/p'

  # Always include a generic fallback for unusual systems.
  echo "default|Default ALSA device"
}

detect_airplay_output_device() {
  if [ -n "${AIRPLAY_OUTPUT_DEVICE:-}" ]; then
    echo "$AIRPLAY_OUTPUT_DEVICE"
    return 0
  fi

  local devices
  devices="$(get_airplay_output_devices)"

  # Prefer the Raspberry Pi DAC Pro / IQaudIO DAC Pro if present.
  if printf '%s\n' "$devices" | cut -d'|' -f1 | grep -qx 'plughw:CARD=Pro,DEV=0'; then
    echo 'plughw:CARD=Pro,DEV=0'
    return 0
  fi

  # Otherwise prefer the first non-HDMI plughw device, which is usually the DAC HAT.
  local non_hdmi_device
  non_hdmi_device="$(printf '%s\n' "$devices" | awk -F'|' '$1 ~ /^plughw:CARD=/ && $1 !~ /vc4hdmi/ { print $1; exit }')"
  if [ -n "$non_hdmi_device" ]; then
    echo "$non_hdmi_device"
    return 0
  fi

  echo 'default'
}

choose_airplay_output_device() {
  if [ -n "${AIRPLAY_OUTPUT_DEVICE:-}" ]; then
    echo "$AIRPLAY_OUTPUT_DEVICE"
    return 0
  fi

  local recommended_device
  recommended_device="$(detect_airplay_output_device)"

  if [ ! -t 0 ]; then
    echo "$recommended_device"
    return 0
  fi

  mapfile -t audio_devices < <(get_airplay_output_devices)

  if [ "${#audio_devices[@]}" -eq 0 ]; then
    echo "$recommended_device"
    return 0
  fi

  echo "🎚️  Available AirPlay ALSA output devices:" >&2

  local i
  local device
  local description
  local marker
  for i in "${!audio_devices[@]}"; do
    device="${audio_devices[$i]%%|*}"
    description="${audio_devices[$i]#*|}"
    marker=""
    if [ "$device" = "$recommended_device" ]; then
      marker="  ← recommended"
    fi
    printf '  %d) %s — %s%s\n' "$((i + 1))" "$device" "$description" "$marker" >&2
  done

  echo "  C) Custom ALSA device string" >&2

  local choice
  local custom_device
  read -r -p "Choose AirPlay output device [recommended: $recommended_device]: " choice

  if [ -z "$choice" ]; then
    echo "$recommended_device"
    return 0
  fi

  case "${choice,,}" in
    c|custom)
      read -r -p "Enter custom ALSA output device: " custom_device
      echo "${custom_device:-$recommended_device}"
      return 0
      ;;
  esac

  if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#audio_devices[@]}" ]; then
    echo "${audio_devices[$((choice - 1))]%%|*}"
    return 0
  fi

  # Advanced escape hatch: allow the user to type the ALSA device directly.
  echo "$choice"
}

configure_airplay() {
  echo "🍏 Optional AirPlay receiver setup..."

  if ! prompt_yes_no "Install and configure AirPlay audio receiver using Shairport Sync? [y/N]: " "no" "${INSTALL_AIRPLAY:-}"; then
    echo "⏭️  Skipping AirPlay setup."
    return 0
  fi

  echo "💾 Installing AirPlay packages..."
  sudo apt install -y shairport-sync avahi-daemon alsa-utils curl sudo

  local default_airplay_name
  local airplay_name_input=""
  local airplay_name
  local airplay_output_device

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

  airplay_output_device="$(choose_airplay_output_device)"
  echo "🎚️  Using AirPlay ALSA output device: $airplay_output_device"

  local systemctl_cmd
  systemctl_cmd="$(command -v systemctl)"

  echo "🤝 Installing Plexamp/AirPlay handover hooks..."
  sudo tee /usr/local/bin/plexamp-airplay-start >/dev/null <<EOHOOKSTART
#!/bin/bash
set -euo pipefail

# Pause Plexamp first so its UI/state is clean, then stop the service so
# Shairport Sync can take the audio device without fighting Plexamp.
curl --silent --fail --max-time 2 "$PLEXAMP_URL/player/playback/pause" >/dev/null 2>&1 || true
sleep 1
sudo $systemctl_cmd stop plexamp.service >/dev/null 2>&1 || true
EOHOOKSTART

  sudo tee /usr/local/bin/plexamp-airplay-stop >/dev/null <<EOHOOKSTOP
#!/bin/bash
set -euo pipefail

# Bring Plexamp Headless back after the AirPlay session has fully ended.
sudo $systemctl_cmd start plexamp.service >/dev/null 2>&1 || true
EOHOOKSTOP

  sudo chmod +x /usr/local/bin/plexamp-airplay-start /usr/local/bin/plexamp-airplay-stop

  if id shairport-sync >/dev/null 2>&1; then
    echo "🔐 Allowing Shairport Sync to start/stop only the Plexamp service..."
    sudo tee /etc/sudoers.d/shairport-sync-plexamp >/dev/null <<EOSUDOERS
shairport-sync ALL=(root) NOPASSWD: $systemctl_cmd stop plexamp.service, $systemctl_cmd start plexamp.service
EOSUDOERS
    sudo chmod 0440 /etc/sudoers.d/shairport-sync-plexamp
    sudo visudo -cf /etc/sudoers.d/shairport-sync-plexamp >/dev/null
  else
    echo "⚠️  Could not find a shairport-sync user; skipping sudoers handover rule."
  fi

  if [ -f /etc/shairport-sync.conf ]; then
    sudo cp /etc/shairport-sync.conf "/etc/shairport-sync.conf.backup.$(date +%Y%m%d-%H%M%S)"
  fi

  echo "⚙️  Writing Shairport Sync configuration..."
  sudo tee /etc/shairport-sync.conf >/dev/null <<EOSHAIRPORT
// Generated by Plexamp-NFC-Listener setup.sh.
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
  output_device = "$airplay_output_device";
};
EOSHAIRPORT

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
sudo tee /etc/systemd/system/nfc-listener.service >/dev/null <<EOSERVICE
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
EOSERVICE

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable nfc-listener.service
sudo systemctl restart nfc-listener.service

echo "🌐 Configuring Chromium to start in kiosk mode..."

# Raspberry Pi OS Bookworm/Trixie uses labwc/Wayland by default.
mkdir -p ~/.config/labwc
cat > ~/.config/labwc/autostart <<EOLABWC
sleep 10
$CHROMIUM_CMD --kiosk --start-maximized --noerrdialogs --disable-infobars --no-first-run "$PLEXAMP_URL" &
EOLABWC
chmod +x ~/.config/labwc/autostart

# Legacy X11/LXDE autostart fallback for older Raspberry Pi OS releases.
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/kiosk.desktop <<EODESKTOP
[Desktop Entry]
Type=Application
Name=Plexamp Kiosk
Exec=bash -c 'sleep 10 && $CHROMIUM_CMD --kiosk --start-maximized --noerrdialogs --disable-infobars --no-first-run "$PLEXAMP_URL"'
X-GNOME-Autostart-enabled=true
EODESKTOP

configure_airplay

echo "✅ Setup complete!"
echo "🔁 Please reboot your Pi so group changes, the NFC listener service, kiosk UI, and optional AirPlay setup all start cleanly."
