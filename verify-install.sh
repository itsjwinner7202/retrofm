#!/bin/bash
# RetroFM Installation Verification Script
# Run this after installation to verify everything is working correctly

set -euo pipefail

INSTALL_DIR=/opt/retrofm
ERRORS=0
WARNINGS=0

echo "============================================"
echo "RetroFM Installation Verification"
echo "============================================"
echo ""

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
  echo "⚠️  Warning: Some checks require root. Run with sudo for complete verification."
  echo "   sudo bash verify-install.sh"
  echo ""
fi

# 1. Check installation directory
echo "1. Checking installation directory..."
if [ -d "${INSTALL_DIR}" ]; then
    echo "   ✓ ${INSTALL_DIR} exists"
else
    echo "   ✗ ERROR: ${INSTALL_DIR} not found"
    ((ERRORS++))
fi

# 2. Check Node.js binary
echo "2. Checking Node.js installation..."
if command -v node >/dev/null 2>&1; then
    NODE_VERSION=$(node -v)
    echo "   ✓ Node.js installed: $NODE_VERSION"
else
    echo "   ✗ ERROR: node not found"
    ((ERRORS++))
fi

# 3. Check PiFmAdv binary
echo "3. Checking PiFmAdv FM transmitter..."
if [ -f "${INSTALL_DIR}/src/PiFmAdv/src/pi_fm_adv" ]; then
    echo "   ✓ pi_fm_adv binary found and executable"
else
    echo "   ✗ ERROR: pi_fm_adv binary not found at ${INSTALL_DIR}/src/PiFmAdv/src/pi_fm_adv"
    echo "   Re-run the installer or check build logs"
    ((ERRORS++))
fi

# 4. Check wlan0 interface
echo "4. Checking WiFi interface (wlan0)..."
if ip link show wlan0 > /dev/null 2>&1; then
    echo "   ✓ wlan0 interface found"
else
    echo "   ⚠️  WARNING: wlan0 interface not found. WiFi may not be available."
    echo "   Make sure WiFi hardware is connected and drivers are loaded."
    ((WARNINGS++))
fi

# 5. Check hostapd configuration
echo "5. Checking hostapd WiFi access point..."
if [ -f "/etc/hostapd/hostapd.conf" ]; then
    if grep -q "ssid=RetroFM" /etc/hostapd/hostapd.conf; then
        echo "   ✓ hostapd configured for RetroFM network"
    else
        echo "   ⚠️  WARNING: hostapd.conf exists but SSID may not be set to RetroFM"
        ((WARNINGS++))
    fi
else
    echo "   ✗ ERROR: /etc/hostapd/hostapd.conf not found"
    ((ERRORS++))
fi

# 6. Check dnsmasq configuration
echo "6. Checking dnsmasq DNS/DHCP..."
if [ -f "/etc/dnsmasq.d/retrofm.conf" ]; then
    echo "   ✓ dnsmasq configuration found"
else
    echo "   ✗ ERROR: /etc/dnsmasq.d/retrofm.conf not found"
    ((ERRORS++))
fi

# 7. Check systemd service
echo "7. Checking systemd service..."
if systemctl list-unit-files | grep -q "retrofm.service"; then
    echo "   ✓ retrofm.service is registered"
    
    if [ "$(id -u)" -eq 0 ]; then
        if systemctl is-active --quiet retrofm.service; then
            echo "   ✓ retrofm.service is running"
        else
            echo "   ⚠️  WARNING: retrofm.service is not currently running"
            echo "   Try: sudo systemctl start retrofm.service"
            ((WARNINGS++))
        fi
        
        if systemctl is-enabled --quiet retrofm.service; then
            echo "   ✓ retrofm.service is enabled (auto-start)"
        else
            echo "   ⚠️  WARNING: retrofm.service is not enabled for auto-start"
            echo "   Try: sudo systemctl enable retrofm.service"
            ((WARNINGS++))
        fi
    fi
else
    echo "   ✗ ERROR: retrofm.service not found"
    ((ERRORS++))
fi

# 8. Check songs directory
echo "8. Checking songs directory..."
if [ -d "${INSTALL_DIR}/src/public/songs" ]; then
    PERM=$(stat -c "%a" "${INSTALL_DIR}/src/public/songs")
    if [ "$PERM" = "755" ]; then
        echo "   ✓ Songs directory exists with correct permissions (755)"
    else
        echo "   ⚠️  WARNING: Songs directory permissions are $PERM (expected 755)"
        ((WARNINGS++))
    fi
else
    echo "   ✗ ERROR: ${INSTALL_DIR}/src/public/songs not found"
    ((ERRORS++))
fi

# 9. Check npm dependencies
echo "9. Checking npm dependencies..."
if [ -d "${INSTALL_DIR}/src/node_modules" ]; then
    echo "   ✓ node_modules directory exists"
else
    echo "   ✗ ERROR: node_modules not found. Try: npm install in ${INSTALL_DIR}/src"
    ((ERRORS++))
fi

# 10. Check required system libraries
echo "10. Checking required system libraries..."
MISSING_LIBS=0
if ! dpkg -l | grep -q "libsndfile1"; then
    echo "   ✗ Missing: libsndfile1"
    ((MISSING_LIBS++))
fi
if ! dpkg -l | grep -q "libsoxr"; then
    echo "   ✗ Missing: libsoxr"
    ((MISSING_LIBS++))
fi
if [ "$MISSING_LIBS" -eq 0 ]; then
    echo "   ✓ All required libraries installed"
else
    echo "   ⚠️  WARNING: Some libraries may be missing. Try: sudo apt-get install libsndfile1-dev libsoxr-dev"
    ((WARNINGS += MISSING_LIBS))
fi

echo ""
echo "============================================"
echo "Summary:"
echo "  Errors:   $ERRORS"
echo "  Warnings: $WARNINGS"
echo "============================================"

if [ "$ERRORS" -gt 0 ]; then
    echo ""
    echo "⚠️  Installation has errors. Please fix them before using RetroFM."
    exit 1
elif [ "$WARNINGS" -gt 0 ]; then
    echo ""
    echo "⚠️  Installation complete with warnings. RetroFM may not work fully."
    echo "   Check WiFi hardware and service status."
    exit 0
else
    echo ""
    echo "✓ RetroFM is ready to use!"
    echo ""
    echo "Next steps:"
    echo "1. Connect to 'RetroFM' WiFi network from another device"
    echo "2. Open your browser to http://192.168.50.1"
    echo "3. You should be redirected to the captive portal automatically"
    echo ""
    echo "Troubleshooting:"
    echo "  View service logs: sudo journalctl -u retrofm.service -f"
    echo "  Check service status: sudo systemctl status retrofm.service"
    echo "  Restart service: sudo systemctl restart retrofm.service"
    exit 0
fi
