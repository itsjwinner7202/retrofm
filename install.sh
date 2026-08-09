#!/bin/bash
set -euo pipefail

INSTALL_DIR=/opt/retrofm
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_FILE_NAME=retrofm.service
SERVICE_DEST=/etc/systemd/system/${SERVICE_FILE_NAME}

if [ "$(id -u)" -ne 0 ]; then
  echo "This installer must be run with sudo or as root."
  echo "Usage: sudo $0"
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "Error: apt-get is required for this installer."
  exit 1
fi

echo "Installing RetroFM to ${INSTALL_DIR}..."

# Update base packages and curl/ca-certificates
apt-get update
apt-get install -y curl ca-certificates build-essential libsndfile1-dev libsoxr-dev git hostapd dnsmasq rsync

# Install Node.js v20 LTS via NodeSource
echo "Setting up Node.js 20.x repository..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Ensure /usr/bin/node exists and points to the newly installed Node 20 binary
NODE_BIN_PATH=$(command -v node || echo "/usr/local/bin/node")
if [ -f "$NODE_BIN_PATH" ]; then
  ln -sf "$NODE_BIN_PATH" /usr/bin/node
  echo "Node.js version $(/usr/bin/node -v) set at /usr/bin/node"
else
  echo "Error: Node.js installation failed."
  exit 1
fi

mkdir -p "${INSTALL_DIR}"
rsync -a --delete --exclude='.git' "${SCRIPT_DIR}/" "${INSTALL_DIR}/"

cd "${INSTALL_DIR}/src"
npm install

cd "${INSTALL_DIR}/src/PiFmAdv/src"
make clean
if ! make; then
  echo "Error: Failed to compile PiFmAdv. Check that build-essential and required libraries are installed."
  exit 1
fi

if [ ! -f "${INSTALL_DIR}/src/PiFmAdv/src/pi_fm_adv" ]; then
  echo "Error: pi_fm_adv binary was not created. Compilation may have failed silently."
  exit 1
fi
echo "Successfully compiled PiFmAdv to ${INSTALL_DIR}/src/PiFmAdv/src/pi_fm_adv"

mkdir -p "${INSTALL_DIR}/src/public/songs"
chmod 755 "${INSTALL_DIR}/src/public/songs"

echo "Configuring RetroFM Wi-Fi access point and captive portal..."

HOSTAPD_CONF=/etc/hostapd/hostapd.conf
if [ ! -f "${HOSTAPD_CONF}" ]; then
  cat > "${HOSTAPD_CONF}" <<'EOF'
interface=wlan0
driver=nl80211
ssid=RetroFM
hw_mode=g
channel=6
ieee80211n=1
wmm_enabled=1
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
EOF
fi

DEFAULT_HOSTAPD=/etc/default/hostapd
if [ -f "${DEFAULT_HOSTAPD}" ]; then
  if grep -q '^DAEMON_CONF=' "${DEFAULT_HOSTAPD}"; then
    sed -i "s|^DAEMON_CONF=.*|DAEMON_CONF=\"${HOSTAPD_CONF}\"|" "${DEFAULT_HOSTAPD}"
  else
    echo "DAEMON_CONF=\"${HOSTAPD_CONF}\"" >> "${DEFAULT_HOSTAPD}"
  fi
else
  echo "DAEMON_CONF=\"${HOSTAPD_CONF}\"" > "${DEFAULT_HOSTAPD}"
fi

DNSMASQ_CONF=/etc/dnsmasq.d/retrofm.conf
cat > "${DNSMASQ_CONF}" <<'EOF'
interface=wlan0
dhcp-range=192.168.50.10,192.168.50.100,255.255.255.0,24h
address=/#/192.168.50.1
no-resolv
cache-size=0
EOF

DHCPCD_CONF=/etc/dhcpcd.conf
if ! grep -q 'interface wlan0' "${DHCPCD_CONF}"; then
  cat >> "${DHCPCD_CONF}" <<'EOF'

interface wlan0
    static ip_address=192.168.50.1/24
    nohook wpa_supplicant
EOF
fi

# Verify wlan0 interface exists
if ! ip link show wlan0 > /dev/null 2>&1; then
  echo "Warning: wlan0 interface not found. WiFi hardware may not be available."
fi

systemctl unmask hostapd
systemctl enable hostapd
systemctl enable dnsmasq
systemctl restart dhcpcd

# Verify services started successfully
if ! systemctl restart hostapd 2>&1; then
  echo "Error: Failed to start hostapd. Check /etc/hostapd/hostapd.conf configuration."
  exit 1
fi

if ! systemctl restart dnsmasq 2>&1; then
  echo "Error: Failed to start dnsmasq. Check /etc/dnsmasq.d/retrofm.conf configuration."
  exit 1
fi

# Only modify gpu_freq for Pi 2/3/4 (skip for Pi Zero and Pi 1)
PI_MODEL=$(grep -oP 'Revision\s*:\s*\K.*' /proc/cpuinfo | tail -1)
if [ ! -z "${PI_MODEL}" ]; then
  CONFIG_FILE=/boot/config.txt
  if [ -f "${CONFIG_FILE}" ]; then
    cp -n "${CONFIG_FILE}" "${CONFIG_FILE}.retrofm.bak"
    if grep -q '^gpu_freq=' "${CONFIG_FILE}"; then
      echo "gpu_freq setting already present in ${CONFIG_FILE}; leaving it unchanged."
    else
      echo 'gpu_freq=250' >> "${CONFIG_FILE}"
      echo "Added gpu_freq=250 to ${CONFIG_FILE}."
    fi
  fi
fi

if [ -f "${SCRIPT_DIR}/${SERVICE_FILE_NAME}" ]; then
  install -m 644 "${SCRIPT_DIR}/${SERVICE_FILE_NAME}" "${SERVICE_DEST}"
else
  echo "Error: ${SERVICE_FILE_NAME} not found in ${SCRIPT_DIR}."
  exit 1
fi

systemctl daemon-reload
systemctl enable ${SERVICE_FILE_NAME}
systemctl restart ${SERVICE_FILE_NAME}

echo ""
echo "RetroFM installation complete."
echo "Service is enabled and started as ${SERVICE_FILE_NAME}."
echo ""
echo "Next steps:"
echo "1. Connect to 'RetroFM' WiFi network from another device"
echo "2. Open your browser and go to http://192.168.50.1"
echo "3. You should see the captive portal redirect automatically"
echo ""
echo "If auto-redirect doesn't work, try:"
echo "  - Visiting http://192.168.50.1 directly"
echo "  - Or http://192.168.50.1:80"
echo ""
echo "To check service status: sudo systemctl status retrofm.service"
echo "To view logs: sudo journalctl -u retrofm.service -f"
