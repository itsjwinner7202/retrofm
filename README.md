# RetroFM

RetroFM is a Raspberry Pi-based FM radio transmitter featuring an intuitive web interface for uploading, queueing, and playing audio files.

>  **IMPORTANT DISCLAIMER & LEGAL NOTICE** 
> 
> **1. RF Compliance & Harmonics:** 
> Broadcasting on FM frequencies without a license is illegal in most countries. Raspberry Pi GPIO pins output square waves that generate significant RF harmonics across unintended frequency bands (including air traffic control and emergency bands). You **MUST** connect a suitable **bandpass filter (BPF)** to the output pin (GPIO 4 / Pin 7) before transmitting.
>
> **2. Disclaimer of Liability:** 
> This project is provided "AS IS" for educational and experimental purposes only. The creators and contributors of RetroFM take no responsibility for any interference caused, regulatory fines incurred, or legal action taken as a result of using this software or hardware design. Operational compliance rests entirely on the end user.
>
> **3.This project is intended strictly for ultra-low-power, short-range experimental use within your immediate vehicle or room.**

---

**Make sure your pi is connected to the internet before running the install.sh script**

##  Install (over ssh ethernet/ssh usb g_ether/monitor)

**RPi OS Bullseye is needed for optimal performance and dhcpcd service required for this version's Wifi AP**
https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2022-01-28/2022-01-28-raspios-bullseye-arm64-lite.zip
**Username: pi**  
**Password: raspberry**  
**Hostname: raspberrypi**  
**Dont forget to create an empty ssh file with no extension in the boot partition on the sdcard after flashing**  

For usb g_ether, in the boot partition, add **modules-load=dwc2,g_ether** immediately after rootwait in the cmdline.txt file.  
In config.txt, add **dtoverlay=dwc2** on a new line at the bottom of the file.  
You can now ssh into it via usb by using **ssh pi@raspberrypi.local**  

```bash
cd /tmp
curl -L -o retrofm.tar.gz https://codeload.github.com/itsjwinner7202/retrofm/tar.gz/main
mkdir -p /tmp/retrofm-install
tar -xzf retrofm.tar.gz -C /tmp/retrofm-install --strip-components=1
cd /tmp/retrofm-install
sudo bash install.sh
```

##  Install (over wifi ssh)

**RPi OS Bullseye is needed for optimal performance and dhcpcd service required for this version's Wifi AP**
https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2022-01-28/2022-01-28-raspios-bullseye-arm64-lite.zip
**Username: pi**  
**Password: raspberry**  
**Hostname: raspberrypi**  
**Dont forget to create an empty ssh file with no extension in the boot partition on the sdcard after flashing**  

```bash
cd /tmp
curl -L -o retrofm.tar.gz https://codeload.github.com/itsjwinner7202/retrofm/tar.gz/main
mkdir -p /tmp/retrofm-install
tar -xzf retrofm.tar.gz -C /tmp/retrofm-install --strip-components=1
cd /tmp/retrofm-install
sudo apt-get install -y screen
screen -S install_retrofm
sudo ./install.sh
```

**You will get disconnected from SSH as soon as the script sets wlan0 to AP moode, but the installation will stay running in the background**  

### Post-Installation Setup

After installation completes, verify everything is working:

```bash
sudo bash verify-install.sh
```

Then connect to the WiFi network named **`RetroFM`** from another device and open your browser to:
- **http://192.168.50.1** (automatic captive portal)
- Or manually navigate if auto-redirect doesn't work

### Troubleshooting

**For Wifi terminal access, connect to RetroFM network then ssh into it: pi@192.168.50.1**

If the WiFi portal doesn't appear:

```bash
# Check service status
sudo systemctl status retrofm.service

# View live logs
sudo journalctl -u retrofm.service -f

# Restart the service
sudo systemctl restart retrofm.service
```
---

##  Features & Enclosure

* **Intuitive Web UI:** Upload and manage music tracks directly through your browser.
* **Built-in Wi-Fi captive portal:** On boot the Pi broadcasts a Wi-Fi network named `RetroFM` that redirects clients to the RetroFM dashboard.
* **Integrated 3D Case:** Includes custom 3D-printable enclosure files (STL) tailored for the Raspberry Pi Zero layout and antenna mount.

---

##  License & Third-Party Credits

This project is licensed under the **GNU General Public License v3.0 (GPLv3)** - see the [LICENSE](LICENSE) file for details.

### Third-Party Software & Works

* **pifmadv:** This project uses [pifmadv](https://github.com/miegl/PiFmAdv), an advanced FM transmitter software for Raspberry Pi, licensed under the GNU General Public License v3.0 (GPLv3).
* **RetroFM Enclosure Design:** The 3D enclosure models included in this repository are released under the **GNU GPLv3** alongside the software codebase.

### Filter Example

```text
Raspberry Pi               Filter Module                Antenna
[ GPIO 4 ] ───▶ [ 56nH Inductor ] ──┬── [ 56nH Inductor ] ───▶  [ Wire ]
                                    │
                                [ 22pF ]
                                    │
[  GND   ] ─────────────────────────┴────────────────────────▶  [ GND  ]
