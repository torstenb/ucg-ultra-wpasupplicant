# 🛜 Unifi Cloud Gateway Ultra — Bypass ATT Modem with `wpa_supplicant`

Authenticate your **Unifi Cloud Gateway Ultra** directly with AT&T Fiber — no stock modem required — using `wpa_supplicant`, EAP authentication, and your extracted certificates.

This guide updates legacy UDM/UXG walkthroughs with a **network-aware, persistent service** designed for the UCG Ultra.

---

## 📋 Contents

- ⚙️ [Prerequisites](#prerequisites)
- 📦 [1. Install `wpa_supplicant`](#-1-install-wpa_supplicant)
- 📁 [2. Upload Certs & Config](#-2-upload-certs--config)
- 🎭 [3. Spoof AT&T Gateway MAC](#-3-spoof-att-mac-address)
- 🧪 [4. Test `wpa_supplicant`](#-4-test-wpa_supplicant)
- 🚀 [5. Setup Service for Startup (Override + Tracking)](#-5-setup-service-for-startup-override--tracking)
- 🔁 [6. Persist Through Firmware Updates](#-6-persist-through-firmware-updates)
- 🧰 [Troubleshooting](#-troubleshooting)
- 🙏 [Credits](#-credits)

---

## Prerequisites

- Extracted `.pem` certs and config from AT&T modem (see example for [`BGW210 and BGW320`](https://github.com/0x888e/certs))
- Gateway MAC address from your AT&T router
- SSH access to your UCG Ultra (usually as `root`)

---

## 📦 1. Install `wpa_supplicant`

SSH into your UCG Ultra:

```bash
apt update
apt install -y wpasupplicant
```
Create cert folder:
```bash
mkdir -p /etc/wpa_supplicant/certs
```

---

## 📁 2. Upload Certs & Config
From your computer:
```bash
scp *.pem root@<ucg-ip>:/etc/wpa_supplicant/certs
scp wpa_supplicant.conf root@<ucg-ip>:/etc/wpa_supplicant/
```
Edit `/etc/wpa_supplicant/wpa_supplicant.conf` and use absolute paths:
```ini
ca_cert="/etc/wpa_supplicant/certs/CA_XXXXXX.pem"
client_cert="/etc/wpa_supplicant/certs/Client_XXXXXX.pem"
private_key="/etc/wpa_supplicant/certs/PrivateKey_PKCS1_XXXXXX.pem"
```

---

## 🎭 3. Spoof AT&T MAC Address
In Unifi dashboard (Settings → Internet → WAN1), set:
* ✅ VLAN ID: 0
* ✅ QoS Tag: 1
* ✅ MAC Override: `<AT&T Gateway MAC>`

---

## 🧪 4. Test wpa_supplicant
Manual test:
```bash
wpa_supplicant -ieth4 -Dwired -c/etc/wpa_supplicant/wpa_supplicant.conf
```
✅ Look for:
```bash
CTRL-EVENT-EAP-SUCCESS
CTRL-EVENT-CONNECTED
```
Use `Ctrl+C` to exit after test.


---

## 🚀 5. Setup Service for Startup (Override + Tracking)
Rename config file
```bash
mv /etc/wpa_supplicant/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant-wired-eth4.conf
```
Add and run version tracking setup script
```bash
vi /usr/local/bin/setup-wpasupplicant-ultra-tracked.sh
```
Paste this script, [setup/setup-wpasupplicant-ultra-tracked.sh](./setup/setup-wpasupplicant-ultra-tracked.sh), save, then:
```bash
chmod +x /usr/local/bin/setup-wpasupplicant-ultra-tracked.sh
sudo bash /usr/local/bin/setup-wpasupplicant-ultra-tracked.sh
```
✅ This:
* Installs a systemd override (device-based ordering, no `network-online.target`)
* Enables `wpa_supplicant-wired@eth4` with clean startup
* Adds reinstall logic for firmware survivability


---

## 🔁 6. Persist Through Firmware Updates
Cache install files:
```bash
mkdir -p /etc/wpa_supplicant/packages
apt-get install --download-only --reinstall wpasupplicant libpcsclite1
cp /var/cache/apt/archives/wpasupplicant_*arm64.deb \
   /var/cache/apt/archives/libpcsclite1_*arm64.deb \
   /etc/wpa_supplicant/packages/
```
✅ These are used by the `reinstall-wpa.service` added in the previous script.

No further action needed — you're covered on reboot and post-upgrade.


---

## 🧰 Troubleshooting
* Check `systemctl status wpa_supplicant-wired@eth4`
* Review `/etc/wpa_supplicant/wpa_supplicant-wired-eth4.conf` paths
* Confirm MAC spoofing applied (dashboard or shell)
* Re-run the setup script after major UniFi OS update if needed


---

## 🙏 Credits

**Adapted from:**
- [evie-lau/Unifi-gateway-wpa-supplicant](https://github.com/evie-lau/Unifi-gateway-wpa-supplicant)
- [uchagani/ucg-ultra-wpa-supplicant](https://github.com/uchagani/ucg-ultra-wpa-supplicant)

**Referenced Work:**
- [superm1](https://github.com/superm1) — for foundational insights and tooling around systemd + firmware workflows
