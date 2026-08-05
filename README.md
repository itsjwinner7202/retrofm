# RetroFM

RetroFM is a Raspberry Pi-based FM radio transmitter featuring an intuitive web interface for uploading, queueing, and playing audio files.

>  **IMPORTANT DISCLAIMER & LEGAL NOTICE** 
> 
> **1. RF Compliance & Harmonics:** 
> Broadcasting on FM frequencies without a license is illegal in most countries. Raspberry Pi GPIO pins output square waves that generate significant RF harmonics across unintended frequency bands (including air traffic control and emergency bands). You **MUST** connect a suitable **bandpass filter (BPF)** to the output pin (GPIO 4 / Pin 7) before transmitting.
>
> **2. Disclaimer of Liability:** 
> This project is provided "AS IS" for educational and experimental purposes only. The creators and contributors of RetroFM take no responsibility for any interference caused, regulatory fines incurred, or legal action taken as a result of using this software or hardware design. Operational compliance rests entirely on the end user.

---

##  Features & Enclosure

* **Intuitive Web UI:** Upload and manage music tracks directly through your browser.
* **Integrated 3D Case:** Includes custom 3D-printable enclosure files (STLs/CAD) tailored for the Raspberry Pi Zero layout and antenna mount.

---

##  License & Third-Party Credits

This project is licensed under the **GNU General Public License v3.0 (GPLv3)** - see the [LICENSE](LICENSE) file for details.

### Third-Party Software & Works

* **pifmadv:** This project uses [pifmadv](https://github.com/MychiDarko/pifmadv), an advanced FM transmitter software for Raspberry Pi, licensed under the GNU General Public License v3.0 (GPLv3).
* **RetroFM Enclosure Design:** The 3D enclosure models included in this repository are released under the **GNU GPLv3** alongside the software codebase.

