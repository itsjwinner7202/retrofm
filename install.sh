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

apt-get update
apt-get install -y nodejs npm build-essential libsndfile1-dev libsoxr-dev git hostapd dnsmasq

if ! command -v node >/dev/null 2>&1; then
  if command -v nodejs >/dev/null 2>&1; then
    ln -sf "$(command -v nodejs)" /usr/bin/node
    echo "Created /usr/bin/node symlink for nodejs."
  else
    echo "Error: node or nodejs is not installed after apt-get."
    exit 1
  fi
fi

mkdir -p "${INSTALL_DIR}"
rsync -a --delete --exclude='.git' "${SCRIPT_DIR}/" "${INSTALL_DIR}/"

cd "${INSTALL_DIR}/src"
npm install

cd "${INSTALL_DIR}/src/PiFmAdv/src"
make clean
make

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
if ! grep -q '^interface wlan0' "${DHCPCD_CONF}"; then
  cat >> "${DHCPCD_CONF}" <<'EOF'

interface wlan0
    static ip_address=192.168.50.1/24
    nohook wpa_supplicant
EOF
fi

systemctl unmask hostapd
systemctl enable hostapd
systemctl enable dnsmasq
systemctl restart dhcpcd
systemctl restart hostapd
systemctl restart dnsmasq

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

if [ -f "${SCRIPT_DIR}/${SERVICE_FILE_NAME}" ]; then
  install -m 644 "${SCRIPT_DIR}/${SERVICE_FILE_NAME}" "${SERVICE_DEST}"
else
  echo "Error: ${SERVICE_FILE_NAME} not found in ${SCRIPT_DIR}."
  exit 1
fi

systemctl daemon-reload
systemctl enable ${SERVICE_FILE_NAME}
systemctl restart ${SERVICE_FILE_NAME}

echo "RetroFM installation complete."
echo "Service is enabled and started as ${SERVICE_FILE_NAME}."
echo "Browse to http://<raspberry-pi-ip>:3000 to use RetroFM."
