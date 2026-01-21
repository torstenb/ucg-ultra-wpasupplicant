#!/bin/bash
#
# setup-wpasupplicant-ultra-tracked.sh
# Description: Configure and persist wpa_supplicant for UniFi Cloud Gateway Ultra
#              with systemd overrides and package re-installation hooks.
# License: GPL-3.0-or-later (see LICENSE)
# Repository: https://github.com/torstenb/ucg-ultra-wpasupplicant
set -e

# ===========================
# Configuration
# ===========================
WAN_IFACE="eth4"  # ← change this to match your WAN port, e.g. eth1, eth0, etc.

TEMPLATE="/lib/systemd/system/wpa_supplicant-wired@.service"
# Tracks only the upstream unit template hash; does NOT hash your config or certs.
MARKER="/etc/wpa_supplicant/.wpa_unit_checksum"
OVERRIDE_DIR="/etc/systemd/system/wpa_supplicant-wired@${WAN_IFACE}.service.d"
OVERRIDE="${OVERRIDE_DIR}/override.conf"

# ===========================
# Function: apply systemd override
# ===========================
apply_override() {
  echo "🔍 Applying network-aware override for interface ${WAN_IFACE}…"
  mkdir -p "${OVERRIDE_DIR}"

  cat > "${OVERRIDE}" <<EOF
[Unit]
# Start as soon as the interface exists; do not wait for network-online.
Wants=network.target
Before=network.target
After=sys-subsystem-net-devices-${WAN_IFACE}.device
BindsTo=sys-subsystem-net-devices-${WAN_IFACE}.device
AssertPathExists=/etc/wpa_supplicant/wpa_supplicant-wired-${WAN_IFACE}.conf
StartLimitIntervalSec=10
StartLimitBurst=4

[Service]
ExecStart=/sbin/wpa_supplicant -i${WAN_IFACE} -Dwired -c/etc/wpa_supplicant/wpa_supplicant-wired-${WAN_IFACE}.conf
Restart=on-failure
RestartSec=2
EOF

  # Store checksum of the original template to detect upstream updates.
  # This prevents repeated re-application unless the vendor unit changes.
  sha256sum "${TEMPLATE}" | awk '{print $1}' > "${MARKER}"

  systemctl daemon-reload
  systemctl enable "wpa_supplicant-wired@${WAN_IFACE}"
  systemctl restart "wpa_supplicant-wired@${WAN_IFACE}"
  echo "✅ Override applied and checksum saved."
}

# ===========================
# Main: Only re-apply if template changed.
# Note: This is not watching /etc/wpa_supplicant/* or certs, so edits there
# will not trigger re-apply/restart loops.
# ===========================
current_sum="$(sha256sum "${TEMPLATE}" | awk '{print $1}')"
if [[ ! -f "${MARKER}" || "${current_sum}" != "$(cat "${MARKER}")" ]]; then
  apply_override
else
  echo "✅ Override already applied and up-to-date."
fi

# ===========================
# Setup persistent reinstall service
# ===========================
cat > /etc/systemd/system/reinstall-wpa.service <<EOF
[Unit]
Description=Reinstall wpa_supplicant after firmware update
AssertPathExistsGlob=/etc/wpa_supplicant/packages/wpasupplicant*arm64.deb
AssertPathExistsGlob=/etc/wpa_supplicant/packages/libpcsclite1*arm64.deb
ConditionPathExists=!/sbin/wpa_supplicant

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'dpkg -i /etc/wpa_supplicant/packages/*.deb'
ExecStart=/bin/bash -c 'systemctl start wpa_supplicant-wired@${WAN_IFACE}'
ExecStartPost=/bin/bash -c 'systemctl enable wpa_supplicant-wired@${WAN_IFACE}'
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable reinstall-wpa.service
echo "✅ Persistent reinstall service installed for interface ${WAN_IFACE}."
